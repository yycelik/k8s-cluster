# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# update helm repo
helm repo update

# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard #--set=nginx.enabled=true --set=cert-manager.enabled=true



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

