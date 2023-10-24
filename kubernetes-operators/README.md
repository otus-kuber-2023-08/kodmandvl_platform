# Подготовка

```
mkdir -p kubernetes-operators/deploy && cd kubernetes-operators
cp -aiv ../README.md ./
```

Запустите kubernetes кластер в minikube (запускал внутри ВМ, поэтому драйвер - docker, а не VirtualBox): 

```
minikube start -p minikube --kubernetes-version=v1.24.16 --driver=docker --cpus=3 --memory=6144m
```

## Посмотреть:

```
kubectl get all -A -o wide

kubectl get pods -A -o wide

kubectl get nodes -o wide
```

# Что должно быть в описании MySQL 

Для создания pod с MySQL оператору понадобится знать: 

1. Какой образ с MySQL использовать 
2. Какую db создать 
3. Какой пароль задать для доступа к MySQL 

То есть мы бы хотели, чтобы описание MySQL выглядело примерно так: 

```yaml
apiVersion: otus.homework/v1
kind: MySQL
metadata:
  name: mysql-instance
spec:
  image: mysql:5.7
  database: otus-database
  password: otuspassword # Так делать не нужно, следует использовать secret
  storage_size: 1Gi
```

# CustomResource 

Cоздадим CustomResource deploy/cr.yml со следующим содержимым: 

```yaml
apiVersion: otus.homework/v1
kind: MySQL
metadata:
  name: mysql-instance
spec:
  image: mysql:5.7
  database: otus-database
  password: otuspassword  # Так делать не нужно, следует использовать secret
  storage_size: 1Gi
usless_data: "useless info"
```

Пробуем применить его: 

```
kubectl apply -f deploy/cr.yml
```

Видим ошибку: 

```
error: resource mapping not found for name: "mysql-instance" namespace: "" from "deploy/cr.yml": no matches for kind "MySQL" in version "otus.homework/v1"
ensure CRDs are installed first
```

Ошибка связана с отсутсвием объектов типа MySQL в API kubernetes. 
Исправим это недоразумение. 

# CustomResourceDefinition 

CustomResourceDefinition - это ресурс для определения других ресурсов (далее CRD). 

Создадим CRD deploy/crd.yml: 

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.otus.homework # имя CRD должно иметь формат plural.group
spec:
  scope: Namespaced          # Данный CRD будер работать в рамках namespace
  group: otus.homework       # Группа, отражается в поле apiVersion CR
  versions:                  # Список версий
    - name: v1
      served: true           # Будет ли обслуживаться API-сервером данная версия
      storage: true          # Фиксирует  версию описания, которая будет сохраняться в etcd
  names:                     # различные форматы имени объекта CR
    kind: MySQL              # kind CR
    plural: mysqls      
    singular: mysql
    shortNames:
      - ms
```

# Создаем CRD и CR 

Создадим CRD: 

```
kubectl apply -f deploy/crd.yml
```

```
The CustomResourceDefinition "mysqls.otus.homework" is invalid: spec.versions[0].schema.openAPIV3Schema: Required value: schemas are required
```

Судя по тексту ошибки, для раздела versions нужно еще описать [схему и openAPIV3Schema в схеме](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/). 

Тогда файл deploy/crd.yml будет выглядеть так: 

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.otus.homework # имя CRD должно иметь формат plural.group
spec:
  scope: Namespaced          # Данный CRD будер работать в рамках namespace
  group: otus.homework       # Группа, отражается в поле apiVersion CR
  versions:                  # Список версий
    - name: v1
      served: true           # Будет ли обслуживаться API-сервером данная версия
      storage: true          # Фиксирует  версию описания, которая будет сохраняться в etcd
      schema:
        openAPIV3Schema:
          type: object
  names:                     # различные форматы имени объекта CR
    kind: MySQL              # kind CR
    plural: mysqls      
    singular: mysql
    shortNames:
      - ms
```

Теперь: 

```
$ kubectl apply -f deploy/crd.yml
customresourcedefinition.apiextensions.k8s.io/mysqls.otus.homework created
```

Cоздаем CR: 

```
kubectl apply -f deploy/cr.yml
```

Ошибка: 

```
error: error validating "deploy/cr.yml": error validating data: [ValidationError(MySQL): unknown field "spec" in homework.otus.v1.MySQL, ValidationError(MySQL): unknown field "usless_data" in homework.otus.v1.MySQL]; if you choose to ignore these errors, turn validation off with --validate=false
```

(закомментил пока usless_data: "useless info") 

```
$ kubectl apply -f deploy/cr.yml
error: error validating "deploy/cr.yml": error validating data: ValidationError(MySQL): unknown field "spec" in homework.otus.v1.MySQL; if you choose to ignore these errors, turn validation off with --validate=false
```

Судя по ошибке, поля из spec должны быть определены в CRD. 
Судя по дальнейшему ходу повествования в методических указаниях, всё это будет далее дозаполняться. 
Возможно, если было бы у нас v1beta, а не v1, или же на более старых версиях Kubernetes выполнилось бы как есть на этом шаге. 

# Взаимодействие с объектами CR CRD 

C созданными объектами можно взаимодействовать через kubectl: 

```
kubectl get crd
kubectl get mysqls.otus.homework
kubectl describe mysqls.otus.homework mysql-instance
```

```
$ kubectl get crd
NAME                   CREATED AT
mysqls.otus.homework   2023-10-22T21:00:19Z
```

А CR-ы посмотрим уже позже, когда досоздадим далее. 

# Validation 

На данный момент мы никак не описали схему нашего CustomResource. 
Объекты типа mysql могут иметь абсолютно произвольные поля, 
нам бы хотелось этого избежать, для этого будем использовать validation. 
Для начала удалим CR mysql-instance (если бы он создался на шагах ранее): 

```
kubectl delete mysqls.otus.homework mysql-instance
```

Добавим в спецификацию CRD (spec) параметры validation: 

```yaml
  validation:
    openAPIV3Schema:
      type: object
      properties:
        apiVersion:
          type: string
        kind:
          type: string
        metadata:
          type: object
          properties:
            name:
              type: string
        spec:
          type: object
          properties:
            image: 
              type: string
            database:
              type: string
            password:
              type: string
            storage_size:
              type: string
```

# Пробуем применить CRD и CR 

```
kubectl apply -f deploy/crd.yml
```

Ошибки: 

```
error: error validating "deploy/crd.yml": error validating data: ValidationError(CustomResourceDefinition.spec): unknown field "validation" in io.k8s.apiextensions-apiserver.pkg.apis.apiextensions.v1.CustomResourceDefinitionSpec; if you choose to ignore these errors, turn validation off with --validate=false
```

В v1beta есть validation, в v1 - не вижу (в т.ч. в примере [документации](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/)). 

По сути там schema (описание схемы) в v1 идет вместо validation (с тем отличием, что ранее validation была подсекцией spec, а сейчас schema - это часть описания versions). 

Меняем (в т.ч. отступы): 

```yaml
      schema:
        openAPIV3Schema:
          type: object
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
              properties:
                name:
                  type: string
            spec:
              type: object
              properties:
                image: 
                  type: string
                database:
                  type: string
                password:
                  type: string
                storage_size:
                  type: string
```

Попробуем теперь: 

```
kubectl apply -f deploy/crd.yml
```

Теперь всё в порядке: 

```
customresourcedefinition.apiextensions.k8s.io/mysqls.otus.homework configured
```

```
kubectl apply -f deploy/cr.yml
```

```
mysql.otus.homework/mysql-instance created
```

# Взаимодействие с объектами CR CRD 

Посмотрим через kubectl: 

```
$ kubectl get crd
NAME                   CREATED AT
mysqls.otus.homework   2023-10-22T21:00:19Z
$ kubectl get mysqls.otus.homework
NAME             AGE
mysql-instance   75s
$ kubectl describe mysqls.otus.homework mysql-instance
Name:         mysql-instance
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  otus.homework/v1
Kind:         MySQL
Metadata:
  Creation Timestamp:  2023-10-23T22:22:57Z
  Generation:          1
  Resource Version:    6451
  UID:                 7066e28f-8ed7-40d1-b114-004b66e1ea94
Spec:
  Database:      otus-database
  Image:         mysql:5.7
  Password:      otuspassword
  storage_size:  1Gi
Events:          <none>
```

(usless_data: "useless info" уже закомментировал ранее) 

# Задание по CRD: 

Если сейчас из описания mysql убрать строчку из спецификации, то манифест будет принят API сервером. 
Для того, чтобы этого избежать, добавьте описание обязательный полей в CustomResourceDefinition. 

На самом деле суждение выше было бы корректно в более старых версиях и в v1beta. 
В нашем же случае после удаления какого-то из свойств в CRD уже больше не перераскатывается CR, ругаясь на неизвестное (удаленное) поле. 
Но [исходя из документации](https://kubernetes.io/blog/2019/06/20/crd-structural-schema/), речь шла об этом параметре: 

```
x-kubernetes-preserve-unknown-fields: true
```

Но на самом деле он по дефолту сейчас на данной версии K8s и в v1 установлено в true. 
При попытке выставить false (и заодно убрать какие-то из полей), получаем ошибку, что либо оно должно быть равным true, либо не должно упоминаться (эдакий выбор без выбора): 

```
$ kubectl apply -f crd.yml
The CustomResourceDefinition "mysqls.otus.homework" is invalid: spec.validation.openAPIV3Schema.x-kubernetes-preserve-unknown-fields: Invalid value: false: must be true or undefined
```

Выставляем его в true и возвращаем удаленные для тестика поля (CRD и CR успешно перераскатаны). 

# Операторы 

Оператор включает в себя CustomResourceDefinition и сustom сontroller: 
- CRD содержит описание объектов CR 
- Контроллер следит за объектами определенного типа и осуществляет всю логику работы оператора 

CRD мы уже создали, далее будем писать свой контроллер (все задания по написанию контроллера дополнительными) 

Далее развернем custom controller: 
- Если вы делаете задания со *, то ваш 
- Если нет, то используем готовый контроллер 

# Описание контроллера 

Используемый/написанный нами контроллер будет обрабатывать два типа событий: 

1. При создании объекта типа ( kind: mySQL ) он будет: 
- Cоздавать PersistentVolume, PersistentVolumeClaim, Deployment, Service для mysql 
- Создавать PersistentVolume, PersistentVolumeClaim для бэкапов базы данных, если их еще нет 
- Пытаться восстановиться из бэкапа 

2. При удалении объекта типа ( kind: mySQL ) он будет: 
- Удалять все успешно завершенные backup-job и restore-job 
- Удалять PersistentVolume, PersistentVolumeClaim, Deployment, Service для mysql 

# Деплой оператора 

Создайте в папке kubernetes-operators/deploy: 
- service-account.yml 
- role.yml 
- role-binding.yml 
- deploy-operator.yml 

(Если вы делали задачи со *, то поменяйте используемый в deploy-operator.yml образ) 

```
cd kubernetes-operators/deploy
wget https://gist.github.com/Evgenikk/581fa5bba6d924a3438be1e3d31aa468/raw/99429270c474cc434748e1058919e27df01d9a48/service-account.yml
wget https://gist.github.com/Evgenikk/581fa5bba6d924a3438be1e3d31aa468/raw/99429270c474cc434748e1058919e27df01d9a48/role.yml
wget https://gist.github.com/Evgenikk/581fa5bba6d924a3438be1e3d31aa468/raw/99429270c474cc434748e1058919e27df01d9a48/ClusterRoleBinding.yml
wget https://gist.github.com/Evgenikk/581fa5bba6d924a3438be1e3d31aa468/raw/619023d01e49ca3702357d4fded4d054cd523a9a/deploy-operator.yml
mv ClusterRoleBinding.yml role-binding.yml
```

Изучим, а затем применим манифесты: 

```
$ cd kubernetes-operators/deploy
$ kubectl apply -f service-account.yml
serviceaccount/mysql-operator created
$ kubectl apply -f role.yml
clusterrole.rbac.authorization.k8s.io/mysql-operator created
$ kubectl apply -f role-binding.yml
clusterrolebinding.rbac.authorization.k8s.io/workshop-operator created
$ kubectl apply -f deploy-operator.yml
deployment.apps/mysql-operator created
```

# Проверим, что все работает 

Создаем CR (если еще не создан): 

```
$ cd kubernetes-operators/deploy
$ kubectl apply -f cr.yml
mysql.otus.homework/mysql-instance created
```

Ждем некоторое время, проверяем, что появились pvc: 

```
$ k get all
NAME                                   READY   STATUS              RESTARTS   AGE
pod/mysql-instance-5686fc5b4d-lbt7x    0/1     ContainerCreating   0          40s
pod/mysql-operator-5f9c654d44-qf2h8    1/1     Running             0          110s
pod/restore-mysql-instance-job-xkvjs   0/1     ContainerCreating   0          40s

NAME                     TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/kubernetes       ClusterIP   10.96.0.1    <none>        443/TCP    3m44s
service/mysql-instance   ClusterIP   None         <none>        3306/TCP   40s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mysql-instance   0/1     1            0           40s
deployment.apps/mysql-operator   1/1     1            1           111s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/mysql-instance-5686fc5b4d   1         1         0       40s
replicaset.apps/mysql-operator-5f9c654d44   1         1         1       110s

NAME                                   COMPLETIONS   DURATION   AGE
job.batch/restore-mysql-instance-job   0/1           40s        40s
```

```
$ k get all
NAME                                   READY   STATUS             RESTARTS      AGE
pod/mysql-instance-5686fc5b4d-lbt7x    1/1     Running            0             87s
pod/mysql-operator-5f9c654d44-qf2h8    1/1     Running            0             2m37s
pod/restore-mysql-instance-job-xkvjs   0/1     CrashLoopBackOff   2 (26s ago)   87s

NAME                     TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/kubernetes       ClusterIP   10.96.0.1    <none>        443/TCP    4m31s
service/mysql-instance   ClusterIP   None         <none>        3306/TCP   87s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mysql-instance   1/1     1            1           87s
deployment.apps/mysql-operator   1/1     1            1           2m38s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/mysql-instance-5686fc5b4d   1         1         1       87s
replicaset.apps/mysql-operator-5f9c654d44   1         1         1       2m37s

NAME                                   COMPLETIONS   DURATION   AGE
job.batch/restore-mysql-instance-job   0/1           87s        87s
```

```
$ k get pvc
NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
backup-mysql-instance-pvc   Bound    pvc-1e0a3168-f5e8-4536-8251-7fb5c8bcd710   1Gi        RWO            standard       2m19s
mysql-instance-pvc          Bound    pvc-0eab6be5-5661-48dc-aff0-e05cff1a9452   1Gi        RWO            standard       2m19s
$ k get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                               STORAGECLASS   REASON   AGE
backup-mysql-instance-pv                   1Gi        RWO            Retain           Available                                                               2m21s
mysql-instance-pv                          1Gi        RWO            Retain           Available                                                               2m21s
pvc-0eab6be5-5661-48dc-aff0-e05cff1a9452   1Gi        RWO            Delete           Bound       default/mysql-instance-pvc          standard                2m21s
pvc-1e0a3168-f5e8-4536-8251-7fb5c8bcd710   1Gi        RWO            Delete           Bound       default/backup-mysql-instance-pvc   standard                2m21s
```

Заполним базу созданного mysql-instance: 

```
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
echo $MYSQLPOD
kubectl exec -it $MYSQLPOD -- mysql -u root -potuspassword -e "CREATE TABLE test (id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id) );" otus-database
kubectl exec -it $MYSQLPOD -- mysql -uroot -potuspassword -e "INSERT INTO test (id, name) VALUES (null, 'Hello from Dimka');" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test (id, name) VALUES (null, 'String number 2');" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
```

```
$ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+------------------+
| id | name             |
+----+------------------+
|  1 | Hello from Dimka |
|  2 | String number 2  |
+----+------------------+
```

Всё создано в неймспейсе default, посмотрим список объектов: 

```
$ 
$ kubectl get all -n default -o wide
NAME                                   READY   STATUS             RESTARTS      AGE     IP           NODE       NOMINATED NODE   READINESS GATES
pod/mysql-instance-5686fc5b4d-lbt7x    1/1     Running            0             4m25s   10.244.0.4   minikube   <none>           <none>
pod/mysql-operator-5f9c654d44-qf2h8    1/1     Running            0             5m35s   10.244.0.3   minikube   <none>           <none>
pod/restore-mysql-instance-job-xkvjs   0/1     CrashLoopBackOff   5 (45s ago)   4m25s   10.244.0.5   minikube   <none>           <none>

NAME                     TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/kubernetes       ClusterIP   10.96.0.1    <none>        443/TCP    7m29s   <none>
service/mysql-instance   ClusterIP   None         <none>        3306/TCP   4m25s   app=mysql-instance

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS       IMAGES                         SELECTOR
deployment.apps/mysql-instance   1/1     1            1           4m25s   mysql-instance   mysql:5.7                      app=mysql-instance
deployment.apps/mysql-operator   1/1     1            1           5m36s   operator         zhenkins/mysql-operator:v0.1   name=mysql-operator

NAME                                        DESIRED   CURRENT   READY   AGE     CONTAINERS       IMAGES                         SELECTOR
replicaset.apps/mysql-instance-5686fc5b4d   1         1         1       4m25s   mysql-instance   mysql:5.7                      app=mysql-instance,pod-template-hash=5686fc5b4d
replicaset.apps/mysql-operator-5f9c654d44   1         1         1       5m35s   operator         zhenkins/mysql-operator:v0.1   name=mysql-operator,pod-template-hash=5f9c654d44

NAME                                   COMPLETIONS   DURATION   AGE     CONTAINERS   IMAGES      SELECTOR
job.batch/restore-mysql-instance-job   0/1           4m25s      4m25s   backup       mysql:5.7   controller-uid=f0e0acc7-8f3c-41bc-8d54-2c09cf98c54d
$ 
$ ketall -n default
NAME                                                 NAMESPACE  AGE
configmap/kube-root-ca.crt                           default    7m31s  
endpoints/kubernetes                                 default    7m45s  
endpoints/mysql-instance                             default    4m41s  
persistentvolumeclaim/backup-mysql-instance-pvc      default    4m41s  
persistentvolumeclaim/mysql-instance-pvc             default    4m41s  
pod/mysql-instance-5686fc5b4d-lbt7x                  default    4m41s  
pod/mysql-operator-5f9c654d44-qf2h8                  default    5m51s  
pod/restore-mysql-instance-job-xkvjs                 default    4m41s  
serviceaccount/default                               default    7m32s  
serviceaccount/mysql-operator                        default    6m11s  
service/kubernetes                                   default    7m45s  
service/mysql-instance                               default    4m41s  
deployment.apps/mysql-instance                       default    4m41s  
deployment.apps/mysql-operator                       default    5m52s  
replicaset.apps/mysql-instance-5686fc5b4d            default    4m41s  
replicaset.apps/mysql-operator-5f9c654d44            default    5m51s  
job.batch/restore-mysql-instance-job                 default    4m41s  
endpointslice.discovery.k8s.io/kubernetes            default    7m45s  
endpointslice.discovery.k8s.io/mysql-instance-5d6tq  default    4m41s  
mysql.otus.homework/mysql-instance                   default    5m41s  
$ 
```

Удалим теперь mysql-instance: 

```
kubectl delete mysqls.otus.homework mysql-instance
```

```
mysql.otus.homework "mysql-instance" deleted
```

Теперь посмотрим kubectl get pv, kubectl get pvc, kubectl get jobs.batch: 

```
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                               STORAGECLASS   REASON   AGE
backup-mysql-instance-pv                   1Gi        RWO            Retain           Available                                                               6m28s
mysql-instance-pv                          1Gi        RWO            Retain           Available                                                               6m28s
pvc-1e0a3168-f5e8-4536-8251-7fb5c8bcd710   1Gi        RWO            Delete           Bound       default/backup-mysql-instance-pvc   standard                6m28s
$ kubectl get pvc
NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
backup-mysql-instance-pvc   Bound    pvc-1e0a3168-f5e8-4536-8251-7fb5c8bcd710   1Gi        RWO            standard       6m30s
$ kubectl get jobs.batch
NAME                         COMPLETIONS   DURATION   AGE
backup-mysql-instance-job    1/1           4s         58s
restore-mysql-instance-job   0/1           6m49s      6m49s
```

get all: 

```
$ kubectl get all -o wide
NAME                                  READY   STATUS      RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
pod/backup-mysql-instance-job-ch8vp   0/1     Completed   0          102s    10.244.0.6   minikube   <none>           <none>
pod/mysql-operator-5f9c654d44-qf2h8   1/1     Running     0          8m43s   10.244.0.3   minikube   <none>           <none>

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10m   <none>

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                         SELECTOR
deployment.apps/mysql-operator   1/1     1            1           8m44s   operator     zhenkins/mysql-operator:v0.1   name=mysql-operator

NAME                                        DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES                         SELECTOR
replicaset.apps/mysql-operator-5f9c654d44   1         1         1       8m43s   operator     zhenkins/mysql-operator:v0.1   name=mysql-operator,pod-template-hash=5f9c654d44

NAME                                   COMPLETIONS   DURATION   AGE     CONTAINERS              IMAGES      SELECTOR
job.batch/backup-mysql-instance-job    1/1           4s         102s    backup-mysql-instance   mysql:5.7   controller-uid=94984f01-1a88-48bc-84c1-9ca06921174e
job.batch/restore-mysql-instance-job   0/1           7m33s      7m33s   backup                  mysql:5.7   controller-uid=f0e0acc7-8f3c-41bc-8d54-2c09cf98c54d
```

Создадим заново mysql-instance: 

```
kubectl apply -f cr.yml
```

```
mysql.otus.homework/mysql-instance created
```

Немного подождем и: 

```
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
```

Должны увидеть таблицу, но восстановление почему-то не произошло, mysql-instance не запустился: 

```
$ kubectl get pods -l app=mysql-instance 
No resources found in default namespace.
```

```
$ k describe job restore-mysql-instance-job
Name:             restore-mysql-instance-job
Namespace:        default
Selector:         controller-uid=f0e0acc7-8f3c-41bc-8d54-2c09cf98c54d
Labels:           controller-uid=f0e0acc7-8f3c-41bc-8d54-2c09cf98c54d
                  job-name=restore-mysql-instance-job
Annotations:      <none>
Parallelism:      1
Completions:      1
Completion Mode:  NonIndexed
Start Time:       Tue, 24 Oct 2023 03:15:16 +0300
Pods Statuses:    0 Active (0 Ready) / 0 Succeeded / 1 Failed
Pod Template:
  Labels:  controller-uid=f0e0acc7-8f3c-41bc-8d54-2c09cf98c54d
           job-name=restore-mysql-instance-job
  Containers:
   backup:
    Image:      mysql:5.7
    Port:       <none>
    Host Port:  <none>
    Command:
      /bin/sh
      -c
      mysql -u root -h mysql-instance -potuspassword otus-database< /backup-mysql-instance-pv/mysql-instance-dump.sql
    Environment:  <none>
    Mounts:
      /backup-mysql-instance-pv from backup-mysql-instance-pv (rw)
  Volumes:
   backup-mysql-instance-pv:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  backup-mysql-instance-pvc
    ReadOnly:   false
Events:
  Type     Reason                Age    From            Message
  ----     ------                ----   ----            -------
  Normal   SuccessfulCreate      14m    job-controller  Created pod: restore-mysql-instance-job-xkvjs
  Normal   SuccessfulDelete      8m30s  job-controller  Deleted pod: restore-mysql-instance-job-xkvjs
  Warning  BackoffLimitExceeded  8m30s  job-controller  Job has reached the specified backoff limit
```

В общем, по моему мнению, что-то некорректно в операторе или методических указаниях, т.к. всё выполнялось по методическим указаниям, а инстанс так и не восстановился из бэкапа и не перезапустился (чистовое повторение мероприятий на новый кластер minikube тоже не помогло). 

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-operators
git branch
mkdir kubernetes-operators
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-operators/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-operators"
git push --set-upstream origin kubernetes-operators
git status
# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.
# Если здесь нужно переключить обратно на ветку main, то:
git branch
git switch main
git branch
git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-operators

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - cd deploy
 - kubectl apply -f crd.yml
 - kubectl apply -f service-account.yml
 - kubectl apply -f role.yml
 - kubectl apply -f role-binding.yml
 - kubectl apply -f deploy-operator.yml
 - kubectl apply -f cr.yml

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get и запросы к базе данных

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-operators отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/номерpr 

