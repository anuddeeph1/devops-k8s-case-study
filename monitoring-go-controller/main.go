package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

type PodEvent struct {
	Timestamp time.Time         `json:"timestamp"`
	EventType string            `json:"event_type"`
	PodName   string            `json:"pod_name"`
	Namespace string            `json:"namespace"`
	PodIP     string            `json:"pod_ip,omitempty"`
	NodeName  string            `json:"node_name,omitempty"`
	Phase     string            `json:"phase"`
	Labels    map[string]string `json:"labels,omitempty"`
	Message   string            `json:"message"`
	Reason    string            `json:"reason,omitempty"`
}

// Prometheus metrics
var (
	podEventsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "pod_monitor_events_total",
			Help: "Total number of pod events observed",
		},
		[]string{"namespace", "event_type", "phase"},
	)

	activePods = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "pod_monitor_active_pods",
			Help: "Number of active pods being monitored",
		},
		[]string{"namespace", "phase"},
	)

	watcherReconnects = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "pod_monitor_watcher_reconnects_total",
			Help: "Total number of watcher reconnections",
		},
		[]string{"namespace"},
	)

	lastEventTimestamp = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "pod_monitor_last_event_timestamp",
			Help: "Timestamp of the last pod event",
		},
		[]string{"namespace"},
	)
)

type PodMonitor struct {
	clientset    *kubernetes.Clientset
	namespace    string
	logger       *log.Logger
	stopCh       chan struct{}
	retryCount   int
	maxRetries   int
	podTracker   map[string]corev1.PodPhase
	trackerMutex sync.RWMutex
}

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(podEventsTotal)
	prometheus.MustRegister(activePods)
	prometheus.MustRegister(watcherReconnects)
	prometheus.MustRegister(lastEventTimestamp)
}

func NewPodMonitor(namespace string) (*PodMonitor, error) {
	var config *rest.Config
	var err error

	// Try in-cluster config first (for when running inside Kubernetes)
	config, err = rest.InClusterConfig()
	if err != nil {
		// Fallback to kubeconfig file
		kubeconfig := os.Getenv("KUBECONFIG")
		if kubeconfig == "" {
			kubeconfig = os.Getenv("HOME") + "/.kube/config"
		}
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			return nil, fmt.Errorf("failed to create Kubernetes config: %v", err)
		}
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Kubernetes client: %v", err)
	}

	logger := log.New(os.Stdout, "[POD-MONITOR] ", log.LstdFlags|log.Lmicroseconds)

	return &PodMonitor{
		clientset:    clientset,
		namespace:    namespace,
		logger:       logger,
		stopCh:       make(chan struct{}),
		retryCount:   0,
		maxRetries:   10,
		podTracker:   make(map[string]corev1.PodPhase),
		trackerMutex: sync.RWMutex{},
	}, nil
}

func (pm *PodMonitor) logEvent(event PodEvent) {
	eventJSON, err := json.Marshal(event)
	if err != nil {
		pm.logger.Printf("❌ Failed to marshal event to JSON: %v", err)
		return
	}
	pm.logger.Printf("%s", string(eventJSON))

	// Update Prometheus metrics
	podEventsTotal.WithLabelValues(event.Namespace, event.EventType, event.Phase).Inc()
	lastEventTimestamp.WithLabelValues(event.Namespace).SetToCurrentTime()

	// Update pod phase tracking
	pm.trackerMutex.Lock()
	if event.EventType == "DELETED" {
		delete(pm.podTracker, event.PodName)
	} else {
		pm.podTracker[event.PodName] = corev1.PodPhase(event.Phase)
	}
	pm.updateActivePods()
	pm.trackerMutex.Unlock()

	// Also log in human-readable format
	switch event.EventType {
	case "ADDED":
		pm.logger.Printf("🆕 NEW POD CREATED: %s in namespace %s (Phase: %s, Node: %s)",
			event.PodName, event.Namespace, event.Phase, event.NodeName)
	case "DELETED":
		pm.logger.Printf("🗑️  POD DELETED: %s in namespace %s",
			event.PodName, event.Namespace)
	case "MODIFIED":
		pm.logger.Printf("🔄 POD UPDATED: %s in namespace %s (Phase: %s, Reason: %s)",
			event.PodName, event.Namespace, event.Phase, event.Reason)
	}
}

