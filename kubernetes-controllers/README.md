##### START KIND CLUSTER: #####

# kind-config.yaml config file:
# a cluster with 1 control-plane node and 3 workers
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker

# Start:
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-kind
kubectl cluster-info dump
kubectl get nodes
kubectl get nodes -o wide
kubectl get events
kubectl get events -o wide 

##### REPLICASET: #####

# frontend-replicaset.yaml file:
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: kodmandvl/myfrontend:k8sintro
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: PORT
          value: "8080"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"
        - name: ENABLE_PROFILER
          value: "0"

kubectl apply -f frontend-replicaset.yaml 

The ReplicaSet "frontend" is invalid: 
* spec.selector: Required value
* spec.template.metadata.labels: Invalid value: map[string]string{"app":"frontend"}: `selector` does not match template `labels`

Нужно задать селектор меток:

# frontend-replicaset.yaml file:
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: kodmandvl/myfrontend:k8sintro
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: PORT
          value: "8080"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"
        - name: ENABLE_PROFILER
          value: "0"

kubectl apply -f frontend-replicaset.yaml 

replicaset.apps/frontend created

kubectl get pods -l app=frontend

NAME             READY   STATUS    RESTARTS   AGE
frontend-jhgc9   1/1     Running   0          49s

Давайте попробуем увеличить количество реплик сервиса ad-hoc командой:

kubectl scale replicaset frontend --replicas=3

replicaset.apps/frontend scaled

Проверить, что ReplicaSet контроллер теперь управляет тремя
репликами, и они готовы к работе, можно следующим образом:

kubectl get rs frontend

NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         1       102s

kubectl get rs frontend

NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       2m

kubectl get events
kubectl describe node kind-control-plane | less
kubectl describe node kind-worker | less
kubectl describe node kind-worker1 | less
kubectl describe node kind-worker2 | less
kubectl get pods -A -o wide
kubectl get nodes -o wide

Проверим, что благодаря контроллеру pod-ы действительно 
восстанавливаются после их ручного удаления:

kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w
kubectl delete pods -l app=frontend
kubectl get pods -l app=frontend

NAME             READY   STATUS    RESTARTS   AGE
frontend-6bfsv   1/1     Running   0          74s
frontend-bzrrg   1/1     Running   0          74s
frontend-tqfht   1/1     Running   0          74s

Повторно примените манифест frontend-replicaset.yaml:

kubectl apply -f frontend-replicaset.yaml 

replicaset.apps/frontend configured

Убедитесь, что количество реплик вновь уменьшилось до одной:

kubectl get pods -l app=frontend

NAME             READY   STATUS    RESTARTS   AGE
frontend-tqfht   1/1     Running   0          91s

Измените манифест таким образом, чтобы сразу разворачивалось три 
реплики сервиса, вновь примените его:

В файле frontend-replicaset.yaml выставим replicas: 3 и затем применим.

# frontend-replicaset.yaml file:
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: kodmandvl/myfrontend:k8sintro
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: PORT
          value: "8080"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"
        - name: ENABLE_PROFILER
          value: "0"

vim frontend-replicaset.yaml 

kubectl apply -f frontend-replicaset.yaml 

replicaset.apps/frontend configured

kubectl get pods -l app=frontend

NAME             READY   STATUS    RESTARTS   AGE
frontend-r8578   1/1     Running   0          6s
frontend-rjrz5   1/1     Running   0          6s
frontend-tqfht   1/1     Running   0          6m3s

##### ОБНОВЛЕНИЕ REPLICASET: #####

Давайте представим, что мы обновили исходный код и хотим выкатить
новую версию микросервиса.

Добавьте на DockerHub версию образа с новым тегом (v0.0.2, можно
просто перетегировать старый образ):

cd ~
git clone https://github.com/GoogleCloudPlatform/microservices-demo
cd microservices-demo/src/frontend/
ls
# Пробуем запушить в DockerHub:
# docker login # Если еще не залогинился на этой машине
docker build -t kodmandvl/myfrontend:v0.0.2 .
docker push kodmandvl/myfrontend:v0.0.2
docker images | grep myfront

