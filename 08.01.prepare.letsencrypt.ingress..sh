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
  - host: nexus.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: my-nexus-nexus-repository-manager
            port:
              number: 8081
  - host: docker-s.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8082
  - host: docker-r.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8083
  - host: docker-p.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8084
  - host: docker-g.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8085
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
    - nexus.s3t.co
    - docker-s.nexus.s3t.co
    - docker-r.nexus.s3t.co
    - docker-p.nexus.s3t.co
    - docker-g.nexus.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF