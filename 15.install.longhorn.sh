helm repo add longhorn https://charts.longhorn.io

helm repo update

helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace

sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: longhorn-ingress
  namespace: longhorn-system
spec:
  ingressClassName: nginx
  rules:
  - host: longhorn.smart.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
  tls:
  - hosts:
    - longhorn.smart.com
    secretName: smart-tls-secret
EOF


sudo kubectl create -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: smart-cert
  namespace: longhorn-system
spec:
  secretName: smart-tls-secret
  issuerRef:
    name: smart-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - longhorn.smart.com
EOF