Обновите в манифесте версию образа:

# frontend-replicaset.yaml file:
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: kodmandvl/myfrontend:v0.0.2
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: PORT
          value: "8080"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"
        - name: ENABLE_PROFILER
          value: "0"

vim frontend-replicaset.yaml

Примените новый манифест, параллельно запустите отслеживание
происходящего:

kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w

NAME             READY   STATUS    RESTARTS   AGE
frontend-r8578   1/1     Running   0          20m
frontend-rjrz5   1/1     Running   0          20m
frontend-tqfht   1/1     Running   0          26m

Кажется, ничего не произошло.

Давайте проверим образ, указанный в ReplicaSet:

kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'

kodmandvl/myfrontend:v0.0.2

И образ, из которого сейчас запущены pod-ы, управляемые контроллером:

kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/myfrontend:k8sintro kodmandvl/myfrontend:k8sintro kodmandvl/myfrontend:k8sintro

Обратите внимание на использование ключа -o jsonpath для
форматирования вывода. Подробнее с данным функционалом kubectl
можно ознакомиться по ссылке:

https://kubernetes.io/docs/reference/kubectl/jsonpath/

Удалите все запущенные pod и после их пересоздания еще раз
проверьте, из какого образа они развернулись:

kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w

kubectl get pods -l app=frontend

NAME             READY   STATUS    RESTARTS   AGE
frontend-ll9q2   1/1     Running   0          16s
frontend-nh2dx   1/1     Running   0          16s
frontend-td67g   1/1     Running   0          16s

kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'

kodmandvl/myfrontend:v0.0.2

kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/myfrontend:v0.0.2 kodmandvl/myfrontend:v0.0.2 kodmandvl/myfrontend:v0.0.2

Еще посмотрим события и внутрь подов, а также запустим bash в поде.

First, look at the logs of the affected container:

kubectl logs ${POD_NAME} ${CONTAINER_NAME}

If your container has previously crashed, you can access the previous containers crash log with:

kubectl logs --previous ${POD_NAME} ${CONTAINER_NAME}

If the container image includes debugging utilities, as is the case with images built from Linux and Windows OS base images, you can run commands inside a specific container with kubectl exec:

kubectl exec ${POD_NAME} -c ${CONTAINER_NAME} -- ${CMD} ${ARG1} ${ARG2} ... ${ARGN}

Note: -c ${CONTAINER_NAME} is optional. You can omit it for Pods that only contain a single container.

Примеры для нашего кластера (под frontend-nh2dx):

kubectl get po -o wide 
kubectl describe pods frontend-nh2dx
kubectl logs frontend-nh2dx
kubectl logs frontend-nh2dx server 
kubectl exec frontend-nh2dx -c server -- ls
kubectl exec frontend-nh2dx -c server -it -- sh
kubectl exec frontend-nh2dx -it -- sh

Посмотреть события в кластере и зайти на ноду:

kubectl get events -o wide
kubectl get events
kubectl events
kubectl get nodes -o wide
docker exec -it kind-worker3 bash

ВОПРОС:
Руководствуясь материалами лекции опишите произошедшую ситуацию,
почему обновление ReplicaSet не повлекло обновление запущенных pod?

ОТВЕТ:
Replicaset не поддерживает обновление образов.
До тех пор, пока есть необходимое количество подов, соответствующих меткам селектора, работа ReplicaSet-а выполнена и изменения не требуются.
Для того, чтобы обновление образов выполнялось, нужно использовать Deployment, в случае Deployment-а поды были бы пересозданы с обновленным образом.
ReplicaSet применим больше в том случае, когда обновление образов не планируется.

Мы, тем временем, перейдем к следующему контроллеру, более
подходящему для развертывания и обновления приложений внутри
Kubernetes.

##### DEPLOYMENT: #####

Для начала воспроизведите действия, проделанные с микросервисом frontend, 
для микросервиса paymentService. 
Используйте label app: paymentservice.

Результат должен быть:
1) Собранный и помещенный в Docker Hub образ с двумя тегами v0.0.1 и v0.0.2;
2) Валидный манифест paymentservice-replicaset.yaml с тремя репликами, разворачивающими из образа версии v0.0.1.

