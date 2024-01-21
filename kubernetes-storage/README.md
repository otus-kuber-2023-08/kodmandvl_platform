# Подготовка

## Создание директории и копирование шаблона README

```
mkdir -p kubernetes-storage && cd kubernetes-storage/
cp -aiv ../README.md ./
```

## Создание кластера

Использовал [свой скриптик-обёртку для создания кластера Kubernetes в Yandex Cloud](https://github.com/kodmandvl/wrapper_scripts/blob/main/yc/yc_k8s_create_new.sh): 

```bash
$ yc_k8s_create_new.sh hwcsi 1.27 10.77.0.0/16 10.76.0.0/16 hwcsi-node-group 3
```

В этих строках в скрипте необходимо подставить имя линуксового пользователя и публичный ключ: 

```
  --metadata ssh-keys='your_user:ssh-rsa your_public_key comment_for_your_public_key' \
```

Версию Kubernetes взял 1.27. 

Для удобства еще и приложил данный скриптик создания кластера и скриптик получения кредов (yc_k8s_get_cred.sh) в kubernetes-storage.hw/ 

## Посмотреть:

```bash
# Получить реквизиты (если необходимо):
yc_k8s_get_cred.sh hwcsi
# Смотрим:
cat ~/.kube/config 
kubectx
kubectl get nodes -o wide
kubectl get all -A -o wide
kubectl get pods -A -o wide
```

```text
$ k get nodes -o wide
NAME                     STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
node1-hwcsi-node-group   Ready    <none>   12h   v1.27.3   10.128.0.6    178.154.200.10    Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
node2-hwcsi-node-group   Ready    <none>   12h   v1.27.3   10.128.0.27   178.154.207.206   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
node3-hwcsi-node-group   Ready    <none>   12h   v1.27.3   10.128.0.34   178.154.200.169   Ubuntu 20.04.6 LTS   5.4.0-165-generic   containerd://1.6.22
```

# Содержание

* Обычное домашнее задание: установить CSI-драйвер и протестировать функционал снапшотов 

# Задание

* Создать StorageClass для CSI Host Path Driver (на своей тестовой машине его нужно установить самостоятельно) 
* Создать объект PVC c именем storage-pvc
* Создать объект Pod c именем storage-pod
* Хранилище нужно смонтировать в /data

# Создать StorageClass для CSI Host Path Driver

## Сначала найдем и установим CSI Host Path драйвер:

Нашел [по ссылке](https://github.com/kubernetes-csi/csi-driver-host-path): 

```bash
cd ~/temp/
git clone git@github.com:kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path/deploy/kubernetes-1.27/
ls -alF
```

```text
$ ls -alF
..........
lrwxrwxrwx 1 dimka dimka   26 янв 19 01:08 deploy.sh -> ../util/deploy-hostpath.sh*
..........
```

```bash
./deploy.sh
```

```text
$ ./deploy.sh
applying RBAC rules
curl https://raw.githubusercontent.com/kubernetes-csi/external-provisioner/v3.6.3/deploy/kubernetes/rbac.yaml --output /tmp/tmp.ttnzRAJDZy/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.ttnzRAJDZy
serviceaccount/csi-provisioner created
role.rbac.authorization.k8s.io/external-provisioner-cfg created
clusterrole.rbac.authorization.k8s.io/external-provisioner-runner created
rolebinding.rbac.authorization.k8s.io/csi-provisioner-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-provisioner-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-attacher/v4.4.3/deploy/kubernetes/rbac.yaml --output /tmp/tmp.ttnzRAJDZy/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.ttnzRAJDZy
serviceaccount/csi-attacher created
role.rbac.authorization.k8s.io/external-attacher-cfg created
clusterrole.rbac.authorization.k8s.io/external-attacher-runner created
rolebinding.rbac.authorization.k8s.io/csi-attacher-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-attacher-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v6.3.3/deploy/kubernetes/csi-snapshotter/rbac-csi-snapshotter.yaml --output /tmp/tmp.ttnzRAJDZy/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.ttnzRAJDZy
serviceaccount/csi-snapshotter created
role.rbac.authorization.k8s.io/external-snapshotter-leaderelection created
clusterrole.rbac.authorization.k8s.io/external-snapshotter-runner created
rolebinding.rbac.authorization.k8s.io/external-snapshotter-leaderelection created
clusterrolebinding.rbac.authorization.k8s.io/csi-snapshotter-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-resizer/v1.9.3/deploy/kubernetes/rbac.yaml --output /tmp/tmp.ttnzRAJDZy/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.ttnzRAJDZy
serviceaccount/csi-resizer created
role.rbac.authorization.k8s.io/external-resizer-cfg created
clusterrole.rbac.authorization.k8s.io/external-resizer-runner configured
rolebinding.rbac.authorization.k8s.io/csi-resizer-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-resizer-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-health-monitor/v0.10.0/deploy/kubernetes/external-health-monitor-controller/rbac.yaml --output /tmp/tmp.ttnzRAJDZy/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.ttnzRAJDZy
serviceaccount/csi-external-health-monitor-controller created
role.rbac.authorization.k8s.io/external-health-monitor-controller-cfg created
clusterrole.rbac.authorization.k8s.io/external-health-monitor-controller-runner created
rolebinding.rbac.authorization.k8s.io/csi-external-health-monitor-controller-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-external-health-monitor-controller-role created
deploying hostpath components
   /home/dimka/share/csi-driver-host-path/deploy/kubernetes-1.27/hostpath/csi-hostpath-driverinfo.yaml
csidriver.storage.k8s.io/hostpath.csi.k8s.io created
   /home/dimka/share/csi-driver-host-path/deploy/kubernetes-1.27/hostpath/csi-hostpath-plugin.yaml
        using           image: registry.k8s.io/sig-storage/hostpathplugin:v1.12.1
        using           image: registry.k8s.io/sig-storage/csi-external-health-monitor-controller:v0.10.0
        using           image: registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.9.3
        using           image: registry.k8s.io/sig-storage/livenessprobe:v2.11.0
        using           image: registry.k8s.io/sig-storage/csi-attacher:v4.4.3
        using           image: registry.k8s.io/sig-storage/csi-provisioner:v3.6.3
        using           image: registry.k8s.io/sig-storage/csi-resizer:v1.9.3
        using           image: registry.k8s.io/sig-storage/csi-snapshotter:v6.3.3
serviceaccount/csi-hostpathplugin-sa created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-cluster-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-role created
statefulset.apps/csi-hostpathplugin created
   /home/dimka/share/csi-driver-host-path/deploy/kubernetes-1.27/hostpath/csi-hostpath-snapshotclass.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-hostpath-snapclass created
   /home/dimka/share/csi-driver-host-path/deploy/kubernetes-1.27/hostpath/csi-hostpath-testing.yaml
        using           image: docker.io/alpine/socat:1.7.4.3-r0
service/hostpath-service created
statefulset.apps/csi-hostpath-socat created
13:47:25 waiting for hostpath deployment to complete, attempt #0
13:47:35 waiting for hostpath deployment to complete, attempt #1
13:47:47 waiting for hostpath deployment to complete, attempt #2
13:47:58 waiting for hostpath deployment to complete, attempt #3
```

Видим statefulset-ы и сервис: 

```text
$ k get all -A | grep -i hostpath
default       pod/csi-hostpath-socat-0                  1/1     Running   0             4m33s
default       pod/csi-hostpathplugin-0                  8/8     Running   0             4m36s
default       service/hostpath-service   NodePort    10.76.168.105   <none>        10000:30035/TCP          4m34s
default     statefulset.apps/csi-hostpath-socat   1/1     4m34s
default     statefulset.apps/csi-hostpathplugin   1/1     4m37s
```

Через ketall видим больше деталей: 

```text
$ ketall | grep -i hostpath
endpoints/hostpath-service                                                                                  default          5m50s      
pod/csi-hostpath-socat-0                                                                                    default          5m50s      
pod/csi-hostpathplugin-0                                                                                    default          5m53s      
serviceaccount/csi-hostpathplugin-sa                                                                        default          5m54s      
service/hostpath-service                                                                                    default          5m50s      
controllerrevision.apps/csi-hostpath-socat-8669b6f5f4                                                       default          5m50s      
controllerrevision.apps/csi-hostpathplugin-65ff66bdb9                                                       default          5m53s      
statefulset.apps/csi-hostpath-socat                                                                         default          5m50s      
statefulset.apps/csi-hostpathplugin                                                                         default          5m53s      
lease.coordination.k8s.io/external-health-monitor-leader-hostpath-csi-k8s-io                                default          5m34s      
endpointslice.discovery.k8s.io/hostpath-service-cl7tw                                                       default          5m50s      
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-cluster-role                                        5m54s      
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-cluster-role                       5m54s      
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-cluster-role                                     5m54s      
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-cluster-role                                         5m54s      
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-cluster-role                                     5m54s      
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-role                                      default          5m53s      
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-role                     default          5m53s      
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-role                                   default          5m53s      
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-role                                       default          5m53s      
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-role                                   default          5m53s      
volumesnapshotclass.snapshot.storage.k8s.io/csi-hostpath-snapclass                                                           5m52s      
csidriver.storage.k8s.io/hostpath.csi.k8s.io                                                                                 5m56s      
```

## Теперь попробуем создать StorageClass для CSI Host Path Driver:

Посмотрим [примеры](https://github.com/kubernetes-csi/csi-driver-host-path/tree/master/examples), среди них есть [csi-storageclass.yaml](https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-storageclass.yaml): 

```bash
wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-storageclass.yaml
# Посмотрим:
cat csi-storageclass.yaml
# Применим:
kubectl apply -f csi-storageclass.yaml
```

```text
$ kubectl apply -f csi-storageclass.yaml
storageclass.storage.k8s.io/csi-hostpath-sc created
$ k get sc | grep -e ^NAME -e hostpath
NAME                           PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
csi-hostpath-sc                hostpath.csi.k8s.io             Delete          Immediate              true                   4m12s
```

# Создать объект PVC c именем storage-pvc

Там же в [примерах](https://github.com/kubernetes-csi/csi-driver-host-path/tree/master/examples), есть [вариант шаблона для PVC](https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-pvc.yaml): 

```bash
wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-pvc.yaml
# Переименуем и подправим файл:
mv csi-pvc.yaml storage-pvc.yaml
nano storage-pvc.yaml
# Переименовали PVC в соответствии с заданием.
# Также проверяем, что в спецификации storageClassName для нашего PVC - это csi-hostpath-sc, созданный выше.
# Применим манифест:
kubectl apply -f storage-pvc.yaml
```

```text
$ kubectl apply -f storage-pvc.yaml
persistentvolumeclaim/storage-pvc created
$ kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-a21b8a99-5cb6-435d-a8a7-74bb5019f509   2Gi        RWO            csi-hostpath-sc   4s
```

# Создать объект Pod c именем storage-pod

Там же в [примерах](https://github.com/kubernetes-csi/csi-driver-host-path/tree/master/examples), есть примеры приложений (подов) с volume-ами. Возьмем шаблон, подправим в соответствии с нашим заданием и именованиями ресурсов, после чего применим: 

```bash
wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-app.yaml
mv csi-app.yaml storage-pod.yaml
nano storage-pod.yaml
kubectl apply -f storage-pod.yaml
kubectl get pods/storage-pod -o wide
kubectl logs pods/storage-pod
kubectl exec -it pods/storage-pod -- /bin/bash
```

Чтобы задание стало еще интереснее и практичнее, я решил не просто создать какой-то обычный Pod, а Pod с инстансом СУБД PostgreSQL 16 (на основе моего образа kodmandvl/mypostgres16). Поэтому хранилище смонтировал не в /data , а в /pgdata . 

```text
$ kubectl apply -f storage-pod.yaml
pod/storage-pod created
$ kubectl get pods/storage-pod -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP             NODE                     NOMINATED NODE   READINESS GATES
storage-pod   1/1     Running   0          31s   10.77.130.15   node2-hwcsi-node-group   <none>           <none>
$ kubectl logs pods/storage-pod

/pgdata/16/data directory does not exist

Create /pgdata/16/data directory

/pgdata/16/data directory is empty

Init database instance

.........................

Success. You can now start the database server using:

    pg_ctl -D /pgdata/16/data -l logfile start

.........................

Starting Postgres database instance

2024-01-20 17:00:43.745 MSK [23] LOG:  redirecting log output to logging collector process
2024-01-20 17:00:43.745 MSK [23] HINT:  Future log output will appear in directory "log".
$ kubectl exec pods/storage-pod -- df -Th | grep -e ^Filesystem -e [/]pgdata
Filesystem     Type     Size  Used Avail Use% Mounted on
/dev/vda2      ext4      63G   11G   50G  18% /pgdata
```

# Протестировать функционал снапшотов

```text
$ kubectl exec pods/storage-pod -- psql -c "create table mytable as select 'Hello' t, now() d;"
SELECT 1
$ kubectl exec pods/storage-pod -- psql -c "insert into mytable(t,d) select 'Hi' t, now() d;"
INSERT 0 1
$ kubectl exec pods/storage-pod -- psql -c "insert into mytable(t,d) select 'Guten Tag' t, now() d;"
INSERT 0 1
$ kubectl exec pods/storage-pod -- psql -c "insert into mytable(t,d) select 'Привет' t, now() d;"
INSERT 0 1
$ kubectl exec pods/storage-pod -- psql -c "select * from mytable order by d;"
     t     |               d               
-----------+-------------------------------
 Hello     | 2024-01-20 17:21:57.630227+03
 Hi        | 2024-01-20 17:23:26.246383+03
 Guten Tag | 2024-01-20 17:23:48.986382+03
 Привет    | 2024-01-20 17:24:01.986605+03
(4 rows)

$ kubectl exec -it pods/storage-pod -- /bin/bash
[storage-pod:~]$ echo "myapp.currency = 'RUB'" >> /pgdata/16/data/postgresql.conf
[storage-pod:~]$ cat /pgdata/16/data/postgresql.conf | tail -n 8
# Add parameters to postgresql.conf file:
listen_addresses = '*'
port = 5432
max_connections = 256
superuser_reserved_connections = 5
password_encryption = 'scram-sha-256'

myapp.currency = 'RUB'
[storage-pod:~]$ pg_ctl status
pg_ctl: server is running (PID: 23)
/usr/pgsql-16/bin/postgres "-D" "/pgdata/16/data"
[storage-pod:~]$ pg_ctl stop
waiting for server to shut down.... done
server stopped
[storage-pod:~]$ exit
exit
```

Таким образом, мы создали тестовую таблицу mytable с 4 строками, добавили некий воображаемый прикладной параметр myapp.currency в файл параметров PostgreSQL, остановили инстанс СУБД. 

В моем образе PostgreSQL 16 (учебно-тестовом) при выключении инстанса СУБД скрипт entrypoint.sh для контейнера еще продолжает работать 15 минут (sleep): 

```text
$ kubectl logs pods/storage-pod | tail -n 5

2024-01-20 17:00:43.745 MSK [23] LOG:  redirecting log output to logging collector process
2024-01-20 17:00:43.745 MSK [23] HINT:  Future log output will appear in directory "log".

Postgres database instance is stopped or restarted, wait 15 minutes before stop container...
```

Соответственно, с файлами в /pgdata больше никаких изменений уже не происходит. 

Возьмем и подредактируем пример для снятия снапшота, после чего сделаем снапшот:

```bash
wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-snapshot-v1.yaml
mv -v csi-snapshot-v1.yaml csi-snapshot.yaml
nano csi-snapshot.yaml
kubectl apply -f csi-snapshot.yaml
```

```text
$ kubectl apply -f csi-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/csi-snapshot created
$ kubectl get volumesnapshots
NAME           READYTOUSE   SOURCEPVC     SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS            SNAPSHOTCONTENT                                    CREATIONTIME   AGE
csi-snapshot   true         storage-pvc                           2Gi           csi-hostpath-snapclass   snapcontent-4fb88055-330a-45af-939b-009c227b9915   92s            93s
```

Удаляем storage-pod и storage-pvc: 

```bash
kubectl delete -f storage-pvc.yaml -f storage-pod.yaml
```

```text
$ kubectl delete -f storage-pvc.yaml -f storage-pod.yaml
persistentvolumeclaim "storage-pvc" deleted
pod "storage-pod" deleted
```

Попробуем создать storage-pvc из снапшота (перед этим скачав и подредактировав манифест csi-restore.yaml из примеров): 

```bash
wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/examples/csi-restore.yaml
nano csi-restore.yaml
kubectl apply -f csi-restore.yaml
```

```text
$ kubectl apply -f csi-restore.yaml
persistentvolumeclaim/storage-pvc created
```

Пересоздадим наш storage-pod: 

```bash
kubectl apply -f storage-pod.yaml
```

```text
$ kubectl apply -f storage-pod.yaml
pod/storage-pod created
```

Посомтрим логи (если всё правильно, должен быть создан не новый инстанс СУБД, а подняться существующий): 

```text
$ kubectl logs pods/storage-pod

/pgdata/16/data directory exists

/pgdata/16/data directory is not empty

Starting Postgres database instance

2024-01-20 18:07:20.133 MSK [9] FATAL:  data directory "/pgdata/16/data" has invalid permissions
2024-01-20 18:07:20.133 MSK [9] DETAIL:  Permissions should be u=rwx (0700) or u=rwx,g=rx (0750).

Postgres database instance is stopped or restarted, wait 15 minutes before stop container...
```

Момент, что права у /pgdata/16/data поменялись после восстановления из снапшота, я учесть, к сожалению, не смог. Попробуем вручную подправить права, запустить инстанс СУБД, проверить наличие таблицы с данными и нашего добавленного параметра (у нас есть 15 минут до перезапуска контейнера): 

```text
$ kubectl exec -it pods/storage-pod -- /bin/bash
[storage-pod:~]$ ls -alF /pgdata/16/
total 12
drwxrwsr-x  3 postgres postgres 4096 Jan 20 18:06 ./
drwxrwsr-x  3 root     postgres 4096 Jan 20 18:06 ../
drwxrws--- 20 postgres postgres 4096 Jan 20 18:06 data/
[storage-pod:~]$ chmod 750 /pgdata/16/data
[storage-pod:~]$ pg_ctl start
waiting for server to start....2024-01-20 18:16:21.288 MSK [63] LOG:  redirecting log output to logging collector process
2024-01-20 18:16:21.288 MSK [63] HINT:  Future log output will appear in directory "log".
 done
server started
[storage-pod:~]$ psql -c "select * from mytable;"
     t     |               d               
-----------+-------------------------------
 Hello     | 2024-01-20 17:21:57.630227+03
 Hi        | 2024-01-20 17:23:26.246383+03
 Guten Tag | 2024-01-20 17:23:48.986382+03
 Привет    | 2024-01-20 17:24:01.986605+03
(4 rows)

[storage-pod:~]$ psql -c "show myapp.currency;"
 myapp.currency 
----------------
 RUB
(1 row)

[storage-pod:~]$ tail -n 8 /pgdata/16/data/postgresql.conf 
# Add parameters to postgresql.conf file:
listen_addresses = '*'
port = 5432
max_connections = 256
superuser_reserved_connections = 5
password_encryption = 'scram-sha-256'

myapp.currency = 'RUB'
[storage-pod:~]$ exit
exit
```

Таким образом, видим, что с восстановленным снапшотом всё в порядке, все наши данные (как текстовые, так и настоящая база данных) были успешно сохранены, тестирование снапшотов успешно проведено. 

Кстати, через 15 минут, когда выполнился рестарт пода, инстанс СУБД (теперь уже с исправленными правами на директорию /pgdata/16/data) успешно запустился и работает самостоятельно без нашей помощи (опять же, с нашими же данными): 

```text
$ kubectl logs pods/storage-pod

/pgdata/16/data directory exists

/pgdata/16/data directory is not empty

Starting Postgres database instance

2024-01-20 18:22:20.404 MSK [10] LOG:  redirecting log output to logging collector process
2024-01-20 18:22:20.404 MSK [10] HINT:  Future log output will appear in directory "log".
```

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-storage
git branch
mkdir kubernetes-storage
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-storage/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-storage"
git push --set-upstream origin kubernetes-storage
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

# Выполнено ДЗ № kubernetes-storage

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - kubectl apply -f имя-файла.yaml

## Как проверить работоспособность:
 - Выполнить приведенные выше команды kubectl get, kubectl logs, kubectl exec

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-storage отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/14 



Спасибо!
С уважением, Корнев Дмитрий