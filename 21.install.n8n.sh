
######################################################
#
# https://artifacthub.io/packages/helm/open-8gears/n8n
#
######################################################

# create namespace
kubectl create namespace keycloak

# create database secret
kubectl create secret generic db-app --from-literal=password='xxxxxx' --namespace my-n8n



sudo cat >>/etc/hosts<<EOF
namespace: my-n8n

replicaCount: 1

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  className: "nginx"
  hosts:
    - host: n8n.s3t.co
      paths:
        - /
  tls:
    - secretName: s3t-wildcard-cert-prod
      hosts:
        - n8n.s3t.co

main:
  config:
    n8n:
      encryption_key: "my_secret"
      db:
        type: postgresdb
        postgresdb:
          host: 192.168.0.151
          port: 5432
          user: n8n_user
      node:
        function_allow_builtin: "*"
  extraEnv: &extraEnv
    DB_POSTGRESDB_PASSWORD:
      valueFrom:
        secretKeyRef:
          name: db-app
          key: password

  persistence:
    enabled: true
    accessModes:
      - ReadWriteOnce
EOF

helm install n8n oci://8gears.container-registry.com/library/n8n --version 1.0.4 --namespace my-n8n -f n8n-values2.yaml #--create-namespace