cd ~
# git clone https://github.com/GoogleCloudPlatform/microservices-demo # Если еще не склонировано на этой машине
cd ~/microservices-demo/src/paymentservice/
ls
# Пробуем запушить в DockerHub:
# docker login # Если еще не залогинился на этой машине
pwd
docker build -t kodmandvl/mypaymentservice:v0.0.1 .
docker push kodmandvl/mypaymentservice:v0.0.1
docker build -t kodmandvl/mypaymentservice:v0.0.2 .
docker push kodmandvl/mypaymentservice:v0.0.2
docker images | grep mypayment

cp -aiv frontend-replicaset.yaml paymentservice-replicaset.yaml

nano paymentservice-replicaset.yaml

# paymentservice-replicaset.yaml file:
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      - name: server
        image: kodmandvl/mypaymentservice:v0.0.1
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"

# Снова смотрим примеры манифестов здесь:
# https://github.com/GoogleCloudPlatform/microservices-demo/tree/main/kubernetes-manifests
# https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/kubernetes-manifests/paymentservice.yaml

# Применим манифест:
kubectl apply -f paymentservice-replicaset.yaml
kubectl get po -l app=paymentservice
kubectl get po -l app=paymentservice -o wide
# Когда ошибки, смотрим логи, редактируем манифест, применяем снова, удаляем старые поды:
kubectl logs имя_пода
nano paymentservice-replicaset.yaml
kubectl apply -f paymentservice-replicaset.yaml
kubectl delete po -l app=paymentservice
kubectl get po -l app=paymentservice

kubectl get po --show-labels -l app=paymentservice
kubectl get po --show-labels -l app=paymentservice -o wide

Приступим к написанию Deployment манифеста для сервиса paymentservice:

1) Скопируйте содержимое файла paymentservice-replicaset.yaml в файл paymentservice-deployment.yaml:

cp -aiv paymentservice-replicaset.yaml paymentservice-deployment.yaml

2) Измените поле kind с ReplicaSet на Deployment

sed -i '/kind..ReplicaSet/s/ReplicaSet/Deployment/' paymentservice-deployment.yaml
# или: sed -i.prev '/kind..ReplicaSet/s/ReplicaSet/Deployment/' paymentservice-deployment.yaml
diff paymentservice-deployment.yaml paymentservice-replicaset.yaml 

3) Манифест готов. Примените его и убедитесь, что в кластере Kubernetes 
действительно запустилось три реплики сервиса paymentservice и 
каждая из них находится в состоянии Ready:

kubectl apply -f paymentservice-deployment.yaml 

deployment.apps/paymentservice created

kubectl get deployments.apps 

NAME             READY   UP-TO-DATE   AVAILABLE   AGE
paymentservice   3/3     3            3           17s

kubectl get po -l app=paymentservice

NAME                   READY   STATUS    RESTARTS   AGE
paymentservice-7wlr8   1/1     Running   0          18m
paymentservice-bwcbw   1/1     Running   0          18m
paymentservice-lvhgz   1/1     Running   0          18m

4) Обратите внимание, что помимо Deployment ( kubectl get deployments ) 
и трех pod, у нас появился новый ReplicaSet ( kubectl get rs ):

kubectl get deployments 

NAME             READY   UP-TO-DATE   AVAILABLE   AGE
paymentservice   3/3     3            3           4m17s

kubectl get replicasets

NAME             DESIRED   CURRENT   READY   AGE
frontend         3         3         3       74m
paymentservice   3         3         3       48m

kubectl get rs

NAME             DESIRED   CURRENT   READY   AGE
frontend         3         3         3       74m
paymentservice   3         3         3       48m

##### Обновление Deployment: #####

Давайте попробуем обновить наш Deployment на версию образа v0.0.2:

sed -i '/image.*v0.0.1/s/v0.0.1/v0.0.2/' paymentservice-deployment.yaml
diff paymentservice-deployment.yaml paymentservice-replicaset.yaml 
kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w

kubectl get pods -l app=paymentservice

