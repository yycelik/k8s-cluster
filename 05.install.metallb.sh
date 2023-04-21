# control k8s cluster
kubectl get no,po,svc -o wide

# create namespace
kubectl create namespace metallb-system 

# install metallb
helm repo add metallb https://metallb.github.io/metallb

# update helm repo
helm repo update

# install metallb
helm install -n metallb-system metallb metallb/metallb

# ip range from router 192.168.0.200-192.168.0.220
sudo cat >>metal-ip.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.200-192.168.0.220
EOF

# create config
kubectl create -f metal-ip.yaml -n metallb-system 

# layer2
sudo cat >>metal-add.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: first-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

# create add config
kubectl create -f metal-add.yaml -n metallb-system 

# control config
kubectl describe configmap config -n metallb-system

# create metal-configmap.yaml
kubectl create -f metal-configmap.yaml

# control external ip
kubectl -n metallb-system get all

# control k8s cluster
kubectl get no,po,svc -o wide