openssl genrsa -out ca.key 4096

openssl req -new -x509 -sha256 -days 365 -key ca.key -out ca.crt
#Country Name (2 letter code) [AU]:tr
#State or Province Name (full name) [Some-State]:uskudar
#Locality Name (eg, city) []:ist
#Organization Name (eg, company) [Internet Widgits Pty Ltd]:smart
#Organizational Unit Name (eg, section) []:tech
#Common Name (e.g. server FQDN or YOUR name) []:*.smart.com
#Email Address []:info@smart.com


# on windows click ca.crt and install
# on windows click ca.crt and install
# on windows click ca.crt and install
# on windows click ca.crt and install


kubectl create secret tls smart-ca-secret -n cert-manager  --cert=ca.crt --key=ca.key

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