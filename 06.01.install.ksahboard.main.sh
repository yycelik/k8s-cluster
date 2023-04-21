# install kubernetes dashboard
VER=$(curl -s https://api.github.com/repos/kubernetes/dashboard/releases/latest|grep tag_name|cut -d '"' -f 4)

echo $VER

wget https://raw.githubusercontent.com/kubernetes/dashboard/$VER/aio/deploy/recommended.yaml -O kubernetes-dashboard.yaml

kubectl apply -f kubernetes-dashboard.yaml

kubectl --namespace kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec": {"type": "LoadBalancer"}}'

kubectl -n kubernetes-dashboard get services

# create token
sudo cat >>sa_cluster_admin.yaml<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
kubectl apply -f sa_cluster_admin.yaml
kubectl -n kubernetes-dashboard create token admin-user

# patch the service to have it listen on LoadBalancer
kubectl --namespace kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec": {"type": "LoadBalancer"}}'

# create spec file
sudo cat >>nodeport_dashboard_patch.yaml<<EOF
spec:
  ports:
  - name: https
      port: 443
      targetPort: 8443
  type: LoadBalancer
EOF

# apply the patch
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard --patch "$(cat nodeport_dashboard_patch.yaml)"

# check deployment status
kubectl get deployments -n kubernetes-dashboard      

# one pod for dashboard and another for metrics
kubectl get pods -n kubernetes-dashboard

# kubernetes-dashboard type should be NodePort
kubectl get service -n kubernetes-dashboard  

