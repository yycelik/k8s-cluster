

#CREATE DATABASE keycloak;
#CREATE USER keycloakuser WITH ENCRYPTED PASSWORD 'xxxxx;
#GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloakuser;
#FLUSH PRIVILEGES;


# create namespace
kubectl create namespace keycloak

# create database secret
kubectl create secret generic keycloak-db-secret --from-literal=db-username=keycloakuser --from-literal=db-password=xxxxx -n keycloak
  
# create deployment
kubectl create -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:latest
        args: ["start"]
        ports:
          - name: http
            containerPort: 8080
        readinessProbe:
          httpGet:
            scheme: HTTP
            path: /realms/master
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 1
        env:
        - name: KC_HOSTNAME
          value: keycloak.s3t.co
        - name: KC_PROXY_HEADERS
          value: xforwarded
        - name: KC_HTTP_ENABLED
          value: 'true'
        - name: KC_TRANSACTION_XA_ENABLED
          value: 'true'
        - name: KC_HEALTH_ENABLED
          value: 'true'
        - name: KC_BOOTSTRAP_ADMIN_USERNAME
          value: admin
        - name: KC_BOOTSTRAP_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: db-password
        - name: KC_DB
          value: postgres  # or 'mysql' for MySQL
        - name: KC_DB_URL
          value: jdbc:postgresql://192.168.0.151:5432/keycloak 
        - name: DB_DATABASE
          value: keycloak
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: db-username
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: db-password
        volumeMounts:
        - name: my-certificate-volume
          mountPath: "/etc/ssl"
      volumes:
      - name: my-certificate-volume
        secret:
          secretName: s3t-wildcard-cert-prod
EOF

# create service
kubectl create -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  selector:
    app: keycloak
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF

#create ingress
sudo kubectl create -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
spec:
  ingressClassName: nginx
  rules:
  - host: keycloak.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: keycloak
            port:
              number: 80
  tls:
  - hosts:
    - keycloak.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF