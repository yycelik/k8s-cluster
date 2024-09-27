helm repo add nextcloud https://nextcloud.github.io/helm/

helm repo update

# create db secret
kubectl create secret generic nextcloud-mysql-secret --from-literal=mysql-user={xxxx} --from-literal=mysql-password={xxxx}


#create values.yaml
sudo cat >>values.yaml<<EOF
nextcloud:
  host: nextcloud.s3t.co #domain name should be enter

persistence:
  enabled: true
  size: 200Gi

ingress:
  enabled: true
  className: nginx
  tls:
    - hosts:
        - nextcloud.s3t.co #domain name should be enter
      secretName: s3t-wildcard-cert-prod
  rules:
    - host: nextcloud.s3t.co #domain name should be enter
      paths:
        - /
		
internalDatabase:
  enabled: false

externalDatabase:
  enabled: true
  type: mysql
  host: 192.168.0.151:3306 #mysql server name should be enter
  database: nextcloud
  existingSecret:
    enabled: true
    secretName: nextcloud-mysql-secret
    usernameKey: mysql-user
    passwordKey: mysql-password

phpClientHttpsFix:
  enabled: true
  protocol: https #redirection error for login
EOF

# install
helm install nextcloud nextcloud/nextcloud -n nextcloud -f values.yaml --create-namespace
#helm upgrade nextcloud nextcloud/nextcloud -n nextcloud -f values.yaml


# Ingresses >> nextcloud >> nextcloud
#annotations:
#    meta.helm.sh/release-name: nextcloud
#    meta.helm.sh/release-namespace: nextcloud
#    nginx.ingress.kubernetes.io/proxy-body-size: 1024m
#    nginx.org/client-max-body-size: 1024m


kubectl cp nextcloud/{pod-name}:/var/www/html/config/config.php ./config.php

kubectl cp ./config.php nextcloud/{pod-name}:/var/www/html/config/config.php