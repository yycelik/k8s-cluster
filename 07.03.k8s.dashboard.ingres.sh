# install manual
#openssl req -x509 -newkey rsa:4096 -days 365 -keyout ca-key.pem -out ca-cert.pem
#Enter PEM pass phrase:
#Verifying - Enter PEM pass phrase:
#Country Name (2 letter code) [AU]:tr
#State or Province Name (full name) [Some-State]:uskudar
#Locality Name (eg, city) []:ist
#Organization Name (eg, company) [Internet Widgits Pty Ltd]:smart
#Organizational Unit Name (eg, section) []:tech
#Common Name (e.g. server FQDN or YOUR name) []:*.smart.com
#Email Address []:info@smart.com

# create pem
openssl req -x509 -newkey rsa:4096 -days 7300 -keyout ca-key.pem -out ca-cert.pem -subj "/C=TR/ST=uskudar/L=ist/O=smart/OU=tech/CN=*.smart.com/emailAddress=info@smart.com"

# create crt
openssl x509 -in ca-cert.pem -out certificate.crt

# create key
openssl rsa -in ca-key.pem -out private.key

# upload crt to the k8s
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key -n kubernetes-dashboard
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key -n cert-manager
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key -n devops-tools
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key -n ingress-nginx
kubectl create secret tls smart-ca-secret --cert=certificate.crt --key=private.key -n kubernetes-dashboard


# click crt to install windows
Invoke-WebRequest -Uri "https://jenkins.smart.com" -OutFile "ca-cert.pem"
certutil -addstore -f "Root" "ca-cert.pem"
