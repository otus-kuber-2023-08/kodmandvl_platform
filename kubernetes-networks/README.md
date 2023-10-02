Файлы манифестов для заданий "без звездочки" доступны на GitHub здесь: 
https://github.com/express42/otus-platform-snippets/tree/master/Module-02/Networks

##### PREPARE: #####

# Before start we can pull image:
docker pull gcr.io/k8s-minikube/kicbase:v0.0.40

# Start MiniKube:
minikube start
# Или так (для выбора определенных нужных параметров запуска запустил так, в т.ч. драйвер virtualbox):
minikube start -p minikube --kubernetes-version=v1.27.4 --driver=virtualbox --cpus=4 --memory=8192m
minikube profile list
echo 'hostname ; date ; pwd ; whoami; exit' | minikube ssh
echo 'docker ps ; exit' | minikube ssh
echo 'docker images ; exit' | minikube ssh
kubectl get pods -A
kubectl get nodes
kubectl get nodes -o wide 
kubectl get pods -A -o wide

##### Добавление проверок Pod: #####

Откройте файл с описанием Pod из предыдущего ДЗ ( kubernetes-intro/web-pod.yml ) 
и добавьте в описание пода readinessProbe (можно добавлять его сразу после указания образа контейнера):
..........
    image: kodmandvl/mywebserver:k8sintro # Образ из которого создается контейнер
    readinessProbe:
      httpGet:
        path: /index.html
        port: 80
..........

Запустите наш под командой kubectl apply -f web-pod.yaml:

kubectl apply -f ../kubernetes-intro/web-pod.yaml

Теперь выполните команду kubectl get pod/web и убедитесь, что под перешел в состояние Running:

kubectl get pod/web -w
Ctrl+C
kubectl get pod/web

NAME   READY   STATUS    RESTARTS   AGE
web    0/1     Running   0          3m54s

Теперь сделайте команду kubectl describe pod/web (вывод объемный, но в нем много интересного), 
посмотрите в конце листинга на список Conditions:

kubectl describe pod/web

..........
  Warning  Unhealthy  59s (x20 over 3m36s)  kubelet            Readiness probe failed: Get "http://10.244.0.4:80/index.html": dial tcp 10.244.0.4:80: connect: connection refused
..........

kubectl describe pod/web | grep -A5 ^Conditions

Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 

Также посмотрите на список событий, связанных с Pod (Readiness probe failed .......... connection refused).

Из листинга выше видно, что проверка готовности контейнера завершается неудачно. 
Это неудивительно - веб-сервер в контейнере слушает порт 8000 (по условиям первого ДЗ). 
Пока мы не будем исправлять эту ошибку, а добавим другой вид проверок: livenessProbe .

Самостоятельно добавьте в манифест проверку состояния веб-сервера. Например, так:

    livenessProbe:
      tcpSocket: { port: 8000 }

Запустите Pod с новой конфигурацией (без удаления пода у меня при применении ошибки были):

kubectl delete pods web

kubectl apply -f ../kubernetes-intro/web-pod.yaml

kubectl get po

kubectl describe pod/web

Вопрос для самопроверки:
Почему следующая конфигурация валидна, но не имеет смысла?
livenessProbe:
  exec:
    command:
      - 'sh'
      - '-c'
      - 'ps aux | grep my_web_server_process'
Бывают ли ситуации, когда она все-таки имеет смысл?

ОТВЕТ:
Я думаю, что данная конфигурация не имеет смысла, т.к. процесс может зависнуть или порт не будет в действительности прослушиваться, 
а это значит, что в действительности процесс для нас как не живой.
Возможно, такая конфигурация будет иметь смысл для приложения, в котором просто важно, чтобы процесс висел/работал (держал какую-то блокировку на файле или т.п.).

##### Создание Deployment #####

Скорее всего, в процессе изменения конфигурации Pod, вы столкнулись 
с неудобством обновления конфигурации пода через kubectl 
(и уже нашли ключик --force ):

Попробуем вернуть изменения назад-вперед и с ключом --force:

kubectl get po

vim ../kubernetes-intro/web-pod.yaml

kubectl apply -f ../kubernetes-intro/web-pod.yaml

kubectl apply --force -f ../kubernetes-intro/web-pod.yaml

kubectl get po

kubectl describe pod/web

vim ../kubernetes-intro/web-pod.yaml

kubectl apply -f ../kubernetes-intro/web-pod.yaml

kubectl apply --force -f ../kubernetes-intro/web-pod.yaml

kubectl get po

kubectl describe pod/web

В любом случае, для управления несколькими однотипными подами 
такой способ не очень подходит. Создадим Deployment, который упростит 
обновление конфигурации пода и управление группами подов.

Для начала, создайте новую папку kubernetes-networks в вашем репозитории:

cd ../ && pwd && mkdir -p kubernetes-networks && cd kubernetes-networks/ && pwd

В этой папке создайте новый файл web-deploy.yaml:

nano web-deploy.yaml

Начнем заполнять наш файл-манифест для Deployment:

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
..........  

Теперь в блок template можно перенести конфигурацию Pod из 
web-pod.yaml, убрав строки apiVersion: v1 и kind: Pod.

Для начала удалим старый под из кластера:

kubectl delete pod/web --grace-period=0 --force

kubectl get po

И приступим к деплою:

cd ../kubernetes-networks/

kubectl apply -f web-deploy.yaml

Посмотрим, что получилось:

kubectl get po

kubectl describe deployment web

Name:                   web
Namespace:              default
CreationTimestamp:      Tue, 26 Sep 2023 14:10:07 +0300
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=web
Replicas:               1 desired | 1 updated | 1 total | 0 available | 1 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=web
  Init Containers:
   init-web:
    Image:      busybox:1.36
    Port:       <none>
    Host Port:  <none>
    Command:
      sh
      -c
      wget -O- https://tinyurl.com/otus-k8s-intro | sh
    Environment:  <none>
    Mounts:
      /app from app (rw)
  Containers:
   web:
    Image:        kodmandvl/mywebserver:k8sintro
    Port:         <none>
    Host Port:    <none>
    Liveness:     tcp-socket :8000 delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:    http-get http://:80/index.html delay=0s timeout=1s period=10s #success=1 #failure=3
    Environment:  <none>
    Mounts:
      /app from app (rw)
  Volumes:
   app:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    True    ReplicaSetUpdated
OldReplicaSets:  <none>
NewReplicaSet:   web-699c8fc6c9 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  58s   deployment-controller  Scaled up replica set web-699c8fc6c9 to 1

'

kubectl get deployments

NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    0/1     1            0           4m25s

Поскольку мы не исправили ReadinessProbe , то поды, входящие в наш Deployment, 
не переходят в состояние Ready из-за неуспешной проверки.

На предыдущем слайде видно, что это влияет на состояние всего Deployment (строчка Available в блоке Conditions).

Теперь самое время исправить ошибку! Поменяйте в файле web-deploy.yaml следующие параметры: 
-◦Увеличьте число реплик до 3 ( replicas: 3 )
- Исправьте порт в readinessProbe на порт 8000

Примените изменения командой kubectl apply -f web-deploy.yaml:

kubectl apply -f web-deploy.yaml

deployment.apps/web configured

kubectl get deployments

NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    3/3     3            3           3m24s

kubectl get pods

NAME                  READY   STATUS    RESTARTS   AGE
web-977d47767-c6b6j   1/1     Running   0          3m37s
web-977d47767-kcwnr   1/1     Running   0          3m37s
web-977d47767-rnnbd   1/1     Running   0          3m37s

##### Deployment | Самостоятельная работа #####

Теперь проверьте состояние нашего Deployment командой kubectl describe deploy/web.
Убедитесь, что условия (Conditions) Available и Progressing выполняются (в столбце Status значение true ).

kubectl describe deploy/web

Name:                   web
Namespace:              default
..........
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
..........

Добавьте в манифест ( web-deploy.yaml ) блок strategy (можно сразу перед шаблоном пода):

..........
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%
  template:
..........


kubectl apply -f web-deploy.yaml

Попробуйте разные варианты деплоя с крайними значениями maxSurge и maxUnavailable (оба 0, оба 100%, 0 и 100%). 
За процессом можно понаблюдать с помощью kubectl get events --watch или установить kubespy и использовать его ( kubespy trace deploy ).

Установим kubespy:

cd ~/Distribs
wget https://github.com/pulumi/kubespy/releases/download/v0.6.2/kubespy-v0.6.2-linux-amd64.tar.gz
tar -xzvf ./kubespy-v0.6.2-linux-amd64.tar.gz
sudo install -o root -g root -m 0755 kubespy /usr/local/bin/kubespy
ls -alFhtr /usr/local/bin/
kubespy version

Меняем maxSurge и maxUnavailable, применяем маничест и смотрим (в трех окнах):

kubectl apply -f web-deploy.yaml

kubectl get events --watch

kubespy trace deploy web

(также в рамках этих тестов я менял и количество реплик для наглядности)

##### Создание Service #####

Для того, чтобы наше приложение было доступно внутри кластера (а тем более - снаружи), 
нам потребуется объект типа Service . Начнем с самого распространенного типа сервисов - ClusterIP .

- ClusterIP выделяет для каждого сервиса IP-адрес из особого диапазона 
(этот адрес виртуален и даже не настраивается на сетевых интерфейсах).
- Когда под внутри кластера пытается подключиться к виртуальному IP-адресу сервиса, 
то нода, где запущен под, меняет адрес получателя в сетевых пакетах на настоящий адрес пода.
- Нигде в сети, за пределами ноды, виртуальный ClusterIP не встречается.

##### Создание Service | ClusterIP #####

ClusterIP удобны в тех случаях, когда:
- Нам не надо подключаться к конкретному поду сервиса
- Нас устраивает случайное расределение подключений между подами
- Нам нужна стабильная точка подключения к сервису, независимая от подов, нод и DNS-имен. 
Например:
- Подключения клиентов к кластеру БД (multi-read) или хранилищу
- Простейшая (не совсем, use IPVS, Luke) балансировка нагрузки внутри кластера

Итак, создадим манифест для нашего сервиса в папке kubernetes-networks .
Файл web-svc-cip.yaml :

apiVersion: v1
kind: Service
metadata:
  name: web-svc-cip
spec:
  selector:
    app: web
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000

nano web-svc-cip.yaml

Применим изменения: 

kubectl apply -f web-svc-cip.yaml

Проверим результат (отметьте назначенный CLUSTER-IP):

kubectl get services

NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
kubernetes    ClusterIP   10.96.0.1      <none>        443/TCP   37m
web-svc-cip   ClusterIP   10.99.254.55   <none>        80/TCP    17s

