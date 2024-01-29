# Create a namespace for Cert Manager
kubectl create namespace cert-manager

# Get the Helm Chart for Cert Manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install Cert Manager using Helm charts
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.13.3 --set installCRDs=true