func (pm *PodMonitor) updateActivePods() {
	// Count pods by phase
	phaseCounts := make(map[corev1.PodPhase]int)
	for _, phase := range pm.podTracker {
		phaseCounts[phase]++
	}

	// Update Prometheus gauges
	for phase, count := range phaseCounts {
		activePods.WithLabelValues(pm.namespace, string(phase)).Set(float64(count))
	}
}

func (pm *PodMonitor) getChangeReason(oldPod, newPod *corev1.Pod) string {
	var reasons []string

	// Check phase changes
	if oldPod.Status.Phase != newPod.Status.Phase {
		reasons = append(reasons, fmt.Sprintf("Phase changed from %s to %s", oldPod.Status.Phase, newPod.Status.Phase))
	}

	// Check container status changes
	for i, container := range newPod.Status.ContainerStatuses {
		if i < len(oldPod.Status.ContainerStatuses) {
			oldContainer := oldPod.Status.ContainerStatuses[i]
			if container.Ready != oldContainer.Ready {
				reasons = append(reasons, fmt.Sprintf("Container %s readiness changed to %v", container.Name, container.Ready))
			}
			if container.RestartCount != oldContainer.RestartCount {
				reasons = append(reasons, fmt.Sprintf("Container %s restart count changed to %d", container.Name, container.RestartCount))
			}
		}
	}

	// Check condition changes
	for _, condition := range newPod.Status.Conditions {
		found := false
		for _, oldCondition := range oldPod.Status.Conditions {
			if condition.Type == oldCondition.Type {
				found = true
				if condition.Status != oldCondition.Status {
					reasons = append(reasons, fmt.Sprintf("Condition %s changed to %s", condition.Type, condition.Status))
				}
				break
			}
		}
		if !found {
			reasons = append(reasons, fmt.Sprintf("New condition %s: %s", condition.Type, condition.Status))
		}
	}

	if len(reasons) == 0 {
		return "Metadata or spec updated"
	}

	return strings.Join(reasons, "; ")
}

