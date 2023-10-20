# Подготовка

## Установка утилиты yc и инициализация:

Подробности по managed k8s в yandex Cloud [здесь](https://cloud.yandex.ru/docs/managed-kubernetes/quickstart). 

```
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

echo $PATH

. .bashrc

echo $PATH

yc init

yc config list
```

```
token: ...
cloud-id: ...
folder-id: ...
compute-default-zone: ru-central1-a
```

```
yc managed-kubernetes clusters list
```

```
+----------------------+-------+---------------------+---------+---------+------------------------+---------------------+
|          ID          | NAME  |     CREATED AT      | HEALTH  | STATUS  |   EXTERNAL ENDPOINT    |  INTERNAL ENDPOINT  |
+----------------------+-------+---------------------+---------+---------+------------------------+---------------------+
| catinh7jgmk8k65p3oep | myk8s | 2023-10-05 11:01:44 | HEALTHY | RUNNING | https://158.160.61.103 | https://10.128.0.11 |
+----------------------+-------+---------------------+---------+---------+------------------------+---------------------+
```

```
yc managed-kubernetes --name myk8s cluster list-nodes
```

```
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
|         CLOUD INSTANCE         |      KUBERNETES NODE      |           RESOURCES            |    DISK     | STATUS |
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
| fhm6258gl78p7lt1msll           | cl1rovp36dlnd96eba7n-elax | 4 20% core(s), 8.0 GB of       | 64.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
| fhm3hne4meg224d63mbi           | cl1rovp36dlnd96eba7n-utyp | 4 20% core(s), 8.0 GB of       | 64.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
| fhmhn67fm7r3eeksq1r4           | cl1rovp36dlnd96eba7n-yter | 4 20% core(s), 8.0 GB of       | 64.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
```

## Реквизиты для кластера kubernetes:

```
yc managed-kubernetes cluster get-credentials myk8s --external
```

```
Context 'yc-myk8s' was added as default to kubeconfig '/home/dimka/.kube/config'.
Check connection to cluster using 'kubectl cluster-info --kubeconfig /home/dimka/.kube/config'.

Note, that authentication depends on 'yc' and its config profile 'default'.
To access clusters using the Kubernetes API, please use Kubernetes Service Account.
```

```
kubectl config view

cat ~/.kube/config

kubectl cluster-info --kubeconfig /home/dimka/.kube/config

kubectl cluster-info
```

```
Kubernetes control plane is running at https://158.160.61.103
CoreDNS is running at https://158.160.61.103/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Посмотреть:

```
kubectl get all -A -o wide

kubectl get pods -A -o wide

kubectl get nodes -o wide
```

## Helm (версии 3)

Helm у меня уже был ранее усатновлен перед началом курса: 

```
helm version
```

```
version.BuildInfo{Version:"v3.12.2", GitCommit:"1e210a2c8cc5117d1055bfaa5d40f51bbc2e345e", GitTreeState:"clean", GoVersion:"go1.20.5"}
```

# Устанавливаем готовые Helm charts

Сегодня будем работать со следующими сервисами: 
- [nginx-ingress](https://github.com/helm/charts/tree/master/stable/nginx-ingress) - сервис, обеспечивающий доступ к публичным ресурсам кластера 
- [cert-manager](https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager) - сервис, позволяющий динамически генерировать Let's Encrypt сертификаты для ingress ресурсов 
- [chartmuseum](https://github.com/helm/charts/tree/master/stable/chartmuseum) - специализированный репозиторий для хранения helm charts 
- [harbor](https://github.com/goharbor/harbor-helm) - хранилище артефактов общего назначения (Docker Registry), поддерживающее helm charts 

## Памятка по использованию Helm

Создание release: 

```
helm install <chart_name> --name=<release_name> --namespace=<namespace>

kubectl get secrets -n <namespace> | grep <release_name>
```

Обновление release: 

```
helm upgrade <release_name> <chart_name> --namespace=<namespace>

kubectl get secrets -n <namespace> | grep <release_name>
```

Создание или обновление release: 

```
helm upgrade --install <release_name> <chart_name> --namespace=<namespace>

kubectl get secrets -n <namespace> | grep <release_name>
```

## Add helm repo

Добавьте репозиторий stable 

По умолчанию в Helm 3 не установлен репозиторий stable 

```
helm repo list

helm repo add stable https://kubernetes-charts.storage.googleapis.com
```

```
Error: repo "https://kubernetes-charts.storage.googleapis.com" is no longer available; try "https://charts.helm.sh/stable" instead
```

```
helm repo add stable https://charts.helm.sh/stable

helm repo list
```

## nginx-ingress

Создадим namespace и release nginx-ingress. 

(При установке из указанного репозитория у меня были ошибки и было написано, что chart is deprecated, поэтому сделал несколько иначе) 

```
kubectl create ns nginx-ingress
```

```
helm search repo nginx-ingress
```

```
NAME                       	CHART VERSION	APP VERSION	DESCRIPTION                                       
ingress-nginx/ingress-nginx	4.8.1        	1.9.1      	Ingress controller for Kubernetes using NGINX a...
...
```

Далее добавление репозитория и установку взял [отсюда](https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager). 

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

```
"ingress-nginx" has been added to your repositories
```

```
helm repo update
```

```
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
```

```
helm repo list
```

```
NAME         	URL                                       
stable       	https://charts.helm.sh/stable             
ingress-nginx	https://kubernetes.github.io/ingress-nginx
```

```
helm search repo ingress-nginx
```

```
NAME                       	CHART VERSION	APP VERSION	DESCRIPTION                                       
ingress-nginx/ingress-nginx	4.8.2        	1.9.3      	Ingress controller for Kubernetes using NGINX a...
```

```
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
--namespace nginx-ingress --atomic --wait --version=4.8.2
```

Изначально ставил версию 4.8.1, но на некоторое время приостановил активность по домашней работе и теперь уже вышла версия 4.8.2. 
Ниже представлен вывод обновления до 4.8.2: 

```
Release "nginx-ingress" has been upgraded. Happy Helming!
NAME: nginx-ingress
LAST DEPLOYED: Sun Oct 15 16:47:47 2023
NAMESPACE: nginx-ingress
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
It may take a few minutes for the LoadBalancer IP to be available.
You can watch the status by running 'kubectl --namespace nginx-ingress get services -o wide -w nginx-ingress-ingress-nginx-controller'

An example Ingress that makes use of the controller:
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: nginx
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls
```

Разберем используемые ключи: 
- --wait - ожидать успешного окончания установки ([подробности](https://helm.sh/docs/intro/)) 
- if set, upgrade process rolls back changes made in case of failed upgrade (the --wait flag will be set automatically if --atomic is used) 
- --timeout - считать установку неуспешной по истечении указанного времени 
- --namespace - установить chart в определенный namespace (если не существует, необходимо создать) 
- --version - установить определенную версию chart 

```
kubectl get -n nginx-ingress all 
```

```
NAME                                                          READY   STATUS    RESTARTS   AGE
pod/nginx-ingress-ingress-nginx-controller-7957dc8ddb-7wdwr   1/1     Running   0          5m15s

NAME                                                       TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
service/nginx-ingress-ingress-nginx-controller             LoadBalancer   10.55.163.202   158.160.65.62   80:32366/TCP,443:32405/TCP   9d
service/nginx-ingress-ingress-nginx-controller-admission   ClusterIP      10.55.212.218   <none>          443/TCP                      9d

NAME                                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-ingress-ingress-nginx-controller   1/1     1            1           9d

NAME                                                                DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-ingress-ingress-nginx-controller-5bbf7d8fdd   0         0         0       9d
replicaset.apps/nginx-ingress-ingress-nginx-controller-7957dc8ddb   1         1         1       5m15s
```

```
kubectl get -n nginx-ingress secrets | grep nginx-ingress
```

```
nginx-ingress-ingress-nginx-admission   Opaque               3      9d
sh.helm.release.v1.nginx-ingress.v1     helm.sh/release.v1   1      9d
sh.helm.release.v1.nginx-ingress.v2     helm.sh/release.v1   1      5m54s
```

Или вот так еще можно посмотреть с помощью утилиты-плагина ketall: 

```
ketall -n nginx-ingress
```

```
NAME                                                                                   NAMESPACE      AGE
configmap/kube-root-ca.crt                                                             nginx-ingress  9d     
configmap/nginx-ingress-ingress-nginx-controller                                       nginx-ingress  9d     
endpoints/nginx-ingress-ingress-nginx-controller                                       nginx-ingress  9d     
endpoints/nginx-ingress-ingress-nginx-controller-admission                             nginx-ingress  9d     
pod/nginx-ingress-ingress-nginx-controller-7957dc8ddb-7wdwr                            nginx-ingress  7m43s  
secret/nginx-ingress-ingress-nginx-admission                                           nginx-ingress  9d     
secret/sh.helm.release.v1.nginx-ingress.v1                                             nginx-ingress  9d     
secret/sh.helm.release.v1.nginx-ingress.v2                                             nginx-ingress  7m54s  
serviceaccount/default                                                                 nginx-ingress  9d     
serviceaccount/nginx-ingress-ingress-nginx                                             nginx-ingress  9d     
service/nginx-ingress-ingress-nginx-controller                                         nginx-ingress  9d     
service/nginx-ingress-ingress-nginx-controller-admission                               nginx-ingress  9d     
deployment.apps/nginx-ingress-ingress-nginx-controller                                 nginx-ingress  9d     
replicaset.apps/nginx-ingress-ingress-nginx-controller-5bbf7d8fdd                      nginx-ingress  9d     
replicaset.apps/nginx-ingress-ingress-nginx-controller-7957dc8ddb                      nginx-ingress  7m43s  
lease.coordination.k8s.io/nginx-ingress-ingress-nginx-leader                           nginx-ingress  9d     
endpointslice.discovery.k8s.io/nginx-ingress-ingress-nginx-controller-4lmj9            nginx-ingress  9d     
endpointslice.discovery.k8s.io/nginx-ingress-ingress-nginx-controller-admission-fs8pn  nginx-ingress  9d     
rolebinding.rbac.authorization.k8s.io/nginx-ingress-ingress-nginx                      nginx-ingress  9d     
role.rbac.authorization.k8s.io/nginx-ingress-ingress-nginx                             nginx-ingress  9d 
```

Пингуется ли external IP для LoadBalancer: 

```
$ ping -c1 158.160.65.62
```

```
PING 158.160.65.62 (158.160.65.62) 56(84) bytes of data.
64 bytes from 158.160.65.62: icmp_seq=1 ttl=51 time=14.0 ms
--- 158.160.65.62 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 13.969/13.969/13.969/0.000 ms
```

```
curl 158.160.65.62
```

```html
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
``` 

Видим, что есть ответ. 

```
helm list -n nginx-ingress
```

```
NAME         	NAMESPACE    	REVISION	UPDATED                                	STATUS  	CHART              	APP VERSION
nginx-ingress	nginx-ingress	2       	2023-10-15 16:47:47.014224581 +0300 MSK	deployed	ingress-nginx-4.8.2	1.9.3   
```

## cert-manager

Добавим репозиторий, в котором хранится актуальный helm chart cert-manager: 

```
helm repo add jetstack https://charts.jetstack.io
```

```
helm repo list
```

```
NAME         	URL                                       
stable       	https://charts.helm.sh/stable             
ingress-nginx	https://kubernetes.github.io/ingress-nginx
jetstack     	https://charts.jetstack.io                
```

```
helm repo update
```

Также для установки cert-manager предварительно потребуется создать в кластере некоторые CRD ([ссылка](https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager) на документацию по установке): 

```
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml
```

Установим cert-manager: 

```
helm search repo cert-manager
```

```
NAME                                   	CHART VERSION	APP VERSION	DESCRIPTION                                       
jetstack/cert-manager                  	v1.13.1      	v1.13.1    	A Helm chart for cert-manager                    
```

```
helm upgrade --install cert-manager jetstack/cert-manager --atomic \
--namespace=cert-manager --create-namespace --version=1.13.1
```

```
Release "cert-manager" does not exist. Installing it now.
NAME: cert-manager
LAST DEPLOYED: Thu Oct  5 18:12:51 2023
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
cert-manager v1.13.1 has been deployed successfully!

In order to begin issuing certificates, you will need to set up a ClusterIssuer
or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

More information on the different types of issuers and how to configure them
can be found in our documentation:

https://cert-manager.io/docs/configuration/

For information on how to configure cert-manager to automatically provision
Certificates for Ingress resources, take a look at the `ingress-shim`
documentation:

https://cert-manager.io/docs/usage/ingress/
```

Выше результат первого прогона. 

```
helm list -n cert-manager
```

```
NAME        	NAMESPACE   	REVISION	UPDATED                                	STATUS  	CHART               	APP VERSION
cert-manager	cert-manager	2       	2023-10-15 17:03:21.076802707 +0300 MSK	deployed	cert-manager-v1.13.1	v1.13.1    
```

```
kubectl get -n cert-manager secrets
```

```
NAME                                 TYPE                 DATA   AGE
cert-manager-webhook-ca              Opaque               3      9d
myencrypt                            Opaque               1      9d
sh.helm.release.v1.cert-manager.v1   helm.sh/release.v1   1      9d
sh.helm.release.v1.cert-manager.v2   helm.sh/release.v1   1      99s
```

```
kubectl get -n cert-manager all
```

```
NAME                                           READY   STATUS    RESTARTS      AGE
pod/cert-manager-c77d84665-m7ttq               1/1     Running   3 (14h ago)   7d16h
pod/cert-manager-cainjector-65f66458c9-z4l8q   1/1     Running   4 (43m ago)   7d16h
pod/cert-manager-webhook-6f87c88dc5-sr8xj      1/1     Running   3 (14h ago)   7d16h

NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/cert-manager           ClusterIP   10.55.239.93    <none>        9402/TCP   9d
service/cert-manager-webhook   ClusterIP   10.55.185.159   <none>        443/TCP    9d

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1/1     1            1           9d
deployment.apps/cert-manager-cainjector   1/1     1            1           9d
deployment.apps/cert-manager-webhook      1/1     1            1           9d

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-c77d84665               1         1         1       9d
replicaset.apps/cert-manager-cainjector-65f66458c9   1         1         1       9d
replicaset.apps/cert-manager-webhook-6f87c88dc5      1         1         1       9d
```

## cert-manager | Самостоятельное задание

Изучите [документацию cert-manager](https://cert-manager.io/docs/) и определите, что еще требуется установить для корректной работы 
- Поместите манифесты дополнительно созданных ресурсов в директорию kubernetes-templating/cert-manager/ 
- Проверить корректную работу cert-manager можно будет на последующих helm chart 

Пример я взял всё [оттуда же](https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager). 

Чтобы протестировать работу менеджера сертификатов, необходимо создать объекты ClusterIssuer, Ingress, Service и Deployment. 

Создаем YAML-файл cluster-issuer.yaml с манифестом объекта ClusterIssuer: 

```
mkdir -p cert-manager/ && cd cert-manager/

nano cluster-issuer.yaml 
```

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: myencrypt-staging
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: kodmandvl@mail.ru
    privateKeySecretRef:
      name: myencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: myencrypt
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: kodmandvl@mail.ru
    privateKeySecretRef:
      name: myencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
```

Выше публикую окончательный вариант файла cluster-issuer.yaml. 
Однако изначально столкнулся с разными проблемами при тестах, с лимитами на количество запросов к удостоверяющему центру и т.д. 
Поэтому в итоге пришел к варианту с двумя разными issuer: для тестов (staging со ссылкой на let's encrypt staging) и основной (со ссылкой на основной let's encrypt). 

```
kubectl apply -f cluster-issuer.yaml 
```

```
clusterissuer.cert-manager.io/myencrypt-staging unchanged
clusterissuer.cert-manager.io/myencrypt configured
```

```
kubectl get -n cert-manager secrets | grep myencrypt
```

```
myencrypt                            Opaque               1      10d
myencrypt-staging                    Opaque               1      14m
```

```
kubectl get -n cert-manager clusterissuers.cert-manager.io -o wide
```

```
NAME                READY   STATUS                                                 AGE
myencrypt           True    The ACME account was registered with the ACME server   10d
myencrypt-staging   True    The ACME account was registered with the ACME server   15m
```

## chartmuseum

Кастомизируем установку chartmuseum 

- Создайте директорию kubernetes-templating/chartmuseum/ и поместите туда файл values.yaml 
- Изучите содержимое оригинального файла values.yaml 
- Включите: 
1. Создание ingress ресурса с корректным hosts.name (должен использоваться nginx-ingress) 
2. Автоматическую генерацию Let's Encrypt сертификата https://github.com/helm/charts/tree/master/stable/chartmuseum 

```
mkdir -p chartmuseum/ && cd chartmuseum/ 

nano values.yaml
```

```
kubectl get -n nginx-ingress all | grep -i loadbalancer
```

```
service/nginx-ingress-ingress-nginx-controller             LoadBalancer   10.55.163.202   158.160.65.62   80:32366/TCP,443:32405/TCP   93m
```

Файл values.yaml для chartmuseum будет выглядеть примерно следующим образом: 

```yaml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: "myencrypt-staging"
    cert-manager.io/acme-challenge-type: http01
  hosts:
    - name: chartmuseum.158.160.65.62.nip.io
      path: /
      tls: true
      tlsSecret: chartmuseum.158.160.65.62.nip.io
```

*Установим chartmuseum:* 

```
cd ../../

kubectl create ns chartmuseum

helm upgrade --install chartmuseum stable/chartmuseum --wait \
--namespace=chartmuseum \
--version=2.14.2 \
-f kubernetes-templating/chartmuseum/values.yaml
```

На этом шаге видим такие ошибки: 

```
Release "chartmuseum" does not exist. Installing it now.
WARNING: This chart is deprecated
Error: unable to build kubernetes objects from release manifest: resource mapping not found for name: "chartmuseum-chartmuseum" namespace: "" from "": no matches for kind "Ingress" in version "networking.k8s.io/v1beta1"
ensure CRDs are installed first
```

Как и ранее для ingress-nginx, добавим [актуальный репозиторий chartmuseum](https://github.com/chartmuseum/charts): 

```
helm repo add chartmuseum https://chartmuseum.github.io/charts
```

```
helm search repo chartmuseum
```

```
NAME                   	CHART VERSION	APP VERSION	DESCRIPTION                                   
chartmuseum/chartmuseum	3.10.1       	0.16.0     	Host your own Helm Chart Repository           
stable/chartmuseum     	2.14.2       	0.12.0     	DEPRECATED Host your own Helm Chart Repository
```

Попробуем еще раз установить: 

```
helm upgrade --install chartmuseum chartmuseum/chartmuseum --atomic \
--namespace=chartmuseum --create-namespace \
--version=3.10.1 -f kubernetes-templating/chartmuseum/values.yaml
```

```
Release "chartmuseum" does not exist. Installing it now.
NAME: chartmuseum
LAST DEPLOYED: Mon Oct 16 00:48:51 2023
NAMESPACE: chartmuseum
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

Get the ChartMuseum URL by running:

  export POD_NAME=$(kubectl get pods --namespace chartmuseum -l "app=chartmuseum" -l "release=chartmuseum" -o jsonpath="{.items[0].metadata.name}")
  echo http://127.0.0.1:8080/
  kubectl port-forward $POD_NAME 8080:8080 --namespace chartmuseum
```

Проверим, что release chartmuseum установился: 

```
helm ls -n chartmuseum
```

```
NAME       	NAMESPACE  	REVISION	UPDATED                                	STATUS  	CHART             	APP VERSION
chartmuseum	chartmuseum	1       	2023-10-16 00:48:51.244681483 +0300 MSK	deployed	chartmuseum-3.10.1	0.16.0  
```

```
ketall -n chartmuseum
```

```
NAME                                                                     NAMESPACE    AGE
configmap/kube-root-ca.crt                                               chartmuseum  63s  
endpoints/chartmuseum                                                    chartmuseum  63s  
pod/chartmuseum-64bf5c6bb6-bzm5d                                         chartmuseum  62s  
secret/chartmuseum                                                       chartmuseum  63s  
secret/chartmuseum.158.160.65.62.nip.io                                  chartmuseum  32s  
secret/sh.helm.release.v1.chartmuseum.v1                                 chartmuseum  63s  
serviceaccount/default                                                   chartmuseum  63s  
service/chartmuseum                                                      chartmuseum  63s  
order.acme.cert-manager.io/chartmuseum.158.160.65.62.nip.io-1-412840757  chartmuseum  62s  
deployment.apps/chartmuseum                                              chartmuseum  63s  
replicaset.apps/chartmuseum-64bf5c6bb6                                   chartmuseum  62s  
certificaterequest.cert-manager.io/chartmuseum.158.160.65.62.nip.io-1    chartmuseum  62s  
certificate.cert-manager.io/chartmuseum.158.160.65.62.nip.io             chartmuseum  62s  
endpointslice.discovery.k8s.io/chartmuseum-p9gq7                         chartmuseum  63s  
ingress.networking.k8s.io/chartmuseum                                    chartmuseum  62s  
```

Helm 2 хранил информацию о релизе в configMap'ах ( kubectl get configmaps -n kube-system ). 

А Helm 3 хранит информацию в secrets ( kubectl get secrets -n chartmuseum ). 

```
kubectl get secrets -n chartmuseum
```

```
NAME                                TYPE                 DATA   AGE
chartmuseum                         Opaque               0      90s
chartmuseum.158.160.65.62.nip.io    kubernetes.io/tls    2      59s
sh.helm.release.v1.chartmuseum.v1   helm.sh/release.v1   1      90s
```

*Критерий успешности установки ChartMuseum* 

- Chartmuseum доступен по URL https://chartmuseum.<IP>.nip.io 
- Сертификат для данного URL валиден 

Проверим: 

- В браузере открывается https://chartmuseum.158.160.65.62.nip.io 

```
Welcome to ChartMuseum!

If you see this page, the ChartMuseum web server is successfully installed and working.

For online documentation and support please refer to the GitHub project.

Thank you for using ChartMuseum.
```

- Сертификат: 

А сертификат не валиден. 
Для тестов сделал staging для безлимитных проверок и prod по основной ссылке для let'sencrypt, т.к. были ошибки в тестах. 
Смотрим сертификат, у него организация "(STAGING) Let's Encrypt" и название сертификата "chartmuseum.158.160.65.62.nip.io". 
Теперь выполним действия выше, но staging issuer myencrypt-staging заменим на prod issuer myencrypt. 

```
cd kubernetes-templating/chartmuseum/

cp -aiv values.yaml values-staging.yaml 

nano values.yaml
```

```yaml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: "myencrypt"
    cert-manager.io/acme-challenge-type: http01
  hosts:
    - name: chartmuseum.158.160.65.62.nip.io
      path: /
      tls: true
      tlsSecret: chartmuseum.158.160.65.62.nip.io
```

Попробуем еще раз установить (перед этим удалим namespace chartmuseum): 

```
cd ../../

helm upgrade --install chartmuseum chartmuseum/chartmuseum --atomic \
--namespace=chartmuseum --create-namespace \
--version=3.10.1 -f kubernetes-templating/chartmuseum/values.yaml
```

```
Release "chartmuseum" does not exist. Installing it now.
NAME: chartmuseum
LAST DEPLOYED: Mon Oct 16 02:12:03 2023
NAMESPACE: chartmuseum
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

Get the ChartMuseum URL by running:

  export POD_NAME=$(kubectl get pods --namespace chartmuseum -l "app=chartmuseum" -l "release=chartmuseum" -o jsonpath="{.items[0].metadata.name}")
  echo http://127.0.0.1:8080/
  kubectl port-forward $POD_NAME 8080:8080 --namespace chartmuseum
```

Сначала снова была ошибка с лимитом выпуска сертификатов, но потом через какое-то время и после рестарта кластера K8s пропала, подтянулся корректный сертификат. 

```
helm ls -n chartmuseum
```

```
NAME       	NAMESPACE  	REVISION	UPDATED                                	STATUS  	CHART             	APP VERSION
chartmuseum	chartmuseum	1       	2023-10-16 02:12:03.440087392 +0300 MSK	deployed	chartmuseum-3.10.1	0.16.0     
```

```
ketall -n chartmuseum
```

```
NAME                                                                      NAMESPACE    AGE
configmap/kube-root-ca.crt                                                chartmuseum  14h  
endpoints/chartmuseum                                                     chartmuseum  14h  
pod/chartmuseum-64bf5c6bb6-m5xfs                                          chartmuseum  14h  
secret/chartmuseum                                                        chartmuseum  14h  
secret/chartmuseum.158.160.65.62.nip.io                                   chartmuseum  39m  
secret/sh.helm.release.v1.chartmuseum.v1                                  chartmuseum  14h  
serviceaccount/default                                                    chartmuseum  14h  
service/chartmuseum                                                       chartmuseum  14h  
order.acme.cert-manager.io/chartmuseum.158.160.65.62.nip.io-1-1704148945  chartmuseum  40m  
deployment.apps/chartmuseum                                               chartmuseum  14h  
replicaset.apps/chartmuseum-64bf5c6bb6                                    chartmuseum  14h  
certificaterequest.cert-manager.io/chartmuseum.158.160.65.62.nip.io-1     chartmuseum  40m  
certificate.cert-manager.io/chartmuseum.158.160.65.62.nip.io              chartmuseum  14h  
endpointslice.discovery.k8s.io/chartmuseum-qrlkw                          chartmuseum  14h  
ingress.networking.k8s.io/chartmuseum                                     chartmuseum  14h  
```

``` 
kubectl get secrets -n chartmuseum
```

```
NAME                                TYPE                 DATA   AGE
chartmuseum                         Opaque               0      14h
chartmuseum.158.160.65.62.nip.io    kubernetes.io/tls    2      40m
sh.helm.release.v1.chartmuseum.v1   helm.sh/release.v1   1      14h
```

Теперь страница в браузере открывается и сертификат валиден: 

```
curl https://chartmuseum.158.160.65.62.nip.io/
```

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to ChartMuseum!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to ChartMuseum!</h1>
<p>If you see this page, the ChartMuseum web server is successfully installed and
working.</p>

<p>For online documentation and support please refer to the
<a href="https://github.com/helm/chartmuseum">GitHub project</a>.<br/>

<p><em>Thank you for using ChartMuseum.</em></p>
</body>
</html>
```

В браузере:

*Вы подключились к этому сайту по защищённому соединению.*

*Подтверждено: Let's Encrypt*

Имя сертификата: chartmuseum.158.160.65.62.nip.io 

Организация: Let's Encrypt 

## harbor | Самостоятельное задание 

*Установите harbor в кластер с использованием helm3:* 

- Используйте репозиторий https://github.com/goharbor/harbor-helm и CHART VERSION 1.1.2 
- Требования:
1. Должен быть включен ingress и настроен host harbor.<IP- адрес>.nip.io
2. Должен быть включен TLS и выписан валидный сертификат
- Скопируйте используемый файл values.yaml в директорию kubernetes-templating/harbor/ 

*Tips & Tricks* 

Формат описания переменных в файле values.yaml для chartmuseum и harbor отличается: 

- Helm3 не создает namespace в который будет установлен release 
- Проще выключить сервис notary , он нам не понадобится 
- Реквизиты по умолчанию - admin/Harbor12345 ( сменил на admin/Tvnq6b_4.h82YBDk )
- nip.io можето казаться забанен в cert-manager. Если у вас есть собственный домен, лучше использовать его, либо попробовать xip.io, либо переключиться на staging ClusterIssuer. 

Обратите внимание, как helm3 хранит информацию о release: 

```
kubectl get secrets -n harbor -l owner=helm
```

Критерий успешности установки: 

- Harbor запущен и работает 
- Предъявленные требования выполняются 

Add Helm repository: 

```
helm repo add harbor https://helm.goharbor.io
helm repo list
helm repo update
```

Для основы файла values.yaml возьмем values.yaml для Harbor с гитхаба, но также будем ориентироваться и на образец для ChartMuseum (сразу возьмем issuer staging): 

```
mkdir -p harbor && cd harbor
wget https://raw.githubusercontent.com/goharbor/harbor-helm/main/values.yaml
nano values.yaml
```

(целиком файл values.yaml представлен в harbor/values.yaml) 

```
helm search repo harbor
```

```
NAME         	CHART VERSION	APP VERSION	DESCRIPTION                                       
harbor/harbor	1.13.0       	2.9.0      	An open source trusted cloud native registry th...
```

```
helm upgrade --install harbor harbor/harbor --atomic \
--namespace=harbor --create-namespace \
--version=1.13.0 \
-f values.yaml
```

```
Release "harbor" does not exist. Installing it now.
NAME: harbor
LAST DEPLOYED: Mon Oct 16 20:04:48 2023
NAMESPACE: harbor
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Please wait for several minutes for Harbor deployment to complete.
Then you should be able to visit the Harbor portal at https://harbor.158.160.65.62.nip.io
For more details, please visit https://github.com/goharbor/harbor
```

```
kubectl get secrets -n harbor -l owner=helm
```

```
NAME                           TYPE                 DATA   AGE
sh.helm.release.v1.harbor.v1   helm.sh/release.v1   1      2m40s
```

Успешно по ссылке  https://harbor.158.160.65.62.nip.io открывается Harbor (используется staging сертификат), авторизуюсь с логином и паролем по умолчанию (см. выше). 

# Создаем свой helm chart

```
cd ~ && git clone git@github.com:GoogleCloudPlatform/microservices-demo.git
```

Стандартными средствами helm инициализируйте структуру директории с содержимым будущего helm chart: 

```
helm create kubernetes-templating/hipster-shop
```

```
Creating kubernetes-templating/hipster-shop
```

Изучите созданный в качестве примера файл values.yaml и шаблоны в директории templates, примерно так выглядит стандартный helm chart. 
Мы будем создавать chart для приложения с нуля, поэтому удалите values.yaml и содержимое templates. 
После этого перенесите [файл all-hipster-shop.yaml](https://github.com/express42/otus-platform-snippets/blob/master/Module-04/05-Templating/manifests/all-hipster-shop.yaml) в директорию templates. 

```
cd kubernetes-templating/hipster-shop
rm -v values.yaml
rm -rfv templates/*
cd templates
wget https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-04/05-Templating/manifests/all-hipster-shop.yaml
```

В целом, helm chart уже готов, вы можете попробовать установить его: 

```
kubectl create ns hipster-shop
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
```

```
Release "hipster-shop" does not exist. Installing it now.
NAME: hipster-shop
LAST DEPLOYED: Thu Oct 19 14:01:27 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

При первой установке в ивентах обнаружил, что невозможно получить образ той версиии, которая указана в файле all-hipster-shop.yaml. 
Поменял в all-hipster-shop.yaml на версию, указанную в гитхаб для microservices-demo (v0.8.0), после чего образы при установке стали выкачиваться (в выоде выше результат повторной установки после правки версии в файле и пересоздания неймспейса). 

```
helm ls -n hipster-shop
```

```
NAME        	NAMESPACE   	REVISION	UPDATED                               	STATUS  	CHART             	APP VERSION
hipster-shop	hipster-shop	1       	2023-10-19 14:01:27.97296628 +0300 MSK	deployed	hipster-shop-0.1.0	1.16.0     
```

После этого можно зайти в UI используя сервис типа NodePort (создается из манифестов) и проверить, что приложение заработало. 

```
kubectl get svc -n hipster-shop | grep -e ^NAME -e frontend
```

```NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend                NodePort    10.55.192.146   <none>        80:32063/TCP   3m47s
```

```
kubectl -n hipster-shop port-forward service/frontend 7000:80
```

```
Forwarding from 127.0.0.1:7000 -> 8080
Forwarding from [::1]:7000 -> 8080
```

В браузере открывается страница OnlineBoutique по localhost:7000 
Но там же видим, что "Uh, oh! Something has failed." 

Сейчас наш helm chart hipster-shop совсем не похож на настоящий. 
При этом все микросервисы станавливаются из одного файла all-hipster-shop.yaml. 
Давайте исправим это и первым делом займемся микросервисом frontend. 
Скорее всего он разрабатывается отдельной командой, а исходный код хранится в отдельном репозитории. 
Поэтому, было бы логично вынести все что связано с frontend в отдельный helm chart. 
Создадим заготовку: 

```
helm create kubernetes-templating/frontend
```

Аналогично чарту hipster-shop, удалите файл values.yaml и файлы в директории templates, создаваемые по умолчанию. 
Выделим из файла all-hipster-shop.yaml манифесты для установки микросервиса frontend. 
В директории templates чарта frontend создайте файлы: 
- deployment.yaml - должен содержать соответствующую часть из файла all-hipster-shop.yaml 
- service.yaml - должен содержать соответствующую часть из файла all-hipster-shop.yaml 
- ingress.yaml - должен разворачивать ingress с доменным именем shop.<IP-адрес>.nip.io 

Манифест для ingress необходимо написать самостоятельно (за основу взял web-ingress.yaml в своем ДЗ kubernetes-networks). 

После того, как вынесете описание deployment и service для frontend из файла all-hipster-shop.yaml, 
переустановите chart hipster-shop и проверьте, что доступ к UI пропал и таких ресурсов больше нет. 

```
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
```

```
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Thu Oct 19 14:21:09 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

```
kubectl get po -n hipster-shop
kubectl get svc -n hipster-shop
```

(frontend больше нет) 

```
helm ls -n hipster-shop
```

```
NAME        	NAMESPACE   	REVISION	UPDATED                                	STATUS  	CHART             	APP VERSION
hipster-shop	hipster-shop	2       	2023-10-19 14:21:09.506152553 +0300 MSK	deployed	hipster-shop-0.1.0	1.16.0     
```

Установите chart frontend в namespace hipster-shop и проверьте, что доступ к UI вновь появился: 

```
helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop
```

```
Release "frontend" does not exist. Installing it now.
NAME: frontend
LAST DEPLOYED: Thu Oct 19 14:25:26 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

```
$ kubectl get po -n hipster-shop | grep -e ^NAME -e frontend
NAME                                     READY   STATUS                   RESTARTS        AGE
frontend-748c98cd89-4dhjs                1/1     Running                  0               87s
$ kubectl get svc -n hipster-shop | grep -e ^NAME -e frontend
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend                NodePort    10.55.200.132   <none>        80:30503/TCP   90s
$ kubectl -n hipster-shop port-forward service/frontend 7000:80
Forwarding from 127.0.0.1:7000 -> 8080
Forwarding from [::1]:7000 -> 8080
Handling connection for 7000
Handling connection for 7000
```

Аналогично проверил доступ в браузере. 
Также у нас должен был создаться ingress для frontend: 

```
ketall -n hipster-shop | grep frontend
```

```
endpoints/frontend                                          hipster-shop  4m44s  
pod/frontend-748c98cd89-4dhjs                               hipster-shop  4m44s  
secret/sh.helm.release.v1.frontend.v1                       hipster-shop  4m44s  
service/frontend                                            hipster-shop  4m44s  
deployment.apps/frontend                                    hipster-shop  4m44s  
replicaset.apps/frontend-748c98cd89                         hipster-shop  4m44s  
endpointslice.discovery.k8s.io/frontend-bzbtb               hipster-shop  4m44s  
ingress.networking.k8s.io/frontend                          hipster-shop  4m44s  
```

```
kubectl get ingress -n hipster-shop
```

```
NAME       CLASS   HOSTS                       ADDRESS         PORTS   AGE
frontend   nginx   shop.158.160.65.62.nip.io   158.160.65.62   80      22m
```

Как и ожидалось, по адресу http://shop.158.160.65.62.nip.io открывается страничка OnlineBoutique (с сообщением "Uh, oh! Something has failed..." 

Пришло время минимально шаблонизировать наш chart frontend. 
Для начала продумаем структуру файла values.yaml 

- Docker образ, из которого выкатывается frontend, может пересобираться, поэтому логично вынести его тег в переменную frontend.image.tag 

В values.yaml это будет выглядеть следующим образом: 

```yaml
image:
  tag: v0.8.0
```

Это значение по умолчанию и может (и должно быть) быть переопределено в CI/CD pipeline 

Теперь в манифесте deployment.yaml надо указать, что мы хотим
использовать эту переменную. 

Было: 

image: gcr.io/google-samples/microservices-demo/frontend:v0.8.0 

Стало: 

image: gcr.io/google-samples/microservices-demo/frontend:{{ .Values.image.tag }} 

Попробуйте обновить chart и убедиться, что ничего не изменилось: 

```
helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop
helm ls -n hipster-shop
kubectl get po -n hipster-shop
kubectl get svc -n hipster-shop
kubectl get ingress -n hipster-shop
ketall -n hipster-shop | grep frontend
curl http://shop.158.160.65.62.nip.io/
kubectl -n hipster-shop port-forward service/frontend 7000:80
```

Аналогичным образом шаблонизируйте следующие параметры frontend chart: 
- Количество реплик в deployment 
- Port, targetPort и NodePort в service 
- Опционально - тип сервиса. Ключ NodePort должен появиться в манифесте только если тип сервиса - NodePort 
- Другие параметры, которые, на ваш взгляд, стоит шаблонизировать 

Не забывайте указывать в файле values.yaml значения по умолчанию! 

У меня такой файл values.yaml получился: 

```yaml
image:
  tag: v0.8.0

replicas: 2

service:
  type: NodePort
  port: 80
  targetPort: 8080
  NodePort: 30001

resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

(я добавил еще requests и limits в деплойменте, а также поменял дефолтное число реплик) 

Обновил и всё работает. 
Причем NodePort выбран не случайный после 30000, а непосредственно заданный (дефолтный из values.yaml): 

```
kubectl get svc -n hipster-shop | grep -e NAME -e frontend
```

```
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend                NodePort    10.55.200.132   <none>        80:30001/TCP   54m
```

Также действительно взято новое дефолтное значение количества реплик: 

```
kubectl get po -n hipster-shop | grep -e NAME -e frontend
```

```
NAME                                     READY   STATUS                   RESTARTS        AGE
frontend-748c98cd89-4dhjs                1/1     Running                  0               62m
frontend-748c98cd89-f94kn                1/1     Running                  0               3m38s
```

```
kubectl get deployment/frontend -n hipster-shop
```

```
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
frontend   2/2     2            2           63m
```

И через ingress в браузере мы поочередно попадаем то на одну реплику, то на другую. 

Теперь наш frontend стал немного похож на настоящий helm chart. 
Не стоит забывать, что он все еще является частью одного большого микросервисного приложения hipster-shop. 
Поэтому было бы неплохо включить его в зависимости этого приложения. 
Для начала, удалите release frontend из кластера: 

```
helm delete frontend -n hipster-shop
```

В Helm 2 файл requirements.yaml содержал список зависимостей helm chart (другие chart). 
В Helm 3 список зависимостей рекомендуют объявлять в файле Chart.yaml. 
При указании зависимостей в старом формате все будет работать, просто выдаст предупреждение. 
[Подробнее](https://helm.sh/docs/faq/#consolidation-of-requirements-yaml-into-chart-yaml) 

Добавьте chart frontend как зависимость: 

```yaml
dependencies:
  - name: frontend
    version: 0.1.0
    repository: "file://../frontend"
```

Обновим зависимости: 

```
helm dep update kubernetes-templating/hipster-shop
```

В директории kubernetes-templating/hipster-shop/charts появился архив frontend-0.1.0.tgz, содержащий chart frontend определенной версии и добавленный в chart hipster-shop как зависимость: 

```
$ ls -lFh kubernetes-templating/hipster-shop/charts/
итого 12K
-rw-r--r-- 1 dimka dimka 1,6K окт 19 15:47 frontend-0.1.0.tgz
```

Обновите release hipster-shop и убедитесь, что ресурсы frontend вновь созданы. 

```
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
```

```
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Thu Oct 19 15:53:42 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 4
TEST SUITE: None
```

```
helm ls -n hipster-shop
kubectl get po -n hipster-shop
kubectl get svc -n hipster-shop
kubectl get deployment/frontend -n hipster-shop
kubectl get ingress -n hipster-shop
ketall -n hipster-shop | grep frontend
curl http://shop.158.160.65.62.nip.io/
kubectl -n hipster-shop port-forward service/frontend 7000:80
```

Всё успешно. 

```
$ ketall -n hipster-shop | grep frontend
endpoints/frontend                                          hipster-shop  2m38s  
pod/frontend-748c98cd89-k6mvc                               hipster-shop  2m37s  
pod/frontend-748c98cd89-zbmtj                               hipster-shop  2m37s  
service/frontend                                            hipster-shop  2m38s  
deployment.apps/frontend                                    hipster-shop  2m37s  
replicaset.apps/frontend-748c98cd89                         hipster-shop  2m37s  
endpointslice.discovery.k8s.io/frontend-8nz62               hipster-shop  2m38s  
ingress.networking.k8s.io/frontend                          hipster-shop  2m35s  
```

Осталось понять, как из CI-системы мы можем менять параметры helm chart, описанные в values.yaml. 
Для этого существует специальный ключ --set. 
Изменим NodePort для frontend в release, не меняя его в самом chart: 

```
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop \
  --set frontend.service.NodePort=31234 \
  --set frontend.replicas=3 \
  --set frontend.resources.limits.cpu=300m \
  --set frontend.resources.limits.memory=256Mi
```

```
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Thu Oct 19 16:09:17 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 5
TEST SUITE: None
```

Так как как мы меняем значение переменной для зависимости, то перед названием переменной указываем имя (название chart) этой зависимости. 
Если бы мы устанавливали chart frontend напрямую, то команда выглядела бы как --set service.NodePort=31234 

Снова проверяем тем же набором команд (helm ls, kubectl get deployment и др., см. выше). 
Всё успешно. 
При этом обратим внимание на число реплик, NodePort, лимиты: 

```
$ kubectl get deployment/frontend -n hipster-shop
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
frontend   3/3     3            3           26m
$ kubectl get -n hipster-shop svc/frontend 
NAME       TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
frontend   NodePort   10.55.219.41   <none>        80:31234/TCP   26m
$ kubectl get deployment/frontend -n hipster-shop -o yaml | grep -A2 limits
          limits:
            cpu: 300m
            memory: 256Mi
```

## Работа с helm-secrets | Необязательное задание

Разберемся как работает плагин helm-secrets. 
Для этого добавим в Helm chart секрет и научимся хранить его в зашифрованном виде. 
Начнем с того, что установим плагин и необходимые для него зависимости. 

Пример для MacOS: 

```
brew install sops
brew install gnupg2
brew install gnu-getopt
```

Пример для LMDE 5: 

```
sudo apt update
sudo apt install gnupg2
```

Установка плагина: 

```
helm plugin install https://github.com/futuresimple/helm-secrets --version 2.0.2
```

Сгенерируем новый PGP ключ: 

```
gpg --full-generate-key
```

```
..........
pub   rsa3072 2023-10-19 [SC]
      78FA3FB0CD5E8C4CE26D8C045AA846F8494966C1
uid                      Dimka (Key_for_kubernetes-templating_HW) <kodmandvl@mail.ru>
sub   rsa3072 2023-10-19 [E]
```

После этого командой gpg -k можно проверить, что ключ появился: 

```
gpg -k
```

```
gpg: проверка таблицы доверия
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: глубина: 0  достоверных:   1  подписанных:   0  доверие: 0-, 0q, 0n, 0m, 0f, 1u
/home/dimka/.gnupg/pubring.kbx
------------------------------
pub   rsa3072 2023-10-19 [SC]
      78FA3FB0CD5E8C4CE26D8C045AA846F8494966C1
uid         [  абсолютно ] Dimka (Key_for_kubernetes-templating_HW) <kodmandvl@mail.ru>
sub   rsa3072 2023-10-19 [E]
```

Создадим новый файл secrets.yaml в директории kubernetes-templating/frontend со следующим содержимым: 

visibleKey: hiddenValue 

```
echo 'visibleKey: hiddenValue' > kubernetes-templating/frontend/secrets.yaml
cat kubernetes-templating/frontend/secrets.yaml
```

И попробуем зашифровать его: 

sops -e -i --pgp <$ID> secrets.yaml 

(sops - encrypted file editor with AWS KMS, GCP KMS and GPG support) 

(Примечание - вместо ID подставьте длинный хеш, в выводе на предыдущей странице) 

```
sops -e -i --pgp 78FA3FB0CD5E8C4CE26D8C045AA846F8494966C1 kubernetes-templating/frontend/secrets.yaml
cat kubernetes-templating/frontend/secrets.yaml
```

Проверьте, что файл secrets.yaml изменился. Сейчас его содержание должно выглядеть примерно так: 

```
visibleKey: ENC[AES256_GCM,data:omYRIELtQJdhdJ4=,iv:1lDUxfGyEIvJxVtsB3Z4KtqZwOJAuJeKp5598v1FAJU=,tag:qeXTcHO1bJf/J3hbmmVsIg==,type:str]
sops:
    kms: []
    gcp_kms: []
    lastmodified: '2023-10-19T22:26:52Z'
..........
    pgp:
    -   created_at: '2023-10-19T22:26:52Z'
..........
```

Заметьте, что структура файла осталась прежней. Мы видим ключ visibleKey, но его значение зашифровано. 

В таком виде файл уже можно коммитить в Git, но для начала - научимся расшифровывать его. 
Можно использовать любой из инструментов: 

```
# helm secrets
helm secrets view kubernetes-templating/frontend/secrets.yaml
# sops
sops -d kubernetes-templating/frontend/secrets.yaml
```

Вывод обеих команд: 

visibleKey: hiddenValue 

Теперь осталось понять, как добавить значение нашего секрета в настоящий секрет kubernetes и устанавливать его вместе с основным helm chart. 

Создайте в директории kubernetes-templating/frontend/templates еще один файл secret.yaml. 
Несмотря на похожее название его предназначение будет отличаться. 
Поместите туда следующий шаблон: 

```
echo '---
apiVersion: v1
kind: Secret
metadata:
  name: secret
type: Opaque
data:
  visibleKey: {{ .Values.visibleKey | b64enc | quote }}
' > kubernetes-templating/frontend/templates/secret.yaml
cat kubernetes-templating/frontend/templates/secret.yaml
```

Теперь, если мы передадим в helm файл secrets.yaml как values файл, плагин helm-secrets поймет, что его надо расшифровать, а значение ключа visibleKey подставить в соответствующий шаблон секрета. 
Запустим установку (перед этим удалил hipster-shop, иначе была ошибка, видимо, из-за frontend как зависимости): 

```
helm secrets upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop \
  -f kubernetes-templating/frontend/values.yaml \
  -f kubernetes-templating/frontend/secrets.yaml
```

```
Release "frontend" does not exist. Installing it now.
NAME: frontend
LAST DEPLOYED: Fri Oct 20 01:48:32 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
удалён 'kubernetes-templating/frontend/secrets.yaml.dec'
```

В процессе установки helm-secrets расшифрует наш секретный файл в другой временный файл secrets.yaml.dec, а после выполнения установки удалит его. 
Если во время установки быстро подвесить на tail в соседнем окне, можно успеть его увидеть: 

```
tail -f kubernetes-templating/frontend/secrets.yaml.dec
```

```
visibleKey: hiddenValue
```

Про что необходимо помнить, если используем helm-secrets 
(например, как обезопасить себя от коммита файлов с секретами, которые забыл зашифровать)? 

Ответ: думаю, нужно как-то проверять исходный код на чувствительные данные (например, использовать какие-то из соответствующих анализаторов кода). 

# Проверка | Поместите все получившиеся helm chart's в ваш установленный harbor в публичный проект.

Если войти в Harbor в проект libraries ( https://harbor.158.160.65.62.nip.io/harbor/projects/1/repositories ) и нажать ниспадающий список PUSH COMMAND, то можно увидеть примеры того, как запушить сюда образы, чарты и CNAB:

## Docker Push Command

Tag an image for this project: 
```
docker tag SOURCE_IMAGE[:TAG] harbor.158.160.65.62.nip.io/library/REPOSITORY[:TAG]
```

Push an image to this project: 
```
docker push harbor.158.160.65.62.nip.io/library/REPOSITORY[:TAG]
```

## Podman Push Command

Push an image to this project: 
```
podman push IMAGE_ID harbor.158.160.65.62.nip.io/library/REPOSITORY[:TAG]
```

## Helm Push Command

Package a chart for this project:
```
helm package CHART_PATH
```

Push a chart to this project: 
```
helm push CHART_PACKAGE oci://harbor.158.160.65.62.nip.io/library
```

## CNAB Push Command

Push a CNAB to this project: 
```
cnab-to-oci push CNAB_PATH --target harbor.158.160.65.62.nip.io/library/REPOSITORY[:TAG] --auto-update-bundle
```

Создайте файл kubernetes-templating/repo.sh со следующим содержанием: 

```
#!/bin/bash
helm repo add templating <Ссылка на ваш репозиторий>
```

После исполнения этого файла должен появляться репозиторий, из которого можно установить следующие helm chart's: 
- templating/frontend 
- templating/hipster-shop 

В нашем случае получилось вот так: 

```
$ helm package kubernetes-templating/hipster-shop/
Successfully packaged chart and saved it to: /home/dimka/myrepgh/hwk8s/hipster-shop-0.1.0.tgz
$ helm package kubernetes-templating/frontend/
Successfully packaged chart and saved it to: /home/dimka/myrepgh/hwk8s/frontend-0.1.0.tgz
# В примере выше подразумевается, что мы залогинилсь в harbor, но мы - пока нет, логинимся:
$ helm --help
..........
$ helm registry --help
..........
$ helm registry login --help
..........
# Перед этим также в Harbor создал пользователя pusher/IZ-QMauB7fJg.rTl с административными правами, но для для пуша артефактов, а также перераскатил Harbor с продовским letsencrypt.
# Однако снова столкнулся с проблемой лимитов на заказ сертификатов, нужно перераскатывать/ждать/или т.п.
# В общем нужно залогиниться с игнором сертификатов как-то:
$ helm registry login https://harbor.158.160.65.62.nip.io -u pusher
..........
$ helm registry login https://harbor.158.160.65.62.nip.io -u pusher --insecure
Password: 
WARN[0001] insecure registry https://harbor.158.160.65.62.nip.io should not contain 'https://' and 'https://' has been removed from the insecure registry config 
Login Succeeded
$ helm push frontend-0.1.0.tgz oci://harbor.158.160.65.62.nip.io/library --insecure-skip-tls-verify
Pushed: harbor.158.160.65.62.nip.io/library/frontend:0.1.0
Digest: sha256:f76557f743a3c287dba3569747b81163e9dfa5fbb2c56ce0e657022f83a6c769
$ helm push hipster-shop-0.1.0.tgz oci://harbor.158.160.65.62.nip.io/library --insecure-skip-tls-verify
Pushed: harbor.158.160.65.62.nip.io/library/hipster-shop:0.1.0
Digest: sha256:4c5f954084b216df8dbead9e26948c5c94bc878067894b4a8c193b88e0b52bc0
```

Далее я попробовал разные вариации адреса для helm repo add, но были каждый раз ошибки вида: 

Error: looks like "протокол://ссылка" is not a valid chart repository or cannot be reached: object required 

Но в Harbor чарты успешно добавились (см. выше). 

Нашел данные чарты в вэб-интерфейсе Harbor и нашел там helm pull для них (разлогинился, чтобы проверить, что доступ к ним действительно публичный): 

```
$ cd ~/temp/
$ ls -lFtrh | grep tgz
$ helm registry logout https://harbor.158.160.65.62.nip.io
Removing login credentials for https://harbor.158.160.65.62.nip.io
$ helm pull oci://harbor.158.160.65.62.nip.io/library/frontend --version 0.1.0 --insecure-skip-tls-verify
Pulled: harbor.158.160.65.62.nip.io/library/frontend:0.1.0
Digest: sha256:f76557f743a3c287dba3569747b81163e9dfa5fbb2c56ce0e657022f83a6c769
$ helm pull oci://harbor.158.160.65.62.nip.io/library/hipster-shop --version 0.1.0 --insecure-skip-tls-verify
Pulled: harbor.158.160.65.62.nip.io/library/hipster-shop:0.1.0
Digest: sha256:4c5f954084b216df8dbead9e26948c5c94bc878067894b4a8c193b88e0b52bc0
$ ls -lFtrh | grep tgz
-rw-r--r--  1 dimka dimka 2,7K окт 20 16:09 frontend-0.1.0.tgz
-rw-r--r--  1 dimka dimka 2,9K окт 20 16:10 hipster-shop-0.1.0.tgz
```

Чарты скачиваются в виде архива, можно извлечь и установить. 
Жаль, что не удалось добавить как репозиторий. 
Однако в целом такой обходной вариант, с моей т.з., рабочий, т.к. данные артефакты размещены в Harbor и скачиваются. 
Также извлек их и проверил установку (по аналогии с установками выше). 

В таком случае скрипт будет выглядеть так: 

```
cd -
echo '#!/bin/bash
helm pull oci://harbor.158.160.65.62.nip.io/library/frontend --version 0.1.0 --insecure-skip-tls-verify
helm pull oci://harbor.158.160.65.62.nip.io/library/hipster-shop --version 0.1.0 --insecure-skip-tls-verify
tar -xzvf frontend-0.1.0.tgz
tar -xzvf hipster-shop-0.1.0.tgz
# Tip! How to install if you need:
# Hipster-Shop with FrontEnd:
# helm upgrade --install hipster-shop hipster-shop --namespace hipster-shop --create-namespace
# FrontEnd only:
# helm upgrade --install frontend frontend --namespace hipster-shop --create-namespace
' > kubernetes-templating/repo.sh
chmod +x kubernetes-templating/repo.sh
cat kubernetes-templating/repo.sh
```

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-templating
git branch
mkdir kubernetes-templating
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-templating/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-templating"
git push --set-upstream origin kubernetes-templating
git status
# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.
# Если здесь нужно переключить обратно на ветку main, то:
git branch
git switch main
git branch
git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-templating

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все основные пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - все действия по порядку указаны в README.md

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get, а также открыть приведенные ниже ссылки в браузере (со своим IP):
 - https://chartmuseum.158.160.65.62.nip.io/
 - https://harbor.158.160.65.62.nip.io/
 - http://shop.158.160.65.62.nip.io/
 - Также можно запустить скрипт repo.sh для скачивания полученных чартов (без секретов)

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-templating отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/номерpr 