Подключимся к ВМ Minikube (команда minikube ssh и затем sudo -i ):
- Сделайте curl http://<CLUSTER-IP>/index.html - работает!
- Сделайте ping <CLUSTER-IP> - пинга нет
- Сделайте arp -an , ip addr show - нигде нет ClusterIP
- Сделайте iptables --list -nv -t nat - вот где наш кластерный IP!

minikube ssh -p minikube

sudo -i

curl http://10.99.254.55/index.html 

..........
<h3>Static hosts info</h3>
<pre># Kubernetes-managed hosts file.
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
fe00::0	ip6-mcastprefix
fe00::1	ip6-allnodes
fe00::2	ip6-allrouters
10.244.0.5	web-977d47767-c6b6j</pre>
</body>
</html>

При этом, как и ожидалось, кластерный IP сам по себе (с ноды) не пингуется, как объяснялось выше:

ping 10.99.254.55 -c5

PING 10.99.254.55 (10.99.254.55): 56 data bytes
--- 10.99.254.55 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss

arp -an

arp -an | grep 10.99.254.55

ip addr show 

ip addr show | grep 10.99.254.55 

iptables --list -nv -t nat

..........
Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-SVC-JD5MR3NA4I4DYORP  tcp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:metrics cluster IP */ tcp dpt:9153
    0     0 KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
    0     0 KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  *      *       0.0.0.0/0            10.96.0.1            /* default/kubernetes:https cluster IP */ tcp dpt:443
    2   120 KUBE-SVC-6CZTMAROCN3AQODZ  tcp  --  *      *       0.0.0.0/0            10.99.254.55         /* default/web-svc-cip cluster IP */ tcp dpt:80
 1362 81704 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
..........

iptables --list -nv -t nat | grep 10.99.254.55 

    2   120 KUBE-SVC-6CZTMAROCN3AQODZ  tcp  --  *      *       0.0.0.0/0            10.99.254.55         /* default/web-svc-cip cluster IP */ tcp dpt:80
    2   120 KUBE-MARK-MASQ  tcp  --  *      *      !10.244.0.0/16        10.99.254.55         /* default/web-svc-cip cluster IP */ tcp dpt:80

- Нужное правило находится в цепочке KUBE-SERVICES
- Затем мы переходим в цепочку KUBE-SVC-..... - здесь находятся правила "балансировки" между цепочками KUBE-SEP-.....
- SVC - очевидно Service
- В цепочках KUBE-SEP-..... находятся конкретные правила перенаправления трафика (через DNAT)
- SEP - Service Endpoint

##### Включение IPVS #####

Итак, с версии 1.0.0 Minikube поддерживает работу kube-proxy в режиме IPVS. 
Попробуем включить его "наживую".

При запуске нового инстанса Minikube лучше использовать ключ --extra-config и сразу указать, что мы хотим IPVS.

Включим IPVS для kube-proxy , исправив ConfigMap (конфигурация Pod, хранящаяся в кластере):
- Выполните команду kubectl --namespace kube-system edit configmap/kube-proxy
- Или minikube dashboard (далее надо выбрать namespace kube-system , Configs and Storage/Config Maps)

kubectl --namespace kube-system get configmap/kube-proxy -o yaml

kubectl --namespace kube-system edit configmap/kube-proxy

Теперь найдите в файле конфигурации kube-proxy строку mode: "", 
измените значение mode с пустого на ipvs и добавьте параметр strictARP: true и сохраните изменения:

..........
    ipvs:
..........
      strictARP: true
..........
    mode: "ipvs"
..........

kubectl --namespace kube-system get configmap/kube-proxy -o yaml

Теперь удалим Pod с kube-proxy , чтобы применить новую конфигурацию 
(он входит в DaemonSet и будет запущен автоматически):

kubectl get po -A | grep kube[-]proxy

kubectl --namespace kube-system delete pod kube-proxy-9kp47

kubectl get po -A | grep kube[-]proxy

Описание работы и настройки IPVS в K8s: 
https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md

Причины включения strictARP описаны тут: 
https://github.com/metallb/metallb/issues/153

После успешного рестарта kube-proxy выполним команду minikube ssh и проверим, что получилось. 
Выполним команду iptables --list -nv -t nat в ВМ Minikube: 

minikube ssh

sudo -i

iptables --list -nv -t nat

Что-то поменялось, но старые цепочки на месте (хотя у них теперь 0
references): 
- kube-proxy настроил все по-новому, но не удалил мусор 
- Запуск kube-proxy --cleanup в нужном поде - тоже не помогает: 

kubectl --namespace kube-system exec kube-proxy-gzklb -- kube-proxy --cleanup

Полностью очистим все правила iptables :

Создадим в ВМ с Minikube файл /tmp/iptables.cleanup :

*nat
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
COMMIT
*filter
COMMIT
*mangle
COMMIT

Применим конфигурацию: 

iptables-restore /tmp/iptables.cleanup

Теперь надо подождать (примерно 30 секунд), пока kube-proxy восстановит правила для сервисов:

Проверим результат: 

iptables --list -nv -t nat

Итак, лишние правила удалены и мы видим только актуальную конфигурацию 
(kube-proxy периодически делает полную синхронизацию правил в своих цепочках).

Как посмотреть конфигурацию IPVS? 
Можно использовать встроенную поддержку IPVS в Kubernetes. 
Для этого выполните команду: 

kubectl get service -o yaml

И среди прочих сервисов найдем наш:

