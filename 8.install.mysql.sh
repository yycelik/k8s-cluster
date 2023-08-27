# add helm repo
helm repo add mysql-operator https://mysql.github.io/mysql-operator/

# update helm repo
helm repo update

# install mysql
helm install my-mysql-operator mysql-operator/mysql-operator --namespace mysql-operator --create-namespace

# create yaml
sudo cat >>volume.yaml<<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-volume
  labels:
    type: local
spec:
  storageClassName: local-storage
  claimRef:
    name: datadir-mycluster-0
    namespace: mysql-operator
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /pv/mysql
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kworker2.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: datadir-mycluster-0
  namespace: mysql-operator
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
EOF

# create persistent volume and claim
kubectl create -f volume.yaml

# create cluster
helm install mycluster mysql-operator/mysql-innodbcluster -n mysql-operator --set credentials.root.user='root' --set credentials.root.password='sakila' --set credentials.root.host='%' --set serverInstances=1 --set routerInstances=1 --set tls.useSelfSigned=true

# patch the service to have it listen on LoadBalancer
kubectl --namespace mysql-operator patch svc mycluster -p '{"spec": {"type": "LoadBalancer"}}'