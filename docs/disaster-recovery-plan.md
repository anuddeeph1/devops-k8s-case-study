# Disaster Recovery Plan for Database

## Overview

This document outlines the disaster recovery (DR) strategy for the MySQL database component in the DevOps case study. The plan ensures business continuity and data protection in case of various failure scenarios.

## Current Architecture

- **Database**: MySQL 8.0 running as a single pod in Kubernetes
- **Storage**: Persistent Volume (PV) with 10Gi capacity
- **Backup**: Manual snapshots and automated backups

## Disaster Recovery Objectives

### Recovery Time Objective (RTO)
- **Critical Systems**: 15 minutes
- **Non-critical Systems**: 1 hour

### Recovery Point Objective (RPO)
- **Critical Data**: 5 minutes
- **Non-critical Data**: 1 hour

## Disaster Recovery Strategies

### 1. Database Replication Strategy

#### Master-Slave Replication
```yaml
# Primary MySQL instance
mysql-primary:
  replicaCount: 1
  persistence:
    enabled: true
    size: 10Gi
  
# Read-only replica for disaster recovery
mysql-replica:
  replicaCount: 2
  persistence:
    enabled: true
    size: 10Gi
  readOnly: true
```

#### Benefits:
- Real-time data replication
- Automatic failover capability
- Load distribution for read operations
- Geographic distribution possible

### 2. Backup and Restore Strategy

#### Automated Backup Schedule
```bash
# Daily full backup at 2 AM
0 2 * * * mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > /backup/full_backup_$(date +%Y%m%d).sql

# Hourly incremental backups
0 * * * * mysqldump -u root -p$MYSQL_ROOT_PASSWORD --single-transaction --flush-logs --all-databases > /backup/incremental_backup_$(date +%Y%m%d_%H).sql

# Binary log backup every 15 minutes
*/15 * * * * cp /var/log/mysql/mysql-bin.* /backup/binlogs/
```

#### Backup Storage Locations:
1. **Local Storage**: Kubernetes Persistent Volume
2. **Remote Storage**: AWS S3 / Google Cloud Storage
3. **Geographic Backup**: Cross-region replication

### 3. Infrastructure-Level DR

#### Multi-Zone Deployment
```yaml
# MySQL deployment with anti-affinity
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - mysql
              topologyKey: failure-domain.beta.kubernetes.io/zone
```

#### Storage Replication
- **Persistent Volume Snapshots**: Daily automated snapshots
- **Cross-Zone Replication**: Storage-level replication across availability zones
- **Volume Cloning**: Quick recovery through PV cloning

## Failure Scenarios and Recovery Procedures

### Scenario 1: Pod Failure
**Impact**: Single pod failure, data intact
**Recovery**:
1. Kubernetes automatically restarts the pod
2. Pod reconnects to existing PV
3. **RTO**: 2-5 minutes

### Scenario 2: Node Failure
**Impact**: Node becomes unavailable, pod needs rescheduling
**Recovery**:
1. Kubernetes reschedules pod to healthy node
2. PV reattaches to new pod
3. **RTO**: 5-10 minutes

### Scenario 3: Persistent Volume Failure
**Impact**: Data storage corruption or loss
**Recovery**:
1. Create new PV from latest snapshot
2. Restore database from backup
3. Update pod configuration
4. **RTO**: 15-30 minutes

### Scenario 4: Complete Cluster Failure
**Impact**: Entire Kubernetes cluster unavailable
**Recovery**:
1. Deploy new Kubernetes cluster
2. Restore PVs from snapshots/backups
3. Deploy application stack
4. **RTO**: 1-2 hours

### Scenario 5: Data Center Failure
**Impact**: Regional outage
**Recovery**:
1. Failover to DR site
2. Promote replica to primary
3. Update application connection strings
4. **RTO**: 30 minutes - 1 hour

## Automated DR Implementation

### 1. Backup CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mysql-backup
            image: mysql:8.0
            command:
            - /bin/bash
            - -c
            - |
              mysqldump -h mysql-service -u root -p$MYSQL_ROOT_PASSWORD \
                --single-transaction --routines --triggers \
                --all-databases > /backup/mysql-backup-$(date +%Y%m%d-%H%M%S).sql
            env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-root-password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
```

### 2. Monitoring and Alerting
```yaml
# Database health monitoring
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql-monitor
spec:
  selector:
    matchLabels:
      app: mysql
  endpoints:
  - port: metrics
    interval: 30s
```

### 3. Automated Failover Script
```bash
#!/bin/bash
# MySQL Failover Script

PRIMARY_HOST="mysql-primary-service"
REPLICA_HOST="mysql-replica-service"
HEALTH_CHECK_TIMEOUT=30

check_mysql_health() {
    timeout $HEALTH_CHECK_TIMEOUT mysql -h $1 -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1" > /dev/null 2>&1
    return $?
}

failover_to_replica() {
    echo "Primary MySQL is down, initiating failover..."
    
    # Stop replica replication
    mysql -h $REPLICA_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "STOP REPLICA;"
    
    # Promote replica to primary
    mysql -h $REPLICA_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "RESET REPLICA ALL;"
    
    # Update application configuration
    kubectl patch service mysql-service -p '{"spec":{"selector":{"app":"mysql-replica"}}}'
    
    echo "Failover completed successfully"
}

# Health check loop
while true; do
    if ! check_mysql_health $PRIMARY_HOST; then
        echo "Primary MySQL health check failed"
        if check_mysql_health $REPLICA_HOST; then
            failover_to_replica
            break
        else
            echo "Both primary and replica are down - manual intervention required"
        fi
    fi
    sleep 30
done
```

## Testing and Validation

### 1. Regular DR Drills
- **Monthly**: Backup and restore testing
- **Quarterly**: Full failover testing
- **Annually**: Complete DR site activation

### 2. Backup Validation
```bash
# Backup integrity check
mysql -u root -p < backup_file.sql
mysqldump -u root -p --all-databases | diff - backup_file.sql
```

### 3. RTO/RPO Measurement
- Automated testing of recovery times
- Monitoring of backup freshness
- Regular validation of data consistency

## Best Practices

1. **Regular Backups**: Implement automated, tested backup procedures
2. **Geographic Distribution**: Deploy replicas across different regions
3. **Monitoring**: Continuous health monitoring and alerting
4. **Documentation**: Keep recovery procedures updated and accessible
5. **Training**: Regular training for operations team
6. **Automation**: Minimize manual intervention in recovery processes

## Recovery Contacts

| Role | Contact | Phone | Email |
|------|---------|--------|-------|
| Primary DBA | John Doe | +1-555-0101 | john.doe@company.com |
| Backup DBA | Jane Smith | +1-555-0102 | jane.smith@company.com |
| Infrastructure Team | On-call | +1-555-0100 | infrastructure@company.com |

## Conclusion

This disaster recovery plan provides comprehensive protection for the MySQL database component. Regular testing, monitoring, and updates to this plan are essential to ensure effectiveness during actual disaster scenarios.

The combination of replication, backups, and infrastructure-level protection ensures that we can meet our RTO and RPO objectives while maintaining data integrity and business continuity.
