# add helm repo
helm repo add sonatype https://sonatype.github.io/helm3-charts/

# update helm repo
helm repo update

# install mysql
helm install my-nexus sonatype/nexus-repository-manager -n devops-tools --create-namespace

# patch the service to have it listen on LoadBalancer
kubectl --namespace devops-tools patch svc my-nexus-nexus-repository-manager -p '{"spec": {"type": "LoadBalancer"}}'

# 
sudo kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nexus-pv-volume
  labels:
    type: local
spec:
  storageClassName: local-storage
  claimRef:
    name: {persistent-volume-claims-name} #my-nexus-nexus-repository-manager-data
    namespace: devops-tools
  capacity:
    storage: 9Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /pv/nexus
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - {worker-node-name}
EOF

# get admin pass from node
kubectl exec -it my-nexus-nexus-repository-manager-5fc8cf4d97-f2wq8 cat /nexus-data/admin.password -n devops-tools



# cert manager and nginx https configuration
sudo kubectl create -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nexus-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: nexus-ca
  secretName: nexus-ca
  privateKey:
    algorithm: ECDSA
    size: 256
  dnsNames:
  - nexus.smart.com
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: nexus-cluster-issuer  
spec:
  ca:
    secretName: nexus-ca
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: nexus-cluster-issuer
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
  tls:
  - hosts:
    - nexus.smart.com
    - docker-s.nexus.smart.com
    - docker-r.nexus.smart.com
    - docker-p.nexus.smart.com
    secretName: nexus-tls

EOF

# add ui and docker port to the service
kubectl --namespace devops-tools patch svc my-nexus-nexus-repository-manager -p '{"spec": {"ports": [{"name": "nexus-ui","protocol": "TCP","port": 8081,"targetPort": 8081},{"name": "nexus-docker-snapshoot","protocol": "TCP","port": 8082,"targetPort": 8082},{"name": "nexus-docker-release","protocol": "TCP","port": 8083,"targetPort": 8083},{"name": "nexus-docker-public","protocol": "TCP","port": 8084,"targetPort": 8084}]}}'