..........
- apiVersion: v1
  kind: Service
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"web-svc-cip","namespace":"default"},"spec":{"ports":[{"port":80,"protocol":"TCP","targetPort":8000}],"selector":{"app":"web"},"type":"ClusterIP"}}
    creationTimestamp: "2023-09-28T12:21:04Z"
    name: web-svc-cip
    namespace: default
    resourceVersion: "2216"
    uid: 8ab541de-8833-497a-ab9e-6569581a134b
  spec:
    clusterIP: 10.99.254.55
    clusterIPs:
    - 10.99.254.55
    internalTrafficPolicy: Cluster
    ipFamilies:
    - IPv4
    ipFamilyPolicy: SingleStack
    ports:
    - port: 80
      protocol: TCP
      targetPort: 8000
    selector:
      app: web
    sessionAffinity: None
    type: ClusterIP
  status:
    loadBalancer: {}
..........

Теперь сделаем ping кластерного IP: 

ping -c1 10.99.254.55

Итак, все работает. Но почему пингуется виртуальный IP? 
Все просто - он уже не такой виртуальный. Этот IP теперь есть на интерфейсе kube-ipvs0 :

ip addr show kube-ipvs0

12: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default 
    link/ether 1e:c9:bd:e6:f8:d5 brd ff:ff:ff:ff:ff:ff
    inet 10.96.0.10/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.96.0.1/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.99.254.55/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever

Также, правила в iptables построены по-другому. 
Вместо цепочки правил для каждого сервиса, теперь используются хэш-таблицы (ipset). 
Можете посмотреть их, установив утилиту ipset в toolbox:

toolbox

dnf install -y ipvsadm && dnf clean all

dnf install -y ipset && dnf clean all

ipvsadm --list -n

..........
TCP  10.99.254.55:80 rr
  -> 10.244.0.3:8000              Masq    1      0          0         
  -> 10.244.0.4:8000              Masq    1      0          0         
  -> 10.244.0.5:8000              Masq    1      0          0       
..........

ipset list

..........
Name: KUBE-CLUSTER-IP
Type: hash:ip,port
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 512
References: 3
Number of entries: 5
Members:
10.96.0.10,tcp:9153
10.99.254.55,tcp:80
10.96.0.10,tcp:53
10.96.0.1,tcp:443
10.96.0.10,udp:53
..........

В действительности у меня наш кластерный IP так и не запинговался, если честно.
Пробовал на виртуалке, внутри которой minikube запускал с движком docker; 
Пробовал на хосте, запуская minikube с движком docker; 
пробовал на хосте, запуская minikube с движком virtualbox. 
Во всех попытках как бы вывод команд корректный и как бы всё работало (до начала шагов с MetalLB), но кластерный IP никак не хотел пинговаться...

##### Если в какой-то момент будем перезапускать кластер minikube, например, после остановки, то: #####

(т.к. настройки IPVS, которые мы делали выше, слетят)

minikube start -p minikube --kubernetes-version=v1.27.4 --driver=virtualbox --cpus=4 --memory=8192m --extra-config kube-proxy.mode=ipvs

# Сначала посмотрим, что изменится: 
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system

# Применим изменения: 
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

kubectl --namespace kube-system get configmap/kube-proxy -o yaml

##### РАБОТА С LOADBALANCER И INGRESS #####

##### Установка MetalLB #####

MetalLB позволяет запустить внутри кластера L4-балансировщик, который будет принимать извне запросы к сервисам и раскидывать их между подами. 
Установка его проста:

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.0/manifests/namespace.yaml

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml

kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

! В продуктиве так делать не надо. Сначала стоит скачать файл и разобраться, что там внутри.

Проверьте, что были созданы нужные объекты: 

kubectl --namespace metallb-system get all

NAME                              READY   STATUS    RESTARTS   AGE
pod/controller-64f57db87d-h9tjs   1/1     Running   0          8m4s
pod/speaker-jz8q7                 1/1     Running   0          8m4s

NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/webhook-service   ClusterIP   10.96.219.13   <none>        443/TCP   8m4s

NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/speaker   1         1         1       1            1           kubernetes.io/os=linux   8m4s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/controller   1/1     1            1           8m4s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/controller-64f57db87d   1         1         1       8m4s

Теперь настроим балансировщик с помощью ConfigMap

Создайте манифест metallb-config.yaml в папке kubernetes-networks :

apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.17.255.1-172.17.255.255 

В конфигурации мы настраиваем:
- Режим L2 (анонс адресов балансировщиков с помощью ARP) 
- Создаем пул адресов 172.17.255.1 - 172.17.255.255 - они будут назначаться сервисам с типом LoadBalancer. 

Теперь можно применить наш манифест: 

kubectl apply -f metallb-config.yaml

Контроллер подхватит изменения автоматически.

Сделайте копию файла web-svc-cip.yaml в web-svc-lb.yaml и откройте его в редакторе, 
измените имя сервиса и его тип на LoadBalancer, 
примените манифест:

cp -aiv web-svc-cip.yaml web-svc-lb.yaml

nano web-svc-lb.yaml 

diff web-svc-cip.yaml web-svc-lb.yaml

4c4
<   name: web-svc-cip
---
>   name: web-svc-lb
8c8
<   type: ClusterIP
---
>   type: LoadBalancer

kubectl apply -f web-svc-lb.yaml

Теперь посмотрите логи пода-контроллера MetalLB (подставьте правильное имя!): 

kubectl --namespace metallb-system logs pod/controller-64f57db87d-h9tjs

Обратите внимание на назначенный IP-адрес (или посмотрите его в выводе kubectl describe svc web-svc-lb ): 

kubectl describe svc web-svc-lb

..........
Events:
  Type     Reason            Age    From                Message
  ----     ------            ----   ----                -------
  Warning  AllocationFailed  3m48s  metallb-controller  Failed to allocate IP for "default/web-svc-lb": no available IPs
..........

На самом деле не удалось выделить IP, в event-ах видим ошибку, также ошибки видим и в логах.

Поменял metallb-config.yaml на такой:

apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-balancer
  namespace: metallb-system
spec:
  addresses:
  - 172.17.255.1-172.17.255.255
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: myl2advertisement
  namespace: metallb-system

kubectl apply -f metallb-config.yaml

kubectl apply -f web-svc-lb.yaml

Теперь посмотрите логи пода-контроллера MetalLB (подставьте правильное имя!): 

kubectl --namespace metallb-system logs pod/controller-64f57db87d-h9tjs

Обратите внимание на назначенный IP-адрес (или посмотрите его в выводе kubectl describe svc web-svc-lb ): 

kubectl describe svc web-svc-lb

Теперь в выоде видим успех:

kubectl describe svc web-svc-lb

Name:                     web-svc-lb
Namespace:                default
Labels:                   <none>
Annotations:              metallb.universe.tf/ip-allocated-from-pool: metallb-balancer
Selector:                 app=web
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.206.84
IPs:                      10.96.206.84
LoadBalancer Ingress:     172.17.255.1
Port:                     <unset>  80/TCP
TargetPort:               8000/TCP
NodePort:                 <unset>  32741/TCP
Endpoints:                10.244.0.19:8000,10.244.0.20:8000,10.244.0.21:8000
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type     Reason            Age    From                Message
  ----     ------            ----   ----                -------
  Warning  AllocationFailed  16m    metallb-controller  Failed to allocate IP for "default/web-svc-lb": no available IPs
  Normal   IPAllocated       3m11s  metallb-controller  Assigned IP ["172.17.255.1"]
  Normal   nodeAssigned      2m36s  metallb-speaker     announcing from node "minikube" with protocol "layer2"

16 минут назад было как раз сообщение об ошибке, а сейчас видм, что адрес был назначен.

kubectl get svc

NAME          TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)        AGE
kubernetes    ClusterIP      10.96.0.1      <none>         443/TCP        174m
web-svc-cip   ClusterIP      10.99.254.55   <none>         80/TCP         136m
web-svc-lb    LoadBalancer   10.96.206.84   172.17.255.1   80:32741/TCP   38m


