# to use wild card
# first u should install replicator for secret
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: devops-tools-ingress
  namespace: devops-tools
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: jenkins-service
            port:
              number: 8080
  tls:
  - hosts:
    - s3t.co
    - jenkins.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF