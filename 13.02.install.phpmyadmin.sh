sudo kubectl create -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: phpmyadmin-system
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
  namespace: phpmyadmin-system
type: Opaque
data:
  root-password: xxxxxxxx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpmyadmin-deployment
  namespace: phpmyadmin-system
  labels:
    app: phpmyadmin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: phpmyadmin
  template:
    metadata:
      labels:
        app: phpmyadmin
    spec:
      containers:
        - name: phpmyadmin
          image: phpmyadmin/phpmyadmin
          ports:
            - containerPort: 80
          env:
            - name: PMA_HOST
              value: mycluster.mysql-operator
            - name: PMA_PORT
              value: "3306"
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secrets
                  key: root-password
---
apiVersion: v1
kind: Service
metadata:
  name: phpmyadmin-service
  namespace: phpmyadmin-system
spec:
  type: NodePort
  selector:
    app: phpmyadmin
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: phpmyadmin-ingress
  namespace: phpmyadmin-system
spec:
  ingressClassName: nginx
  rules:
  - host: myadmin.s3t.co
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: phpmyadmin-service
            port:
              number: 80
  tls:
  - hosts:
    - myadmin.s3t.co
    secretName: s3t-wildcard-cert-prod
EOF