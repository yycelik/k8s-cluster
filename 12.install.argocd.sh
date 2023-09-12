# add repo
helm repo add argo https://argoproj.github.io/argo-helm

# update repo
helm repo update

# create namespace
kubectl create namespace argocd

# install argocd
helm install argocd argo/argo-cd --namespace argocd

# change type
kubectl --namespace argo-cd patch svc argocd-server -p '{"spec": {"type": "LoadBalancer"}}'

# get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d