NAME                             READY   STATUS        RESTARTS   AGE
paymentservice-7wlr8             1/1     Terminating   0          26m
paymentservice-bbb7856c9-jsc6c   1/1     Running       0          32s
paymentservice-bbb7856c9-rbpkr   1/1     Running       0          29s
paymentservice-bbb7856c9-t4hlh   1/1     Running       0          35s
paymentservice-lvhgz             1/1     Terminating   0          26m

Обратите внимание на последовательность обновления pod. 
По умолчанию применяется стратегия Rolling Update:

1) Создание одного нового pod с версией образа v0.0.2;
2) Удаление одного из старых pod;
3) Создание еще одного нового pod;
4) ... (и т.д.)

Убедитесь что:

1) Все новые pod развернуты из образа v0.0.2:

kubectl get replicaset paymentservice-bbb7856c9 -o=jsonpath='{.spec.template.spec.containers[0].image}'

kodmandvl/mypaymentservice:v0.0.2

kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/mypaymentservice:v0.0.2 kodmandvl/mypaymentservice:v0.0.2 kodmandvl/mypaymentservice:v0.0.2

2) Создано два ReplicaSet:
- Один (новый) управляет тремя репликами pod с образом v0.0.2;
- Второй (старый) управляет нулем реплик pod с образом v0.0.1;

kubectl get replicaset -o wide | grep -v ^frontend

NAME                       DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES                              SELECTOR
paymentservice             0         0         0       61m     server       kodmandvl/mypaymentservice:v0.0.1   app=paymentservice
paymentservice-bbb7856c9   3         3         3       8m23s   server       kodmandvl/mypaymentservice:v0.0.2   app=paymentservice,pod-template-hash=bbb7856c9

Также мы можем посмотреть на историю версий нашего Deployment:

kubectl rollout history deployment paymentservice

deployment.apps/paymentservice 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

##### Deployment | Rollback #####

Представим, что обновление по каким-то причинам произошло
неудачно и нам необходимо сделать откат. 
Kubernetes предоставляет такую возможность:

kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w

NAME                       DESIRED   CURRENT   READY   AGE
paymentservice             0         0         0       64m
paymentservice-bbb7856c9   3         3         3       11m
paymentservice             0         0         0       64m
paymentservice             1         0         0       64m
paymentservice             1         0         0       64m
paymentservice             1         1         0       64m
paymentservice             1         1         1       64m
paymentservice-bbb7856c9   2         3         3       11m
paymentservice             2         1         1       64m
paymentservice-bbb7856c9   2         3         3       11m
paymentservice-bbb7856c9   2         2         2       11m
paymentservice             2         1         1       64m
paymentservice             2         2         1       64m
paymentservice             2         2         2       64m
paymentservice-bbb7856c9   1         2         2       11m
paymentservice-bbb7856c9   1         2         2       11m
paymentservice             3         2         2       64m
paymentservice-bbb7856c9   1         1         1       11m
paymentservice             3         2         2       64m
paymentservice             3         3         2       64m
paymentservice             3         3         3       64m
paymentservice-bbb7856c9   0         1         1       11m
paymentservice-bbb7856c9   0         1         1       11m
paymentservice-bbb7856c9   0         0         0       11m
^C

kubectl get rs -l app=paymentservicece

NAME                       DESIRED   CURRENT   READY   AGE
paymentservice             3         3         3       65m
paymentservice-bbb7856c9   0         0         0       12m

В выводе мы можем наблюдать, как происходит постепенное 
масштабирование вниз “нового” ReplicaSet, и масштабирование вверх “старого”.

kubectl get replicaset paymentservice-bbb7856c9 -o=jsonpath='{.spec.template.spec.containers[0].image}'

kodmandvl/mypaymentservice:v0.0.2

kubectl get replicaset paymentservice -o=jsonpath='{.spec.template.spec.containers[0].image}'

kodmandvl/mypaymentservice:v0.0.1

kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/mypaymentservice:v0.0.1 kodmandvl/mypaymentservice:v0.0.1 kodmandvl/mypaymentservice:v0.0.1

##### Deployment | Задание со * #####

С использованием параметров maxSurge и maxUnavailable 
самостоятельно реализуйте два следующих сценария развертывания:

