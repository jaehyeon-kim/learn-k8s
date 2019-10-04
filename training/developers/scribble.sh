minikube start \
    --cpus 2 \
    --memory 4096 \
    --kubernetes-version v1.15.4 \
    --insecure-registry 10.0.0.0/24s

minikube status
kubectl cluster-info
kubectl version
kubectl get componentstatuses
kubectl get events

kubectl get pods --all-namespaces
kubectl get services --all-namespaces

watch -n 1 kubectl get pod,rs,deployment,service --all-namespaces
watch -n 1 kubectl get pod,rs,deployment,service --show-labels

######## Ch2

eval `minikube docker-env`
docker rmi -f $(docker images -a -q)

## if use local images in minikube
cd apps/kfd-flask
git fetch --tags
git checkout tags/first_container

eval `minikube docker-env`
docker build -t flask:0.1.0 .

# create deployment
# if deployment not working, --generator=run-pod/v1
kubectl run flask \
    --image=quay.io/kubernetes-for-developers/flask:latest \
    --port=5000 --save-config

## expose pod
# port forwarding
kubectl port-forward flask-66dc5c9d7f-zmz6c 5000:5000

curl localhost:5000

# kube proxy
kubectl proxy

curl localhost:8001/api/v1/namespaces/default/pods/flask-66dc5c9d7f-zmz6c

kubectl logs flask-66dc5c9d7f-zmz6c

kubectl logs deployment/flask
kubectl logs deployment/flask -f
# --timestamps
# -p

######## Ch3

## interactive deployment of an image
kubectl run -it alpine-interactive --image=alpine -- sh

kubectl run -it python-interactive \
    --image=quay.io/kubernetes-for-developers/flask:latest \
    --command -- /bin/sh

# once exit
# Session ended, resume using 'kubectl attach python-interactive-9d57c8d78-95m9t -c python-interactive -i -t' command when the pod is running

## running a second process in a container
kubectl exec flask-66dc5c9d7f-8sp5d -it -- /bin/sh

## common labels
# environment
# version
# app name
# tier of service

## selectors can be
# equality - = or !=
# or set - in, notin and exists
# to combine with a comma (,)

kubectl get pod -l run=flask # allows =, == or !=

# interactively add label to a resource
# kubectl label deployment flask <key>=<value>
kubectl label deployment flask enable=true
kubectl label deployment flask foo=bar

kubectl get deployment -l foo=bar,enable="true"

kubectl get deployment -L run,foo # add columns to show

kubectl expose deploy flask --port 5000

---
kind: Service
apiVersion: v1
metadata:
    name: service
spec:
  selector:
      run: flask
  ports:
  - protocol: TCP # TCP or UDP, default TCP
    port: 80 # any request on TCP port 80
    targetPort: 5000 # forward to port 5000 of selected pods
---

# A service does not require a selector, and a service without a selector is 
#   how Kubernetes represents a service that's outside of the cluster 
#   for the other resources within. To enable this, you create a service without a selector 
#   as well as a new resource, an Endpoint, which defines the network location of the remote service.

---
kind: Service
apiVersion: v1
metadata:
  name: some-remote-service
spec:
  ports:
  - protocol: TCP
    port: 1976
    targetPort: 1976
---
---
kind: Endpoints
apiVersion: v1
metadata:
  name: some-remote-service
subsets:
  - addresses:
      - ip: 1.2.3.4
    ports:
      - port: 1976
---

## Note other types of services
# ExternalName 
---
kind: Service
apiVersion: v1
metadata:
  name: another-remote-service
  namespace: default
spec:
  type: ExternalName
  externalName: my.rest.api.example.com
---

# Headless service
---
kind: Service
apiVersion: v1
metadata:
    name: flask-service
spec:
  ClusterIP: None
  selector:
      app: flask
---

#### discovering services from within your Pod
# if Pod is created AFTER service, info to reference service is found in env
# ==> in general it’s best to always define and apply your service declarations first
kubectl exec -it <pod-name> -- /bin/sh
$ env

