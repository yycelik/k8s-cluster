# https://cert-manager.io/docs/tutorials/acme/nginx-ingress/#step-5---deploy-cert-manager
# https://letsencrypt.org/docs/challenge-types/ 
# https://cert-manager.io/docs/troubleshooting/acme/

sudo kubectl create -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: s3t-clusterissuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: yavuzyasincelik@gmail.com
    privateKeySecretRef:
      name: s3t-cluster-issuer-private-key
    solvers:
    - http01:
        ingress:
          class: nginx 
EOF


sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: s3t-cert
  namespace: default
spec:
  secretName: s3t-cert-tls
  issuerRef:
    name: s3t-clusterissuer
    kind: ClusterIssuer
  commonName: s3t.co
  dnsNames:
    - s3t.co
EOF

# get url or errors
kubectl describe challenge

# get svc cm-acme-http-solver-{id of}  
kubectl get svc

# do not forget to open 80 port from modem
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: s3t-acme-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "s3t-clusterissuer"
spec:
  ingressClassName: nginx
  rules:
  - host: "s3t.co"
    http:
      paths:
      - path: /.well-known/acme-challenge/
        pathType: Prefix
        backend:
          service:
            name: cm-acme-http-solver-{id of} 
            port:
              number: 8089
EOF

# control certificate
kubectl get certificate

# delete ingress
sudo kubectl delete ingress s3t-acme-ingress
