#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   MAILU_HOST=mail.example.com TLS_SECRET=mail-tls ./22.install.mailu.sh
#
# Notes:
# - This is a minimal Mailu front deployment template.
# - Update image versions, secrets, and hostnames before production use.
# - Do NOT include ingress controller pod CIDR in MAILU_SUBNET.

NAMESPACE="${NAMESPACE:-mailu}"
MAILU_HOST="${MAILU_HOST:-mail.example.com}"
TLS_SECRET="${TLS_SECRET:-mail-tls}"
MAILU_IMAGE="${MAILU_IMAGE:-ghcr.io/mailu/nginx:2024.06.46}"
SMTP_LISTENER_NAME="${SMTP_LISTENER_NAME:-smtp-200-listener}"
MAILU_DOMAIN="${MAILU_DOMAIN:-${MAILU_HOST#*.}}"
MAILU_SUBNET="${MAILU_SUBNET:-10.42.0.0/16}"
POSTFIX_MYNETWORKS="${POSTFIX_MYNETWORKS:-127.0.0.1/32}"

if [[ "${MAILU_SUBNET}" == *"92.68.0.0/16"* ]]; then
  echo "ERROR: MAILU_SUBNET contains 92.68.0.0/16 (ingress pod CIDR)."
  echo "This can allow unauthenticated relay via ingress pods."
  echo "Use a dedicated internal subnet only (example: 10.42.0.0/16)."
  exit 1
fi

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

kubectl apply -n "${NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mailu-postfix-overrides
  labels:
    app: mailu
    component: postfix
data:
  postfix.cf: |
    inet_protocols = ipv4
    mynetworks = ${POSTFIX_MYNETWORKS}
    smtpd_relay_restrictions = permit_sasl_authenticated, reject_unauth_destination
    smtpd_sender_restrictions = check_sender_access lmdb:/etc/postfix/sender_access.map, reject_non_fqdn_sender, reject_unknown_sender_domain, permit
  sender_access.map: |
    # Add temporary blocks as needed:
    # baduser@example.com REJECT blocked temporarily due spam abuse
    # baddomain.tld REJECT blocked temporarily due spam abuse
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mailu-envvars
  labels:
    app: mailu
    component: front
data:
  DOMAIN: ${MAILU_DOMAIN}
  HOSTNAMES: ${MAILU_HOST}
  SUBNET: ${MAILU_SUBNET}
  WEBMAIL: roundcube
  WEB_ADMIN: /admin
  WEB_WEBMAIL: /webmail
  WEBROOT_REDIRECT: /webmail
  TLS_FLAVOR: notls
  SESSION_COOKIE_SECURE: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: mailu-secret
  labels:
    app: mailu
    component: front
type: Opaque
stringData:
  secret-key: "CHANGE_ME_TO_A_LONG_RANDOM_VALUE"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailu-front
  labels:
    app: mailu
    component: front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mailu
      component: front
  template:
    metadata:
      labels:
        app: mailu
        component: front
    spec:
      containers:
      - name: front
        image: ${MAILU_IMAGE}
        imagePullPolicy: IfNotPresent
        envFrom:
        - configMapRef:
            name: mailu-envvars
        - secretRef:
            name: mailu-secret
        ports:
        - name: smtp
          containerPort: 25
        - name: http
          containerPort: 80
        - name: https
          containerPort: 443
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mailu-front
  labels:
    app: mailu
    component: front
spec:
  selector:
    app: mailu
    component: front
  ports:
  - name: smtp
    port: 25
    targetPort: 25
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mailu
  labels:
    app: mailu
    component: front
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTP
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-buffering: "off"
spec:
  ingressClassName: nginx
  rules:
  - host: ${MAILU_HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mailu-front
            port:
              name: http
  tls:
  - hosts:
    - ${MAILU_HOST}
    secretName: ${TLS_SECRET}
---
apiVersion: k8s.nginx.org/v1
kind: TransportServer
metadata:
  name: smtp-mailu
  labels:
    app: mailu
    component: front
spec:
  listener:
    name: ${SMTP_LISTENER_NAME}
    protocol: TCP
  upstreams:
  - name: smtp-upstream
    service: mailu-front
    port: 25
  action:
    pass: smtp-upstream
EOF

echo "Applied Mailu manifests to namespace: ${NAMESPACE}"
echo "Host: ${MAILU_HOST}"
echo "Domain: ${MAILU_DOMAIN}"
echo "Mailu SUBNET: ${MAILU_SUBNET}"
echo "Postfix mynetworks: ${POSTFIX_MYNETWORKS}"
echo "SMTP listener: ${SMTP_LISTENER_NAME}"
