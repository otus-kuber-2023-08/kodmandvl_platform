# Подготовка

```
mkdir -p kubernetes-vault && cd kubernetes-vault/
cp -aiv ../README.md ./
```

## Создание кластера Kubernetes для данной домашней работы

Для данной домашней работы решил использовать Kind (образ kindest/node версии 1.24). 

Использовал [свой скрипт-обёртку для создания кластера Kind](https://github.com/kodmandvl/wrapper_scripts/blob/main/kind/kind_create_cluster.sh). 

Делаем конфиг для 3 воркер-нод (hwvault_config.yaml) и запускаем скрипт: 

```bash
./kind_create_cluster.sh hwvault 1.24.15 ./hwvault_config.yaml
```

```text
$ ./kind_create_cluster.sh hwvault 1.24.15 ./hwvault_config.yaml

CREATE hwvault KIND CLUSTER AFTER 5 SECONDS:

kind create cluster --name hwvault --image kindest/node:v1.24.15 --config ./hwvault_config.yaml

Creating cluster "hwvault" ...
 ✓ Ensuring node image (kindest/node:v1.24.15) 🖼 
 ✓ Preparing nodes 📦 📦 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-hwvault"
You can now use your cluster with:

kubectl cluster-info --context kind-hwvault

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
```

Примечание: в дальнейшем выяснилось, что на шаге `Проверим как работает авторизация` поймал неустранимую ошибку при использовании кластера Kind, поэтому создал еще кластер в Yandex Cloud (там проблема не воспроизвелась). Снова взял [свои скрипты-обёртки для работы с утилитой yc](https://github.com/kodmandvl/wrapper_scripts/tree/main/yc): 

```bash
yc_k8s_create_new.sh hwvault 1.27 10.99.0.0/16 10.98.0.0/16 hwvault-node-group 3
```

Соответственно, далее где-то примеры вывода команд из Kind-ов (тоже несколько стендов), где-то - с managed K8s в Yandex Cloud (начиная с шага `Проверим как работает авторизация` вывод команд только с Yandex Cloud кластера). 

Также отмечу, что при создании кластера в Yandex Cloud нельзя уже выбрать версию ниже, чем 1.25, поэтому для корректной установки Consul-а необходимо перед установкой Consul-а заменить в файле `consul-helm/templates/server-disruptionbudget.yaml` версию `apiVersion: policy/v1beta1` на `apiVersion: policy/v1`, иначе будет такая ошибка (при установке Consul-а в кластерах версии 1.25 и свежее): 

```text
$ helm upgrade --install consul consul-helm -f consul_values.yaml --atomic --wait --create-namespace -n hwvault
Release "consul" does not exist. Installing it now.
Error: unable to build kubernetes objects from release manifest: resource mapping not found for name: "consul-consul-server" namespace: "hwvault" from "": no matches for kind "PodDisruptionBudget" in version "policy/v1beta1"
ensure CRDs are installed first
```

Также после установки vault столкнулся с ошибками в подах vault-а (в Yandex Cloud), поэтому для установки vault в Kind у меня был файл `vault_values.yaml`, а для установки в yandex Cloud его пришлось еще переделать (файл `vault_values_for_yc.yaml`). 

## Посмотрим на кластер

```bash
kubectl get all -A -o wide
kubectl get pods -A -o wide
kubectl get nodes -o wide
```

В Kind-е: 

```text
$ kubectl get nodes -o wide
NAME                    STATUS   ROLES           AGE     VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
hwvault-control-plane   Ready    control-plane   3h44m   v1.24.15   172.18.0.4    <none>        Debian GNU/Linux 11 (bullseye)   6.1.0-12-amd64   containerd://1.7.1
hwvault-worker          Ready    <none>          3h43m   v1.24.15   172.18.0.2    <none>        Debian GNU/Linux 11 (bullseye)   6.1.0-12-amd64   containerd://1.7.1
hwvault-worker2         Ready    <none>          3h43m   v1.24.15   172.18.0.5    <none>        Debian GNU/Linux 11 (bullseye)   6.1.0-12-amd64   containerd://1.7.1
hwvault-worker3         Ready    <none>          3h43m   v1.24.15   172.18.0.3    <none>        Debian GNU/Linux 11 (bullseye)   6.1.0-12-amd64   containerd://1.7.1
```

В YC: 

```text
$ kubectl get nodes -o wide
NAME                       STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
node1-hwvault-node-group   Ready    <none>   7h50m   v1.27.3   10.128.0.4    158.160.123.39    Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
node2-hwvault-node-group   Ready    <none>   7h50m   v1.27.3   10.128.0.18   158.160.104.158   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
node3-hwvault-node-group   Ready    <none>   7h50m   v1.27.3   10.128.0.22   158.160.97.93     Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
```

# Инсталляция Hashicorp Vault HA в K8S

Склонируем репозиторий consul (необходимо минимум 3 ноды): 

```bash
git clone https://github.com/hashicorp/consul-helm.git
helm install consul consul-helm
```

>> "необходимо минимум 3 ноды" => сделаем файл values. 

Попробуем заполнить values для чарта (в т.ч. disruptionBudget и количество реплик) и перезапустить установку (заодно запустим helm с параметрами, привычными по ДЗ № kubernetes-templating): 

```bash
nano consul_values.yaml
helm upgrade --install consul consul-helm -f consul_values.yaml --atomic --wait --create-namespace -n hwvault
```

```
$ helm upgrade --install consul consul-helm -f consul_values.yaml --atomic --wait --create-namespace -n hwvault
Release "consul" does not exist. Installing it now.
W0125 22:32:59.674433   38521 warnings.go:70] policy/v1beta1 PodDisruptionBudget is deprecated in v1.21+, unavailable in v1.25+; use policy/v1 PodDisruptionBudget
W0125 22:32:59.822088   38521 warnings.go:70] policy/v1beta1 PodDisruptionBudget is deprecated in v1.21+, unavailable in v1.25+; use policy/v1 PodDisruptionBudget
NAME: consul
LAST DEPLOYED: Thu Jan 25 22:32:59 2024
NAMESPACE: hwvault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Consul!

Now that you have deployed Consul, you should look over the docs on using 
Consul with Kubernetes available here: 

https://www.consul.io/docs/platform/k8s/index.html


Your release is named consul.

To learn more about the release, run:

  $ helm status consul
  $ helm get all consul
```

```bash
helm status consul -n hwvault
helm get all consul -n hwvault
```

```text
$ kubectl get all -n hwvault
NAME                         READY   STATUS    RESTARTS   AGE
pod/consul-consul-d7g5n      1/1     Running   0          3m21s
pod/consul-consul-f97g5      1/1     Running   0          3m21s
pod/consul-consul-n7flh      1/1     Running   0          3m21s
pod/consul-consul-server-0   1/1     Running   0          3m21s
pod/consul-consul-server-1   1/1     Running   0          3m21s
pod/consul-consul-server-2   1/1     Running   0          3m20s

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                                                   AGE
service/consul-consul-dns      ClusterIP   10.96.198.7    <none>        53/TCP,53/UDP                                                             3m21s
service/consul-consul-server   ClusterIP   None           <none>        8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   3m21s
service/consul-consul-ui       ClusterIP   10.96.94.217   <none>        80/TCP                                                                    3m21s

NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/consul-consul   3         3         3       3            3           <none>          3m21s

NAME                                    READY   AGE
statefulset.apps/consul-consul-server   3/3     3m21s
```

Склонируем репозиторий vault: 

```bash
git clone https://github.com/hashicorp/vault-helm.git
```

## Отредактируем параметры установки в values.yaml

```text
standalone:
enabled: false
....
ha:
enabled: true
...
ui:
enabled: true
serviceType: "ClusterIP"
```

Сохраним в файле helm_values.yaml и запустим установку с параметрами, привычными по ДЗ № kubernetes-templating. 

## Установим vault

```bash
nano vault_values.yaml 
helm upgrade --install vault vault-helm -f ./vault_values.yaml --atomic --wait -n hwvault
```

```text
$ helm upgrade --install vault vault-helm -f ./vault_values.yaml --atomic --wait -n hwvault
Release "vault" does not exist. Installing it now.
NAME: vault
LAST DEPLOYED: Thu Jan 25 22:40:15 2024
NAMESPACE: hwvault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://developer.hashicorp.com/vault/docs


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```

```bash
helm status vault -n hwvault
helm get manifest vault -n hwvault
kubectl logs -n hwvault vault-0
kubectl logs -n hwvault vault-1
kubectl logs -n hwvault vault-2
kubectl get -n hwvault pods -w
kubectl get -n hwvault pods
```

```text
$ kubectl logs -n hwvault vault-0
==> Vault server configuration:

Administrative Namespace: 
             Api Address: http://10.244.2.5:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
   Environment Variables: CONSUL_CONSUL_DNS_PORT, CONSUL_CONSUL_DNS_PORT_53_TCP, .................................................. VAULT_UI_SERVICE_PORT_HTTP, VERSION
              Go Version: go1.21.3
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: 
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.15.2, built 2023-11-06T11:33:28Z
             Version Sha: cf1b5cafa047bc8e4a3f93444fcb4011593b92cb

==> Vault server started! Log data will stream in below:

2024-01-25T19:46:34.538Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2024-01-25T19:46:34.538Z [WARN]  storage.consul: appending trailing forward slash to path
2024-01-25T19:46:34.543Z [INFO]  incrementing seal generation: generation=1
2024-01-25T19:46:34.545Z [INFO]  core: Initializing version history cache for core
2024-01-25T19:46:34.545Z [INFO]  events: Starting event system
2024-01-25T19:46:43.024Z [INFO]  core: security barrier not initialized
2024-01-25T19:46:43.025Z [INFO]  core: seal configuration missing, not initialized
..................................................
2024-01-25T20:09:03.019Z [INFO]  core: security barrier not initialized
2024-01-25T20:09:03.020Z [INFO]  core: seal configuration missing, not initialized
```

```text
$ kubectl get all -n hwvault
NAME                                        READY   STATUS    RESTARTS   AGE
pod/consul-consul-d7g5n                     1/1     Running   0          37m
pod/consul-consul-f97g5                     1/1     Running   0          37m
pod/consul-consul-n7flh                     1/1     Running   0          37m
pod/consul-consul-server-0                  1/1     Running   0          37m
pod/consul-consul-server-1                  1/1     Running   0          37m
pod/consul-consul-server-2                  1/1     Running   0          37m
pod/vault-0                                 0/1     Running   0          30m
pod/vault-1                                 0/1     Running   0          30m
pod/vault-2                                 0/1     Running   0          30m
pod/vault-agent-injector-7fb9bb8dc7-k9f5q   1/1     Running   0          30m

NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                   AGE
service/consul-consul-dns          ClusterIP   10.96.198.7     <none>        53/TCP,53/UDP                                                             37m
service/consul-consul-server       ClusterIP   None            <none>        8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   37m
service/consul-consul-ui           ClusterIP   10.96.94.217    <none>        80/TCP                                                                    37m
service/vault                      ClusterIP   10.96.33.149    <none>        8200/TCP,8201/TCP                                                         30m
service/vault-active               ClusterIP   10.96.14.242    <none>        8200/TCP,8201/TCP                                                         30m
service/vault-agent-injector-svc   ClusterIP   10.96.73.174    <none>        443/TCP                                                                   30m
service/vault-internal             ClusterIP   None            <none>        8200/TCP,8201/TCP                                                         30m
service/vault-standby              ClusterIP   10.96.235.219   <none>        8200/TCP,8201/TCP                                                         30m
service/vault-ui                   ClusterIP   10.96.180.89    <none>        8200/TCP                                                                  30m

NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/consul-consul   3         3         3       3            3           <none>          37m

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/vault-agent-injector   1/1     1            1           30m

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/vault-agent-injector-7fb9bb8dc7   1         1         1       30m

NAME                                    READY   AGE
statefulset.apps/consul-consul-server   3/3     37m
statefulset.apps/vault                  0/3     30m
```

Обратите внимание на статус подов vault. 

Вывод helm status vault - добавьте в README.md. 

```text
$ helm status vault -n hwvault
NAME: vault
LAST DEPLOYED: Thu Jan 25 22:40:15 2024
NAMESPACE: hwvault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://developer.hashicorp.com/vault/docs


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```

## Изменим дефолтный неймспейс в контексте на hwvault

Для дальнейших шагов сделаем в контексте дефолтным неймспейс hwvault для удобства (с помощью [kubens](https://github.com/ahmetb/kubectx) или с помощью [моего простенького аналога kubens под названием kubectl_ns.sh](https://github.com/kodmandvl/wrapper_scripts/blob/main/kubectl/kubectl_ns.sh): 

```bash
kubens hwvault
# или
kubectl_ns.sh hwvault
# Проверить контекст и дефолтный неймспейс:
kubectx
kubens
# или
kubectl_ctx.sh
kubectl_ns.sh
```

```text
$ kubectl_ns.sh hwvault
SET hwvault NAMESPACE AS CURRENT NAMESPACE FOR CURRENT CONTEXT:
Context "kind-hwvault" modified.
===== GET CONTEXTS: =====
CURRENT   NAME           CLUSTER                               AUTHINFO                              NAMESPACE
*         kind-hwvault   kind-hwvault                          kind-hwvault                          hwvault
```

В этом месте снял снимок с работающей виртуальной машины для последующих проб и ошибок (на ВМ инициализация vault-а по итогу была выбрана с --key-shares=3 и --key-threshold=2). 

Параллельно делал эти же все шаги на физическом хосте в таком же кластере Kind с тем же именем и параметрами, там инициализация была с --key-shares=1 и --key-threshold=1 (далее где-то вывод с ВМ, а где-то - с хоста). 

## Инициализируем vault

Проведите инициализацию черерз любой под vault'а: 

```bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
```

С --key-shares=1 и --key-threshold=1 в Kind: 

```text
$ kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
Unseal Key 1: e+46TCkvFzhXAvwvkrCQrNl7zsMiEmY/3A9m2mYrxa0=

Initial Root Token: hvs.cfFoPKgfMztEuDIMJgCmXKAo

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

С --key-shares=1 и --key-threshold=1 в Yandex Cloud: 

```text
Unseal Key 1: ZoU1fzZb5z3YSTwryaN6nm0mzzqnpWe/BA8hrTVdFuw=

Initial Root Token: hvs.kOjrhesJYmiVS8Xa5hYu2J95

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

А с --key-shares=3 и --key-threshold=1 ошибка: 

```text
$ kubectl exec -it vault-0 -- vault operator init --key-shares=3 --key-threshold=1
Error initializing: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/init
Code: 400. Errors:

* invalid seal configuration: threshold must be greater than one for multiple shares
```

Попробуем взять 3 и 3 или 3 и 2 (3 и 2 на ВМ, 1 и 1 на хосте): 

```text
$ kubectl exec -it vault-0 -- vault operator init --key-shares=3 --key-threshold=3
Unseal Key 1: oXMgd/zmS5t8OG4Wt7k5iq20ziiJFzML/6zIEGcKfPh6
Unseal Key 2: DNS7Tt3/oZ16drKOjILag8moV/Q83WcE03d8YoPULgwR
Unseal Key 3: 1hpGuJ9koKU3VxA5iJjmhPmEMzxnFIAiNYExF61l768p

Initial Root Token: hvs.s2nmAfYCRGf2mSBvZZ26wVmc

Vault initialized with 3 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

```text
$ kubectl exec -it vault-0 -- vault operator init --key-shares=3 --key-threshold=2
Unseal Key 1: hXEEM9M1YXXuF4QlE/0Aep0A5c3MGE/XVjobBveNiZfa
Unseal Key 2: K4BtCeYFyFdkQ/S1hCpglgCskNFJnj/vM1CnVrxPG7U9
Unseal Key 3: n/f5Bqd+q+hDDyvPKSOWa9n1daAg4eAN/9LX25dVjApP

Initial Root Token: hvs.hcsKB6RdzrmTV9hRiVSi1Tl9

Vault initialized with 3 key shares and a key threshold of 2. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 2 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 2 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

Само собой, приводить токен и ключ в README небезопасно. Но это пример учебный на локальном Kind, который, к тому же, уже будет не существовать к моменту проверки ДЗ, т.ч. ничего страшного. 

## Проверим состояние vault'а:

```bash
kubectl logs vault-0
```

```text
$ kubectl logs vault-0 | tail -n 50
..................................................
2024-01-26T06:19:19.170Z [INFO]  core: security barrier not initialized
2024-01-26T06:19:19.202Z [INFO]  core: security barrier initialized: stored=1 shares=3 threshold=2
2024-01-26T06:19:19.233Z [INFO]  core: post-unseal setup starting
2024-01-26T06:19:19.250Z [INFO]  core: loaded wrapping token key
2024-01-26T06:19:19.250Z [INFO]  core: successfully setup plugin runtime catalog
2024-01-26T06:19:19.250Z [INFO]  core: successfully setup plugin catalog: plugin-directory=""
2024-01-26T06:19:19.252Z [INFO]  core: no mounts; adding default mount table
2024-01-26T06:19:19.273Z [INFO]  core: successfully mounted: type=cubbyhole version="v1.15.2+builtin.vault" path=cubbyhole/ namespace="ID: root. Path: "
2024-01-26T06:19:19.275Z [INFO]  core: successfully mounted: type=system version="v1.15.2+builtin.vault" path=sys/ namespace="ID: root. Path: "
2024-01-26T06:19:19.277Z [INFO]  core: successfully mounted: type=identity version="v1.15.2+builtin.vault" path=identity/ namespace="ID: root. Path: "
2024-01-26T06:19:19.348Z [INFO]  core: successfully mounted: type=token version="v1.15.2+builtin.vault" path=token/ namespace="ID: root. Path: "
2024-01-26T06:19:19.356Z [INFO]  rollback: Starting the rollback manager with 256 workers
2024-01-26T06:19:19.357Z [INFO]  rollback: starting rollback manager
2024-01-26T06:19:19.359Z [INFO]  core: restoring leases
2024-01-26T06:19:19.360Z [INFO]  expiration: lease restore complete
2024-01-26T06:19:19.431Z [INFO]  identity: entities restored
2024-01-26T06:19:19.431Z [INFO]  identity: groups restored
2024-01-26T06:19:19.434Z [INFO]  core: usage gauge collection is disabled
2024-01-26T06:19:19.440Z [INFO]  core: Recorded vault version: vault version=1.15.2 upgrade time="2024-01-26 06:19:19.433899762 +0000 UTC" build date=2023-11-06T11:33:28Z
2024-01-26T06:19:19.778Z [INFO]  core: post-unseal setup complete
2024-01-26T06:19:19.799Z [INFO]  core: root token generated
2024-01-26T06:19:19.799Z [INFO]  core: pre-seal teardown starting
2024-01-26T06:19:19.800Z [INFO]  rollback: stopping rollback manager
2024-01-26T06:19:19.800Z [INFO]  core: pre-seal teardown complete
```

Обратите внимание на параметры Initialized, Sealed: 

```bash
kubectl exec -it vault-0 -- vault status
```

```text
$ kubectl exec -it vault-0 -- vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       3
Threshold          2
Unseal Progress    0/2
Unseal Nonce       n/a
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
```

## Распечатаем vault

Обратите внимание на переменные окружения в подах: 

```bash
kubectl exec -it vault-0 -- env | grep VAULT
kubectl exec -it vault-0 -- env | grep VAULT | grep -i addr
```

```text
$ kubectl exec -it vault-0 -- env | grep VAULT | grep -i addr
VAULT_API_ADDR=http://10.244.2.5:8200
VAULT_CLUSTER_ADDR=https://vault-0.vault-internal:8201
VAULT_ADDR=http://127.0.0.1:8200
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_ADDR=10.96.73.174
VAULT_ACTIVE_PORT_8201_TCP_ADDR=10.96.14.242
VAULT_PORT_8200_TCP_ADDR=10.96.33.149
VAULT_ACTIVE_PORT_8200_TCP_ADDR=10.96.14.242
VAULT_PORT_8201_TCP_ADDR=10.96.33.149
VAULT_STANDBY_PORT_8200_TCP_ADDR=10.96.235.219
VAULT_UI_PORT_8200_TCP_ADDR=10.96.180.89
VAULT_STANDBY_PORT_8201_TCP_ADDR=10.96.235.219
```

Распечатать нужно каждый под (двумя из трех ключей): 

>> "When the Vault is re-sealed, restarted, or stopped, you must supply at least 2 of these keys to unseal it before it can start servicing requests." 

```bash
kubectl exec -it vault-0 -- vault operator unseal 'hXEEM9M1YXXuF4QlE/0Aep0A5c3MGE/XVjobBveNiZfa'
kubectl exec -it vault-0 -- vault operator unseal 'K4BtCeYFyFdkQ/S1hCpglgCskNFJnj/vM1CnVrxPG7U9'
kubectl exec -it vault-1 -- vault operator unseal 'K4BtCeYFyFdkQ/S1hCpglgCskNFJnj/vM1CnVrxPG7U9'
kubectl exec -it vault-1 -- vault operator unseal 'n/f5Bqd+q+hDDyvPKSOWa9n1daAg4eAN/9LX25dVjApP'
kubectl exec -it vault-2 -- vault operator unseal 'n/f5Bqd+q+hDDyvPKSOWa9n1daAg4eAN/9LX25dVjApP'
kubectl exec -it vault-2 -- vault operator unseal 'hXEEM9M1YXXuF4QlE/0Aep0A5c3MGE/XVjobBveNiZfa'
```

```text
$ kubectl exec -it vault-0 -- vault operator unseal 'hXEEM9M1YXXuF4QlE/0Aep0A5c3MGE/XVjobBveNiZfa'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       3
Threshold          2
Unseal Progress    1/2
Unseal Nonce       f3a6aed5-0972-3f52-6bf2-c294ae980dc3
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
$ kubectl exec -it vault-0 -- vault operator unseal 'K4BtCeYFyFdkQ/S1hCpglgCskNFJnj/vM1CnVrxPG7U9'
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    3
Threshold       2
Version         1.15.2
Build Date      2023-11-06T11:33:28Z
Storage Type    consul
Cluster Name    vault-cluster-5528f7e7
Cluster ID      fd25ac38-2fbb-1275-c387-64797e6b8cdd
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2024-01-26T06:38:48.177816866Z
```

>> "Sealed          false" => под-0 распечатали ("распломбировали"). 

Продолжаем: 

```text
$ kubectl exec -it vault-1 -- vault operator unseal 'K4BtCeYFyFdkQ/S1hCpglgCskNFJnj/vM1CnVrxPG7U9'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       3
Threshold          2
Unseal Progress    1/2
Unseal Nonce       6b463d17-6548-3a3a-0123-d7ed6dfa25ee
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
$ kubectl exec -it vault-1 -- vault operator unseal 'n/f5Bqd+q+hDDyvPKSOWa9n1daAg4eAN/9LX25dVjApP'
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           3
Threshold              2
Version                1.15.2
Build Date             2023-11-06T11:33:28Z
Storage Type           consul
Cluster Name           vault-cluster-5528f7e7
Cluster ID             fd25ac38-2fbb-1275-c387-64797e6b8cdd
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.2.5:8200
$ kubectl exec -it vault-2 -- vault operator unseal 'n/f5Bqd+q+hDDyvPKSOWa9n1daAg4eAN/9LX25dVjApP'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       3
Threshold          2
Unseal Progress    1/2
Unseal Nonce       7c381ee4-7ec4-707b-0950-d3518f08df08
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
$ kubectl exec -it vault-2 -- vault operator unseal 'hXEEM9M1YXXuF4QlE/0Aep0A5c3MGE/XVjobBveNiZfa'
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           3
Threshold              2
Version                1.15.2
Build Date             2023-11-06T11:33:28Z
Storage Type           consul
Cluster Name           vault-cluster-5528f7e7
Cluster ID             fd25ac38-2fbb-1275-c387-64797e6b8cdd
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.2.5:8200
```

Добавьте выдачу vault status в README.md (vault operator unseal выводит по итогу выполнения vault status, поэтом данный пункт выполнен чуть выше). 

Для случая 1 и 1 (на хосте) вот так будет: 

```bash
kubectl exec -it vault-0 -- vault operator unseal 'ZoU1fzZb5z3YSTwryaN6nm0mzzqnpWe/BA8hrTVdFuw='
kubectl exec -it vault-1 -- vault operator unseal 'ZoU1fzZb5z3YSTwryaN6nm0mzzqnpWe/BA8hrTVdFuw='
kubectl exec -it vault-2 -- vault operator unseal 'ZoU1fzZb5z3YSTwryaN6nm0mzzqnpWe/BA8hrTVdFuw='
```

## Посмотрим список доступных авторизаций

Выполните `kubectl exec -it vault-0 -- vault auth list` и получите ошибку: 

```text
$ kubectl exec -it vault-0 -- vault auth list
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 403. Errors:

* permission denied
```

## Залогинимся в vault (у нас есть root token)

```bash
kubectl exec -it vault-0 -- vault login
kubectl exec -it vault-0 -- vault auth list
```

* Вывод после логина добавьте в README.md.
* Повторно запросим список авторизаций.
* Вывод сохранить в README.md.

```text
$ kubectl exec -it vault-0 -- vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.kOjrhesJYmiVS8Xa5hYu2J95
token_accessor       bughheBDTgkAvDtsObAqdCLn
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

## Заведем секреты

* Вывод команды чтения секрета добавить в README.md.

```bash
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
```

```text
$ kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
Success! Enabled the kv secrets engine at: otus/
$ kubectl exec -it vault-0 -- vault secrets list --detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID                                    Version    Running Version          Running SHA256    Deprecation Status
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----                                    -------    ---------------          --------------    ------------------
cubbyhole/    cubbyhole    cubbyhole_02439883    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           efe22970-eabe-cb74-be2c-c18a60b68d00    n/a        v1.15.2+builtin.vault    n/a               n/a
identity/     identity     identity_ae991ce7     system         system     false             replicated     false        false                      map[]      identity store                                             aa489b62-e9cc-dc92-c47a-a01dfc023b64    n/a        v1.15.2+builtin.vault    n/a               n/a
otus/         kv           kv_76cd7625           system         system     false             replicated     false        false                      map[]      n/a                                                        bf724625-aeaf-b747-837f-f2706b396417    n/a        v0.16.1+builtin          n/a               supported
sys/          system       system_f28436a8       n/a            n/a        false             replicated     true         false                      map[]      system endpoints used for control, policy and debugging    d711aef6-20ff-34b6-078c-c88757bbb4ec    n/a        v1.15.2+builtin.vault    n/a               n/a
$ kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-ro/config
$ kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-rw/config
$ kubectl exec -it vault-0 -- vault read otus/otus-ro/config
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus
$ kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus
```

## Включим авторизацию черерз k8s

* Обновленный список авторизаций - добавить в README.md.

```bash
kubectl exec -it vault-0 -- vault auth enable kubernetes
kubectl exec -it vault-0 -- vault auth list
```

```text
$ kubectl exec -it vault-0 -- vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/
$ kubectl exec -it vault-0 -- vault auth list
Path           Type          Accessor                    Description                Version
----           ----          --------                    -----------                -------
kubernetes/    kubernetes    auth_kubernetes_b4782f45    n/a                        n/a
token/         token         auth_token_c0624da1         token based credentials    n/a
```

## Создадим yaml для ClusterRoleBinding

* Файл должен быть приложен в ДЗ.

```bash
tee vault-auth-service-account.yml <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: hwvault
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: hwvault
EOF
```

## Создадим Service Account vault-auth и применим ClusterRoleBinding

Можем создать через `kubectl create serviceaccount` и затем применить манифест `vault-auth-service-account.yml`: 

```bash
# Create a service account, 'vault-auth'
kubectl create serviceaccount vault-auth
# Update the 'vault-auth' service account
kubectl apply --filename vault-auth-service-account.yml
```

Но лучше сохранить настройки в манифестах, поэтому добавим создание сервисного аакаунта в начало файла `vault-auth-service-account.yml` (также добавим туда создание секрета для нашего сервисного аккаунта, который потребуется для дальнейшей настройки): 

```bash
nano vault-auth-service-account.yml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: hwvault
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-secret
  namespace: hwvault
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
..................................................
# а дальше то, что выше мы в файл записали
```

Теперь применим манифест, в котором и сервисный аккаунт, и секрет, и ClusterRoleBinding: 

```text
$ kubectl apply -f vault-auth-service-account.yml
serviceaccount/vault-auth created
secret/vault-auth-secret created
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created
```

## Подготовим переменные для записи в конфиг кубер авторизации

```bash
kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name'
export SA_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name')
kubectl get secret $SA_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo
export SA_JWT_TOKEN=$(kubectl get secret $SA_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode; echo
export SA_CA_CRT=$(kubectl config view --raw --minify --flatten --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode; echo)
kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.server}' ; echo
export K8S_HOST=$(kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.server}')
```

```text
$ kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name'
vault-auth-secret
$ export SA_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name')
$ kubectl get secret $SA_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo
export SA_JWT_TOKEN=$(kubectl get secret $SA_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
eyJhbGciOiJSUzI1NiIsImtpZCI6IlJacm5ES2w5b3VNcjd5S2Ixb1ZHT1lIX2ZpaVRhMWpLSjdfemI4a1h4QlUifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJod3ZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InZhdWx0LWF1dGgtc2VjcmV0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6InZhdWx0LWF1dGgiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI2NDcyZjgzMS1mMTU5LTQ5NTEtYTY2Yi0wNDVkMTkxOTIyYTUiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6aHd2YXVsdDp2YXVsdC1hdXRoIn0.AATQAHJL0HkSgHDtOXaagwEkwYjVd-9qym5ekOlcyt-vJrweefFl_v6GmgFibH3bKjhnjIfzqgF-4W0DoJGll-tm_ueYuAK9gNAz0K0obm1cKWYdtlWXw0IE29fU6wMwdDpagAjzYxn8maSO_0gq0FoNL9rgxwTvAbNV3s62fbRIovZ33L1OLIK0PfXqeVAJibw-0wHuu1jJzL2ViZRczwVZRTwynfLHsmTWnBUmQd4hAvtGT9recLsMkuKL-i8S8tqtfpyuFn4PEHs-7tNUpoN8Ml-cP_T7SG7vcHn1HoZq_slwA9RRcKfgaAOu-4cu6kbzusgGpQOH_6sUG8V2EA
$ kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode; echo
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTI0MDEyODA4MzAwMFoXDTM0MDEyNTA4MzAwMFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALcC
JJyxwPGeOXuiKIjybJ6MVFCX+18mYJdhllwsJzbEKDWW0eIngA3ZxIfm7Ke/KP2+
KKca7ceXnVJohq8hvxOW2ZtBZ4Ze5KNWZYJEq0P9AtqeN36ueMncyybnetGJtxmA
DOKTT9MIaaU4HbrYiURxRnWZ5F6gqiy2ua9HPHBkYnSrT/XzVndPQTXHA37VeWc8
+8DVNy/1NhH1n8MGYMAJC0Bk32z9I1P0HAQ+m8b3y7qnSCxBQJzSJlBSNVFwUMWE
XLvnT1+nBShQkvfQ2fAnhxBTZP9tl6pUHp1nl6GMlmyNymJx6MmvI85AQllOcqjT
kcxy7XY8lYrs2ACx6ekCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFJIBk1vpz9dSQgm7vc+SBoBYSs5rMA0GCSqGSIb3
DQEBCwUAA4IBAQCTZ8989/yUL7CosSrKSRIduD5DY/PkdQAtrJGrl1IyJF0HTRmU
vzZeUxkB5bDEUVUl49Xs072BjSNijVDwbBZ5fhlxBcOdvqMVcO1Vq8H4TtEuIkEc
P4/Vh0ppd+XrJmSTw6vNtp2ypQC+fq7vfhM8RQ+FmbG5JLMz0mPkfy8cFPZq5Mrj
vkl3zxaCJ+m2AAtSBTXiw0KUfoWR6ywt6fxB3egJe0Jww7sw7+S9SVBgjnfTcdgQ
j4MhT9HfER9C1kaRGwI035IEr5BzmaVeWtVFhRv1K8Pw4IlwfHL5Zd7aDLVI1bVD
i+J/eINQQA7ZA4J3eN/TNI4xybINyrvfcQB9
-----END CERTIFICATE-----

$ export SA_CA_CRT=$(kubectl config view --raw --minify --flatten --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode; echo)
$ kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.server}' ; echo
https://158.160.96.202
$ export K8S_HOST=$(kubectl config view --raw --minify --flatten   --output 'jsonpath={.clusters[].cluster.server}')
```

## Запишем конфиг в vault

```bash
echo $SA_JWT_TOKEN
echo $SA_CA_CRT
echo $K8S_HOST
kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="$K8S_HOST" \
kubernetes_ca_cert="$SA_CA_CRT" \
issuer="https://kubernetes.default.svc.cluster.local"
```

```text
$ kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="$K8S_HOST" \
kubernetes_ca_cert="$SA_CA_CRT" \
issuer="https://kubernetes.default.svc.cluster.local"
Success! Data written to: auth/kubernetes/config
```

```bash
kubectl exec -it vault-0 -- vault read auth/kubernetes/config
kubectl exec -it vault-0 -- vault kv get auth/kubernetes/config
```
```text
$ kubectl exec -it vault-0 -- vault read auth/kubernetes/config
Key                       Value
---                       -----
disable_iss_validation    true
disable_local_ca_jwt      false
issuer                    https://kubernetes.default.svc.cluster.local
kubernetes_ca_cert        -----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTI0MDEyODA4MzAwMFoXDTM0MDEyNTA4MzAwMFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALcC
JJyxwPGeOXuiKIjybJ6MVFCX+18mYJdhllwsJzbEKDWW0eIngA3ZxIfm7Ke/KP2+
KKca7ceXnVJohq8hvxOW2ZtBZ4Ze5KNWZYJEq0P9AtqeN36ueMncyybnetGJtxmA
DOKTT9MIaaU4HbrYiURxRnWZ5F6gqiy2ua9HPHBkYnSrT/XzVndPQTXHA37VeWc8
+8DVNy/1NhH1n8MGYMAJC0Bk32z9I1P0HAQ+m8b3y7qnSCxBQJzSJlBSNVFwUMWE
XLvnT1+nBShQkvfQ2fAnhxBTZP9tl6pUHp1nl6GMlmyNymJx6MmvI85AQllOcqjT
kcxy7XY8lYrs2ACx6ekCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFJIBk1vpz9dSQgm7vc+SBoBYSs5rMA0GCSqGSIb3
DQEBCwUAA4IBAQCTZ8989/yUL7CosSrKSRIduD5DY/PkdQAtrJGrl1IyJF0HTRmU
vzZeUxkB5bDEUVUl49Xs072BjSNijVDwbBZ5fhlxBcOdvqMVcO1Vq8H4TtEuIkEc
P4/Vh0ppd+XrJmSTw6vNtp2ypQC+fq7vfhM8RQ+FmbG5JLMz0mPkfy8cFPZq5Mrj
vkl3zxaCJ+m2AAtSBTXiw0KUfoWR6ywt6fxB3egJe0Jww7sw7+S9SVBgjnfTcdgQ
j4MhT9HfER9C1kaRGwI035IEr5BzmaVeWtVFhRv1K8Pw4IlwfHL5Zd7aDLVI1bVD
i+J/eINQQA7ZA4J3eN/TNI4xybINyrvfcQB9
-----END CERTIFICATE-----
kubernetes_host           https://158.160.96.202
pem_keys                  []
```

## Создадим файл политики

```bash
tee otus-policy.hcl <<EOF
path "otus/otus-ro/*" {
capabilities = ["read", "list"]
}
path "otus/otus-rw/*" {
capabilities = ["read", "create", "list"]
}
EOF
```

## Создадим политку и роль в vault

```bash
kubectl cp otus-policy.hcl vault-0:/vault/
kubectl exec -it vault-0 -- ls -F /vault/
kubectl exec -it vault-0 -- cat /vault/otus-policy.hcl
kubectl exec -it vault-0 -- vault policy write otus-policy /vault/otus-policy.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=hwvault policies=otus-policy ttl=24h
```

```text
$ kubectl cp otus-policy.hcl vault-0:/vault/
$ kubectl exec -it vault-0 -- ls -F /vault/
config/          file/            logs/            otus-policy.hcl
$ kubectl exec -it vault-0 -- cat /vault/otus-policy.hcl
path "otus/otus-ro/*" {
capabilities = ["read", "list"]
}
path "otus/otus-rw/*" {
capabilities = ["read", "create", "list"]
}
$ kubectl exec -it vault-0 -- vault policy write otus-policy /vault/otus-policy.hcl
Success! Uploaded policy: otus-policy
$ kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=hwvault policies=otus-policy ttl=24h
Success! Data written to: auth/kubernetes/role/otus
```

## Проверим как работает авторизация

* Создадим под с привязанным сервис аккаунтом и установим туда curl и jq:

```bash
kubectl run tmp --rm -i --tty --overrides='{ "spec": { "serviceAccount": "vault-auth" }  }' --image alpine:3.18
apk add curl jq
```

* Залогинимся и получим клиентский токен:

```bash
VAULT_ADDR=http://vault:8200
cat /var/run/secrets/kubernetes.io/serviceaccount/token
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}'
TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
```

На этом шаге никак ни на одном из стендов с Kind-ом не удавалось авторизоваться: и на виртуальной машине на стенде с Kind-ом, и на хосте с аналогичным Kind-ом с теми же настройками, и немного с другими настройками выше в README, и в другой версии образа alpine. Также пробовал добавить `issuer="https://kubernetes.default.svc.cluster.local"` в `auth/kubernetes/config`. Все шаги перепроверил и перевыполнил несколько раз, всё одно и то же: 

```text
/ # KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
/ # echo $KUBE_TOKEN
eyJhbGciOiJSUzI1NiIsImtpZCI6IlZFRWQ0WnhfWTNLR0tXVWxWY1Z4RnY4N1NCVXZJMjZoTkQ0aG9rNVlaSVEifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzM3OTE5NDE2LCJpYXQiOjE3MDYzODM0MTYsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJod3ZhdWx0IiwicG9kIjp7Im5hbWUiOiJ0bXAiLCJ1aWQiOiJiZTQwMDMwNy1hMmU3LTRkMWMtOGY1MC00NGNkMTFkZTAzYWYifSwic2VydmljZWFjY291bnQiOnsibmFtZSI6InZhdWx0LWF1dGgiLCJ1aWQiOiJkNDYwN2RiYS02NzUxLTRhY2EtOWM3Zi03YTQ2ODY2OGYxODYifSwid2FybmFmdGVyIjoxNzA2Mzg3MDIzfSwibmJmIjoxNzA2MzgzNDE2LCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6aHd2YXVsdDp2YXVsdC1hdXRoIn0.AoDwiIYkywNhBreUyTVBdg-dOcYcjZt8ce6Blh2H2acKJ83qiNsfA-hLzaG25mwxq4OD0jqOA1Q-iJzL2OxL_hH4VaLOX4TLKy5dAZ6pAlxXv7dVD-e2FN7hQEAJ-V7fY5kh4MnihqQY1MJZ3aYXLPJ6x39jLu0jyCunTcvXgjUdFRm-stxHzqCrzwnNkoqGkfM-TYvmeawDLFWwPST-sV4Fu4tlGASoqvHYZXAJrSOCDzRH88bT51n9_uqsBqPcviPidl00bbW4KstoIsJNMlx1I59VL7hCPsfqcKTp_qt1Xf4nWt2cjXZwsUMQI9S7vy7h5vNF1cHWiVDo5dNJ_g
/ # curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  1057  100    33  100  1024  11587   351k --:--:-- --:--:-- --:--:--  516k
{
  "errors": [
    "permission denied"
  ]
}
```

Но на managed K8s кластере в Yande Cloud всё прошло без ошибок: 

```text
/ # echo $KUBE_TOKEN
eyJhbGciOiJSUzI1NiIsImtpZCI6IlJacm5ES2w5b3VNcjd5S2Ixb1ZHT1lIX2ZpaVRhMWpLSjdfemI4a1h4QlUifQ.eyJhdWQiOlsia3ViZXJuZXRlcy5kZWZhdWx0LnN2YyJdLCJleHAiOjE3MzgwMDUzNTMsImlhdCI6MTcwNjQ2OTM1MywiaXNzIjoia3ViZXJuZXRlcy5kZWZhdWx0LnN2YyIsImt1YmVybmV0ZXMuaW8iOnsibmFtZXNwYWNlIjoiaHd2YXVsdCIsInBvZCI6eyJuYW1lIjoidG1wIiwidWlkIjoiZmEzMGIyMWQtZTZiZi00YzM3LTlmMTctYjBkMjRlNDZjN2EyIn0sInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJ2YXVsdC1hdXRoIiwidWlkIjoiNjQ3MmY4MzEtZjE1OS00OTUxLWE2NmItMDQ1ZDE5MTkyMmE1In0sIndhcm5hZnRlciI6MTcwNjQ3Mjk2MH0sIm5iZiI6MTcwNjQ2OTM1Mywic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omh3dmF1bHQ6dmF1bHQtYXV0aCJ9.SBhz7P2sJpgpO-27Soq6tm5RUUOxPN_QYj5KLaO1dscyPbqm4eHqKHjZCG4llk3BNjRN247fP9DSBqC0W_aPivwWUx9675PmjfeFBgp0cW3UqxNryj0fslpNQC4-lppXIkIMHiN2-lHqEvJ2mIcXMtpgRjmAzTSEoKDmbvBAEk9pt9xKppKKfNinOZ6VgThBVtLxT0kaXSEbORJH-EsUxbvrPLXkrylmpt79D8djWNoR2XgAAkKpZsHTbQ93T_0suiyvZBYf_-AhEnUGmxyFVZR0Cs1684WJoXatL65Lg71e8cdk-vMVqaJ9odovH7g7CSdAs5wxS95bSKnTv8OdbQ
/ # curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  1714  100   749  100   965  15453  19910 --:--:-- --:--:-- --:--:-- 35708
{
  "request_id": "fa877a0f-fae1-a349-a39d-88b313484431",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "hvs.CAESIAOsDOvOiqduBQkLaorMtlI29VdTvM2i70hVfhn56DyJGh4KHGh2cy5IeFg1ZFVDOEZUc0N4cFFjcTVCbHhERUQ",
    "accessor": "0tXnjwkNO4swAh6JsDUqKf3l",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "hwvault",
      "service_account_secret_name": "",
      "service_account_uid": "6472f831-f159-4951-a66b-045d191922a5"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "a6369649-f848-3f77-8b29-454c4f69454f",
    "token_type": "service",
    "orphan": true,
    "mfa_requirement": null,
    "num_uses": 0
  }
}
/ # curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login |
 jq '.auth.client_token' | awk -F\" '{print $2}'
hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk
TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
```

## Прочитаем записанные ранее секреты и попробуем их обновить

* Используйте свой клиентский токен

* Проверим чтение:

```bash
curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-ro/config
curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
```

* Проверим запись:

```bash
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-ro/config
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config1
```

```text
/ # curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-ro/config
{"request_id":"18fd0cc4-4a75-0867-e076-265d913f7ca7","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
/ # curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"1620401d-2e97-4e73-22b2-8f39fb2754b8","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
/ # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
/ # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
/ # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config1
# Запись в config1 прошла, ошибки нет. Посмотрим:
/ # curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config1
{"request_id":"51a45365-6d0b-f74b-a674-2d41feda5dc1","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
```

## Разберемся с ошибками при записи

* Почему мы смогли записать otus-rw/config1 но не смогли otus-rw/config
* Измените политику так, чтобы можно было менять otus-rw/config
* Ответы на вопросы добавить в README.md

Добавим в политику в capabilities для "otus/otus-rw/*" еще `update` (есть create, read, list, но update нет): 

```bash
tee otus-policy-changed.hcl <<EOF
path "otus/otus-ro/*" {
capabilities = ["read", "list"]
}
path "otus/otus-rw/*" {
capabilities = ["read", "create", "list", "update"]
}
EOF
kubectl cp otus-policy-changed.hcl vault-0:/vault/
kubectl exec -it vault-0 -- ls -F /vault/
kubectl exec -it vault-0 -- cat /vault/otus-policy-changed.hcl
kubectl exec -it vault-0 -- vault policy write otus-policy /vault/otus-policy-changed.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=hwvault policies=otus-policy ttl=24h
```

Проверим теперь (в той же сессии в том же поде): 

```text
/ # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
/ # curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
/ # curl --header "X-Vault-Token:hvs.CAESICDlubiPmD_GmkeQCG3XaeSGs8jumA5B4MwOHQhhVB2gGh4KHGh2cy5SRklKTmtGWkR4VVRoZFpUWGJUOVBDYmk" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"a94fd99e-d8ae-ec6e-7bfc-304f7254c4bf","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
```

Теперь изменение `otus-rw/config` успешно выполнилось. 

## Use case использования авторизации через кубер

* Авторизуемся через vault-agent и получим клиентский токен
* Через consul-template достанем секрет и положим его в nginx
* Итог - nginx получил секрет из волта, не зная ничего про волт

## Заберем репозиторий с примерами

```bash
git clone https://github.com/hashicorp/vault-guides.git
cd vault-guides/identity/vault-agent-k8s-demo
```

* В каталоге configs-k8s скорректируйте конфиги с учетом ранее созданых ролей и секретов
* Проверьте и скорректируйте конфиг example-k8s-spec.
* Скорректированные конфиги приложить к ДЗ

```bash
git clone https://github.com/hashicorp/vault-guides.git
mkdir configs-k8s
cd vault-guides/identity/vault-agent-k8s-demo
cp -aiv configmap.yaml ../../../configs-k8s/
cp -aiv example-k8s-spec.yaml ../../../configs-k8s/
cd ../../../
nano configs-k8s/configmap.yaml
nano configs-k8s/example-k8s-spec.yaml
diff configs-k8s/configmap.yaml vault-guides/identity/vault-agent-k8s-demo/configmap.yaml
diff configs-k8s/example-k8s-spec.yaml vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yaml
```

## Запускаем пример

```bash
# Create a ConfigMap, example-vault-agent-config
kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/configmap.yaml
# View the created ConfigMap
kubectl get configmap example-vault-agent-config -o yaml
# Finally, create vault-agent-example Pod
kubectl apply -f ./configs-k8s/example-k8s-spec.yaml
```

```text
$ kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/configmap.yaml
configmap/example-vault-agent-config created
$ kubectl get configmap example-vault-agent-config -o yaml
apiVersion: v1
data:
  configmap.yaml: "---\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: example-vault-agent-config\n
    \ namespace: hwvault\ndata:\n  vault-agent-config.hcl: |\n    # Comment this out
    if running as sidecar instead of initContainer\n    exit_after_auth = true\n    \n
    \   pid_file = \"/home/vault/pidfile\"\n    \n    auto_auth {\n        method
    \"kubernetes\" {\n            mount_path = \"auth/kubernetes\"\n            config
    = {\n                role = \"otus\"\n            }\n        }\n    \n        sink
    \"file\" {\n            config = {\n                path = \"/home/vault/.vault-token\"\n
    \           }\n        }\n    }\n    \n    template {\n    destination = \"/etc/secrets/index.html\"\n
    \   contents = <<EOT\n    <html>\n    <body>\n    <p>Some secrets:</p>\n    {{-
    with secret \"otus/otus-ro/config\" }}\n    <ul>\n    <li><pre>username: {{ .Data.username
    }}</pre></li>\n    <li><pre>password: {{ .Data.password }}</pre></li>\n    </ul>\n
    \   {{ end }}\n    </body>\n    </html>\n    EOT\n    }\n"
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-29T09:21:44Z"
  name: example-vault-agent-config
  namespace: hwvault
  resourceVersion: "409691"
  uid: d8a7eb03-25a5-482b-a6a0-885338ed49c9
$ kubectl apply -f ./configs-k8s/example-k8s-spec.yaml
pod/vault-agent-example created
```

## Проверка

* законнектиться к поду nginx и вытащить оттуда index.html
* index.html приложить к ДЗ

```bash
kubectl exec -it vault-agent-example -c nginx-container -- cat /usr/share/nginx/html/index.html
```

```text
<html>
<body>
<p>Some secrets:</p>
<ul>
<li><pre>username: otus</pre></li>
<li><pre>password: asajkjkahs</pre></li>
</ul>

</body>
</html>
```

## Создадим CA на базе vault

* Включим pki секретс

```bash
kubectl exec -it vault-0 -- vault secrets enable pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal \
common_name="exmaple.ru" ttl=87600h > CA_cert.crt
```

```text
$ kubectl exec -it vault-0 -- vault secrets enable pki
Success! Enabled the pki secrets engine at: pki/
$ kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
Success! Tuned the secrets engine at: pki/
$ kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal \
common_name="exmaple.ru" ttl=87600h > CA_cert.crt
$ cat CA_cert.crt 
-----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUJ9BQu0hThr2QxMBl5tg42cdIDbAwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkwOTM5MjRaFw0zNDAx
MjYwOTM5NTNaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDTIW9OYW8uOwPPGVG4scRNRRI486uu1PVQLOmmKnI8
o3fgATnxT8Y7QvlVV5Sus0BR9iu+t5ovVpP8vcqyEcdKa6lFQ5nybjEYIuWwxPrD
+H3VBhPXyXmGY/8hU9WS4HNOdHEPx1Cph5Ej2ckPs5f78PQ63mnQABHoPk85zZcx
YsudYlap5M4Zp+e6XTI1piSVwkMJZennNIYRzbW4OB5cI8hVnLgF2h6+BxP1DfAs
VTJddgGhWsLU5FYHneQINeU+0ExtEUQxkLM8EDbm0nV+jPH8Yk6i8i+o3+BcpIEd
ppyN79w9inWwDTjsqR4uVbA99GGhCOrzyDdEjczmkn9PAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRLGylACpQQz0y5
9zUt+ReXsEVdfDAfBgNVHSMEGDAWgBRLGylACpQQz0y59zUt+ReXsEVdfDAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQBzmYfh3DkBt9mJ
PyK1p2A8BaTPGc4e/mPDjEH2tUPpxWmr+KVtA6aJrvQyVU12v6AuTRqne7FNy9+l
v1YASz+SxqWItP6LHe0J8jN2coOhEk1pxHtwpn4/Xpx4NqPe297jIIEModD30ZHm
GW/JbLh1w+fRcKNmr4JBDBAl8YOjeLai//UsvNVN9AU45n0DiZpJkeqxThCaNKwR
P8nBHsG11aaSAaZ91vGj+VMAu28ubEjzlKNIhOOxxwTbesGq4Z7JRQaOHIGbZi3n
drPU7+PwC/UpON9Q/xKCcKNK7Yi9Tk7m3D+TcQRAAa4VwCrP0Pktpe79bR2pDODN
dT3CG5aC
-----END CERTIFICATE-----
```

## пропишем урлы для ca и отозванных сертификатов

```bash
kubectl exec -it vault-0 -- vault write pki/config/urls \
issuing_certificates="http://vault:8200/v1/pki/ca" \
crl_distribution_points="http://vault:8200/v1/pki/crl"
```

```text
$ kubectl exec -it vault-0 -- vault write pki/config/urls \
issuing_certificates="http://vault:8200/v1/pki/ca" \
crl_distribution_points="http://vault:8200/v1/pki/crl"
Key                        Value
---                        -----
crl_distribution_points    [http://vault:8200/v1/pki/crl]
enable_templating          false
issuing_certificates       [http://vault:8200/v1/pki/ca]
ocsp_servers               []
```

## создадим промежуточный сертификат

```bash
kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
kubectl exec -it vault-0 -- vault write -format=json \
pki_int/intermediate/generate/internal \
common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
```

```text
$ kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
Success! Enabled the pki secrets engine at: pki_int/
$ kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
Success! Tuned the secrets engine at: pki_int/
$ kubectl exec -it vault-0 -- vault write -format=json \
pki_int/intermediate/generate/internal \
common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
$ cat pki_intermediate.csr 
-----BEGIN CERTIFICATE REQUEST-----
MIICcTCCAVkCAQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUg
QXV0aG9yaXR5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxLRXdZC+
AjqTGfYJI6OMVSmZVxfyLv0bKa7nlfTuzoNSEuGgC2tNGyiardDNJi5r75CLSLxy
bO/+jX95cYArjFNNxnQvKKS3MwiTEWufeH/FNE84P22+CsuLxwXzgra2geJuPqNd
rGwHeSO7NEHOVkQ9VHDHsO/XA/zSVB4qIOj+5JIJOqBl28060OWl6nh1hx6Yl7J3
hU6aYwE1Hy8jPEDPoomJbElFCfhkrtjcVEsXAPu0DeXG8crQZ+6pOR8udPJk7ki9
2cCb4wB7C+in85Zz5qlyTRzsxfZ+8vw+E9aD6LWEUndh/tJ1geBpcYRgAzFko51/
Ujou+n0giVPeHQIDAQABoAAwDQYJKoZIhvcNAQELBQADggEBAL/ZE/CYvjOfwnoq
peHX/6y1dBFhrdCSt6LNdpVniMRP3SJMJEQlTWd03OCj0LbpqKYHxjSs89CAUkdF
QvaXxGLeZ7UDhvPNc626kQTzE/JuzL3mtG4Ecs4cTIIivrZxbkqwZ8gWu/kH2dqL
xZURcxNYEFh2bJ7phXXgzrUr2NNI32YSvoVspiu3Kd3n6rI7gOb+ITWfdAQLIFEI
d5pl0twNrdEQZiSHKAuSl4w/QLHuwbneitcuV+qSbpBLMmEVAk6zK+GA79OlaE17
JOcg57P40pTiRc8UUrKou+1zOigWnhDzBKDFb0W11navkZu0TGVFdVcAOYjAC1fl
uGRvnds=
-----END CERTIFICATE REQUEST-----
```

## пропишем промежуточный сертификат в vault

```bash
kubectl cp pki_intermediate.csr vault-0:/vault/
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@/vault/pki_intermediate.csr \
format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
kubectl cp intermediate.cert.pem vault-0:/vault/
kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed \
certificate=@/vault/intermediate.cert.pem
```

```text
$ kubectl cp pki_intermediate.csr vault-0:/vault/
$ kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@/vault/pki_intermediate.csr \
format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
$ kubectl cp intermediate.cert.pem vault-0:/vault/
$ kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed \
certificate=@/vault/intermediate.cert.pem
WARNING! The following warnings were returned from Vault:

  * This mount hasn't configured any authority information access (AIA)
  fields; this may make it harder for systems to find missing certificates
  in the chain or to validate revocation status of certificates. Consider
  updating /config/urls or the newly generated issuer with this information.

Key                 Value
---                 -----
existing_issuers    <nil>
existing_keys       <nil>
imported_issuers    [7243f804-d776-87fa-a31d-b4c68e85f69e ac8e0dea-df99-2d85-a6d0-758bfca0fbb7]
imported_keys       <nil>
mapping             map[7243f804-d776-87fa-a31d-b4c68e85f69e:5f1e8181-00f7-23a8-a3f4-daca6d8bddec ac8e0dea-df99-2d85-a6d0-758bfca0fbb7:]
$ cat intermediate.cert.pem
-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUaFlhIsx+kbOyml6b/+39hBhglZcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkxMDAxMjhaFw0yOTAx
MjcxMDAxNThaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMS0V3WQvgI6
kxn2CSOjjFUpmVcX8i79Gymu55X07s6DUhLhoAtrTRsomq3QzSYua++Qi0i8cmzv
/o1/eXGAK4xTTcZ0LyiktzMIkxFrn3h/xTRPOD9tvgrLi8cF84K2toHibj6jXaxs
B3kjuzRBzlZEPVRwx7Dv1wP80lQeKiDo/uSSCTqgZdvNOtDlpep4dYcemJeyd4VO
mmMBNR8vIzxAz6KJiWxJRQn4ZK7Y3FRLFwD7tA3lxvHK0GfuqTkfLnTyZO5IvdnA
m+MAewvop/OWc+apck0c7MX2fvL8PhPWg+i1hFJ3Yf7SdYHgaXGEYAMxZKOdf1I6
Lvp9IIlT3h0CAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUggme99AQ8VArZO+X4vuBN7K2Bt4wHwYDVR0jBBgwFoAU
SxspQAqUEM9Mufc1LfkXl7BFXXwwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
Tfimy8mPOTuVkeT7Tg7wbAeVW6TukW3hOcJS42NgXZ5sQ/2h0nxbw5M8FTxg+IYE
AmmeJu2cNtTQHgERr3Cmu7hsQ0rbcBKlOaVUT5DxgEe3NfW+NkgK+MzR6FSm5Z7p
ZPElEZ9u6uKUr3c8dKqZcTSuIeTPp0W5/R3eYPfli9xZTHPmu3P+g08G/PrGlr4J
b5jaBnDaiBlOKIn5BmH0a4eE3xbWoiHun/Vq5mFNgd8OkdyE3mimIfI7XR9mVdmG
Qkyy3ltPT947LIk8vdKSR1sjoLNZqyoS8WKbI74F9mCr2Q1XdTsv/gnCn48JM8UK
Sh3IqMXhB4IQaxcud/LpsA==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUJ9BQu0hThr2QxMBl5tg42cdIDbAwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkwOTM5MjRaFw0zNDAx
MjYwOTM5NTNaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDTIW9OYW8uOwPPGVG4scRNRRI486uu1PVQLOmmKnI8
o3fgATnxT8Y7QvlVV5Sus0BR9iu+t5ovVpP8vcqyEcdKa6lFQ5nybjEYIuWwxPrD
+H3VBhPXyXmGY/8hU9WS4HNOdHEPx1Cph5Ej2ckPs5f78PQ63mnQABHoPk85zZcx
YsudYlap5M4Zp+e6XTI1piSVwkMJZennNIYRzbW4OB5cI8hVnLgF2h6+BxP1DfAs
VTJddgGhWsLU5FYHneQINeU+0ExtEUQxkLM8EDbm0nV+jPH8Yk6i8i+o3+BcpIEd
ppyN79w9inWwDTjsqR4uVbA99GGhCOrzyDdEjczmkn9PAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRLGylACpQQz0y5
9zUt+ReXsEVdfDAfBgNVHSMEGDAWgBRLGylACpQQz0y59zUt+ReXsEVdfDAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQBzmYfh3DkBt9mJ
PyK1p2A8BaTPGc4e/mPDjEH2tUPpxWmr+KVtA6aJrvQyVU12v6AuTRqne7FNy9+l
v1YASz+SxqWItP6LHe0J8jN2coOhEk1pxHtwpn4/Xpx4NqPe297jIIEModD30ZHm
GW/JbLh1w+fRcKNmr4JBDBAl8YOjeLai//UsvNVN9AU45n0DiZpJkeqxThCaNKwR
P8nBHsG11aaSAaZ91vGj+VMAu28ubEjzlKNIhOOxxwTbesGq4Z7JRQaOHIGbZi3n
drPU7+PwC/UpON9Q/xKCcKNK7Yi9Tk7m3D+TcQRAAa4VwCrP0Pktpe79bR2pDODN
dT3CG5aC
-----END CERTIFICATE-----
```

## Создадим и отзовем новые сертификаты

* Создадим роль для выдачи с ертификатов

```bash
kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru \
allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
```

```text
$ kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru \
allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
Key                                   Value
---                                   -----
allow_any_name                        false
allow_bare_domains                    false
allow_glob_domains                    false
allow_ip_sans                         true
allow_localhost                       true
allow_subdomains                      true
allow_token_displayname               false
allow_wildcard_certificates           true
allowed_domains                       [example.ru]
allowed_domains_template              false
allowed_other_sans                    []
allowed_serial_numbers                []
allowed_uri_sans                      []
allowed_uri_sans_template             false
allowed_user_ids                      []
basic_constraints_valid_for_non_ca    false
client_flag                           true
cn_validations                        [email hostname]
code_signing_flag                     false
country                               []
email_protection_flag                 false
enforce_hostnames                     true
ext_key_usage                         []
ext_key_usage_oids                    []
generate_lease                        false
issuer_ref                            default
key_bits                              2048
key_type                              rsa
key_usage                             [DigitalSignature KeyAgreement KeyEncipherment]
locality                              []
max_ttl                               720h
no_store                              false
not_after                             n/a
not_before_duration                   30s
organization                          []
ou                                    []
policy_identifiers                    []
postal_code                           []
province                              []
require_cn                            true
server_flag                           true
signature_bits                        256
street_address                        []
ttl                                   0s
use_csr_common_name                   true
use_csr_sans                          true
use_pss                               false
```

* Создадим и отзовем сертификат

```bash
kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru \
common_name="gitlab.example.ru" ttl="24h"
kubectl exec -it vault-0 -- vault write pki_int/revoke \
serial_number="68:3f:48:1e:f7:1e:73:e5:87:d6:ea:22:f8:1b:7a:1f:26:37:4e:76"
```

```text
$ kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru \
common_name="gitlab.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUaFlhIsx+kbOyml6b/+39hBhglZcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkxMDAxMjhaFw0yOTAx
MjcxMDAxNThaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMS0V3WQvgI6
kxn2CSOjjFUpmVcX8i79Gymu55X07s6DUhLhoAtrTRsomq3QzSYua++Qi0i8cmzv
/o1/eXGAK4xTTcZ0LyiktzMIkxFrn3h/xTRPOD9tvgrLi8cF84K2toHibj6jXaxs
B3kjuzRBzlZEPVRwx7Dv1wP80lQeKiDo/uSSCTqgZdvNOtDlpep4dYcemJeyd4VO
mmMBNR8vIzxAz6KJiWxJRQn4ZK7Y3FRLFwD7tA3lxvHK0GfuqTkfLnTyZO5IvdnA
m+MAewvop/OWc+apck0c7MX2fvL8PhPWg+i1hFJ3Yf7SdYHgaXGEYAMxZKOdf1I6
Lvp9IIlT3h0CAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUggme99AQ8VArZO+X4vuBN7K2Bt4wHwYDVR0jBBgwFoAU
SxspQAqUEM9Mufc1LfkXl7BFXXwwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
Tfimy8mPOTuVkeT7Tg7wbAeVW6TukW3hOcJS42NgXZ5sQ/2h0nxbw5M8FTxg+IYE
AmmeJu2cNtTQHgERr3Cmu7hsQ0rbcBKlOaVUT5DxgEe3NfW+NkgK+MzR6FSm5Z7p
ZPElEZ9u6uKUr3c8dKqZcTSuIeTPp0W5/R3eYPfli9xZTHPmu3P+g08G/PrGlr4J
b5jaBnDaiBlOKIn5BmH0a4eE3xbWoiHun/Vq5mFNgd8OkdyE3mimIfI7XR9mVdmG
Qkyy3ltPT947LIk8vdKSR1sjoLNZqyoS8WKbI74F9mCr2Q1XdTsv/gnCn48JM8UK
Sh3IqMXhB4IQaxcud/LpsA==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUJ9BQu0hThr2QxMBl5tg42cdIDbAwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkwOTM5MjRaFw0zNDAx
MjYwOTM5NTNaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDTIW9OYW8uOwPPGVG4scRNRRI486uu1PVQLOmmKnI8
o3fgATnxT8Y7QvlVV5Sus0BR9iu+t5ovVpP8vcqyEcdKa6lFQ5nybjEYIuWwxPrD
+H3VBhPXyXmGY/8hU9WS4HNOdHEPx1Cph5Ej2ckPs5f78PQ63mnQABHoPk85zZcx
YsudYlap5M4Zp+e6XTI1piSVwkMJZennNIYRzbW4OB5cI8hVnLgF2h6+BxP1DfAs
VTJddgGhWsLU5FYHneQINeU+0ExtEUQxkLM8EDbm0nV+jPH8Yk6i8i+o3+BcpIEd
ppyN79w9inWwDTjsqR4uVbA99GGhCOrzyDdEjczmkn9PAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRLGylACpQQz0y5
9zUt+ReXsEVdfDAfBgNVHSMEGDAWgBRLGylACpQQz0y59zUt+ReXsEVdfDAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQBzmYfh3DkBt9mJ
PyK1p2A8BaTPGc4e/mPDjEH2tUPpxWmr+KVtA6aJrvQyVU12v6AuTRqne7FNy9+l
v1YASz+SxqWItP6LHe0J8jN2coOhEk1pxHtwpn4/Xpx4NqPe297jIIEModD30ZHm
GW/JbLh1w+fRcKNmr4JBDBAl8YOjeLai//UsvNVN9AU45n0DiZpJkeqxThCaNKwR
P8nBHsG11aaSAaZ91vGj+VMAu28ubEjzlKNIhOOxxwTbesGq4Z7JRQaOHIGbZi3n
drPU7+PwC/UpON9Q/xKCcKNK7Yi9Tk7m3D+TcQRAAa4VwCrP0Pktpe79bR2pDODN
dT3CG5aC
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUaD9IHvcec+WH1uoi+Bt6HyY3TnYwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTI0MDEyOTEwMTI0OVoXDTI0MDEzMDEwMTMxOFowHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCm
zb8wuW2FT+kpkepMLoK4RclsdF36Fzm5j7k63O6GPaST8oEUyuIodRoaZJ5anBWD
ANdrcFSJghE2SIJ4BKMuyK9EJ2p+xk4WGxGq7GfLU32VDc82KBz5lZKbKmnk+L9p
S5ePPw9MSJO2PEzONOJVvunuSKP++Sdvk1hO/rS1I9WPjXuhkowOAUDTkQ1n7Olz
PreAXFRI5s+sL8zz7cVgGOeywmMzKLRasQG+mQLQTLtdKlmnOlQYXzshnd49DFCD
7O5lox7lWq9pF1Ckf7SDtPe/CcCfDacmM8SFIJgy5bfKWMo6mZzX5PqJIq5sX2zl
WYnfUhsRo+XKRfCRbH0jAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQU2gQaNnJFYjdJoeQZ
vAmPN6r+zNYwHwYDVR0jBBgwFoAUggme99AQ8VArZO+X4vuBN7K2Bt4wHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAK8a/vxh
xuaF4yzk6jl26zUo8EnC2VK1wxdO7EavViOa9207pnpRnIVCpkbiHVbvn7fFiRNH
emLw326rKvZAJY3bxV9xzWGaxcS9SDbqCNStphIkhzcwN0hc7tAmVd5zV38s+04t
e7LCcVsryD15iMMoIm9IOszBnXkSSuKIOPwyfHEXHuxaTa/cUzrjU47PwcjFpVDe
U17q4JhMczT+QKCeo5qK+/+26kFywWz1TTpD5e1FpVLbb3PUbAjNsjit6LyKRYZT
iWtOosulaEak1OEw716ivOCK/3UXUNCBpKQ2zcOZICduRU8402lTc9Zq0tqX0OY4
FtihEL2tAnaHlO0=
-----END CERTIFICATE-----
expiration          1706609598
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUaFlhIsx+kbOyml6b/+39hBhglZcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjkxMDAxMjhaFw0yOTAx
MjcxMDAxNThaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMS0V3WQvgI6
kxn2CSOjjFUpmVcX8i79Gymu55X07s6DUhLhoAtrTRsomq3QzSYua++Qi0i8cmzv
/o1/eXGAK4xTTcZ0LyiktzMIkxFrn3h/xTRPOD9tvgrLi8cF84K2toHibj6jXaxs
B3kjuzRBzlZEPVRwx7Dv1wP80lQeKiDo/uSSCTqgZdvNOtDlpep4dYcemJeyd4VO
mmMBNR8vIzxAz6KJiWxJRQn4ZK7Y3FRLFwD7tA3lxvHK0GfuqTkfLnTyZO5IvdnA
m+MAewvop/OWc+apck0c7MX2fvL8PhPWg+i1hFJ3Yf7SdYHgaXGEYAMxZKOdf1I6
Lvp9IIlT3h0CAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUggme99AQ8VArZO+X4vuBN7K2Bt4wHwYDVR0jBBgwFoAU
SxspQAqUEM9Mufc1LfkXl7BFXXwwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
Tfimy8mPOTuVkeT7Tg7wbAeVW6TukW3hOcJS42NgXZ5sQ/2h0nxbw5M8FTxg+IYE
AmmeJu2cNtTQHgERr3Cmu7hsQ0rbcBKlOaVUT5DxgEe3NfW+NkgK+MzR6FSm5Z7p
ZPElEZ9u6uKUr3c8dKqZcTSuIeTPp0W5/R3eYPfli9xZTHPmu3P+g08G/PrGlr4J
b5jaBnDaiBlOKIn5BmH0a4eE3xbWoiHun/Vq5mFNgd8OkdyE3mimIfI7XR9mVdmG
Qkyy3ltPT947LIk8vdKSR1sjoLNZqyoS8WKbI74F9mCr2Q1XdTsv/gnCn48JM8UK
Sh3IqMXhB4IQaxcud/LpsA==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAps2/MLlthU/pKZHqTC6CuEXJbHRd+hc5uY+5Otzuhj2kk/KB
FMriKHUaGmSeWpwVgwDXa3BUiYIRNkiCeASjLsivRCdqfsZOFhsRquxny1N9lQ3P
Nigc+ZWSmypp5Pi/aUuXjz8PTEiTtjxMzjTiVb7p7kij/vknb5NYTv60tSPVj417
oZKMDgFA05ENZ+zpcz63gFxUSObPrC/M8+3FYBjnssJjMyi0WrEBvpkC0Ey7XSpZ
pzpUGF87IZ3ePQxQg+zuZaMe5VqvaRdQpH+0g7T3vwnAnw2nJjPEhSCYMuW3yljK
Opmc1+T6iSKubF9s5VmJ31IbEaPlykXwkWx9IwIDAQABAoIBAGDfSrMUbYunviTb
TjQSKu6z8OfgqRduV6Lx2kRaPNiPgj4970NRFIkkgRVk7CZ5UXD0kycdZKs7c52P
/N2Q6+hmuosdTRb1OjJSZC9c/mayRVPEYlv0bedxO2SL/FXzNM8FDK8vk0XdPJPw
bzautefQaXFulHem4YVGEFpISFCN4BeI9WrYeblrfWaieYXwd9aXHWNUvxiSLIFq
021I8baBnadv5QySgQNqT2A6JHRpN2DAndhQiypuMXnbhobUbk/Rz+Iucg+k2P+m
1g3HF80MElCoj+8+lmgcF45BgeC8fufXLHs420aEC6Eqcop87iHFJi/+1dL1vOVz
tmMzt3ECgYEA0LChZAGSy91QM4YeMMCg+M/pRmypzawvnC44QxWhQBRK9JW3zoFU
VwbkA+AesL6UlbIuvYJxel+LIpvoThA28PIyNbbhmPGhHcczO4OI7y/53oEGCfTi
EWYrneg3eBxjHI1J1DRllczqknEIP/TDskAfSQJYaN45INgGYMDhGHsCgYEAzJ48
zh4Lu5Orr4+RCK3tt2D5k9j8HNRbvyCkDlEfmqsfsLGCI8ZQOIJv3UA3m2m7WaPo
NviSWJoupi+YfZolPMfMmerx8vsLHit0AG9xRLQ3ggCQ8WsEEmEJW2c/9SranMUQ
tSfUyIq+cx3hYhd7tX0SOGFzj064lXqzwxMLUXkCgYEAhFfPMZWR23kROGuQT8iJ
DOEFBaU5lfXhB4GEKn7YEMQNuMgNlYcMzlfPV+nUbK+fmMMzwvirMDjRCnSmwIKl
5O0jDE9bB9wMGc9O3SoQN+dL5WAbTUsf5nrNpEk0jBYsgFnVfR5xYatfAtltqul1
BWCGto0nNfHfdsWoXclTtmsCgYEAriFLZa00FuFIjhMDPful/RTN0AAsLOybVz+T
3Ysz9hAC2/9z3LX7tttqD0ODDwMfqN1P1Ngc0sIDSPHgN6NiZSMy/xlt5XW2tGoO
QgCUx/8F7eBFeO21fV6O8/Yd+6oIeLlLyp6m+jL4eEbJcwzA/mX9h3WHPkGj27Gc
ITqnuyECgYBRyQATIksGYNHLbUx0KAHyqmGBy3TEgE4SoNii6+/k+xCZyU60g4oh
fSzHcqlHRWclJMSD0gxOf4Hw2uVPdycY3KnC+2ur15N4YKbis7Opuk0J/vupW7Jc
4RuBMc6nyCLSuZTZy9oz/7NFYzmWlKPN3xeXP6x0OWisWQVCxZrL8Q==
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       68:3f:48:1e:f7:1e:73:e5:87:d6:ea:22:f8:1b:7a:1f:26:37:4e:76
$ kubectl exec -it vault-0 -- vault write pki_int/revoke \
serial_number="68:3f:48:1e:f7:1e:73:e5:87:d6:ea:22:f8:1b:7a:1f:26:37:4e:76"
Key                        Value
---                        -----
revocation_time            1706523298
revocation_time_rfc3339    2024-01-29T10:14:58.266594102Z
state                      revoked
```

* выдачу при создании сертификата добавить в README.md

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-vault
git branch
mkdir kubernetes-vault
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-vault/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-vault"
git push --set-upstream origin kubernetes-vault
git status
# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.
# Если здесь нужно переключить обратно на ветку main, то:
git branch
# git switch main # не во всех версиях git работает
git checkout main
git branch
git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-vault

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - kubectl apply -f имя-файла.yaml по порядку из README.md

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get, kubectl logs и kubectl describe

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-vault отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/15 



Спасибо!
С уважением, Корнев Дмитрий