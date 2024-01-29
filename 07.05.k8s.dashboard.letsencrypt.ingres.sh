sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: s3t-cert
  namespace: kubernetes-dashboard 
spec:
  secretName: s3t-cert-tls
  issuerRef:
    name: s3t-clusterissuer
    kind: ClusterIssuer
  commonName: k8s.s3t.co
  dnsNames:
    - k8s.s3t.co
EOF

# get url or errors
kubectl describe challenge -n kubernetes-dashboard

# get svc cm-acme-http-solver-{id of}  
kubectl get svc -n kubernetes-dashboard

# do not forget to open 80 port from modem
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: s3t-acme-ingress
  namespace: kubernetes-dashboard
  annotations:
    cert-manager.io/cluster-issuer: "s3t-clusterissuer"
spec:
  ingressClassName: nginx
  rules:
  - host: "k8s.s3t.co"
    http:
      paths:
      - path: /.well-known/acme-challenge/
        pathType: Prefix
        backend:
          service:
            name: cm-acme-http-solver-5xnfm
            port:
              number: 8089
EOF

# control certificate
kubectl get certificate -n kubernetes-dashboard

# delete ingress
sudo kubectl delete ingress s3t-acme-ingress -n kubernetes-dashboard

sudo kubectl create -f - <<EOF
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
  - host: k8s.s3t.co
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
    - k8s.s3t.co
    secretName: s3t-cert-tls
EOF