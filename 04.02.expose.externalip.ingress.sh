
kubectl delete service k8s-api-service -n external-tools
kubectl delete endpoints k8s-api-service -n external-tools
kubectl delete EndpointSlice k8s-api-service -n external-tools
kubectl delete ingress k8s-api-ingress -n external-tools
kubectl delete ingress k8s-api-ingress -n external-tools


kubectl create namespace external-tools

sudo kubectl create -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: k8s-api-service
  namespace: external-tools
spec:
  ports:
    - port: 6443
      protocol: TCP
      targetPort: 6443
      name: http
EOF

sudo kubectl create -f - <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: k8s-api-service
  namespace: external-tools
subsets:
- addresses:
  - ip: 192.168.0.240
  ports:
  - port: 6443
EOF

kubectl describe svc/k8s-api-service -n  external-tools

sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
    nginx.org/ssl-services: k8s-api-service
  name: k8s-api-ingress
  namespace: external-tools
spec:
  ingressClassName: nginx
  rules:
  - host: k8s-api.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: k8s-api-service
            port:
              number: 6443
  tls:
  - hosts:
    - k8s-api.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF