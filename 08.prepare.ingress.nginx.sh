# no need if you run before
sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: smart-clusterissuer
spec:
  ca:
    secretName: smart-ca-secret
EOF

sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: smart-cert
  namespace: devops-tools
spec:
  secretName: smart-tls-secret
  issuerRef:
    name: smart-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - smart.com
    - jenkins.smart.com
    - nexus.smart.com
    - docker-s.nexus.smart.com
    - docker-r.nexus.smart.com
    - docker-p.nexus.smart.com
EOF

sudo kubectl apply -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: nexus-ingress
  namespace: devops-tools
spec:
  ingressClassName: nginx
  rules:
  - host: nexus.smart.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: my-nexus-nexus-repository-manager
            port:
              number: 8081
  - host: docker-s.nexus.smart.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8082
  - host: docker-r.nexus.smart.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8083
  - host: docker-p.nexus.smart.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-nexus-nexus-repository-manager
              port:
                number: 8084
  - host: jenkins.smart.com
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
    - smart.com
    - jenkins.smart.com
    - nexus.smart.com
    - docker-s.nexus.smart.com
    - docker-r.nexus.smart.com
    - docker-p.nexus.smart.com
    secretName: smart-tls-secret
EOF