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
    path: /pv/jenkins
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

