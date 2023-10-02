##### PREPARE: #####

cd ~/kodmandvl_platform/
ls
git checkout -b kubernetes-prepare
mkdir -p .github
mkdir -p .github/workflows
cd .github
cd workflows/
wget https://raw.githubusercontent.com/otus-kuber-2021-03/.github/main/workflows-templates/auto-assign.yml
cat auto-assign.yml 
wget https://raw.githubusercontent.com/otus-kuber-2021-03/.github/main/workflows-templates/labeler.yml
cat labeler.yml 
wget https://gist.githubusercontent.com/mrgreyves/7e3dd9c0cb46834ae983177b69656314/raw/183144459ec10e519271b3665579f5eea0ede9e0/otus-k8s-2022-06-run-test.yaml
ls
cat otus-k8s-2022-06-run-test.yaml 
cd ../
wget https://raw.githubusercontent.com/otus-kuber-2021-03/.github/main/auto_assign.yml
wget https://raw.githubusercontent.com/otus-kuber-2021-03/.github/main/labeler.yml
wget https://raw.githubusercontent.com/express42/otus-platform-tests/2020-04/.github/PULL_REQUEST_TEMPLATE.md
ls -alFtrhR
ls -alFhR
cd workflows/
mv otus-k8s-2022-06-run-test.yaml run-tests.yaml 
cd ../
ls -alFhR
cd workflows/
mv run-tests.yaml run-tests.yml 
vim run-tests.yml 
cd ../../
git add -A
git add .
git commit -m "add ga files"
git --help
ls
git push
git push --set-upstream origin kubernetes-prepare
git status



##### MIINIKUBE START: #####

minikube start
kubectl config view
cat ~/.kube/config 
kubectl cluster-info
kubectl cluster-info dump
ifconfig
minikube addons list
minikube addons --help
minikube addons enable dashboard
minikube addons list

minikube dashboard
minikube dashboard --url=false --port=40088
# or:
nohup minikube dashboard --url=false --port=40088 &

minikube addons disable dashboard
minikube addons list

k9s

minikube ssh
docker ps
exit
echo 'docker ps ; exit' | minikube ssh
docker ps