Если мы попробуем открыть URL http://<our_LB_address>/index.html , то... ничего не выйдет. 
Это потому, что сеть кластера изолирована от нашей основной ОС 
(а ОС не знает ничего о подсети для балансировщиков). 
Чтобы это поправить, добавим статический маршрут. 
(В реальном окружении это решается добавлением нужной подсети на интерфейс сетевого оборудования 
или использованием L3-режима (что потребует усилий от сетевиков, но более предпочтительно). 

Найдите IP-адрес виртуалки с Minikube. Например так:

# С хоста ОС: 

minikube ip

192.168.59.103

ping -c5 192.168.59.103

# Внутри ВМ MiniKube: 

minikube ssh

ip addr show

ip addr show | grep -C3 192.168.59.103

       valid_lft 82695sec preferred_lft 82695sec
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:cb:3c:46 brd ff:ff:ff:ff:ff:ff
    inet 192.168.59.103/24 brd 192.168.59.255 scope global dynamic eth1
       valid_lft 490sec preferred_lft 490sec
4: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0

Добавьте маршрут в вашей ОС на IP-адрес Minikube:

route

sudo ip route add 172.17.255.0/24 via 192.168.59.103

route

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
..........
172.17.255.0    192.168.59.103  255.255.255.0   UG    0      0        0 vboxnet0
..........

route | grep 172.17.255.0 | grep 192.168.59.103

Если все получилось, то можно открыть в браузере хоста URL с IP-адресом нашего балансировщика 
и посмотреть, как космические корабли бороздят просторы вселенной: 

curl http://172.17.255.1/index.html

Из браузера (отрывок):

..........
Environment
export HOME='/root'
export HOSTNAME='web-977d47767-kcwnr'
..........
DNS resolvers info
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
..........

После Ctrl+F5:

..........
Environment
export HOME='/root'
export HOSTNAME='web-977d47767-rnnbd'
..........

Если пообновлять страничку с помощью Ctrl-F5 (т.е. игнорируя кэш), 
то будет видно, что каждый наш запрос приходит на другой под. 
Причем порядок смены подов - всегда один и тот же. 
Так работает IPVS - по умолчанию он использует rr (Round-Robin) балансировку. 
К сожалению, выбрать алгоритм на уровне манифеста сервиса нельзя. 
Но когда-нибудь, эта полезная фича появится 
( https://kubernetes.io/blog/2018/07/09/ipvs-based-in-cluster-load-balancing-deep-dive/ ). 

Доступные алгоритмы балансировки описаны здесь и здесь: 

https://github.com/kubernetes/kubernetes/blob/1cb3b5807ec37490b4582f22d991c043cc468195/pkg/proxy/apis/config/types.go#L185 

http://www.linuxvirtualserver.org/docs/scheduling.html 

##### Задание со * | DNS через MetalLB #####

Сделайте сервис LoadBalancer , который откроет доступ к CoreDNS снаружи кластера 
(позволит получать записи через внешний IP). 
Например, nslookup web.default.cluster.local 172.17.255.10 .
Поскольку DNS работает по TCP и UDP протоколам - учтите это в 
конфигурации. Оба протокола должны работать по одному и тому же IP-адресу балансировщика. 
Полученные манифесты положите в подкаталог ./coredns

Подсказка:

https://metallb.universe.tf/usage/

mkdir -p coredns && cd coredns

nano coredns-svc-lb.yaml

Как выбрать приложение coredns:

kubectl get pods -n kube-system -o wide --show-labels | grep -i -e status -e coredns

NAME                               READY   STATUS    RESTARTS      AGE   IP               NODE       NOMINATED NODE   READINESS GATES   LABELS
coredns-5d78c9869d-qcngr           1/1     Running   5 (18h ago)   20h   10.244.0.27      minikube   <none>           <none>            k8s-app=kube-dns,pod-template-hash=5d78c9869d

Видим, что там метка k8s-app=kube-dns.

Неймспейс прописываем kube-system.

nano coredns-svc-lb.yaml

kubectl apply -f coredns-svc-lb.yaml

Посмотрим и попроверяем (с хоста смотрим, на подсеть для балансировщиков маршрут ранее добавили): 

kubectl get po -o wide -A

NAMESPACE        NAME                               READY   STATUS    RESTARTS      AGE   IP               NODE       NOMINATED NODE   READINESS GATES
default          web-977d47767-c6b6j                1/1     Running   5 (18h ago)   21h   10.244.0.25      minikube   <none>           <none>
default          web-977d47767-kcwnr                1/1     Running   5 (18h ago)   21h   10.244.0.24      minikube   <none>           <none>
default          web-977d47767-rnnbd                1/1     Running   5 (18h ago)   21h   10.244.0.23      minikube   <none>           <none>
kube-system      coredns-5d78c9869d-qcngr           1/1     Running   5 (18h ago)   21h   10.244.0.27      minikube   <none>           <none>
kube-system      etcd-minikube                      1/1     Running   5 (18h ago)   21h   192.168.59.103   minikube   <none>           <none>
kube-system      kube-apiserver-minikube            1/1     Running   5 (18h ago)   21h   192.168.59.103   minikube   <none>           <none>
kube-system      kube-controller-manager-minikube   1/1     Running   5 (18h ago)   21h   192.168.59.103   minikube   <none>           <none>
kube-system      kube-proxy-gzklb                   1/1     Running   5 (18h ago)   20h   192.168.59.103   minikube   <none>           <none>
kube-system      kube-scheduler-minikube            1/1     Running   5 (18h ago)   21h   192.168.59.103   minikube   <none>           <none>
kube-system      storage-provisioner                1/1     Running   6 (18h ago)   21h   192.168.59.103   minikube   <none>           <none>
metallb-system   controller-64f57db87d-h9tjs        1/1     Running   1 (18h ago)   19h   10.244.0.26      minikube   <none>           <none>
metallb-system   speaker-jz8q7                      1/1     Running   1 (18h ago)   19h   192.168.59.103   minikube   <none>           <none>

kubectl get svc -o wide -A

NAMESPACE        NAME              TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                  AGE   SELECTOR
default          kubernetes        ClusterIP      10.96.0.1        <none>         443/TCP                  21h   <none>
default          web-svc-cip       ClusterIP      10.99.254.55     <none>         80/TCP                   21h   app=web
default          web-svc-lb        LoadBalancer   10.96.206.84     172.17.255.1   80:32741/TCP             19h   app=web
kube-system      dns-service-tcp   LoadBalancer   10.105.230.154   172.17.255.2   53:32725/TCP             27s   k8s-app=kube-dns
kube-system      dns-service-udp   LoadBalancer   10.99.40.57      172.17.255.2   53:30585/UDP             27s   k8s-app=kube-dns
kube-system      kube-dns          ClusterIP      10.96.0.10       <none>         53/UDP,53/TCP,9153/TCP   21h   k8s-app=kube-dns
metallb-system   webhook-service   ClusterIP      10.96.219.13     <none>         443/TCP                  19h   component=controller

nslookup 192.168.59.103 172.17.255.2

103.59.168.192.in-addr.arpa	name = 192-168-59-103.kubernetes.default.svc.cluster.local.

nslookup kubernetes.default.svc.cluster.local 172.17.255.2

Server:		172.17.255.2
Address:	172.17.255.2#53

Name:	kubernetes.default.svc.cluster.local
Address: 10.96.0.1

nslookup 10.244.0.23 172.17.255.2

23.0.244.10.in-addr.arpa	name = 10-244-0-23.web-svc-cip.default.svc.cluster.local.
23.0.244.10.in-addr.arpa	name = 10-244-0-23.web-svc-lb.default.svc.cluster.local.

nslookup web-svc-lb.default.svc.cluster.local 172.17.255.2

Server:		172.17.255.2
Address:	172.17.255.2#53

Name:	web-svc-lb.default.svc.cluster.local
Address: 10.96.206.84

nslookup web-svc-cip.default.svc.cluster.local 172.17.255.2

Server:		172.17.255.2
Address:	172.17.255.2#53

Name:	web-svc-cip.default.svc.cluster.local
Address: 10.99.254.55

Работает!

##### Создание Ingress #####

Теперь, когда у нас есть балансировщик, можно заняться Ingress-контроллером и прокси: 
- неудобно, когда на каждый Web-сервис надо выделять свой IP-адрес 
- а еще хочется балансировку по HTTP-заголовкам (sticky sessions) 

Для нашего домашнего задания возьмем почти "коробочный" ingress-nginx от проекта Kubernetes. 
Это "достаточно хороший" Ingress для умеренных нагрузок, основанный на OpenResty и пачке Lua-скриптов. 

Установка начинается с основного манифеста: 

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml

После установки основных компонентов в инструкции ( https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal ) рекомендуется 
применить манифест, который создаст NodePort -сервис. Но у нас есть MetalLB, мы можем сделать круче. 

(Можно сделать просто minikube addons enable ingress , но мы не ищем легких путей) 

kubectl get -n ingress-nginx all

Создадим файл nginx-lb.yaml c конфигурацией LoadBalancer-сервиса (работаем в каталоге kubernetes-networks): 

kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
spec:
  externalTrafficPolicy: Local
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
  ports:
    - { name: http, port: 80, targetPort: http }
    - { name: https, port: 443, targetPort: https }

nano nginx-lb.yaml

Теперь применим созданный манифест и посмотрим на IP-адрес,
назначенный ему MetalLB:

kubectl apply -f nginx-lb.yaml

kubectl get -n ingress-nginx all

kubectl get -n ingress-nginx svc

NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                      AGE
ingress-nginx                        LoadBalancer   10.101.185.238   172.17.255.3   80:30478/TCP,443:31908/TCP   39s
ingress-nginx-controller             NodePort       10.97.171.11     <none>         80:30456/TCP,443:31308/TCP   72m
ingress-nginx-controller-admission   ClusterIP      10.101.80.125    <none>         443/TCP                      72m

Теперь можно сделать пинг на этот IP-адрес и даже curl (с хоста смотрим, на подсеть для балансировщиков маршрут ранее добавили):

curl 172.17.255.3

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>

Если видим страничку 404 от OpenResty (или Nginx) - значит работает!

curl 172.17.255.3:443

<html>
<head><title>400 The plain HTTP request was sent to HTTPS port</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<center>The plain HTTP request was sent to HTTPS port</center>
<hr><center>nginx</center>
</body>
</html>

##### Подключение приложение Web к Ingress. Создание Headless-сервиса #####

Наш Ingress-контроллер не требует ClusterIP для балансировки трафика
• Список узлов для балансировки заполняется из ресурса Endpoints
нужного сервиса (это нужно для "интеллектуальной" балансировки,
привязки сессий и т.п.)
• Поэтому мы можем использовать headless-сервис для нашего веб-приложения.
• Скопируйте web-svc-cip.yaml в web-svc-headless.yaml
◦ измените имя сервиса на web-svc
◦ добавьте параметр clusterIP: None

С хабра:
"Для начала надо уточнить, что такое Headless-сервис: 
это сервис, который не использует отдельный IP-адрес для маршрутизации запросов (ClusterIP: None). 
В этом случае под DNS-именем сервиса видны IP всех Pod, которые в этот сервис входят. 
Headless-сервисы полезны, когда приложение само должно управлять тем, к какому Pod подключаться."

cp -aiv web-svc-cip.yaml web-svc-headless.yaml

nano web-svc-headless.yaml

diff web-svc-cip.yaml web-svc-headless.yaml

4c4
<   name: web-svc-cip
---
>   name: web-svc
8a9
>   clusterIP: None

Теперь примените полученный манифест и проверьте, что ClusterIP
для сервиса web-svc действительно не назначен:

kubectl apply -f web-svc-headless.yaml

kubectl get svc web-svc -o wide

NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
web-svc   ClusterIP   None         <none>        80/TCP    10s   app=web

##### Создание правил Ingress #####

Теперь настроим наш ingress-прокси, создав манифест с ресурсом
Ingress (файл назовите web-ingress.yaml ):

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 8000

nano web-ingress.yaml 

Примените манифест и проверьте, что корректно заполнены Address и Backends: 

kubectl apply -f web-ingress.yaml

kubectl get ingress/web

NAME   CLASS   HOSTS   ADDRESS          PORTS   AGE
web    nginx   *       192.168.59.103   80      25m

kubectl describe ingress/web

Name:             web
Labels:           <none>
Namespace:        default
Address:          192.168.59.103
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /web   web-svc:8000 (10.244.0.23:8000,10.244.0.24:8000,10.244.0.25:8000)
Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /$1
Events:
  Type    Reason  Age                    From                      Message
  ----    ------  ----                   ----                      -------
  Normal  Sync    4m23s (x2 over 4m33s)  nginx-ingress-controller  Scheduled for sync

Теперь можно проверить, что страничка доступна в браузере: 

curl http://172.17.255.3/web/index.html

curl http://172.17.255.3/web/index.html | grep web[-]

http://172.17.255.3/web/index.html

Обратите внимание, что обращения к странице тоже балансируются между Podами. 
Только сейчас это происходит средствами nginx, а не IPVS.

##### Задания со * | Ingress для Dashboard #####

Добавьте доступ к kubernetes-dashboard через наш Ingress-прокси: 
- Cервис должен быть доступен через префикс /dashboard ) 
- Kubernetes Dashboard должен быть развернут из официального манифеста. Актуальная ссылка есть в репозитории проекта: https://github.com/kubernetes/dashboard 
- Написанные вами манифесты положите в подкаталог ./dashboard 

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml

kubectl get -n kubernetes-dashboard all

NAME                                                        READY   STATUS    RESTARTS   AGE
pod/kubernetes-dashboard-api-776f7d4b87-hkbxx               1/1     Running   0          3m18s
pod/kubernetes-dashboard-metrics-scraper-6b85f74cd5-sfj7n   1/1     Running   0          3m18s
pod/kubernetes-dashboard-web-685bf6fd94-jg6nn               1/1     Running   0          3m18s

NAME                                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/kubernetes-dashboard-api               ClusterIP   10.102.246.36    <none>        9000/TCP   3m18s
service/kubernetes-dashboard-metrics-scraper   ClusterIP   10.107.211.145   <none>        8000/TCP   3m18s
service/kubernetes-dashboard-web               ClusterIP   10.96.18.138     <none>        8000/TCP   3m18s

NAME                                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kubernetes-dashboard-api               1/1     1            1           3m18s
deployment.apps/kubernetes-dashboard-metrics-scraper   1/1     1            1           3m18s
deployment.apps/kubernetes-dashboard-web               1/1     1            1           3m18s

NAME                                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/kubernetes-dashboard-api-776f7d4b87               1         1         1       3m18s
replicaset.apps/kubernetes-dashboard-metrics-scraper-6b85f74cd5   1         1         1       3m18s
replicaset.apps/kubernetes-dashboard-web-685bf6fd94               1         1         1       3m18s

mkdir -p dashboard && cd dashboard/

nano user.yaml

nano bind.yaml

kubectl apply -f user.yaml 

kubectl apply -f bind.yaml 

nano  ingress.yaml

kubectl apply -f ingress.yaml 

В браузере открывается:

https://172.17.255.3/dashboard/#/login

Смотрим сервисные аккаунты и находим наш:

kubectl get serviceaccounts -n kubernetes-dashboard 

NAME                   SECRETS   AGE
default                0         2d6h
kubernetes-dashboard   0         2d6h
myadmin                0         2d6h

Генерируем токен:

kubectl create token myadmin -n kubernetes-dashboard

eyJhbGciOiJSUzI1NiIsImtpZCI6Ik9JV3l5cTNaSFRyd1lkY0ZxSmNBbXY3TjM0cDR2dWIxVlVvNE1nbEVQQ2cifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNjk2MjgzMDI3LCJpYXQiOjE2OTYyNzk0MjcsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJteWFkbWluIiwidWlkIjoiNmE1M2FjM2EtMGJkYS00N2M2LWI3YjYtZjgzZmRkNDIwYWJiIn19LCJuYmYiOjE2OTYyNzk0MjcsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDpteWFkbWluIn0.Tio9844G725VvFHQNxHlELvAPX0CLEE04VIzJg6o0r_Lp1cD0D0eF4TCiqXxLVvWrHlA4kragMcBgRkkAHl5qACSgYrRj4Eu7KB9xEtxK29soK3D_6i9rFAe1E_S5ADP7mgW5ky2GiJlSfh1Jfsk4MI7dSWWv9n-pn24D2RSIIVFDL55h0yPHMLupjdCpbimND1LHoI3NM7lWf_DaYAE9J1ybxB4HTJ-vp0qWemvg5vxBA__zNCcwYCD_rf3jBXX2Njddk8BVos8bYC31r5HHJoRp-2quVLFscgy_reHzMD9N1LqxOCrw80GOZWeGQiX4S5ETWFAurihzjTKivoY0A

Теперь с полученным токеном удается зайти под myadmin в дашборд ( https://172.17.255.3/dashboard/#/workloads?namespace=default ).

В конце работ удалим созданный ранее маршрут:

route

route | grep 172.17.255.0 | grep 192.168.59.103

sudo route -v del -net 172.17.255.0/24 gw 192.168.59.103

route

route | grep 172.17.255.0 | grep 192.168.59.103

##### GIT CHECKOUT, CREATE DIRECTORY, COPY FILES, PULL REQUEST: #####

cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-networks
git branch
mkdir kubernetes-networks
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-networks/
# Также копируем измененный kubernetes-intro/web-pod.yaml
# Также копируем README (в т.ч. измененные README с двух прошлых ДЗ для истории)
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-networks"
git push --set-upstream origin kubernetes-networks
git status

# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.

# Если здесь нужно переключить в ветку main, то:
git branch
git switch main
git branch
git status

########## ТЕКСТ ДЛЯ PULL REQUEST: ##########

# Выполнено ДЗ № kubernetes-networks

 - [OK] Основное ДЗ
 - [OK] Задания со * (кроме задания "Canary для Ingress")

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (кроме задания "Canary для Ingress")

## Как запустить проект:
 - По порядку из методических указаний или из README выполнять настройки и применять манифесты kubectl apply -f kodmandvl_platform/kubernetes-networks/имя_файла.yaml

## Как проверить работоспособность:
 - Открыть в браузере http://172.17.255.1/index.html
 - Выполнить команду nslookup kubernetes.default.svc.cluster.local 172.17.255.2
 - Открыть в браузере https://172.17.255.3/web
 - Открыть в браузере https://172.17.255.3/dashboard/#/login

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

