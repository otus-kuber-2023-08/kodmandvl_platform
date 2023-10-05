# Подготовка

```
mkdir -p kubernetes-volumes && cd kubernetes-volumes/

touch README.md

kind create cluster

kubectl cluster-info --context kind-kind

kind get kubeconfig

cat ~/.kube/config

kind get clusters

kubectl get nodes -o wide
```

# Применение StatefulSet

В этом ДЗ мы развернем StatefulSet c [MinIO](https://min.io/) - локальным S3 хранилищем. 

Создаем minio-statefulset.yaml из [источника](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-statefulset.yaml). 

```
nano minio-statefulset.yaml

kubectl apply -f minio-statefulset.yaml
```

```
statefulset.apps/minio created
```

```
kubectl get po -o wide
```

```
NAME      READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
minio-0   1/1     Running   0          93s   10.244.0.6   kind-control-plane   <none>           <none>
```

```
kubectl get all -n default
```

```
NAME          READY   STATUS    RESTARTS   AGE
pod/minio-0   1/1     Running   0          97s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   13m

NAME                     READY   AGE
statefulset.apps/minio   1/1     97s
```

В результате применения конфигурации должно произойти следующее: 
- Запуститься под с MinIO
- Создаться PVC
- Динамически создаться PV на этом PVC с помощью дефолотного StorageClass

```
kubectl get pvc
```

```
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399   10Gi       RWO            standard       6m45s
```

```
kubectl get pv
```

```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                6m45s
```

# Применение Headless Service

Для того, чтобы наш StatefulSet был доступен изнутри кластера, создадим Headless Service. 

[Источник конфигурации](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-headless-service.yaml). 

```
nano minio-headless-service.yaml

kubectl apply -f minio-headless-service.yaml
```

```
service/minio created
```

```
kubectl get svc --show-labels -l app=minio
```

```
NAME    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE   LABELS
minio   ClusterIP   None         <none>        9000/TCP   38s   app=minio
```

# Проверка работы MinIO

Проверить работу Minio можно с помощью консольного клиента [mc](https://github.com/minio/mc). 

Также для проверки ресурсов k8s помогут команды: 

```
kubectl get statefulsets
```

```
NAME    READY   AGE
minio   1/1     20m
```

```
kubectl get pods
```

```
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          20m
```

```
kubectl get pvc
```

```
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399   10Gi       RWO            standard       20m
```

```
kubectl get pv
```

```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                20m
```

```
kubectl describe pv pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399
```

```
Name:              pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399
Labels:            <none>
Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
Finalizers:        [kubernetes.io/pv-protection]
StorageClass:      standard
Status:            Bound
Claim:             default/data-minio-0
Reclaim Policy:    Delete
Access Modes:      RWO
VolumeMode:        Filesystem
Capacity:          10Gi
Node Affinity:     
  Required Terms:  
    Term 0:        kubernetes.io/hostname in [kind-control-plane]
Message:           
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /var/local-path-provisioner/pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399_default_data-minio-0
    HostPathType:  DirectoryOrCreate
Events:            <none>
```

```
kubectl describe statefulset minio
```

```
Name:               minio
Namespace:          default
CreationTimestamp:  Thu, 05 Oct 2023 09:44:57 +0300
Selector:           app=minio
Labels:             <none>
Annotations:        <none>
Replicas:           1 desired | 1 total
Update Strategy:    RollingUpdate
  Partition:        0
Pods Status:        1 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=minio
  Containers:
   minio:
    Image:      minio/minio:RELEASE.2019-07-10T00-34-56Z
    Port:       9000/TCP
    Host Port:  0/TCP
    Args:
      server
      /data
    Liveness:  http-get http://:9000/minio/health/live delay=120s timeout=1s period=20s #success=1 #failure=3
    Environment:
      MINIO_ACCESS_KEY:  minio
      MINIO_SECRET_KEY:  minio123
    Mounts:
      /data from data (rw)
  Volumes:  <none>
Volume Claims:
  Name:          data
  StorageClass:  
  Labels:        <none>
  Annotations:   <none>
  Capacity:      10Gi
  Access Modes:  [ReadWriteOnce]
Events:
  Type    Reason            Age   From                    Message
  ----    ------            ----  ----                    -------
  Normal  SuccessfulCreate  21m   statefulset-controller  create Claim data-minio-0 Pod minio-0 in StatefulSet minio success
  Normal  SuccessfulCreate  21m   statefulset-controller  create Pod minio-0 in StatefulSet minio successful
```

```
kubectl describe pvc data-minio-0 
```

```
Name:          data-minio-0
Namespace:     default
StorageClass:  standard
Status:        Bound
Volume:        pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399
Labels:        app=minio
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: rancher.io/local-path
               volume.kubernetes.io/selected-node: kind-control-plane
               volume.kubernetes.io/storage-provisioner: rancher.io/local-path
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      10Gi
Access Modes:  RWO
VolumeMode:    Filesystem
Used By:       minio-0
Events:
  Type    Reason                 Age   From                                                                                                Message
  ----    ------                 ----  ----                                                                                                -------
  Normal  WaitForFirstConsumer   25m   persistentvolume-controller                                                                         waiting for first consumer to be created before binding
  Normal  ExternalProvisioning   25m   persistentvolume-controller                                                                         waiting for a volume to be created, either by external provisioner "rancher.io/local-path" or manually created by system administrator
  Normal  Provisioning           25m   rancher.io/local-path_local-path-provisioner-6bc4bddd6b-cc774_31595dab-a647-481d-8d96-c7aa46692767  External provisioner is provisioning volume for claim "default/data-minio-0"
  Normal  ProvisioningSucceeded  25m   rancher.io/local-path_local-path-provisioner-6bc4bddd6b-cc774_31595dab-a647-481d-8d96-c7aa46692767  Successfully provisioned volume pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399
```

# Задание со *

В конфигурации нашего StatefulSet данные указаны в открытом виде, что не безопасно. 

Поместите данные в [secrets](https://kubernetes.io/docs/concepts/configuration/secret/) и настройте конфигурацию на их использование. 

Создадим Secrets и подправим minio-statefulset.yaml: 

```
nano my-secrets.yaml

cp -aiv minio-statefulset.yaml minio-statefulset.yaml.old

nano minio-statefulset.yaml 

diff minio-statefulset.yaml minio-statefulset.yaml.old
```

```
19,21c19,23
<         envFrom:
<           - secretRef:
<               name: my-secrets
---
>         env:
>         - name: MINIO_ACCESS_KEY
>           value: "minio"
>         - name: MINIO_SECRET_KEY
>           value: "minio123"
```

Попробуем применить:

```
kubectl apply -f my-secrets.yaml
```

```
secret/my-secrets created
```

Удалил и затем пересоздал ресурсы:

```
kubectl apply -f minio-statefulset.yaml 
```

```
statefulset.apps/minio created
```

```
kubectl apply -f minio-headless-service.yaml 
```

```
service/minio created
```

```
kubectl get all -o wide
```

```
NAME          READY   STATUS    RESTARTS   AGE    IP            NODE                 NOMINATED NODE   READINESS GATES
pod/minio-0   1/1     Running   0          3m1s   10.244.0.10   kind-control-plane   <none>           <none>

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP    127m    <none>
service/minio        ClusterIP   None         <none>        9000/TCP   2m41s   app=minio

NAME                     READY   AGE    CONTAINERS   IMAGES
statefulset.apps/minio   1/1     3m1s   minio        minio/minio:RELEASE.2019-07-10T00-34-56Z
```

И здесь же еще раз проверил остальные команды:

```
kubectl get statefulsets

kubectl get pods

kubectl get pvc

kubectl get pv

kubectl describe pv pvc-24dabeb9-a0fe-4568-ae60-c7ce5253c399

kubectl describe statefulset minio

kubectl describe pvc data-minio-0 
```

Всё в порядке.

Секреты: 

```
kubectl get secrets my-secrets
```

```
NAME         TYPE     DATA   AGE
my-secrets   Opaque   2      15m
```

```
kubectl get secrets my-secrets -o yaml
```

```
apiVersion: v1
data:
  MINIO_ACCESS_KEY: Dk6VtcMZdAQ=
  MINIO_SECRET_KEY: krf7NZDusXotJ7JqxVGoaw==
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"MINIO_ACCESS_KEY":"Dk6VtcMZdAQ=","MINIO_SECRET_KEY":"krf7NZDusXotJ7JqxVGoaw=="},"kind":"Secret","metadata":{"annotations":{},"name":"my-secrets","namespace":"default"},"type":"Opaque"}
  creationTimestamp: "2023-10-05T08:30:37Z"
  name: my-secrets
  namespace: default
  resourceVersion: "9585"
  uid: 6d451b87-fbf7-4978-aaf6-cd0f2b2b9364
type: Opaque
```

```
rm minio-statefulset.yaml.old 
```

# Удаление кластера

После завершения работ: 

```
kind delete cluster
```

```
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane"]
```

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/

git pull ; git status

ls

git branch

git checkout -b kubernetes-volumes

git branch

mkdir kubernetes-volumes

# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-volumes/

# Далее:

git status

git add -A

git status

git commit -m "kubernetes-volumes"

git push --set-upstream origin kubernetes-volumes

git status

# И далее Pull Request, кнопка "Отправить на проверку ДЗ", мёрж после проверки.

# Если здесь нужно переключить обратно на ветку main, то:

git branch

git switch main

git branch

git status
```

# ТЕКСТ ДЛЯ PULL REQUEST:

# Выполнено ДЗ № kubernetes-volumes

 - [OK] Основное ДЗ
 - [OK] Задание со *

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям

## Как запустить проект:
 - kind create cluster
 - kubectl apply -f my-secrets.yaml
 - kubectl apply -f minio-statefulset.yaml
 - kubectl apply -f minio-headless-service.yaml  

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get и kubectl describe

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

