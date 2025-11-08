
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace prometheus

helm install prometheus prometheus-community/prometheus -n prometheus

htpasswd -c ./auth admin
kubectl create secret generic basic-auth --type=nginx.org/htpasswd --from-file=htpasswd=./auth -n prometheus

sudo cat >>prometheus-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: prometheus
  annotations:
    nginx.org/basic-auth-secret: basic-auth
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10000"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "10000"
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.s3t.co
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-server
            port:
              number: 80
  tls:
  - hosts:
    - prometheus.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF

kubectl apply -f prometheus-ingress.yaml
