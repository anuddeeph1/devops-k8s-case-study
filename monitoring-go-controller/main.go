package main

// Test comment to trigger GitHub Actions workflow
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

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

type PodMonitor struct {
	clientset  *kubernetes.Clientset
	namespace  string
	logger     *log.Logger
	stopCh     chan struct{}
	retryCount int
	maxRetries int
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
		clientset:  clientset,
		namespace:  namespace,
		logger:     logger,
		stopCh:     make(chan struct{}),
		retryCount: 0,
		maxRetries: 10,
	}, nil
}

func (pm *PodMonitor) logEvent(event PodEvent) {
	eventJSON, err := json.Marshal(event)
	if err != nil {
		pm.logger.Printf("❌ Failed to marshal event to JSON: %v", err)
		return
	}
	pm.logger.Printf("%s", string(eventJSON))

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

	return pm.watchPods(ctx)
}

func healthCheck() {
	// Simple health check - verify we can connect to Kubernetes API
	namespace := os.Getenv("NAMESPACE")
	if namespace == "" {
		namespace = "devops-case-study"
	}

	monitor, err := NewPodMonitor(namespace)
	if err != nil {
		log.Printf("Health check failed: unable to create monitor: %v", err)
		os.Exit(1)
	}

	// Test connectivity with a quick namespace check
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = monitor.clientset.CoreV1().Namespaces().Get(ctx, "default", metav1.GetOptions{})
	if err != nil {
		log.Printf("Health check failed: unable to connect to Kubernetes API: %v", err)
		os.Exit(1)
	}

	// Success - exit with 0
	fmt.Println("Health check passed: pod monitor is healthy")
	os.Exit(0)
}

func main() {
	// Check for health check flag
	if len(os.Args) > 1 && os.Args[1] == "--health-check" {
		healthCheck()
		return
	}

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
