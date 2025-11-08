kubectl create namespace grafana




helm repo add grafana https://grafana.github.io/helm-charts
helm repo update











sudo cat >>grafana.yaml<<EOF
adminUser: admin
adminPassword: "ChangeMe123!"

service:
  type: ClusterIP
  port: 3000            # grafana chart default'u 3000'dir; istersen 80 yapabilirsin

persistence:
  enabled: true
  size: 10Gi
  accessModes: [ "ReadWriteOnce" ]

# Prometheus'u datasource olarak ekle
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        isDefault: true
        url: http://prometheus-server.prometheus.svc.cluster.local
        editable: true

# (Opsiyonel) Dashboard sidecar
sidecar:
  dashboards:
    enabled: true
  datasources:
    enabled: true
EOF
	
helm install grafana grafana/grafana -n grafana -f grafana-values.yaml
kubectl get pods -n grafana

sudo cat >>grafana-ingress<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: grafana
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


kubectl apply -f grafana-ingress.yaml