kubectl create namespace prometheus

# copy longhorn basic-auth credentials to prometheus namespace
kubectl get secret basic-auth -n longhorn-system -o jsonpath='{.data.htpasswd}' | base64 -d > ./auth
kubectl create secret generic basic-auth --type=nginx.org/htpasswd --from-file=htpasswd=./auth -n prometheus --dry-run=client -o yaml | kubectl apply -f -

kubectl delete ingress prometheus-ingress -n prometheus --ignore-not-found
kubectl delete endpoints prometheus-service -n prometheus --ignore-not-found
kubectl delete service prometheus-service -n prometheus --ignore-not-found

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: prometheus
spec:
  ports:
  - name: prometheus-web
    protocol: TCP
    port: 9090
    targetPort: 9090
EOF

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Endpoints
metadata:
  name: prometheus-service
  namespace: prometheus
subsets:
- addresses:
  - ip: 192.168.0.151
  ports:
  - name: prometheus-web
    port: 9090
EOF

sudo kubectl create -f - <<EOF
---
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
      - pathType: Prefix
        path: /
        backend:
          service:
            name: prometheus-service
            port:
              number: 9090
  tls:
  - hosts:
    - prometheus.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF
