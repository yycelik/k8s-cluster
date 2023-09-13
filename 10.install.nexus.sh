# add helm repo
helm repo add sonatype https://sonatype.github.io/helm3-charts/

# update helm repo
helm repo update

# install mysql
helm install my-nexus sonatype/nexus-repository-manager -n devops-tools --create-namespace

# patch the service to have it listen on LoadBalancer
kubectl --namespace devops-tools patch svc my-nexus-nexus-repository-manager -p '{"spec": {"type": "LoadBalancer"}}'

# 
sudo cat >>volume.yaml<<EOF
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

#	  
kubectl create -f volume.yaml

# get admin pass from node
kubectl exec -it my-nexus-nexus-repository-manager-5fc8cf4d97-f2wq8 cat /nexus-data/admin.password -n devops-tools



# cert manager and nginx https configuration
kubectl apply -f - <<EOF
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
  tls:
  - hosts:
    - nexus.smart.com
    secretName: nexus-tls

EOF