1) Аналог blue-green:
- Развертывание трех новых pod;
- Удаление трех старых pod;

2) Reverse Rolling Update:
- Удаление одного старого pod;
- Создание одного нового pod;
- ... (и т.д.)

Документация с описанием стратегий развертывания для Deployment:

https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy

В результате должно получиться два манифеста:
1) paymentservice-deployment-bg.yaml
2) paymentservice-deployment-reverse.yaml

1) Blue-green:

cp -aiv paymentservice-deployment.yaml paymentservice-deployment-bg.yaml 
nano paymentservice-deployment-bg.yaml 

cat paymentservice-deployment-bg.yaml | grep -A3 strategy

  strategy:
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 0

Применим и посмотрим в динамике:

kubectl apply -f paymentservice-deployment-bg.yaml | kubectl get pods -l app=paymentservice -w

kubectl get pods -l app=paymentservice -o wide

kubectl get replicaset paymentservice-bbb7856c9 -o=jsonpath='{.spec.template.spec.containers[0].image}'

kubectl get replicaset paymentservice -o=jsonpath='{.spec.template.spec.containers[0].image}'

kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kubectl get replicaset -l app=paymentservice -o wide

2) Reverse Rolling Update:

cp -aiv paymentservice-deployment-bg.yaml paymentservice-deployment-reverse.yaml
nano paymentservice-deployment-reverse.yaml 
diff paymentservice-deployment-bg.yaml paymentservice-deployment-reverse.yaml

$ cat paymentservice-deployment-reverse.yaml | grep -A3 strategy
  strategy:
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1

Снова откатим к v0.0.1 и снова применим в динамике и посмотрим:

kubectl rollout history deployment paymentservice
kubectl rollout undo deployment paymentservice --to-revision=3 | kubectl get rs -l app=paymentservice -w
kubectl get rs -l app=paymentservice
kubectl get replicaset paymentservice-bbb7856c9 -o=jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get replicaset paymentservice -o=jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'
kubectl apply -f paymentservice-deployment-reverse.yaml | kubectl get pods -l app=paymentservice -w
kubectl get pods -l app=paymentservice

##### PROBES #####

Давайте на примере микросервиса frontend посмотрим на то, как
probes влияют на процесс развертывания:

Создайте манифест frontend-deployment.yaml из которого можно
развернуть три реплики pod с тегом образа v0.0.1 
(сначала нужно собрать и выложить v0.0.1 на Docker Hub, т.к. по frontend-у у меня теги k8sintro и v0.0.2):

cd ~
# git clone https://github.com/GoogleCloudPlatform/microservices-demo # Если еще не склонирован репозиторий
cd ~/microservices-demo/src/frontend/
ls
# Пробуем запушить в DockerHub:
# docker login # Если еще не залогинился на этой машине
docker build -t kodmandvl/myfrontend:v0.0.1 .
docker push kodmandvl/myfrontend:v0.0.1
docker images | grep myfront

cp -aiv frontend-replicaset.yaml frontend-deployment.yaml
nano frontend-deployment.yaml 

diff frontend-replicaset.yaml frontend-deployment.yaml 
2c2
< kind: ReplicaSet
---
> kind: Deployment
19c19
<         image: kodmandvl/myfrontend:v0.0.2
---
>         image: kodmandvl/myfrontend:v0.0.1

Добавьте туда описание readinessProbe. Описание можно взять из манифеста по ссылке:
https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/kubernetes-manifests/frontend.yaml

nano frontend-deployment.yaml

Примените манифест с readinessProbe. Если все сделано правильно, то
мы вновь увидим три запущенных pod в описании которых ( kubectl
describe pod ) будет указание на наличие readinessProbe и ее
параметры.

kubectl apply -f frontend-deployment.yaml
kubectl get po -l app=frontend -w
kubectl get po -l app=frontend

kubectl describe pod -l app=frontend

kubectl describe pod -l app=frontend | grep -i readiness

    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3

Давайте попробуем сымитировать некорректную работу приложения и
посмотрим, как будет вести себя обновление:
- Замените в описании пробы URL /_healthz на /_health ;
- Разверните версию v0.0.2.

