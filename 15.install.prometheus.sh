kubectl create namespace monitoring

echo -n 'xxxx' > ./admin-user
echo -n 'xxxx' > ./admin-password

kubectl create secret generic grafana-admin-credentials --from-file=./admin-user --from-file=admin-password -n monitoring

rm admin-user && rm admin-passwordassword

sudo cat >>values.yaml<<EOF
fullnameOverride: prometheus

defaultRules:
  create: true
  rules:
    alertmanager: true
    etcd: true
    configReloaders: true
    general: true
    k8s: true
    kubeApiserverAvailability: true
    kubeApiserverBurnrate: true
    kubeApiserverHistogram: true
    kubeApiserverSlos: true
    kubelet: true
    kubeProxy: true
    kubePrometheusGeneral: true
    kubePrometheusNodeRecording: true
    kubernetesApps: true
    kubernetesResources: true
    kubernetesStorage: true
    kubernetesSystem: true
    kubeScheduler: true
    kubeStateMetrics: true
    network: true
    node: true
    nodeExporterAlerting: true
    nodeExporterRecording: true
    prometheus: true
    prometheusOperator: true

alertmanager:
  fullnameOverride: alertmanager
  enabled: true
  ingress:
    enabled: false

grafana:
  enabled: true
  fullnameOverride: grafana
  forceDeployDatasources: false
  forceDeployDashboards: false
  defaultDashboardsEnabled: true
  defaultDashboardsTimezone: utc
  serviceMonitor:
    enabled: true
  admin:
    existingSecret: grafana-admin-credentials
    userKey: admin-user
    passwordKey: admin-password

kubeApiServer:
  enabled: true

kubelet:
  enabled: true
  serviceMonitor:
    metricRelabelings:
      - action: replace
        sourceLabels:
          - node
        targetLabel: instance

kubeControllerManager:
  enabled: true
  endpoints: # ips of servers 
    - 192.168.0.240

coreDns:
  enabled: true

kubeDns:
  enabled: false

kubeEtcd:
  enabled: true
  endpoints: # ips of servers
    - 192.168.0.240
  service:
    enabled: true
    port: 2381
    targetPort: 2381

kubeScheduler:
  enabled: true
  endpoints: # ips of servers
    - 192.168.0.240

kubeProxy:
  enabled: true
  endpoints: # ips of servers
    - 192.168.0.240

kubeStateMetrics:
  enabled: true

kube-state-metrics:
  fullnameOverride: kube-state-metrics
  selfMonitor:
    enabled: true
  prometheus:
    monitor:
      enabled: true
      relabelings:
        - action: replace
          regex: (.*)
          replacement: $1
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: kubernetes_node

nodeExporter:
  enabled: true
  serviceMonitor:
    relabelings:
      - action: replace
        regex: (.*)
        replacement: $1
        sourceLabels:
          - __meta_kubernetes_pod_node_name
        targetLabel: kubernetes_node

prometheus-node-exporter:
  fullnameOverride: node-exporter
  podLabels:
    jobLabel: node-exporter
  extraArgs:
    - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)
    - --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$
  service:
    portName: http-metrics
  prometheus:
    monitor:
      enabled: true
      relabelings:
        - action: replace
          regex: (.*)
          replacement: $1
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: kubernetes_node
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 2048Mi

prometheusOperator:
  enabled: true
  prometheusConfigReloader:
    resources:
      requests:
        cpu: 200m
        memory: 50Mi
      limits:
        memory: 100Mi

prometheus:
  enabled: true
  prometheusSpec:
    replicas: 1
    replicaExternalLabelName: "replica"
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    retention: 6h
    enableAdminAPI: true
    walCompression: true

thanosRuler:
  enabled: false
EOF

helm install -n monitoring prometheus prometheus-community/kube-prometheus-stack -f values.yaml

sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: grafana-ingress
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: grafana
            port:
              number: 80
  tls:
  - hosts:
    - grafana.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF
