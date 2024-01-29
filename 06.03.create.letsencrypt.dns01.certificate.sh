# https://github.com/kelvie/cert-manager-webhook-namecheap

git clone https://github.com/kelvie/cert-manager-webhook-namecheap.git

cd cert-manager-webhook-namecheap

helm install -n cert-manager namecheap-webhook deploy/cert-manager-webhook-namecheap/

helm install --set email=yavuzyasincelik@gmail.com -n cert-manager letsencrypt-namecheap-issuer deploy/letsencrypt-namecheap-issuer/

sudo kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: namecheap-credentials
  namespace: cert-manager
type: Opaque
stringData:
  apiKey: {namecheap-credentials}
  apiUser: {namecheap-username}
EOF

sudo kubectl create -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: s3t-wildcard-cert-prod
  namespace: default
spec:
  secretName: s3t-wildcard-cert-prod
  commonName: "*.s3t.co"
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  dnsNames:
  - "*.s3t.co"
EOF