! В манифесте, который попадет в PR, readinessProbe должна остаться рабочей.

nano frontend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
kubectl get po -l app=frontend -w

Если посмотреть на текущее состояние нашего микросервиса, мы
увидим, что был создан один pod новой версии, но его статус готовности
следующий:

kubectl get po -l app=frontend -o wide 

NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE           NOMINATED NODE   READINESS GATES
frontend-74d847d47d-cnkk7   0/1     Running   0          111s    10.244.2.5   kind-worker2   <none>           <none>
..........

Команда kubectl describe pod поможет нам понять причину:

kubectl describe pod frontend-74d847d47d-cnkk7  

..........
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  3m38s                 default-scheduler  Successfully assigned default/frontend-74d847d47d-cnkk7 to kind-worker2
  Normal   Pulled     3m38s                 kubelet            Container image "kodmandvl/myfrontend:v0.0.2" already present on machine
  Normal   Created    3m38s                 kubelet            Created container server
  Normal   Started    3m38s                 kubelet            Started container server
  Warning  Unhealthy  18s (x22 over 3m28s)  kubelet            Readiness probe failed: HTTP probe failed with statuscode: 404

Как можно было заметить, пока readinessProbe для нового pod не 
станет успешной, Deployment не будет пытаться продолжить обновление. 
На данном этапе может возникнуть вопрос - как автоматически
отследить успешность выполнения Deployment (например для запуска в
CI/CD).
В этом нам может помочь следующая команда:

kubectl rollout status deployment/frontend

Waiting for deployment "frontend" rollout to finish: 1 out of 3 new replicas have been updated...
Ctrl+C

kubectl rollout status deployment/frontend --timeout=60s

Waiting for deployment "frontend" rollout to finish: 1 out of 3 new replicas have been updated...
error: timed out waiting for the condition

kubectl rollout undo deployment/frontend

kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/myfrontend:v0.0.1 kodmandvl/myfrontend:v0.0.1 kodmandvl/myfrontend:v0.0.1

Вернем в манифесте описание пробы на корректное, а версию оставим v0.0.2:

nano frontend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
kubectl get po -l app=frontend -w
kubectl get po -l app=frontend
kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

kodmandvl/myfrontend:v0.0.2 kodmandvl/myfrontend:v0.0.2 kodmandvl/myfrontend:v0.0.2

kubectl describe pod -l app=frontend | grep -i readiness
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3

kubectl get pod -l app=frontend -o wide

NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE           NOMINATED NODE   READINESS GATES
frontend-6fd9ccff9d-5zwww   1/1     Running   0          7m48s   10.244.1.5   kind-worker3   <none>           <none>
frontend-6fd9ccff9d-lkxsz   1/1     Running   0          7m38s   10.244.2.6   kind-worker2   <none>           <none>
frontend-6fd9ccff9d-rcwpp   1/1     Running   0          7m18s   10.244.3.5   kind-worker    <none>           <none>

##### DAEMONSET: #####

Рассмотрим еще один контроллер Kubernetes. 
Отличительная особенность DaemonSet в том, что при его применении на каждом
физическом хосте создается по одному экземпляру pod, описанного в спецификации.
Типичные кейсы использования DaemonSet:
- Сетевые плагины;
- Утилиты для сбора и отправки логов (Fluent Bit, Fluentd, etc...);
- Различные утилиты для мониторинга (Node Exporter, etc...);
- ...

# DaemonSet | Задание со *

Опробуем DaemonSet на примере Node Exporter :
Найдите в интернете или напишите самостоятельно манифест node-
exporter-daemonset.yaml для развертывания DaemonSet с Node
Exporter;
После применения данного DaemonSet и выполнения команды: kubectl
port-forward <имя любого pod в DaemonSet> 9100:9100 метрики
должны быть доступны на localhost: curl localhost:9100/metrics .

nano node-exporter-daemonset.yaml
kubectl apply -f node-exporter-daemonset.yaml 
kubectl get po -o wide

kubectl get po -o wide | grep -e ^NAME -e ^node[-]exporter