# KUBERNETES_SERVICE_PORT=443
# KUBERNETES_PORT=tcp://10.96.0.1:443
# KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
# KUBERNETES_PORT_443_TCP_PORT=443
# KUBERNETES_PORT_443_TCP_PROTO=tcp
# KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
# KUBERNETES_SERVICE_PORT_HTTPS=443
# KUBERNETES_SERVICE_HOST=10.96.0.1
# FLASK_PORT_5000_TCP_ADDR=10.106.199.83
# FLASK_PORT_5000_TCP_PORT=5000
# FLASK_PORT_5000_TCP_PROTO=tcp
# FLASK_SERVICE_HOST=10.106.199.83
# FLASK_PORT_5000_TCP=tcp://10.106.199.83:5000
# FLASK_SERVICE_PORT=5000
# FLASK_PORT=tcp://10.106.199.83:5000

#### DNS for services
# a cluster add-on that is included for all clusters in version 1.3+ 
#   that provides internal DNS services for Kubernetes
# a service gets an internal A record (address record in DNS)
#   <servicename>.<namespace>.svc.cluster.local
#   It can be reference in Pods as <servicename>.<namespace>.svc or <servicename>

kubectl exec -it <pod-name> -- /bin/sh
$ nslookup <service-name>

# nslookup flask
# nslookup: can't resolve '(null)': Name does not resolve

# Name:      flask
# Address 1: 10.106.199.83 flask.default.svc.cluster.local

# NOTE: Tacking on a namespace should only be done when you are explicitly trying to refer to 
#   a service in another namespace. Leaving the namespace off makes your manifest inherently 
#   more reusable, since you can stamp out an entire stack of services with static routing 
#   configuration into arbitrary namespaces.

#### exposing services outside the cluster
## LoadBalancer is usually to work with cloud providers
## NodePort

kubectl expose deploy flask --port 5000 --type=NodePort

minikube service flask
minikube service flask --url

# minikube service list

#### example service - redis
sudo apt-get -y install redis-tools

kubectl run redis --image=docker.io/redis:alpine
kubectl expose deploy redis --port=6379 --type=NodePort

kubectl exec -it redis-55f67b886d-k56ld -- /bin/sh

redis-cli -h $(minikube ip) -p 30267
# 192.168.99.100:30267> ping
# PONG

kubectl exec -it flask-66dc5c9d7f-7qcrn -- /bin/sh
# / # nslookup redis.default
# nslookup: can't resolve '(null)': Name does not resolve

# Name:      redis.default
# Address 1: 10.103.15.217 redis.default.svc.cluster.local

# / # python3
# import redis
# redis_db = redis.StrictRedis(host="redis.default", port=6379, db=0)
# redis_db.ping()
# #True
# redis_db.set("hello", "world")
# #True
# redis_db.get("hello")
# #b'world'

kubectl get deployment flask -o yaml > flask_deployment.yml
# change image to quay.io/kubernetes-for-developers/flask:0.1.1
kubectl replace -f flask_deployment.yml 
# deployment.extensions/flask replaced
rm flask_deployment.yml

# kubectl exec -it flask-5d76f4674-zvbpm -- python3
# import redis
# redis_db = redis.StrictRedis(host="redis.default", port=6379, db=0)
# redis_db.ping()
# #True
# redis_db.get('hello')
# #b'world'

## deployments and rollouts
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment
---
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
---
# maxUnavailable is an optional field that specifies the maximum number of Pods
#    that can be unavailable during the update process
# maxSurge is an optional field that specifies the maximum number of Pods
#     that can be created over the desired number of Pods
# eg)
# min (75% wrt maxUnavailable) - desired (100%) - max (125% wrt maxSerge)

## rollout history
kubectl rollout status deployment flask

kubectl rollout history deployment flask
# deployment.extensions/flask 
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# annotate to update CHANGE-CAUSE
kubectl annotate deployment flask kubernetes.io/change-cause='deploying image 0.1.1'

# more info on specific revision
kubectl rollout history deployment flask --revision=2

## rollout undo
kubectl rollout undo deployment flask

# kubectl rollout status deployment flask -w

kubectl rollout history deployment flask
# deployment.extensions/flask 
# REVISION  CHANGE-CAUSE
# 2         deploying image 0.1.1
# 3         <none>


## updating with the kubectl set command
kubectl delete deployment flask

kubectl run flask --image=quay.io/kubernetes-for-developers/flask:latest
kubectl annotate deployment flask kubernetes.io/change-cause='initial deployment'

kubectl set image deployment flask flask=quay.io/kubernetes-for-developers/flask:0.1.1
kubectl annotate deployment flask kubernetes.io/change-cause='deploying image 0.1.1'

kubectl rollout undo deployment flask --to-revision=1