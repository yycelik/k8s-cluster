
kubectl create namespace proxmox-manager

kubectl delete endpoints proxmox-service -n proxmox-manager
kubectl delete service proxmox-service -n proxmox-manager

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: proxmox-service
  namespace: proxmox-manager
spec:
  ports:
  - name: proxmox-web
    protocol: TCP
    port: 8006
    targetPort: 8006
  - name: proxmox-letsencrypt
    protocol: TCP
    port: 8006
    targetPort: 8006
EOF

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Endpoints
metadata:
  name: proxmox-service
  namespace: proxmox-manager
subsets:
- addresses:
  - ip: 192.168.0.114
  ports:
  - name: proxmox-web
    port: 8006
  - name: proxmox-letsencrypt
    port: 80
EOF

kubectl describe svc proxmox-service -n proxmox-manager


kubectl delete ingress proxmox-ingress -n proxmox-manager
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: proxmox-ingress
  namespace: proxmox-manager
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
spec:
  ingressClassName: nginx
  rules:
  - host: proxmox.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: proxmox-service
            port:
              number: 8006
  tls:
  - hosts:
    - proxmox.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF

kubectl describe svc proxmox-service -n proxmox-manager
