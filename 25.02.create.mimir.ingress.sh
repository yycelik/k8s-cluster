kubectl create namespace mimir --dry-run=client -o yaml | kubectl apply -f -

# copy longhorn basic-auth credentials to mimir namespace
kubectl get secret basic-auth -n longhorn-system -o jsonpath='{.data.htpasswd}' | base64 -d > ./auth
kubectl create secret generic basic-auth --type=nginx.org/htpasswd --from-file=htpasswd=./auth -n mimir --dry-run=client -o yaml | kubectl apply -f -

kubectl delete ingress mimir-ingress -n mimir --ignore-not-found

kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mimir-ingress
  namespace: mimir
  annotations:
    nginx.org/basic-auth-secret: basic-auth
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10000"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "10000"
spec:
  ingressClassName: nginx
  rules:
  - host: mimir.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: mimir-gateway
            port:
              number: 80
  tls:
  - hosts:
    - mimir.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF
