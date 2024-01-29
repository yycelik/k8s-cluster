# create issuer yaml {app-name} {dns-name}
sudo cat >>create-issuer.yaml<<EOF
piVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {app-name}-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: {app-name}-ca
  secretName: {app-name}-ca
  privateKey:
    algorithm: ECDSA
    size: 256
  dnsNames:
  - {dns-name}
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: {app-name}-cluster-issuer  
spec:
  ca:
    secretName: {app-name}-ca
EOF

# create issuer
kubectl apply -f create-issuer.yaml