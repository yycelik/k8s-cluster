
kubectl create namespace external-tools

kubectl delete endpoints nexus-service -n external-tools
kubectl delete service nexus-service -n external-tools

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: nexus-service
  namespace: external-tools
spec:
  ports:
  - name: nexus-ui
    port: 8081
    protocol: TCP
    targetPort: 8081
  - name: nexus-docker-s
    port: 8082
    protocol: TCP
    targetPort: 8082
  - name: nexus-docker-r
    port: 8083
    protocol: TCP
    targetPort: 8083
  - name: nexus-docker-p
    port: 8084
    protocol: TCP
    targetPort: 8084
  - name: nexus-docker-g
    port: 8085
    protocol: TCP
    targetPort: 8085
EOF

sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Endpoints
metadata:
  name: nexus-service
  namespace: external-tools
subsets:
- addresses:
  - ip: 192.168.0.155
  ports:
  - name: nexus-ui
    port: 8081
  - name: nexus-docker-s
    port: 8082
  - name: nexus-docker-r
    port: 8083
  - name: nexus-docker-p
    port: 8084
  - name: nexus-docker-g
    port: 8085
EOF

kubectl describe svc nexus-service -n external-tools


kubectl delete ingress nexus-ingress -n external-tools
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nexus-ingress
  namespace: external-tools
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
spec:
  ingressClassName: nginx
  rules:
  - host: nexus.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: nexus-service
            port:
              number: 8006
  tls:
  - hosts:
    - nexus.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF

kubectl describe svc nexus-service -n external-tools


sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: nexus-ingress
  namespace: external-tools
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
            name: nexus-service
            port:
              number: 8081
  - host: docker-s.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: nexus-service
              port:
                number: 8082
  - host: docker-r.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: nexus-service
              port:
                number: 8083
  - host: docker-p.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: nexus-service
              port:
                number: 8084
  - host: docker-g.nexus.s3t.co
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: nexus-service
              port:
                number: 8085
  tls:
  - hosts:
    - nexus.s3t.co
    - docker-s.nexus.s3t.co
    - docker-r.nexus.s3t.co
    - docker-p.nexus.s3t.co
    - docker-g.nexus.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF