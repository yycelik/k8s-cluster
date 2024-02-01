helm repo add longhorn https://charts.longhorn.io

helm repo update

helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace



#create user
USER=admin; PASSWORD=xxxxxx; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
kubectl delete secret basic-auth -n longhorn-system
kubectl create secret generic basic-auth --from-file=auth -n longhorn-system


# to use wild card
# first u should install replicator for secret
kubectl delete ingress longhorn-ingress -n longhorn-system
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
    nginx.ingress.kubernetes.io/proxy-body-size: 10000m
  name: longhorn-ingress
  namespace: longhorn-system
spec:
  ingressClassName: nginx
  rules:
  - host: longhorn.s3t.co
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
    - longhorn.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF










#self sign ingress
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