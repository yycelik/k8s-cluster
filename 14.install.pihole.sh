# https://github.com/MoJo2600/pihole-kubernetes
# https://artifacthub.io/packages/helm/mojo2600/pihole

helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/

helm repo update

sudo cat >>myvalues.yaml<<EOF
persistentVolumeClaim:
  enabled: true

serviceWeb:
  loadBalancerIP: 192.168.0.205
  annotations:
    metallb.universe.tf/allow-shared-ip: pihole-svc
  type: LoadBalancer

serviceDns:
  loadBalancerIP: 192.168.0.205
  annotations:
    metallb.universe.tf/allow-shared-ip: pihole-svc
  type: LoadBalancer
EOF


helm install smart mojo2600/pihole --create-namespace --namespace tools -f myvalues.yaml

#helm install smart mojo2600/pihole --create-namespace --namespace tools --set serviceWeb.type=LoadBalancer --set persistentVolumeClaim.enabled=true

#kubectl --namespace tools patch svc smart-pihole-web -p '{"spec": {"type": "LoadBalancer"}}'

sudo kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pihole-pv-volume
  labels:
    type: local
spec:
  storageClassName: local-storage
  claimRef:
    name: smart-pihole
    namespace: tools
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /kworker2-pv/pihole
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kworker2.com
EOF




# to use wild card
# first u should install replicator for secret
kubectl delete ingress pihole-ingress -n tools
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: pihole-ingress
  namespace: tools
spec:
  ingressClassName: nginx
  rules:
  - host: pihole.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: smart-pihole-web
            port:
              number: 80
  tls:
  - hosts:
    - pihole.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF







# selfsign ingress
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.org/client-max-body-size: '0'
    nginx.org/proxy-connect-timeout: 10000s
    nginx.org/proxy-read-timeout: 10000s
  name: pihole-ingress
  namespace: tools
spec:
  ingressClassName: nginx
  rules:
  - host: pihole.smart.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: smart-pihole-web
            port:
              number: 80
  tls:
  - hosts:
    - pihole.smart.com
    secretName: smart-tls-secret
EOF


sudo kubectl create -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: smart-cert
  namespace: tools
spec:
  secretName: smart-tls-secret
  issuerRef:
    name: smart-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - pihole.smart.com
EOF