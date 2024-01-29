#
helm repo add mittwald https://helm.mittwald.de

#
helm repo update

#
helm install kubernetes-replicator mittwald/kubernetes-replicator

#
kubectl annotate secret s3t-wildcard-cert-prod replicator.v1.mittwald.de/replicate-to=*

# no need for it
sudo kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: s3t-wildcard-cert-prod
  namespace: devops-tools
  annotations:
    replicator.v1.mittwald.de/replication-allowed: "true"
    replicator.v1.mittwald.de/replication-allowed-namespaces: "*"
type: Opaque
data:
  # This data can be empty or dummy data; it will be overwritten by the Replicator
EOF