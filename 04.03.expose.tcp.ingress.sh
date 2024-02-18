# add GlobalConfiguration for nginx namespaces
kubectl apply -f - <<EOF
apiVersion: k8s.nginx.org/v1
kind: GlobalConfiguration
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
spec:
  listeners:
  - name: debug-01-listener
    port: 5005
    protocol: TCP
EOF


# update arguments and container ports for deployment
kubectl edit deployment my-release-nginx-ingress-controller -n ingress-nginx
#spec 
#  args:
#    - '-global-configuration=$(POD_NAMESPACE)/nginx-configuration'
#  containers
#    ports:
#      - name: debug-01
#        containerPort: 5005
#        protocol: TCP


# update ports for services
kubectl edit svc my-release-nginx-ingress-controller -n ingress-nginx
#spec
#  ports:
#    - name: debug-01-port
#      protocol: TCP
#      port: 5005
#      targetPort: 5005


# add TransportServer for application namespaces
kubectl create -f - <<EOF
apiVersion: k8s.nginx.org/v1
kind: TransportServer
metadata:
  name: debug-smart-user-api
  namespace: smart-dev
spec:
  listener:
    name: debug-01-listener
    protocol: TCP
  upstreams:
    - name: debug-01-upstream
      service: smart-user-api
      port: 5005
  action:
    pass: debug-01-upstream
EOF