minikube ssh
# ВНУТРИ ВМ МИНИКУБА ИЛИ ВНУТРИ КОРНЕВОГО КОНТЕЙНЕРА МИНИКУБА (В ЗАВИСИМОСТИ ОТ ВЫБРАННОГО ДРАЙВЕРА):
docker ps
cat /etc/*release
# Проверим, что Kubernetes обладает некоторой устойчивостью к отказам, удалим все контейнеры:
docker ps -a
# docker rm -f $(docker ps -a -q)
docker ps -a
docker ps

# Эти же компоненты, но уже в виде pod можно увидеть в namespace kube-system:
kubectl get pods -n kube-system
# Расшифруем: данной командой мы запросили у API вывести список ( get ) всех pod ( pods ) в namespace ( -n , сокращенное от namespace ) kube-system.

kubectl get pods -A
kubectl get po -A

# Можно устроить еще одну проверку на прочность и удалить все pod с системными компонентами:
# kubectl delete pod --all -n kube-system

# Проверим, что кластер находится в рабочем состоянии, команды выведут состояние системных компонентов:
kubectl get componentstatuses
# или сокращенно:
kubectl get cs

minikube config set memory 6000
minikube config set memory 4096
minikube config unset memory

# Разберитесь почему все pod в namespace kube-system восстановились после удаления. Укажите причину в описании PR
# Hint: core-dns и, например, kube-apiserver , имеют различия в механизме запуска и восстанавливаются по разным причинам

kubectl get po -n kube-system coredns-5d78c9869d-np9fp --output yaml
kubectl describe pod -n kube-system coredns-5d78c9869d-np9fp

# ОТВЕТ:

1) coredns управляется через ReplicaSet:

kubectl get po -n kube-system coredns-5d78c9869d-np9fp --output yaml | grep kind
kind: Pod
    kind: ReplicaSet
Поэтому он должен быть представлен заданным числом реплик (в данном случае 1).

2) kube-proxy на ноде (в нашем случае единственной) как DaemonSet, поэтому кластер Kubernetes также приводит ноду в рабочее состояние (т.е. с работающим kube-proxy):

kubectl get po -n kube-system kube-proxy-l97v6 --output yaml | grep kind
kind: Pod
    kind: DaemonSet

3) apiserver, scheduler, etcd и controller-manager являются неотъемлемыми компонентами мастер-ноды (опять же у нас в данном случае всего одна нода Minikube):

$ kubectl get po -n kube-system kube-apiserver-minikube --output yaml | grep kind
kind: Pod
    kind: Node
$ kubectl get po -n kube-system kube-scheduler-minikube --output yaml | grep kind
kind: Pod
    kind: Node
$ kubectl get po -n kube-system kube-controller-manager-minikube --output yaml | grep kind
kind: Pod
    kind: Node
$ kubectl get po -n kube-system etcd-minikube --output yaml | grep kind
kind: Pod
    kind: Node

##### DOCKERFILE AND POD: #####

cd ~/kodmandvl_platform/
git status
git checkout -b kubernetes-intro
git status
git checkout -b kubernetes-intro
git switch --help
git branch 
git switch main
git branch 
git switch kubernetes-intro
git branch 

mkdir -p kubernetes-intro/web
cd kubernetes-intro/web
nano Dockerfile

docker pull python:3.9
docker images
docker image history python:3.9

docker run -it --name mysuperwebserver python:3.9 bash

nano homework.html
nano Dockerfile

docker rm -f my8000 my7000
docker rmi -f mywebserver:k8sintro
docker build -t mywebserver:k8sintro .
docker images | grep myweb

# Чекнем в докере (проверить в целом запуск):
docker run -p 7000:8000 -it --name my7000 mywebserver:k8sintro bash
Ctrl+C
# or:
docker run -p 8000:8000 -d --name my8000 mywebserver:k8sintro
# Посмоотрим в контейнер my8000:
docker exec my8000 cat /app/homework.html
docker exec my8000 ls -alF /app/
docker exec my8000 pwd
docker exec my8000 id
curl localhost:8000
curl localhost:8000/homework.html

docker kill my8000 my7000
docker rm my8000 my7000
docker ps
docker ps -a

# Пробуем запушить в DockerHub:
docker login
docker build -t kodmandvl/mywebserver:k8sintro .
docker push kodmandvl/mywebserver:k8sintro

# Готовим web-pod.yaml, рестартуем minikube (ранее выключали) и применяем наш манифест web-pod.yaml:
cd ../
nano web-pod.yaml
minikube start
kubectl apply -f web-pod.yaml
kubectl get pods

# В Kubernetes есть возможность получить манифест уже запущенного в кластере pod.
# В подобном манифесте помимо описания pod будут фигурировать служебные поля (например, различные статусы) и значения, подставленные по умолчанию.
kubectl get pod web -o yaml

# Другой способ посмотреть описание pod - использовать ключ describe.
# Команда позволяет отследить текущее состояние объекта, а также события, которые с ним происходили:
kubectl describe pod web

# Успешный старт pod в kubectl describe выглядит следующим образом:
# 1. scheduler определил, на какой ноде запускать pod
# 2. kubelet скачал необходимый образ и запустил контейнер

Events:
  Type    Reason     Age    From               Message
  ----    ------     ----   ----               -------
  Normal  Scheduled  4m56s  default-scheduler  Successfully assigned default/web to minikube
  Normal  Pulling    4m55s  kubelet            Pulling image "kodmandvl/mywebserver:k8sintro"
  Normal  Pulled     3m59s  kubelet            Successfully pulled image "kodmandvl/mywebserver:k8sintro" in 56.020691273s (56.020700861s including waiting)
  Normal  Created    3m59s  kubelet            Created container web
  Normal  Started    3m59s  kubelet            Started container web

При этом kubectl describe - хороший старт для поиска причин проблем с запуском pod.
Укажите в манифесте несуществующий тег образа web и примените его заново ( kubectl apply -f web-pod.yaml ).

Статус pod ( kubectl get pods ) должен измениться на ErrImagePull/ImagePullBackOff, а команда kubectl describe pod web поможет понять причину такого поведения:

kubectl delete pod web
kubectl apply -f web-pod.yaml
kubectl describe pod web

Events:
  Type     Reason          Age                From               Message
  ----     ------          ----               ----               -------
  Normal   Scheduled       16s                default-scheduler  Successfully assigned default/web to minikube
  Normal   Pulling         16s                kubelet            Pulling image "kodmandvl/mywebserver:1.0"
  Warning  Failed          13s                kubelet            Failed to pull image "kodmandvl/mywebserver:1.0": rpc error: code = Unknown desc = Error response from daemon: manifest for kodmandvl/mywebserver:1.0 not found: manifest unknown: manifest unknown
  Warning  Failed          13s                kubelet            Error: ErrImagePull
  Normal   SandboxChanged  13s                kubelet            Pod sandbox changed, it will be killed and re-created.
  Normal   BackOff         12s (x2 over 12s)  kubelet            Back-off pulling image "kodmandvl/mywebserver:1.0"
  Warning  Failed          12s (x2 over 12s)  kubelet            Error: ImagePullBackOff

kubectl get pods

NAME   READY   STATUS             RESTARTS   AGE
web    0/1     ImagePullBackOff   0          97s

# Подправим web-pod.yaml обратно и перезапустим:
kubectl delete pod web
kubectl get pods
kubectl apply -f web-pod.yaml
kubectl get pods
kubectl describe pod web
# Пробросим порт для проверки:
kubectl port-forward pods/web 4321:8000
# Посмотрим ссылки в браузере и в другом окне:
curl http://127.0.0.1:4321
curl http://127.0.0.1:4321/homework.html
# Еще можно так пробросить:
kubectl port-forward --address 0.0.0.0 pods/web 4321:8000
# Тогда можно так обратиться (192.168.49.1 - адрес моего хоста в сети роутера):
curl 192.168.49.1:4321
curl 192.168.49.1:4321/homework.html
# Еще так можно:
nohup kubectl port-forward --address 0.0.0.0 pods/web 1234:8000 &
cat nohup.out 
# Тогда продолжаем в том же окне терминала:
curl 192.168.49.1:1234
curl 192.168.49.1:1234/homework.html
ps -ef | grep kubectl | grep -v grep

# Обновили манифест, добавили initContainer и Volume.
# Запустим pod. Сначала удалим запущенный pod web из кластера:
kubectl delete pod web
# И применим обновленный манифест web-pod.yaml:
kubectl apply -f web-pod.yaml
# Отслеживать происходящее можно так:
kubectl get pods -w

Вывод получился следующий:

NAME   READY   STATUS     RESTARTS   AGE
web    0/1     Init:0/1   0          3s
web    0/1     Init:0/1   0          7s
web    0/1     PodInitializing   0          9s
web    1/1     Running           0          10s

# Проверка работы приложения

Проверим работоспособность web сервера. Существует несколько
способов получить доступ к pod, запущенным внутри кластера.
Мы воспользуемся командой kubectl port-forward

kubectl port-forward --address 0.0.0.0 pod/web 8000:8000

Если все выполнено правильно, на локальном компьютере по ссылке
http://localhost:8000/index.html должна открыться страница.

В качестве альтернативы kubectl port-forward можно использовать удобную обертку kube-forwarder.
Она отлично подходит для доступа к pod внутри кластера с локальной машины во время разработки продукта.
Но лично мне также нравится мой вариант с nohup и & (см. выше).

##### МИКРОСЕРВИСНОЕ ПРИЛОЖЕНИЕ HIPSTER SHOP: #####

https://github.com/GoogleCloudPlatform/microservices-demo

В последующих домашних заданиях мы будем использовать микросервисное приложение Hipster Shop.

Давайте познакомимся с приложением поближе и попробуем запустить
внутри нашего кластера его компоненты.
Начнем с микросервиса frontend . Его исходный код доступен по
адресу https://github.com/GoogleCloudPlatform/microservices-demo/tree/main/src/frontend .

cd ~
git clone https://github.com/GoogleCloudPlatform/microservices-demo
cd microservices-demo/src/frontend/
ls
docker build -t myfrontend:k8sintro .
docker images | grep myfront
# Пробуем запушить в DockerHub:
# docker login # Если еще не залогинился на этой машине
docker build -t kodmandvl/myfrontend:k8sintro .
docker push kodmandvl/myfrontend:k8sintro

Рассмотрим альтернативный способ запуска pod в нашем Kubernetes
кластере.
Вы уже умеете работать с манифестами (и это наиболее корректный
подход к развертыванию ресурсов в Kubernetes), но иногда бывает удобно
использовать ad-hoc режим и возможности Kubectl для создания ресурсов.

Разберем пример для запуска frontend pod:

kubectl run frontend --image kodmandvl/myfrontend:k8sintro --restart=Never

Что выполняется:
kubectl run - запустить ресурс
frontend - с именем frontend
--image - из образа kodmandvl/myfrontend:k8sintro (подставьте свой образ)
--restart=Never указываем на то, что в качестве ресурса запускаем pod .

kubectl get po
kubectl get pods frontend -w
Ctrl+C

kubectl get pods frontend

NAME       READY   STATUS   RESTARTS   AGE
frontend   0/1     Error    0          3m3s

kubectl logs frontend

..........
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set
..........

Видим, что ошибка вызвана тем, что не задана переменная среды PRODUCT_CATALOG_SERVICE_ADDR.
Это ответ на задание со звёздочкой, которое ниже будет далее по тексту.

Один из распространенных кейсов использования ad-hoc режима - генерация манифестов средствами kubectl:

kubectl run frontend --image kodmandvl/myfrontend:k8sintro --restart=Never --dry-run -o yaml > frontend-pod.yaml

Рассмотрим дополнительные ключи:
--dry-run - вывод информации о ресурсе без его реального создания
-o yaml - форматирование вывода в YAML
> frontend-pod.yaml - перенаправление вывода в файл

Hipster Shop | Задание со *

Выясните причину, по которой pod frontend находится в статусе Error

kubectl logs frontend показывает, что не задана переменная среды PRODUCT_CATALOG_SERVICE_ADDR:
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set
Добавление только этой переменной в манифест не помогло, нужны еще переменные из примера https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/kubernetes-manifests/frontend.yaml .
Добавление всех переменных среды в секцию env из примера https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/kubernetes-manifests/frontend.yaml помогло:

cat frontend-pod.yaml 
kubectl logs frontend
cp -aiv frontend-pod.yaml frontend-pod-healthy.yaml
nano frontend-pod-healthy.yaml 
vim frontend-pod-healthy.yaml 
nano frontend-pod-healthy.yaml 
vim frontend-pod-healthy.yaml 
kubectl get pods
kubectl delete pod frontend 
kubectl get pods
kubectl apply -f frontend-pod-healthy.yaml 
kubectl get pods
kubectl logs frontend
kubectl delete pod frontend 
vim frontend-pod-healthy.yaml 
kubectl apply -f frontend-pod-healthy.yaml 
kubectl get pods
kubectl logs frontend

kubectl get pods frontend 

NAME       READY   STATUS    RESTARTS   AGE
frontend   1/1     Running   0          5m8s

kubectl logs frontend

{"message":"Tracing disabled.","severity":"info","timestamp":"2023-09-14T19:43:17.873661229Z"}
{"message":"Profiling disabled.","severity":"info","timestamp":"2023-09-14T19:43:17.873710874Z"}
{"message":"starting server on :8080","severity":"info","timestamp":"2023-09-14T19:43:17.875748174Z"}
{"message":"Failed to fetch the name of the cluster in which the pod is runningGet \"http://169.254.169.254/computeMetadata/v1/instance/attributes/cluster-name\": dial tcp 169.254.169.254:80: connect: no route to host","severity":"error","timestamp":"2023-09-14T19:43:20.926974894Z"}
{"message":"Failed to fetch the Zone of the node where the pod is scheduledGet \"http://169.254.169.254/computeMetadata/v1/instance/zone\": dial tcp 169.254.169.254:80: connect: no route to host","severity":"error","timestamp":"2023-09-14T19:43:23.998935714Z"}
{"cluster":"","hostname":"frontend","message":"Loaded deployment details","severity":"debug","timestamp":"2023-09-14T19:43:23.99897937Z","zone":""}

Поместите исправленный манифест frontend-pod-healthy.yaml в
директорию kubernetes-intro:

cp -aiv frontend-pod-healthy.yaml ~/kodmandvl_platform/kubernetes-intro/

cd ~/kodmandvl_platform/
git status
git add -A
git status
git commit -m "kubernetes-intro"
git push
git push --set-upstream origin kubernetes-intro
git status

И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.

########## ТЕКСТ ДЛЯ PULL REQUEST: ##########

# Выполнено ДЗ № kubernetes-intro

 - [OK] Основное ДЗ
 - [OK] Задания со *

## В процессе сделано:
 - установка необходимых инструментов (Docker Engine, minikube, kubectl, автодополнение для kubectl, k9s)
 - все описанные в методических указаниях действия (подробности и ответы на задания со * в kodmandvl_platform/kubernetes-intro/README.md)

## Как запустить проект web-pod:
 - kubectl apply -f web-pod.yaml
 - nohup kubectl port-forward --address 0.0.0.0 pods/web 1234:8000 &

## Как проверить работоспособность web-pod:
 - Перейти по ссылке http://localhost:1234

## Как запустить проект frontend:
 - kubectl apply -f frontend-pod-healthy.yaml

## Как проверить работоспособность frontend:
 - kubectl get pods frontend
 - kubectl logs frontend

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