NAME                             READY   STATUS    RESTARTS      AGE   IP           NODE           NOMINATED NODE   READINESS GATES
node-exporter-6q6bl              1/1     Running   0             22m   10.244.3.4   kind-worker    <none>           <none>
node-exporter-8qh5s              1/1     Running   0             22m   10.244.1.4   kind-worker3   <none>           <none>
node-exporter-qbxdt              1/1     Running   0             22m   10.244.2.4   kind-worker2   <none>           <none>

cd ~
nohup kubectl port-forward node-exporter-6q6bl 9100:9100 &
curl localhost:9100/metrics

# DaemonSet | Задание с **

Как правило, мониторинг требуется не только для worker, но и для master
нод. При этом, по умолчанию, pod управляемые DaemonSet, на master
нодах не разворачиваются;
Найдите способ модернизировать свой DaemonSet таким образом, чтобы
Node Exporter был развернут как на master, так и на worker нодах
(конфигурацию самих нод изменять нельзя);
Отразите изменения в манифесте.

Добавил такое в спецификацию шаблона:

      tolerations:
      # these tolerations are to have the daemonset runnable on control plane nodes
      # remove them if your control plane nodes should not run pods
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule

nano node-exporter-daemonset.yaml 

kubectl apply -f node-exporter-daemonset.yaml 

daemonset.apps/node-exporter configured

kubectl get po -o wide | grep -e ^NAME -e ^node[-]exporter

NAME                             READY   STATUS              RESTARTS      AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
node-exporter-6q6bl              1/1     Running             0             32m   10.244.3.4   kind-worker          <none>           <none>
node-exporter-8qh5s              1/1     Running             0             32m   10.244.1.4   kind-worker3         <none>           <none>
node-exporter-8vsn8              0/1     ContainerCreating   0             7s    <none>       kind-control-plane   <none>           <none>
node-exporter-qbxdt              1/1     Running             0             32m   10.244.2.4   kind-worker2         <none>           <none>

kubectl get po -o wide | grep -e ^NAME -e ^node[-]exporter

NAME                             READY   STATUS    RESTARTS      AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
node-exporter-2tr2s              1/1     Running   0             15s   10.244.3.5   kind-worker          <none>           <none>
node-exporter-758ws              1/1     Running   0             12s   10.244.1.5   kind-worker3         <none>           <none>
node-exporter-8vsn8              1/1     Running   0             26s   10.244.0.5   kind-control-plane   <none>           <none>
node-exporter-cl69r              1/1     Running   0             10s   10.244.2.5   kind-worker2         <none>           <none>

nohup kubectl port-forward node-exporter-8vsn8 9100:9100 &

curl localhost:9100/metrics | less

##### GIT CHECKOUT, CREATE DIRECTORY, COPY FILES, PULL REQUEST: #####

cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-controllers
git branch
mkdir kubernetes-controllers
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-controllers/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-controllers"
git push --set-upstream origin kubernetes-controllers
git status

# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.

# Если здесь нужно переключить в ветку main, то:
git branch
git switch main
git branch
git status

########## ТЕКСТ ДЛЯ PULL REQUEST: ##########

# Выполнено ДЗ № kubernetes-controllers

 - [OK] Основное ДЗ
 - [OK] Задание со * для Deployment, задания со * и с ** для DaemonSet

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям

## Как запустить проект:
 - kubectl apply -f kodmandvl_platform/kubernetes-controllers/имя_файла.yaml

## Как проверить работоспособность:
 - kubectl get po -o wide

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

## Ответ на вопрос про ReplicaSet:
 - ВОПРОС: Руководствуясь материалами лекции опишите произошедшую ситуацию, почему обновление ReplicaSet не повлекло обновление запущенных pod?
 - ОТВЕТ: Replicaset не поддерживает обновление образов. До тех пор, пока есть необходимое количество подов, соответствующих меткам селектора, работа ReplicaSet-а выполнена и изменения не требуются. Для того, чтобы обновление образов выполнялось, нужно использовать Deployment, в случае Deployment-а поды были бы пересозданы с обновленным образом. ReplicaSet применим больше в том случае, когда обновление образов не планируется.

