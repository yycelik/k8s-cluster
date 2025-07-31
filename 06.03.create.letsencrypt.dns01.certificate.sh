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
  - "*.nexus.s3t.co"
EOF


#to clean order
#kubectl delete order s3t-wildcard-cert-prod-3-4058508564-1170114524


# put that name to dns server with {Key}
# _acme-challenge.<YOUR_DOMAIN> TEXT 
kubectl describe challenge

#kubectl describe challenge
#Name:         s3t-wildcard-cert-prod-3-4058508564-1170114524
#Namespace:    default
#Labels:       <none>
#Annotations:  <none>
#API Version:  acme.cert-manager.io/v1
#Kind:         Challenge
#Metadata:
#  Creation Timestamp:  2024-05-23T08:25:55Z
#  Finalizers:
#    finalizer.acme.cert-manager.io
#  Generation:  1
#  Owner References:
#    API Version:           acme.cert-manager.io/v1
#    Block Owner Deletion:  true
#    Controller:            true
#    Kind:                  Order
#    Name:                  s3t-wildcard-cert-prod-3-4058508564
#    UID:                   176dcb30-0a5e-430d-9fda-0104bd2eeabb
#  Resource Version:        5829614
#  UID:                     d448c8c4-a13c-4435-8627-2f43045d2fe7
#Spec:
#  Authorization URL:  https://acme-v02.api.letsencrypt.org/acme/authz-v3/354335565952
#  Dns Name:           s3t.co
#  Issuer Ref:
#    Kind:  ClusterIssuer
#    Name:  letsencrypt-prod
#  Key:     dxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxM
