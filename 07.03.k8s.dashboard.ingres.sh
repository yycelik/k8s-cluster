sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: smart-cert
  namespace: kubernetes-dashboard 
spec:
  secretName: smart-tls-secret
  issuerRef:
    name: smart-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - k8s.smart.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
    nginx.org/ssl-services: kubernetes-dashboard
  name: k8s-dashboard-ingress
  namespace: kubernetes-dashboard 
spec:
  ingressClassName: nginx
  rules:
  - host: k8s.smart.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
  tls:
  - hosts:
    - k8s.smart.com
	secretName: smart-tls-secret
EOF