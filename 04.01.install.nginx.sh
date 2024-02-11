# deploy Nginx Ingress Controller
helm repo add nginx-stable https://helm.nginx.com/stable

# update helm repo
helm repo update

# create namespace
kubectl create namespace ingress-nginx

# install nginx
helm install my-release nginx-stable/nginx-ingress -n ingress-nginx

# checking runningPods in the namespace
kubectl get pods -n ingress-nginx

# check logs in the Pods use the commands
kubectl -n ingress-nginx  logs deploy/ingress-nginx-controller

# nano values.yaml 
# controller:
#   replicaCount: 3
#helm upgrade -n ingress-nginx ingress-nginx -f values.yaml .


kubectl -n ingress-nginx  get deploy

# control external ip
kubectl -n ingress-nginx get all

#
kubectl get service -n ingress-nginx
