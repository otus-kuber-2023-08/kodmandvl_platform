# Подготовка

```
minikube start -p sec-hw --kubernetes-version=v1.27.4 --driver=virtualbox --cpus=4 --memory=8192m

mkdir -p kubernetes-security && cd kubernetes-security/ && touch README.md

minikube profile list

minikube status -p sec-hw

kubectl get nodes -o wide

kubectl get po -A -o wide
```

# Посмотрим

Не все вещи уходят в namespaces (nodes, persistentVolumes, например, нет). kubectl api-resources покажет в колонке namespaced, уходит ли оно в Namespace:

```
kubectl api-resources

kubectl api-resources | grep -e NAMESPACED -e true

kubectl api-resources | grep -e NAMESPACED -e false
```

Authorization mode:

```
kubectl cluster-info dump | grep authorization-mode
```

```
                            "--authorization-mode=Node,RBAC",
```

```
kubectl -n kube-system describe pod kube-apiserver-minikube | grep authorization-mode
```

```
      --authorization-mode=Node,RBAC
```

Roles, ClusterRoles, Bindings:

```
kubectl get clusterroles

kubectl get clusterrolebindings

kubectl get roles -A

kubectl get rolebindings -A
```

Какие Admission Controller-ы включены сразу же из коробки:

```
kubectl cluster-info dump | grep enable-admission
```

```
                            "--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota",
```

# task01

- Создать Service Account bob , дать ему роль admin в рамках всего кластера
- Создать Service Account dave без доступа к кластеру

```
mkdir -p task01 && cd task01

nano 01-bob-sa.yaml

nano 02-bob-binding.yaml

cp -aiv 01-bob-sa.yaml 03-dave-sa.yaml 

nano 03-dave-sa.yaml 

kubectl apply -f 01-bob-sa.yaml
```

```
serviceaccount/bob created
```

```
kubectl apply -f 02-bob-binding.yaml 
```

```
clusterrolebinding.rbac.authorization.k8s.io/Admin-ClusterRole-For-Bob created
```

```
kubectl apply -f 03-dave-sa.yaml 
```

```
serviceaccount/dave created
```

Файлы 01-bob-sa.yaml и 03-dave-sa.yaml отличаются только именеам сервисного аккаунта.

По условию задачи у dave не должно быть прав к кластеру, поэтому для никакую привязку (binding) не выполняем.

Посмотрим и проверим информацию о созданных сущностях:

```
kubectl get serviceaccounts | grep -e bob -e dave
```

```
bob       0         12m
dave      0         10m
```

```
kubectl get clusterroles | grep ^admin
```

```
admin                                                                  2023-10-03T21:57:06Z
```

```
kubectl get clusterrolebindings -o wide | grep -i -e ^name -e bob -e dave
```

```
NAME                          ROLE                    AGE   USERS GROUPS      SERVICEACCOUNTS
Admin-ClusterRole-For-Bob     ClusterRole/admin       14m                     default/bob
```

У bob есть роль admin на уровне кластера, а у dave - нет.

Также на уровне каких-либо неймспейсов привязок (binding) ни у олного из этих сервисных аккаунтов не находим:

```
kubectl get rolebindings -A -o wide | grep -i -e ^namespace -e bob -e dave
```

```
NAMESPACE NAME    ROLE  AGE   USERS GROUPS      SERVICEACCOUNTS
(пусто)
```

# task02

- Создать Namespace prometheus
- Создать Service Account carol в этом Namespace
- Дать всем Service Account в Namespace prometheus возможность делать get , list , watch в отношении Pods всего кластера

```
cd ../

mkdir -p task02 && cd task02

nano 01-prometheus-ns.yaml

kubectl apply -f 01-prometheus-ns.yaml
```

```
namespace/prometheus created
```

```
nano 02-carol-sa.yaml

kubectl apply -f 02-carol-sa.yaml 
```

```
serviceaccount/carol created
```

Т.к. необходима привилегия просмотра Pods всего кластера, то создадим роль на уровне кластера:

```
nano 03-pods-view-clusterrole.yaml

kubectl apply -f 03-pods-view-clusterrole.yaml 
```

```
clusterrole.rbac.authorization.k8s.io/pods-view created
```

Привязка роли (необходимо привязать данную кластерную роль к сервисным аккаунтам, находящимся в неймспейсе prometheus): 

```
nano 04-binding.yaml

kubectl apply -f 04-binding.yaml 
```

```
clusterrolebinding.rbac.authorization.k8s.io/Pods-View-For-Prometheus-NS-SA created
```

Посмотрим на результаты:

```
kubectl get serviceaccounts -n prometheus | grep -e carol
```

```
carol     0         29m
```

```
kubectl get clusterroles/pods-view -o yaml
```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"annotations":{},"name":"pods-view"},"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["get","list","watch"]}]}
  creationTimestamp: "2023-10-03T23:02:14Z"
  name: pods-view
  resourceVersion: "3603"
  uid: 4f07173b-f52c-4b8b-8b35-be1191329185
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```

```
kubectl get clusterrolebindings -o wide | grep -i -e ^name -e pods-view
```

```
NAME                                ROLE                    AGE         USERS       GROUPS                              SERVICEACCOUNTS
Pods-View-For-Prometheus-NS-SA      ClusterRole/pods-view   2m54s                   system:serviceaccounts:prometheus   
```

# task03

- Создать Namespace dev
- Создать Service Account jane в Namespace dev
- Дать jane роль admin в рамках Namespace dev
- Создать Service Account ken в Namespace dev
- Дать ken роль view в рамках Namespace dev

Создадим соответствующие манифесты и применим:

```
cd ../

mkdir -p task03 && cd task03

cp -aiv ../task02/01-prometheus-ns.yaml 01-dev-ns.yaml

nano 01-dev-ns.yaml 

kubectl apply -f 01-dev-ns.yaml 
```

```
namespace/dev created
```

```
cp -aiv ../task02/02-carol-sa.yaml ./02-jane-sa.yaml

nano 02-jane-sa.yaml 

kubectl apply -f 02-jane-sa.yaml 
```

```
serviceaccount/jane created
```

Поскольку ролей admin и view в неймспейсе dev нет, а они есть только как кластерные роли, мы их создадим для неймспейса dev и уже после этого осуществим привязку. 

```
nano 03-admin-role.yaml

kubectl apply -f 03-admin-role.yaml 
```

```
role.rbac.authorization.k8s.io/admin created
```

```
nano 04-jane-binding.yaml

kubectl apply -f 04-jane-binding.yaml 
```

```
rolebinding.rbac.authorization.k8s.io/admin-role-on-dev-for-jane-sa created
```

По аналогии создадим ken, роль view (в ней будут не все verbs, а только "на посмотреть") и привязку.

```
kubectl apply -f 05-ken-sa.yaml 
```

```
serviceaccount/ken created
```

```
kubectl apply -f 06-view-role.yaml 
```

```
role.rbac.authorization.k8s.io/view created
```

```
kubectl apply -f 07-ken-binding.yaml 
```

```
rolebinding.rbac.authorization.k8s.io/view-role-on-dev-for-ken-sa created
```

Посмотрим и проверим:

```
kubectl get sa -n dev | grep -e jane -e ken
```

```
jane      0         40m
ken       0         13m
```

```
kubectl get roles.rbac.authorization.k8s.io -n dev
```

```
NAME    CREATED AT
admin   2023-10-03T23:50:29Z
view    2023-10-04T00:07:01Z
```

```
kubectl get roles.rbac.authorization.k8s.io/admin -n dev -o yaml
```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"Role","metadata":{"annotations":{},"name":"admin","namespace":"dev"},"rules":[{"apiGroups":["*"],"resources":["*"],"verbs":["*"]}]}
  creationTimestamp: "2023-10-03T23:50:29Z"
  name: admin
  namespace: dev
  resourceVersion: "5922"
  uid: 111fa59d-78a1-4266-b081-eee8b4d370f9
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
```

```
kubectl get roles.rbac.authorization.k8s.io/view -n dev -o yaml
```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"Role","metadata":{"annotations":{},"name":"view","namespace":"dev"},"rules":[{"apiGroups":["*"],"resources":["*"],"verbs":["get","watch","list"]}]}
  creationTimestamp: "2023-10-04T00:07:01Z"
  name: view
  namespace: dev
  resourceVersion: "6718"
  uid: ec5007d0-c99b-44c0-8c6d-f338045129bf
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - get
  - watch
  - list
```

```
kubectl get -n dev rolebindings.rbac.authorization.k8s.io -o wide
```

```
NAME                            ROLE         AGE     USERS   GROUPS   SERVICEACCOUNTS
admin-role-on-dev-for-jane-sa   Role/admin   18m                      dev/jane
view-role-on-dev-for-ken-sa     Role/view    6m19s                    dev/ken
```

# git checkout, create directory, copy files, pull request

```
cd ~/kodmandvl_platform/

git pull ; git status

ls

git branch

git checkout -b kubernetes-security

git branch

mkdir kubernetes-security

# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-security/

# Далее: 

git status

git add -A

git status

git commit -m "kubernetes-security"

git push --set-upstream origin kubernetes-security

git status

# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.

# Если здесь нужно обратно переключить в ветку main, то:

git branch

git switch main

git branch

git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-security

 - [OK] Основное ДЗ
 - [OK] Задания со * в данном ДЗ не предусмотрены

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям

## Как запустить проект:
 - По порядку из методических указаний или из README выполнять настройки и применять манифесты kubectl apply -f kodmandvl_platform/kubernetes-security/task0N/0N-имя-файла.yaml

## Как проверить работоспособность:
 - Выполнить соответствующие команды kubectl из README.md

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