func (pm *PodMonitor) watchPods(ctx context.Context) error {
	var listOptions metav1.ListOptions
	if pm.namespace != "" {
		listOptions = metav1.ListOptions{
			FieldSelector: fields.Everything().String(),
		}
	}

	// Get current pods to track existing state
	existingPods := make(map[string]*corev1.Pod)
	pods, err := pm.clientset.CoreV1().Pods(pm.namespace).List(ctx, listOptions)
	if err != nil {
		return fmt.Errorf("failed to list existing pods: %v", err)
	}

	for _, pod := range pods.Items {
		// Create a copy to avoid pointer issues
		podCopy := pod.DeepCopy()
		existingPods[string(pod.UID)] = podCopy
	}

	pm.logger.Printf("🚀 Starting pod monitor for namespace: %s (found %d existing pods)", pm.namespace, len(existingPods))

	// Start watching for changes
	watcher, err := pm.clientset.CoreV1().Pods(pm.namespace).Watch(ctx, listOptions)
	if err != nil {
		return fmt.Errorf("failed to create pod watcher: %v", err)
	}

	defer watcher.Stop()

	for {
		select {
		case event, ok := <-watcher.ResultChan():
			if !ok {
				pm.retryCount++
				watcherReconnects.WithLabelValues(pm.namespace).Inc()
				if pm.retryCount >= pm.maxRetries {
					return fmt.Errorf("watch failed after %d retries", pm.maxRetries)
				}

				backoffDuration := time.Duration(pm.retryCount*pm.retryCount) * time.Second
				pm.logger.Printf("⚠️  Watch channel closed, retrying in %v (attempt %d/%d)",
					backoffDuration, pm.retryCount, pm.maxRetries)

				time.Sleep(backoffDuration)
				return pm.watchPods(ctx)
			}

			// Reset retry count on successful event
			pm.retryCount = 0

			if event.Type == watch.Error {
				pm.logger.Printf("❌ Watch error: %v", event.Object)
				continue
			}

			pod, ok := event.Object.(*corev1.Pod)
			if !ok {
				pm.logger.Printf("⚠️  Unexpected object type: %T", event.Object)
				continue
			}

			podEvent := PodEvent{
				Timestamp: time.Now(),
				EventType: string(event.Type),
				PodName:   pod.Name,
				Namespace: pod.Namespace,
				PodIP:     pod.Status.PodIP,
				NodeName:  pod.Spec.NodeName,
				Phase:     string(pod.Status.Phase),
				Labels:    pod.Labels,
			}

			switch event.Type {
			case watch.Added:
				if _, exists := existingPods[string(pod.UID)]; !exists {
					podEvent.Message = "New pod created"
					pm.logEvent(podEvent)
					existingPods[string(pod.UID)] = pod.DeepCopy()
				}

			case watch.Deleted:
				podEvent.Message = "Pod deleted"
				pm.logEvent(podEvent)
				delete(existingPods, string(pod.UID))

			case watch.Modified:
				if oldPod, exists := existingPods[string(pod.UID)]; exists {
					reason := pm.getChangeReason(oldPod, pod)
					podEvent.Reason = reason
					podEvent.Message = "Pod updated"
					pm.logEvent(podEvent)
					existingPods[string(pod.UID)] = pod.DeepCopy()
				} else {
					// This is a new pod we haven't seen before
					podEvent.Message = "New pod detected during watch"
					pm.logEvent(podEvent)
					existingPods[string(pod.UID)] = pod.DeepCopy()
				}
			}

		case <-ctx.Done():
			pm.logger.Println("🛑 Context cancelled, stopping pod monitor")
			return ctx.Err()

		case <-pm.stopCh:
			pm.logger.Println("🛑 Stop signal received, stopping pod monitor")
			return nil
		}
	}
}

func (pm *PodMonitor) startMetricsServer() {
	metricsAddr := os.Getenv("METRICS_ADDR")
	if metricsAddr == "" {
		metricsAddr = ":8080"
	}

	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	pm.logger.Printf("📊 Starting metrics server on %s", metricsAddr)
	go func() {
		if err := http.ListenAndServe(metricsAddr, nil); err != nil {
			pm.logger.Printf("❌ Metrics server error: %v", err)
		}
	}()
}

func (pm *PodMonitor) Start() error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigCh
		pm.logger.Println("📶 Received shutdown signal")
		close(pm.stopCh)
		cancel()
	}()

	// Test connectivity
	_, err := pm.clientset.CoreV1().Namespaces().Get(ctx, "default", metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to connect to Kubernetes API: %v", err)
	}

	pm.logger.Println("✅ Successfully connected to Kubernetes API")

	// Start metrics server
	pm.startMetricsServer()

	return pm.watchPods(ctx)
}

func main() {
	namespace := os.Getenv("NAMESPACE")
	if namespace == "" {
		namespace = "devops-case-study"
	}

	monitor, err := NewPodMonitor(namespace)
	if err != nil {
		log.Fatalf("Failed to create pod monitor: %v", err)
	}

	log.Printf("Starting Pod Monitor for namespace: %s", namespace)
	if err := monitor.Start(); err != nil && err != context.Canceled {
		log.Fatalf("Pod monitor error: %v", err)
	}

	log.Println("Pod monitor stopped gracefully")
}
