# Подготовка

## Создание кластера

Использовал [свой скриптик-обёртку для создания кластера Kubernetes в Yandex Cloud](https://github.com/kodmandvl/wrapper_scripts/blob/main/yc/yc_k8s_create_new.sh): 

```bash
$ yc_k8s_create_new.sh hwdebug 1.27 10.77.0.0/16 10.76.0.0/16 hwdebug-node-group 3
```

Также запустил Kind, пробовал еще в нем: 

```bash
kind create cluster --name kindhwdebug --image kindest/node:v1.27.3
```

И такой Kind (пробовал для iptables-tailer): 

```bash
kind create cluster --name kindhwdebug --image kindest/node:v1.27.3 --config kind-config.yaml
```

А также MiniKube: 

```bash
minikube start -p minikubehwdebug --kubernetes-version=v1.27.4 --driver=podman --container-runtime=cri-o --cpus=2 --memory=4096m
```

```bash
$ kubectx
kind-kindhwdebug
minikubehwdebug
yc-hwdebug
```

## Создание директории и копирование шаблона README

```bash
mkdir -p kubernetes-debug && cd kubernetes-debug/
cp -aiv ../README.md ./
```

# Установка kubectl-debug

Скачал [исполняемый файл kubectl-debug версии 0.1.1](https://github.com/aylei/kubectl-debug/releases) и добавил в одну из локаций, входящих в $PATH (туда же, где лежат kubectl, k9s, helm и др. инструменты): 

```bash
$ kubectl-debug --version
debug version v0.0.0-master+$Format:%h$
$ kubectl-debug --help   

Run a container in a running pod, this container will join the namespaces of an existing container of the pod.

You may set default configuration such as image and command in the config file, which locates in "~/.kube/debug-config" by default.

Usage:
  debug POD [-c CONTAINER] -- COMMAND [args...]

Examples:

	# debug a container in the running pod, the first container will be picked by default
	kubectl debug POD_NAME

	# specify namespace or container
	kubectl debug --namespace foo POD_NAME -c CONTAINER_NAME

	# override the default troubleshooting image
	kubectl debug POD_NAME --image aylei/debug-jvm

	# override entrypoint of debug container
	kubectl debug POD_NAME --image aylei/debug-jvm /bin/bash

	# override the debug config file
	kubectl debug POD_NAME --debug-config ./debug-config.yml

..................................................
```

# Установка debug agent DaemonSet

Запустите в кластере поды с агентом kubectl-debug из [этого манифеста](https://raw.githubusercontent.com/aylei/kubectl-debug/dd7e4965e4ae5c4f53e6cf9fd17acc964274ca5c/scripts/agent_daemonset.yml): 

```bash
kubectl create ns debug-agent
wget https://raw.githubusercontent.com/aylei/kubectl-debug/dd7e4965e4ae5c4f53e6cf9fd17acc964274ca5c/scripts/agent_daemonset.yml
kubectl apply -n debug-agent -f agent_daemonset.yml
```

Ошибка: 

```
error: resource mapping not found for name: "debug-agent" namespace: "" from "agent_daemonset.yml": no matches for kind "DaemonSet" in version "extensions/v1beta1"
ensure CRDs are installed first
```

Кстати, в README в архиве с дистрибутивом kubectl-debug используется такой манифест (ниже выдержка из исходного README). 

`kubectl-debug` requires an agent pod to communicate with the container runtime. In the [agentless mode](#port-forward-mode-And-agentless-mode), the agent pod can be created when a debug session starts and to be cleaned up when the session ends. 

While convenient, creating pod before debugging can be time consuming. You can install the debug agent DaemonSet in advance to skip this: 

```bash
kubectl apply -f https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
# or using helm
helm install -n=debug-agent ./contrib/helm/kubectl-debug
```

Этим способом ставится без ошибок (попробовал до начала выполнения задания и удалил). 

Теперь еще раз поставил: 

```bash
mv agent_daemonset.yml agent_daemonset_old.yml
wget https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
kubectl apply -f agent_daemonset.yml
```

```text
daemonset.apps/debug-agent created
```

Посмотрим: 

```text
kubectl get po -o wide              
NAME                READY   STATUS    RESTARTS   AGE     IP            NODE                       NOMINATED NODE   READINESS GATES
debug-agent-2rbbf   1/1     Running   0          2m53s   10.77.129.5   node2-hwdebug-node-group   <none>           <none>
debug-agent-4dtqg   1/1     Running   0          2m53s   10.77.130.6   node1-hwdebug-node-group   <none>           <none>
debug-agent-jxs8x   1/1     Running   0          2m53s   10.77.128.9   node3-hwdebug-node-group   <none>           <none>
```

# Развёртывание тестового вэб-сервера

Для развёртывания тестового вэб-сервера будем использовать свой Nginx из ДЗ kubernetes-monitoring: 

```bash
kubectl create -f nginx_pod.yml
```

# Смотрим

```text
$ kubectl get po -o wide
NAME                READY   STATUS    RESTARTS      AGE   IP             NODE                       NOMINATED NODE   READINESS GATES
debug-agent-2rbbf   1/1     Running   1 (64m ago)   76m   10.77.129.8    node2-hwdebug-node-group   <none>           <none>
debug-agent-4dtqg   1/1     Running   1 (65m ago)   76m   10.77.130.9    node1-hwdebug-node-group   <none>           <none>
debug-agent-jxs8x   1/1     Running   1 (65m ago)   76m   10.77.128.15   node3-hwdebug-node-group   <none>           <none>
myngnx              1/1     Running   0             34s   10.77.129.12   node2-hwdebug-node-group   <none>           <none>
```

```bash
kubectl debug -it myngnx --image=nicolaka/netshoot:latest --target=myngnx
```

```text
$ kubectl debug -it myngnx --image=nicolaka/netshoot:latest --target=myngnx
Targeting container "myngnx". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-lq5n5.
If you don't see a command prompt, try pressing enter.
                    dP            dP                           dP   
                    88            88                           88   
88d888b. .d8888b. d8888P .d8888b. 88d888b. .d8888b. .d8888b. d8888P 
88'  `88 88ooood8   88   Y8ooooo. 88'  `88 88'  `88 88'  `88   88   
88    88 88.  ...   88         88 88    88 88.  .88 88.  .88   88   
dP    dP `88888P'   dP   `88888P' dP    dP `88888P' `88888P'   dP   
                                                                    
Welcome to Netshoot! (github.com/nicolaka/netshoot)
Version: 0.11

                                         


 myngnx  ~  ps aux
PID   USER     TIME  COMMAND
    1 1080      0:00 {entrypoint.sh} /bin/sh /ngnx/scripts/entrypoint.sh
   13 1080      0:00 nginx: master process nginx -g daemon off;
   14 1080      0:00 nginx: worker process
   15 1080      0:00 nginx: worker process
  267 root      0:00 zsh
  329 root      0:00 ps aux

 myngnx  ~  whoami
root

 myngnx  ~  strace -p 1 -c
strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted

 myngnx  ~  strace -p 13 -c
strace: attach: ptrace(PTRACE_SEIZE, 13): Operation not permitted

 myngnx  ~  exit
Session ended, the ephemeral container will not be restarted but may be reattached using 'kubectl attach myngnx -c debugger-lq5n5 -i -t' if it is still running
```

# Добавление прав

kubectl debug | Подсказки 

Возможность запуска трассировки определяется наличием у процесса capability SYS_PTRACE 

Нужно добавить эту возможность: 

```yaml
securityContext:
  capabilities:
    add: [ "SYS_PTRACE" ]
```

Но попытки добавить это в спецификацию контейнеров не дали эффекта. 

А попытки добавить это для эфемерных контейнеров через `kubectl edit pods` не увенчались успехом (ошибки). 

Порядок действий для проверок: 

```bash
cd strace
kubectx <контекст>
k delete po myngnx
k delete daemonsets.apps debug-agent
k apply -f agent_daemonset.yml
k create -f nginx_pod.yml
kubectl debug -it myngnx --image=docker.io/nicolaka/netshoot:latest --target=myngnx -- strace -p 1 -c
kubectl edit pods myngnx 
```

# iptables-tailer

Один из полезных инструментов, который был упомянут, но не показан на лекции - это kube-iptables-tailer. 

Он предназначен для того, чтобы выводить информацию об отброшенных iptables пакетах в журнал событий Kubernetes ( kubectl get events ) 

Основной кейс - сообщить разработчикам сервисов о проблемах с NetworkPolicy. 

Кластер должен быть с установленным и запущенным Calico: 

```bash
wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
kubectl apply -f calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```

Для нашего задания в качестве тестового приложения вы возьмем [netperf-operator](https://github.com/piontec/netperf-operator). 

Это Kubernetes-оператор, который позволяет запускать тесты пропускной
способности сети между нодами кластера. 

Установите манифесты для запуска оператора в кластере (лежат в папке deploy в репозитории проекта): 

* Custom Resource Definition - схема манифестов для запуска тестов Netperf
* RBAC - политики и разрешения для нашего оператора
* И сам оператор, который будет следить за появлением ресурсов с `Kind: Netperf` и запускать поды с клиентом и сервером утилиты NetPerf

```bash
mkdir -p kit/deploy
cd kit/deploy
wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/crd.yaml
wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/rbac.yaml
wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/operator.yaml
kubectl apply -f crd.yaml
kubectl apply -f rbac.yaml
kubectl apply -f operator.yaml
```

При выполнении `kubectl apply -f crd.yaml` ошибка: 

```text
error: resource mapping not found for name: "netperfs.app.example.com" namespace: "" from "crd.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
```

Поискал иинфу по ошибке в сети. Попробовал взять версию K8s для Kind постарее: 

```bash
cd ../../
kind create cluster --name kindhwdebug119 --image kindest/node:v1.19.16 --config kind-config.yaml
kubectx
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```

Еще раз: 

```bash
mkdir -p kit/deploy
cd kit/deploy
# Уже скачаны:
# wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/crd.yaml
# wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/rbac.yaml
# wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/operator.yaml
kubectl apply -f crd.yaml
kubectl apply -f rbac.yaml
kubectl apply -f operator.yaml
```

При выполнении `kubectl apply -f crd.yaml` ошибки не было, но видим предупреждение такое: 

```text
Warning: apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
customresourcedefinition.apiextensions.k8s.io/netperfs.app.example.com created
```

Версия 1.19 пока еще подходит в общем. 

```text
$ kubectl apply -f crd.yaml
Warning: apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
customresourcedefinition.apiextensions.k8s.io/netperfs.app.example.com created
$ kubectl apply -f rbac.yaml
Warning: rbac.authorization.k8s.io/v1beta1 Role is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 Role
role.rbac.authorization.k8s.io/netperf-operator created
Warning: rbac.authorization.k8s.io/v1beta1 RoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 RoleBinding
rolebinding.rbac.authorization.k8s.io/default-account-netperf-operator created
$ kubectl apply -f operator.yaml
deployment.apps/netperf-operator created
```

```bash
k get po -A --show-labels
k get po -A --show-labels -l name=netperf-operator
```

```text
$ k get po -A --show-labels -l name=netperf-operator
NAMESPACE   NAME                                READY   STATUS    RESTARTS   AGE    LABELS
default     netperf-operator-55b49546b5-mwmt5   1/1     Running   0          3m1s   name=netperf-operator,pod-template-hash=55b49546b5
```

Теперь можно запустить наш первый тест, применив манифест cr.yaml из папки deploy: 

```bash
pwd
wget https://raw.githubusercontent.com/piontec/netperf-operator/master/deploy/cr.yaml
k apply -f cr.yaml
```

```bash
kubectl describe netperf.app.example.com/example
```

```text
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-12-21T12:00:50Z
  Generation:          4
  Resource Version:    2424
  Self Link:           /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:                 052d8087-b9bb-4b05-a54c-b089ab80033a
Spec:
  Client Node:  
  Server Node:  
Status:
  Client Pod:          netperf-client-b089ab80033a
  Server Pod:          netperf-server-b089ab80033a
  Speed Bits Per Sec:  6727.45
  Status:              Done
Events:                <none>
```

Если в результатах `kubectl describe` вы увидели `Status: Done` и результат измерений, значит все прошло хорошо (обычно на тест нужно 1-2 минуты). 

Теперь можно добавить сетевую политику для Calico, чтобы ограничить доступ к подам Netperf и включить логирование в `iptables`. 

```bash
cd ../
pwd
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/netperf-calico-policy.yaml
kubectl apply -f netperf-calico-policy.yaml
```

```text
networkpolicy.crd.projectcalico.org/netperf-calico-policy created
```

Теперь, если повторно запустить тест, мы увидим, что тест висит в состоянии `Starting`. 

В нашей сетевой политике есть ошибка. 

```text
$ k delete netperfs.app.example.com example 
netperf.app.example.com "example" deleted
$ k apply -f cr.yaml
netperf.app.example.com/example created
$ date -u
четверг, 21 декабря 2023 г. 12:18:41 (UTC)
$ kubectl describe netperf.app.example.com/example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-12-21T12:17:24Z
  Generation:          3
  Resource Version:    4573
  Self Link:           /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:                 7bba608f-ffe1-41ee-b45d-22cfd1e7bdfe
Spec:
  Client Node:  
  Server Node:  
Status:
  Client Pod:          netperf-client-22cfd1e7bdfe
  Server Pod:          netperf-server-22cfd1e7bdfe
  Speed Bits Per Sec:  0
  Status:              Started test
Events:                <none>
```

Проверьте, что в логах ноды Kubernetes появились сообщения об отброшенных пакетах: 

* Подключитесь к ноде по SSH
* `iptables --list -nv | grep DROP` - счетчики дропов ненулевые
* `iptables --list -nv | grep LOG` - счетчики с действием логирования ненулевые
* `journalctl -k | grep calico`

```bash
podman exec -it kindhwdebug119-control-plane /bin/bash <<EOF
iptables --list -nv | grep DROP
iptables --list -nv | grep LOG
journalctl -k | grep calico
exit
EOF
```

```text
root@kindhwdebug119-control-plane:/# iptables --list -nv | grep DROP | grep cali[:]He8TRqGPuUw3VGwk
   66  3960 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:He8TRqGPuUw3VGwk */
root@kindhwdebug119-control-plane:/# iptables --list -nv | grep LOG | grep cali[:]B30DykF1ntLW86eD
   68  4080 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:B30DykF1ntLW86eD */ LOG flags 0 level 5 prefix "calico-packet: "
```

В journalctl записей нет (видимо, з-за того, что это Kind, кубер в докере). 

```text
root@kindhwdebug119-control-plane:/# journalctl -k
-- No entries --
```

# iptables-tailes | Установка

* Попробуем запустить iptables-tailer используя манифест из репозитория проекта
* Проверим логи запущенного пода
* В зависимости от степени везения, мы можем увидеть в логе кучу ошибок, связанных с тем, что сервис не имеет права на листинг подов с дефолтным ServiceAccount
* Это исправляется созданием отдельного сервис-аккаунта с правами на просмотр информации о подах и созданием Event-ресурсов

```bash
cd kubernetes-debug/kit
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/iptables-tailer.yaml
k apply -f iptables-tailer.yaml
```

```text
$ k apply -f iptables-tailer.yaml 
error: error validating "iptables-tailer.yaml": error validating data: ValidationError(DaemonSet.spec): missing required field "selector" in io.k8s.api.apps.v1.DaemonSetSpec; if you choose to ignore these errors, turn validation off with --validate=false
```

Добавил селектор в спецификацию: 

```yaml
    selector:
      matchLabels:
        app: kube-iptables-tailer
```

```text
$ k apply -f iptables-tailer.yaml
daemonset.apps/kube-iptables-tailer created
```

* Теперь можно снова запустить тесты NetPerf (удалив и снова применив манифест cr.yaml ): 

```text
$ k delete netperfs.app.example.com example 
netperf.app.example.com "example" deleted
$ k apply -f deploy/cr.yaml
netperf.app.example.com/example created
$ date -u
четверг, 21 декабря 2023 г. 13:16:07 (UTC)
$ kubectl describe netperf.app.example.com/example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-12-21T13:13:07Z
  Generation:          3
  Resource Version:    11984
  Self Link:           /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:                 bffa79ea-6b4d-44b9-93c6-5d2778c65876
Spec:
  Client Node:  
  Server Node:  
Status:
  Client Pod:          netperf-client-5d2778c65876
  Server Pod:          netperf-server-5d2778c65876
  Speed Bits Per Sec:  0
  Status:              Started test
Events:                <none>
```

* Проверим логи пода iptables-tailer и события в кластере ( `kubectl get events -A` ): 

```
$ kubectl get events -A
..................................................
default       4m29s       Normal    Created        pod/netperf-server-5d2778c65876   Created container netperf-server-5d2778c65876
default       4m29s       Normal    Started        pod/netperf-server-5d2778c65876   Started container netperf-server-5d2778c65876
kube-system   8m26s       Warning   FailedCreate   daemonset/kube-iptables-tailer    Error creating: pods "kube-iptables-tailer-" is forbidden: error looking up service account kube-system/kube-iptables-tailer: serviceaccount "kube-iptables-tailer" not found
kube-system   63s         Warning   FailedCreate   daemonset/kube-iptables-tailer    Error creating: pods "kube-iptables-tailer-" is forbidden: error looking up service account kube-system/kube-iptables-tailer: serviceaccount "kube-iptables-tailer" not found
```

Да, надо досоздать сервисный аккаунт и выдать ему прав через ClusterRoleBinding: 

```bash
cd kubernetes-debug/kit
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-serviceaccount.yaml
k apply -f kit-serviceaccount.yaml
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-clusterrole.yaml
k apply -f kit-clusterrole.yaml
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/kit-clusterrolebinding.yaml
k apply -f kit-clusterrolebinding.yaml
```

Теперь пересоздадим DaemonSet: 

```text
$ k delete -n kube-system daemonsets.apps kube-iptables-tailer
daemonset.apps "kube-iptables-tailer" deleted
$ k apply -f iptables-tailer.yaml                             
daemonset.apps/kube-iptables-tailer created
```

```text
$ kubectl get events -A | tail -n 1
kube-system   78s         Normal    SuccessfulCreate   daemonset/kube-iptables-tailer    Created pod: kube-iptables-tailer-6xr5l
```

Теперь другое дело, под создался. 

И опять, мы ничего не увидим. А жаль... 

Исправим... 

Снова запустим тесты NetPerf и проверим события в кластере Kubernetes: 

```bash
k delete netperfs.app.example.com example 
k apply -f deploy/cr.yaml
sleep 120
kubectl describe netperf.app.example.com/example
kubectl get events -A
kubectl describe pod --selector=app=netperf-operator
```

```text
$ kubectl get events -A
NAMESPACE     LAST SEEN   TYPE      REASON             OBJECT                            MESSAGE
..................................................
kube-system   57m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.089060601s
kube-system   57m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.140033877s
kube-system   56m         Normal    Pulled             pod/kube-iptables-tailer-6xr5l    Successfully pulled image "virtualshuric/kube-iptables-tailer:8d4296a" in 1.223761593s
kube-system   58m         Normal    SuccessfulCreate   daemonset/kube-iptables-tailer    Created pod: kube-iptables-tailer-6xr5l
```

```text
$ kubectl describe pod --selector=app=netperf-operator
..................................................
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  32m   default-scheduler  Successfully assigned default/netperf-server-7697681339b8 to kindhwdebug119-control-plane
  Normal  Pulled     32m   kubelet            Container image "tailoredcloud/netperf:v2.7" already present on machine
  Normal  Created    32m   kubelet            Created container netperf-server-7697681339b8
  Normal  Started    32m   kubelet            Started container netperf-server-7697681339b8
```

У меня в выводе не было строки, подобной этой: `Warning PacketDrop 70s kube-iptables-tailer Packet dropped when receiving traffic from 10.48.0.14`. 

Опять же, скорее всего, это связано с тем, что запускал в Kind и там нет путей, по которым ожидалось получить логи iptables. 

И хотя image для iptables-tailer успешно скачался и DaemonSet запускается, в логах пода `kubectl logs -n kube-system pods/kube-iptables-tailer-6xr5l` имеются ошибки, говорящие о том, что он, судя по всему, не видит логов (модуль `main.startJournalWatcher`). 

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-debug
git branch
mkdir kubernetes-debug
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-debug/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-debug"
git push --set-upstream origin kubernetes-debug
git status
# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.
# Если здесь нужно переключить обратно на ветку main, то:
git branch
git switch main
git branch
git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-debug

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - Применение манифестов с помощью kubectl apply -f имя-файла.yaml (подробнее по тексту README.md)

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get, kubectl debug, kubectl logs и kubectl describe

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-debug отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/номерpr 

