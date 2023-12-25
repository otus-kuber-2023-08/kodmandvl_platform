# Подготовка

Ветка для данного ДЗ: kubernetes-prod 

```
mkdir -p kubernetes-prod && cd kubernetes-prod/
cp -aiv ../README.md ./
```

В этом ДЗ через kubeadm мы поднимем кластер версии 1.23 и обновим его. 

## Создание нод для кластера

В YC создайте 4 ноды с образом Ubuntu 20.04 LTS: 

* master - 1 экземпляр (intel ice lake, 2vCPU, 8 GB RAM)
* worker - 3 экземпляра (intel ice lake, 2vCPU, 8 GB RAM)

Я взял свои скрипты-обёртки для создания виртуальных машин: 

* скрипт [yc_vm_create_prod.sh](https://github.com/kodmandvl/wrapper_scripts/blob/main/yc/yc_vm_create_prod.sh) для создания ВМ на SSD-дисках (для master-ноды)
* скрипт [yc_vm_create.sh](https://github.com/kodmandvl/wrapper_scripts/blob/main/yc/yc_vm_create.sh) для создания ВМ на HDD-дисках (для worker-нод)

На их основе сделал новый подходящий для задачи скрипт [yc_vm_create_new.sh](https://github.com/kodmandvl/wrapper_scripts/blob/main/yc/yc_vm_create_new.sh). 

Для использования скриптов нужно подправить файл users.yaml (добавить своего пользователя/пользователей и публичный ключ/ключи). 

Идентификатор образа Ubuntu 20.04 LTS при создании ВМ в YC: 

* `family_id: ubuntu-2004-lts`

Запуск создания ВМ: 

```bash
cd wrapper_scripts/yc/
nano users.yaml
./yc_vm_create_new.sh master1 ubuntu-2004-lts ./users.yaml
./yc_vm_create_new.sh worker1 ubuntu-2004-lts ./users.yaml
./yc_vm_create_new.sh worker2 ubuntu-2004-lts ./users.yaml
./yc_vm_create_new.sh worker3 ubuntu-2004-lts ./users.yaml
```

Список машин: 

```text
$ ./yc_vm_list.sh                                           

LIST VM:

+----------------------+---------+---------------+---------+-----------------+-------------+
|          ID          |  NAME   |    ZONE ID    | STATUS  |   EXTERNAL IP   | INTERNAL IP |
+----------------------+---------+---------------+---------+-----------------+-------------+
| fhm3q04206k3s18cd1d5 | worker1 | ru-central1-a | RUNNING | 62.84.117.31    | 10.128.0.18 |
| fhmgpmlj68rarqb6282l | worker3 | ru-central1-a | RUNNING | 158.160.97.19   | 10.128.0.10 |
| fhmpk26dq4hik3bcsl4i | master1 | ru-central1-a | RUNNING | 158.160.58.220  | 10.128.0.32 |
| fhmrka8r1j6n5os7ql7n | worker2 | ru-central1-a | RUNNING | 158.160.103.192 | 10.128.0.12 |
+----------------------+---------+---------------+---------+-----------------+-------------+


DONE.
```

Пример, конечно, тестовый и не планируется настраивать различные удобства и защиту, но, по крайней мере, поменял имя хостов на совпадающее с именами ВМ, поменял порт SSH с 22-го на какой-то абстрактный другой и еще кое-какие настройки добавил/проверил: 

```bash
# (на всех 4 машинах)
sudo su -
hostnamectl set-hostname <удобное-имя-хоста-совпадающее-с-именем-виртуалки>
cp -aiv /etc/ssh/sshd_config /etc/ssh/sshd_config.begin.bak
cat /etc/ssh/sshd_config
cat /etc/ssh/sshd_config | grep -i -e Port -e PasswordAuthentication -e PermitRootLogin -e PermitEmptyPasswords | sort -u
cat /etc/ssh/sshd_config | grep -i -e Port -e PasswordAuthentication -e PermitRootLogin -e PermitEmptyPasswords | grep -v ^# | sort -u
sed -i '/PasswordAuthentication/s/^.*PasswordAuthentication.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i '/Port.22/s/^.*Port.22.*$/Port 6142/' /etc/ssh/sshd_config
sed -i '/PermitRootLogin/s/^.*PermitRootLogin.*$/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i '/PermitEmptyPasswords/s/^.*PermitEmptyPasswords.*$/PermitEmptyPasswords no/' /etc/ssh/sshd_config
diff /etc/ssh/sshd_config /etc/ssh/sshd_config.begin.bak
cat /etc/ssh/sshd_config | grep -i -e Port -e PasswordAuthentication -e PermitRootLogin -e PermitEmptyPasswords | grep -v ^# | sort -u
systemctl restart ssh.service
exit
```

Подправил свой конфигурационный файл для Ansible в домашней директории, а в текущей директории создал такой файл hosts.ini, чтобы какие-то вещи можно было проверять/пробегать сразу ансиблом по всем хостам: 

```text
[masters]
master1 ansible_host=158.160.58.220 ansible_port=6142
[workers]
worker1 ansible_host=62.84.117.31 ansible_port=6142
worker2 ansible_host=158.160.103.192 ansible_port=6142
worker3 ansible_host=158.160.97.19 ansible_port=6142
```

Проверил коннект и что всё соответствует ожидаемому: 

```text
$ ansible all -i hosts.ini -m ping                                               
worker2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
worker1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
master1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
worker3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
$ ansible all -i hosts.ini -m shell -a "hostname"
worker2 | CHANGED | rc=0 >>
worker2
worker1 | CHANGED | rc=0 >>
worker1
master1 | CHANGED | rc=0 >>
master1
worker3 | CHANGED | rc=0 >>
worker3
```

В идеале еще бы нужно назначить статические IP-адреса для машин, т.к. после остановки и повторного запуска ВМ в YC они с высокой вероятностью получат другой внешний IP-адрес, но для тестового задания этот момент опустим (тем более, что машин у нас 4, а [в пробном периоде можно использовать только 2 статических адреса](https://cloud.yandex.ru/ru/docs/free-trial/concepts/limits#vpc-quotas)). 

## Подготовка машин

Отключите на машинах swap: 

```bash
ansible all -i hosts.ini -m shell -a "cat /etc/fstab"
ansible all -i hosts.ini -m shell -a "cat /etc/fstab | grep -i swap"
ansible all -i hosts.ini -m shell -a "cat /proc/meminfo | grep -i swap"
```

В общем-то на данных ВМ swap не включен (в fstab он не прописан и /proc/meminfo показывает, что swap 0 kB: 

```text
..........
master1 | CHANGED | rc=0 >>
SwapCached:            0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
..........
```

Но пройдёмся в соответствии с инструкцией: 

```bash
ansible all -i hosts.ini -m shell -a "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
ansible all -i hosts.ini -m shell -a "sudo swapoff -a"
```

```text
$ ansible all -i hosts.ini -m shell -a "cat /etc/fstab | grep -v -e ^# -e ^$"
worker1 | CHANGED | rc=0 >>
UUID=be2c7c06-cc2b-4d4b-96c6-e3700932b129 /               ext4    errors=remount-ro 0       1
worker3 | CHANGED | rc=0 >>
UUID=be2c7c06-cc2b-4d4b-96c6-e3700932b129 /               ext4    errors=remount-ro 0       1
worker2 | CHANGED | rc=0 >>
UUID=be2c7c06-cc2b-4d4b-96c6-e3700932b129 /               ext4    errors=remount-ro 0       1
master1 | CHANGED | rc=0 >>
UUID=be2c7c06-cc2b-4d4b-96c6-e3700932b129 /               ext4    errors=remount-ro 0       1
$ ansible all -i hosts.ini -m shell -a "sudo swapoff -a"                     
master1 | CHANGED | rc=0 >>

worker2 | CHANGED | rc=0 >>

worker1 | CHANGED | rc=0 >>

worker3 | CHANGED | rc=0 >>
```

## Включаем маршрутизацию

```bash
# (на всех машинах)
sudo su -
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
cat /etc/sysctl.d/99-kubernetes-cri.conf
# Apply sysctl params without reboot
sysctl --system
exit
```

## Загрузим br_netfilter и позволим iptables видеть трафик

```bash
# (на всех машинах)
sudo su -
modprobe overlay
modprobe br_netfilter
tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
cat /etc/sysctl.d/kubernetes.conf
# Apply sysctl params without reboot
sysctl --system
exit
```

Обратил внимание, что одни и те же параметры мы прописали в два разных файла, я думаю, что достаточно было бы одного расположения. 

Не очень понятно пока, зачем так, но пусть будет: кашу маслом не испортишь. 

# Установим Containerd

```bash
# (на всех машинах)
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
cat /etc/modules-load.d/containerd.conf
sudo modprobe overlay
sudo modprobe br_netfilter
# Setup required sysctl params, these persist across reboots (уже ранее выше было выполнено, поэтому ниже эти шаги с /etc/sysctl.d/99-kubernetes-cri.conf и sysctl --system убрал из скрипта)
# Install and configure containerd:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# Start containerd:
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
```

# Установим kubectl, kubeadm, kubelet

Установим версию 1.23, данные команды необходимо выполнить на всех нодах. 

```bash
# (на всех машинах)
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update -y
sudo apt -y install vim git curl wget kubelet=1.23.0-00 kubeadm=1.23.0-00 kubectl=1.23.0-00
sudo apt-mark hold kubelet kubeadm kubectl
sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock --kubernetes-version v1.23.0
```

```text
myuser@master1:~$ sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock --kubernetes-version v1.23.0
[config/images] Pulled k8s.gcr.io/kube-apiserver:v1.23.0
[config/images] Pulled k8s.gcr.io/kube-controller-manager:v1.23.0
[config/images] Pulled k8s.gcr.io/kube-scheduler:v1.23.0
[config/images] Pulled k8s.gcr.io/kube-proxy:v1.23.0
[config/images] Pulled k8s.gcr.io/pause:3.6
[config/images] Pulled k8s.gcr.io/etcd:3.5.1-0
[config/images] Pulled k8s.gcr.io/coredns/coredns:v1.8.6
```

Также периодически хотелось бы еще через ifconfig смотреть сетевые интерфейсы, поэтому: 

```bash
# (на всех машинах)
sudo apt install -y net-tools
ifconfig
```

# Создание кластера

Создадим и настроим мастер ноду при помощи kubeadm, для этого на ней выполним: 

```bash
# (на master-ноде master1)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --kubernetes-version=v1.23.0 --ignore-preflight-errors=Mem --cri-socket /run/containerd/containerd.sock
```

В выводе будут: 

* команда для копирования конфига `kubectl`
* сообщение о том, что необходимо установить сетевой плагин
* команда для присоединения worker ноды

Ниже текст вывода команды создания кластера (часть, особенно с токеном, заменена многоточиями): 

```text
myuser@master1:~$ sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --kubernetes-version=v1.23.0 --ignore-preflight-errors=Mem --cri-socket /run/containerd/containerd.sock
[init] Using Kubernetes version: v1.23.0
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local master1] and IPs [10.96.0.1 10.128.0.32]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost master1] and IPs [10.128.0.32 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost master1] and IPs [10.128.0.32 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 12.502066 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.23" in namespace kube-system with the configuration for the kubelets in the cluster
NOTE: The "kubelet-config-1.23" naming of the kubelet ConfigMap is deprecated. Once the UnversionedKubeletConfigMap feature gate graduates to Beta the default name will become just "kubelet-config". Kubeadm upgrade will handle this transition transparently.
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
..................................................
[mark-control-plane] Marking the node master1 as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node master1 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: ..........
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.128.0.32:6443 --token .......... \
	--discovery-token-ca-cert-hash ..........
```

Сохранил весь вывод команды, в т.ч. токен, в надёжном месте. 

Как и было указано в выводе команды, скопировал себе kubeconfig и посмотрел get nodes: 

```bash
# (на master-ноде master1)
mkdir -p $HOME/.kube
sudo cp -iv /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl version
kubectl cluster-info
kubectl get nodes
```

```text
myuser@master1:~$ kubectl version
Client Version: version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.0", GitCommit:"ab69524f795c42094a6630298ff53f3c3ebab7f4", GitTreeState:"clean", BuildDate:"2021-12-07T18:16:20Z", GoVersion:"go1.17.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.0", GitCommit:"ab69524f795c42094a6630298ff53f3c3ebab7f4", GitTreeState:"clean", BuildDate:"2021-12-07T18:09:57Z", GoVersion:"go1.17.3", Compiler:"gc", Platform:"linux/amd64"}
myuser@master1:~$ kubectl cluster-info
Kubernetes control plane is running at https://10.128.0.32:6443
CoreDNS is running at https://10.128.0.32:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
myuser@master1:~$ kubectl get nodes
NAME      STATUS     ROLES                  AGE   VERSION
master1   NotReady   control-plane,master   24m   v1.23.0
```

# Установим сетевой плагин

После инициализации кластера `kubeadm` требуется сетевой плагин для сетевой связанности между подами ([документация](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network)). 

В этом ДЗ в качестве примера мы установим Flannel, Вы можете установить и любой другой. 

```bash
# (на master-ноде master1)
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kubeflannel.yml
```

Ошибка: 

```text
myuser@master1:~$ kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kubeflannel.yml
error: unable to read URL "https://github.com/coreos/flannel/raw/master/Documentation/kubeflannel.yml", server reported 404 Not Found, status code=404
```

Нужно найти актуальную ссылку. 

Попрбуем так: 

```bash
# (на master-ноде master1)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl get nodes -o wide
```

Теперь успех, ссылка актуальная, нужные ресурсы созданы, теперь наша master-нода в статусе `Ready`: 

```text
myuser@master1:~$ kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
namespace/kube-flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created
myuser@master1:~$ kubectl get nodes -o wide
NAME      STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready    control-plane,master   33m   v1.23.0   10.128.0.32   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
```

# Подключаем worker-ноды

Установите на worker ноды docker, включите маршрутизацию, выключите swap, установите kubeadm, kubelet, kubectl и выполните kubeadm join на worker нодах. 

Указанные подготовительные шаги были выполнены мной на всех нодах, поэтому сейчас нужно сразу выполнить kubeadm join: 

```bash
# (на worker-нодах)
# Then you can join any number of worker nodes by running the following on each as root:
sudo su -
kubeadm join 10.128.0.32:6443 --token .......... --discovery-token-ca-cert-hash sha256:..........
```

Пример вывода с worker-ноды worker3: 

```text
myuser@worker3:~$ sudo su -
root@worker3:~# kubeadm join 10.128.0.32:6443 --token .......... --discovery-token-ca-cert-hash sha256:..........
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W1223 22:45:40.633102   18721 utils.go:69] The recommended value for "resolvConf" in "KubeletConfiguration" is: /run/systemd/resolve/resolv.conf; the provided value is: /run/systemd/resolve/resolv.conf
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

После присоединения worker-нод на master-ноде master1 смотрим: 

```text
myuser@master1:~$ kubectl get nodes
NAME      STATUS   ROLES                  AGE     VERSION
master1   Ready    control-plane,master   50m     v1.23.0
worker1   Ready    <none>                 3m38s   v1.23.0
worker2   Ready    <none>                 3m18s   v1.23.0
worker3   Ready    <none>                 3m5s    v1.23.0
myuser@master1:~$ kubectl get nodes -o wide
NAME      STATUS   ROLES                  AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready    control-plane,master   50m     v1.23.0   10.128.0.32   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker1   Ready    <none>                 3m39s   v1.23.0   10.128.0.18   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker2   Ready    <none>                 3m19s   v1.23.0   10.128.0.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker3   Ready    <none>                 3m6s    v1.23.0   10.128.0.10   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
```

Если бы вывод команды `kubeadm init` потерялся, токены можно было бы посмотреть командой: 

```bash
kubeadm token list
```

Получить хэш можно было бы так: 

```bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
openssl dgst -sha256 -hex | sed 's/^.* //'
```

Я проверил - токен и хэш, полученные таким образом, совпадают с приведёнными в выводе `kubeadm init`. 

# Запуск нагрузки

Для демонстрации работы кластера запустим nginx, файл nginx-deployment.yaml (я взял свой кастомный образ nginx по мотивам прошлых ДЗ): 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 4
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: docker.io/kodmandvl/mynginx:v5
        ports:
        - containerPort: 8080
```

```bash
# (на master-ноде master1)
nano nginx-deployment.yaml
kubectl apply -f nginx-deployment.yaml
kubectl get po
kubectl get po -o wide
```

```text
myuser@master1:~$ nano nginx-deployment.yaml
myuser@master1:~$ kubectl apply -f nginx-deployment.yaml
deployment.apps/nginx-deployment created
myuser@master1:~$ kubectl get po
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-7c5b6db49b-4wpht   1/1     Running   0          2m21s
nginx-deployment-7c5b6db49b-crgp8   1/1     Running   0          2m21s
nginx-deployment-7c5b6db49b-fwrtj   1/1     Running   0          2m21s
nginx-deployment-7c5b6db49b-rlrth   1/1     Running   0          2m21s
myuser@master1:~$ kubectl get po -o wide
NAME                                READY   STATUS    RESTARTS   AGE     IP           NODE      NOMINATED NODE   READINESS GATES
nginx-deployment-7c5b6db49b-4wpht   1/1     Running   0          2m25s   10.244.1.2   worker1   <none>           <none>
nginx-deployment-7c5b6db49b-crgp8   1/1     Running   0          2m25s   10.244.2.2   worker2   <none>           <none>
nginx-deployment-7c5b6db49b-fwrtj   1/1     Running   0          2m25s   10.244.3.2   worker3   <none>           <none>
nginx-deployment-7c5b6db49b-rlrth   1/1     Running   0          2m25s   10.244.3.3   worker3   <none>           <none>
myuser@master1:~$ ifconfig
cni0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1450
        inet 10.244.0.1  netmask 255.255.255.0  broadcast 10.244.0.255
        inet6 fe80::9cf0:8bff:fe4f:2e67  prefixlen 64  scopeid 0x20<link>
        ether 9e:f0:8b:4f:2e:67  txqueuelen 1000  (Ethernet)
        RX packets 4021  bytes 337744 (337.7 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4807  bytes 450005 (450.0 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.128.0.32  netmask 255.255.255.0  broadcast 10.128.0.255
        inet6 fe80::d20d:19ff:fea0:8cdd  prefixlen 64  scopeid 0x20<link>
        ether d0:0d:19:a0:8c:dd  txqueuelen 1000  (Ethernet)
        RX packets 64751  bytes 405821468 (405.8 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 39936  bytes 6885786 (6.8 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

flannel.1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1450
        inet 10.244.0.0  netmask 255.255.255.255  broadcast 0.0.0.0
        inet6 fe80::5482:adff:feea:b75f  prefixlen 64  scopeid 0x20<link>
        ether 56:82:ad:ea:b7:5f  txqueuelen 0  (Ethernet)
        RX packets 5  bytes 600 (600.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 7  bytes 451 (451.0 B)
        TX errors 0  dropped 15 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 589491  bytes 101324704 (101.3 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 589491  bytes 101324704 (101.3 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

veth08c0078d: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1450
        inet6 fe80::8c3b:1cff:fea8:97ab  prefixlen 64  scopeid 0x20<link>
        ether 8e:3b:1c:a8:97:ab  txqueuelen 0  (Ethernet)
        RX packets 2024  bytes 197675 (197.6 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2399  bytes 223813 (223.8 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

vethd154ae70: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1450
        inet6 fe80::9cc8:9dff:fed2:cf1a  prefixlen 64  scopeid 0x20<link>
        ether 9e:c8:9d:d2:cf:1a  txqueuelen 0  (Ethernet)
        RX packets 1999  bytes 196447 (196.4 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2467  bytes 230646 (230.6 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

myuser@master1:~$ curl 10.244.1.2:8080
You've hit nginx-deployment-7c5b6db49b-4wpht (IP: 10.244.1.2, STARTED: 2023-12-24 02:02:46 MSK)
myuser@master1:~$ curl 10.244.2.2:8080
You've hit nginx-deployment-7c5b6db49b-crgp8 (IP: 10.244.2.2, STARTED: 2023-12-24 02:02:46 MSK)
myuser@master1:~$ curl 10.244.3.2:8080
You've hit nginx-deployment-7c5b6db49b-fwrtj (IP: 10.244.3.2, STARTED: 2023-12-24 02:02:46 MSK)
myuser@master1:~$ curl 10.244.3.3:8080
You've hit nginx-deployment-7c5b6db49b-rlrth (IP: 10.244.3.3, STARTED: 2023-12-24 02:02:48 MSK)
```

# Обновление кластера

Так как кластер мы разворачивали с помощью kubeadm, то и производить обновление будем с помощью него. 

Обновлять ноды будем по очереди. 

## Обновление мастера

Допускается отставание версий worker-нод от master, но не наоборот. 

Поэтому обновление будем начинать с master-ноды, она у нас версии 1.23.0. 

Обновление пакетов: 

```bash
# (на master-ноде master1)
sudo su -
apt update
apt-cache madison kubeadm
apt-cache madison kubeadm | grep 1.24
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm=1.24.17-00 && \
apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v1.24.17
```

Результат выполнения последних двух команд: 

```text
root@master1:~# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W1223 23:19:02.881097   27218 initconfiguration.go:120] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/run/containerd/containerd.sock". Please update your configuration!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.23.0
[upgrade/versions] kubeadm version: v1.24.17
I1223 23:19:06.532957   27218 version.go:256] remote version is much newer: v1.29.0; falling back to: stable-1.24
[upgrade/versions] Target version: v1.24.17
[upgrade/versions] Latest version in the v1.23 series: v1.23.17

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     4 x v1.23.0   v1.23.17

Upgrade to the latest version in the v1.23 series:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.23.0   v1.23.17
kube-controller-manager   v1.23.0   v1.23.17
kube-scheduler            v1.23.0   v1.23.17
kube-proxy                v1.23.0   v1.23.17
CoreDNS                   v1.8.6    v1.8.6
etcd                      3.5.1-0   3.5.6-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.23.17

_____________________________________________________________________

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     4 x v1.23.0   v1.24.17

Upgrade to the latest stable version:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.23.0   v1.24.17
kube-controller-manager   v1.23.0   v1.24.17
kube-scheduler            v1.23.0   v1.24.17
kube-proxy                v1.23.0   v1.24.17
CoreDNS                   v1.8.6    v1.8.6
etcd                      3.5.1-0   3.5.6-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.24.17

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

root@master1:~# kubeadm upgrade apply v1.24.17
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W1223 23:19:50.118246   27508 initconfiguration.go:120] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/run/containerd/containerd.sock". Please update your configuration!
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.24.17"
[upgrade/versions] Cluster version: v1.23.0
[upgrade/versions] kubeadm version: v1.24.17
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.24.17" (timeout: 5m0s)...
[upgrade/etcd] Upgrading to TLS for etcd
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-12-23-23-21-17/etcd.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=etcd
[upgrade/staticpods] Component "etcd" upgraded successfully!
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests1242072195"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-12-23-23-21-17/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-12-23-23-21-17/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-12-23-23-21-17/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upgrade/postupgrade] Removing the deprecated label node-role.kubernetes.io/master='' from all control plane Nodes. After this step only the label node-role.kubernetes.io/control-plane='' will be present on control plane Nodes.
[upgrade/postupgrade] Adding the new taint &Taint{Key:node-role.kubernetes.io/control-plane,Value:,Effect:NoSchedule,TimeAdded:<nil>,} to all control plane Nodes. After this step both taints &Taint{Key:node-role.kubernetes.io/control-plane,Value:,Effect:NoSchedule,TimeAdded:<nil>,} and &Taint{Key:node-role.kubernetes.io/master,Value:,Effect:NoSchedule,TimeAdded:<nil>,} should be present on control plane Nodes.
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.24.17". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

## Проверка

`kubectl get nodes` все ноды должны быть готовы. 

Какая версия у мастер ноды? Почему? Какая версия у Api сервера, какая у kubelet? 

Мой вывод команды `kubectl get nodes` пока что отличается от примера из методических указаний, а именно: несмотря на успешное обновление, там указана версия 1.23, однако `kubectl version` показывает корректную версию для сервера): 

```text
myuser@master1:~$ kubectl get nodes
NAME      STATUS   ROLES           AGE   VERSION
master1   Ready    control-plane   93m   v1.23.0
worker1   Ready    <none>          46m   v1.23.0
worker2   Ready    <none>          46m   v1.23.0
worker3   Ready    <none>          46m   v1.23.0
myuser@master1:~$ kubectl version
Client Version: version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.0", GitCommit:"ab69524f795c42094a6630298ff53f3c3ebab7f4", GitTreeState:"clean", BuildDate:"2021-12-07T18:16:20Z", GoVersion:"go1.17.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"24", GitVersion:"v1.24.17", GitCommit:"22a9682c8fe855c321be75c5faacde343f909b04", GitTreeState:"clean", BuildDate:"2023-08-23T23:37:25Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}
```

## Обновим остальные компоненты кластера

Обновление компонентов кластера (API-server, kube-proxy, controllermanager) 

```bash
# (на master-ноде master1)
sudo su -
# просмотр изменений, которые собирает сделать kubeadm
kubeadm upgrade plan
```

```text
root@master1:~# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.24.17
[upgrade/versions] kubeadm version: v1.24.17
I1223 23:36:35.348670   33506 version.go:256] remote version is much newer: v1.29.0; falling back to: stable-1.24
[upgrade/versions] Target version: v1.24.17
[upgrade/versions] Latest version in the v1.24 series: v1.24.17
```

```bash
# (на master-ноде master1)
sudo su -
# применение изменений
kubeadm upgrade apply
kubeadm upgrade apply v1.24.17
```

```text
root@master1:~# kubeadm upgrade apply
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
missing one or more required arguments. Required arguments: [version]
To see the stack trace of this error execute with --v=5 or higher
root@master1:~# kubeadm upgrade apply v1.24.17
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.24.17"
[upgrade/versions] Cluster version: v1.24.17
[upgrade/versions] kubeadm version: v1.24.17
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.24.17" (timeout: 5m0s)...
[upgrade/etcd] Upgrading to TLS for etcd
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Current and new manifests of etcd are equal, skipping upgrade
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests3967947067"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Current and new manifests of kube-apiserver are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Current and new manifests of kube-controller-manager are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Current and new manifests of kube-scheduler are equal, skipping upgrade
[upgrade/postupgrade] Removing the deprecated label node-role.kubernetes.io/master='' from all control plane Nodes. After this step only the label node-role.kubernetes.io/control-plane='' will be present on control plane Nodes.
[upgrade/postupgrade] Adding the new taint &Taint{Key:node-role.kubernetes.io/control-plane,Value:,Effect:NoSchedule,TimeAdded:<nil>,} to all control plane Nodes. After this step both taints &Taint{Key:node-role.kubernetes.io/control-plane,Value:,Effect:NoSchedule,TimeAdded:<nil>,} and &Taint{Key:node-role.kubernetes.io/master,Value:,Effect:NoSchedule,TimeAdded:<nil>,} should be present on control plane Nodes.
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.24.17". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

Проверка: 

```bash
# (на master-ноде master1)
kubeadm version
kubelet --version
kubectl version
kubectl describe pod <Ваш под с API сервером> -n kube-system
```

Также обновил kubelet на master-ноде: 

```bash
# (на master-ноде master1)
sudo su -
apt update
apt-cache madison kubelet
apt-cache madison kubelet | grep 1.24
apt-mark unhold kubelet && \
apt-get update && apt-get install -y kubelet=1.24.17-00 && \
apt-mark hold kubelet
kubeadm upgrade plan
kubeadm upgrade apply v1.24.17
systemctl daemon-reload
systemctl restart kubelet.service
```

Также обновил kubectl на master-ноде: 

```bash
# (на master-ноде master1)
sudo su -
apt update
apt-cache madison kubectl
apt-cache madison kubectl | grep 1.24
apt-mark unhold kubectl && \
apt-get update && apt-get install -y kubectl=1.24.17-00 && \
apt-mark hold kubectl
kubeadm upgrade plan
kubeadm upgrade apply v1.24.17
```

Еще раз: 

```bash
# (на master-ноде master1)
kubeadm version
kubelet --version
kubectl version
kubectl describe pod kube-apiserver-master1 -n kube-system
```

И еще дополнительно, на всякий случай:  

```bash
# (на master-ноде master1)
sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock --kubernetes-version v1.24.17
```

```text
myuser@master1:~$ sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock --kubernetes-version v1.24.17
W1224 00:23:09.203756   49365 initconfiguration.go:120] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/run/containerd/containerd.sock". Please update your configuration!
[config/images] Pulled registry.k8s.io/kube-apiserver:v1.24.17
[config/images] Pulled registry.k8s.io/kube-controller-manager:v1.24.17
[config/images] Pulled registry.k8s.io/kube-scheduler:v1.24.17
[config/images] Pulled registry.k8s.io/kube-proxy:v1.24.17
[config/images] Pulled registry.k8s.io/pause:3.7
[config/images] Pulled registry.k8s.io/etcd:3.5.6-0
[config/images] Pulled registry.k8s.io/coredns/coredns:v1.8.6
```

Версия у master-ноды теперь обновлённая: 

```text
$ kubectl get nodes
NAME      STATUS   ROLES           AGE    VERSION
master1   Ready    control-plane   147m   v1.24.17
worker1   Ready    <none>          100m   v1.23.0
worker2   Ready    <none>          99m    v1.23.0
worker3   Ready    <none>          99m    v1.23.0
```

## Вывод worker-нод из планирования

Первым делом, мы сливаем всю нагрузку с ноды worker1 и выводим ее из планирования: 

```bash
kubectl drain worker1
```

`kubectl drain` убирает всю нагрузку, кроме DaemonSet, поэтому мы явно должны сказать, что уведомлены об этом: 

```bash
kubectl drain worker1 --ignore-daemonsets
```

`kubectl drain` возвращает управление только тогда, когда все поды выведены с ноды. 

## Обновление статуса worker-нод

Когда мы вывели ноду worker1 на обслуживание, к статусу добавилась строчка `SchedulingDisabled`: 

```text
myuser@master1:~$ kubectl get nodes -o wide
NAME      STATUS                     ROLES           AGE    VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready                      control-plane   158m   v1.24.17   10.128.0.32   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker1   Ready,SchedulingDisabled   <none>          111m   v1.23.0    10.128.0.18   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker2   Ready                      <none>          111m   v1.23.0    10.128.0.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker3   Ready                      <none>          111m   v1.23.0    10.128.0.10   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
```

## Обновление worker-нод

На worker-ноде worker1 выполняем: 

```bash
# (на worker-ноде worker1)
sudo su -
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm=1.24.17-00 && \
apt-mark hold kubeadm
sudo kubeadm upgrade node
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.24.17-00 kubectl=1.24.17-00 && \
apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## Просмотр обновления

После обновления kubectl показывает новую версию, и статус `SchedulingDisabled`: 

```text
myuser@master1:~$ kubectl get nodes
NAME      STATUS                     ROLES           AGE    VERSION
master1   Ready                      control-plane   164m   v1.24.17
worker1   Ready,SchedulingDisabled   <none>          117m   v1.24.17
worker2   Ready                      <none>          117m   v1.23.0
worker3   Ready                      <none>          117m   v1.23.0
```

## Возвращение ноды в планирование

Командой `kubectl uncordon worker1` возвращаем ноду обратно в планирование нагрузки: 

```bash
kubectl uncordon worker1
```

## Задание | Обновите оставшиеся ноды при помощи kubeadm

По аналогии обновил оставшиеся две worker-ноды. 

Выводил их из нагрузки и обновлял одновременно, т.к у нас worker-нода worker1 уже была обновлена и доступна (хотя правильнее с т.з. отказоустойчивости было бы обновлять их последоательно по одной, как обновляли worker1). 

Выполненные команды: 


```bash
kubectl drain worker2 --ignore-daemonsets
kubectl drain worker3 --ignore-daemonsets
kubectl get nodes -o wide
```

```text
myuser@master1:~$ kubectl get nodes -o wide
NAME      STATUS                     ROLES           AGE    VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready                      control-plane   179m   v1.24.17   10.128.0.32   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker1   Ready                      <none>          132m   v1.24.17   10.128.0.18   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker2   Ready,SchedulingDisabled   <none>          132m   v1.23.0    10.128.0.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker3   Ready,SchedulingDisabled   <none>          132m   v1.23.0    10.128.0.10   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
```

В этот момент видно, что нагрузка ушла с этих worker-нод и наш nginx только на worker1 работает: 

```text
$ kubectl get po -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
nginx-deployment-7c5b6db49b-cxzkn   1/1     Running   0          10m   10.244.1.6    worker1   <none>           <none>
nginx-deployment-7c5b6db49b-jbz7f   1/1     Running   0          10m   10.244.1.7    worker1   <none>           <none>
nginx-deployment-7c5b6db49b-jw4cq   1/1     Running   0          10m   10.244.1.9    worker1   <none>           <none>
nginx-deployment-7c5b6db49b-n6qhs   1/1     Running   0          10m   10.244.1.10   worker1   <none>           <none>
```

```bash
# (на worker-нодах worker2 и worker3)
sudo su -
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm=1.24.17-00 && \
apt-mark hold kubeadm
sudo kubeadm upgrade node
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.24.17-00 kubectl=1.24.17-00 && \
apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

```bash
kubectl get nodes
```

```bash
kubectl uncordon worker2
kubectl uncordon worker3
```

Результат: 

```text
$ kubectl get nodes
NAME      STATUS   ROLES           AGE    VERSION
master1   Ready    control-plane   3h4m   v1.24.17
worker1   Ready    <none>          137m   v1.24.17
worker2   Ready    <none>          136m   v1.24.17
worker3   Ready    <none>          136m   v1.24.17
```

Если удалить часть подов nginx, то они перезапустятся уже на обновленных worker-нодах: 

```text
myuser@master1:~$ kubectl delete po nginx-deployment-7c5b6db49b-jbz7f
pod "nginx-deployment-7c5b6db49b-jbz7f" deleted
myuser@master1:~$ kubectl delete po nginx-deployment-7c5b6db49b-jw4cq
pod "nginx-deployment-7c5b6db49b-jw4cq" deleted
myuser@master1:~$ kubectl delete po nginx-deployment-7c5b6db49b-n6qhs 
pod "nginx-deployment-7c5b6db49b-n6qhs" deleted
myuser@master1:~$ kubectl get po -o wide
NAME                                READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
nginx-deployment-7c5b6db49b-2jnw9   1/1     Running   0          34s    10.244.3.14   worker3   <none>           <none>
nginx-deployment-7c5b6db49b-bwnrp   1/1     Running   0          73s    10.244.3.13   worker3   <none>           <none>
nginx-deployment-7c5b6db49b-cxzkn   1/1     Running   0          17m    10.244.1.6    worker1   <none>           <none>
nginx-deployment-7c5b6db49b-qwd9l   1/1     Running   0          112s   10.244.2.5    worker2   <none>           <none>
```

# Автоматическое развертывание кластеров

В данном задании ради демонстрации механики обновления мы вручную развернули и обновили кластер с одной master-нодой. 

Но развертывать большие кластера подобным способом не удобно. 

Поэтому мы рассмотрим инструмент для автоматического развертывания кластеров: [kubespray](https://github.com/kubernetes-sigs/kubespray). 

Kubespray - это Ansible playbook для установки Kubernetes. 

Для его использования достаточно иметь SSH-доступ на машины, поэтому не важно, как они были созданы (Cloud, Bare metal). 

## Установка kubespray

Пре-реквизиты:

* Python и pip на локальной машине
* SSH доступ на все ноды кластера

```bash
# получение kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
# установка зависимостей (возьмем virtualenv):
pip3 install virtualenv
mkdir myapp && cd myapp
python3 -m virtualenv myenv
ls -F
# activate virtualenv:
source myenv/bin/activate
# deactivate virtualenv (по окончании работы с этой средой): deactivate
which python
which python3
pip3 install --upgrade pip
cat ~/kubespray/requirements.txt
pip3 install -r ~/kubespray/requirements.txt
# check:
which ansible
ansible --version
ansible all -i 127.0.0.1, -m ping -c local
ansible all -i 127.0.0.1, -m shell -a "whoami ; hostname -f ; hostname -i ; pwd" -c local
# копирование примера конфига в отдельную директорию
mkdir -p kubernetes-prod/inventory/
cp -rfp ~/kubespray/inventory/sample kubernetes-prod/inventory/mycluster
```

Добавьте адреса машин кластера в конфиг kubespray (inventory/mycluster/inventory.ini). 

## Установка кластера

После редактирования конфига можно устанавливать кластер: 

```bash
# (перед этим удостовериться, что применена наша virtualenv)
cd kubernetes-prod
export SSH_USERNAME=myuser
export SSH_PRIVATE_KEY=/path/to/private/key
# (также добавил в секцию [defaults] конфигурационного файла для Ansible параметр roles_path = ~/kubespray/roles, без него плейбук не работает)
# (также понабодились еще кое-какие настройки, см. ниже)
pip3 install ipaddr
pip3 install netaddr
ansible-playbook -i ./inventory/mycluster/inventory.ini \
--become --become-user=root --user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} \
~/kubespray/cluster.yml
```

Попробовал для интереса запустить сначала на тех же ВМ (чтобы посмотреть, сможет ли он обновить до той еще более свежей версии v1.28.5, которая по умолчанию ставится через kubespray, и вообще посмотреть, что будет). 

Эта версия файла с хостами сохранилась под именем old_inventory.ini. 

Результат (после ооочень долгого выполнения): 

```text
PLAY RECAP *******************************************************************************************
localhost                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
master1                    : ok=99   changed=20   unreachable=0    failed=1    skipped=95   rescued=0    ignored=0   
worker1                    : ok=408  changed=72   unreachable=0    failed=1    skipped=523  rescued=0    ignored=1   
worker2                    : ok=408  changed=72   unreachable=0    failed=1    skipped=523  rescued=0    ignored=1   
worker3                    : ok=408  changed=72   unreachable=0    failed=1    skipped=523  rescued=0    ignored=1   
```

Не все шаги прошли гладко, часть шагов завершились с ошибкой (но на запуск сценария поверх ручной установки я и не рассчитывал особо). 

Удалил виртуальные машины, пересоздал их заново (теми же скриптами, с теми же именами ВМ, с теми же параметрами и версией образа Ubuntu, но уже с другими выданными IP-адресами и без замены порта SSH), после чего уже на новых машинах плейбук запустил (файл inventory.ini): 

```text
yc_vm_list.sh 

LIST VM:

+----------------------+---------+---------------+---------+---------------+-------------+
|          ID          |  NAME   |    ZONE ID    | STATUS  |  EXTERNAL IP  | INTERNAL IP |
+----------------------+---------+---------------+---------+---------------+-------------+
| fhm3bkduf4mucolhicfe | master1 | ru-central1-a | RUNNING | 84.201.158.52 | 10.128.0.17 |
| fhm3m32h86tgb497r5hq | worker3 | ru-central1-a | RUNNING | 51.250.90.76  | 10.128.0.26 |
| fhmeecffnkpjeaeosnsr | worker2 | ru-central1-a | RUNNING | 51.250.67.23  | 10.128.0.9  |
| fhmfu09umbsn3rmeknuh | worker1 | ru-central1-a | RUNNING | 84.201.173.38 | 10.128.0.27 |
+----------------------+---------+---------------+---------+---------------+-------------+


DONE.
```

Запуск с новыми ВМ: 

```bash
source ~/myapp/myenv/bin/activate
which python
which python3
which ansible
pip3 install --upgrade pip
cat ~/kubespray/requirements.txt
pip3 install -r ~/kubespray/requirements.txt
cd kubernetes-prod
export SSH_USERNAME=myuser
export SSH_PRIVATE_KEY=/path/to/private/key
# (также добавил в секцию [defaults] конфигурационного файла для Ansible параметр roles_path = ~/kubespray/roles, без него плейбук не работает)
# (также понабодились еще кое-какие настройки, см. ниже)
pip3 install ipaddr
pip3 install netaddr
ansible-playbook -i ./inventory/mycluster/inventory.ini \
--become --become-user=root --user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} \
~/kubespray/cluster.yml
```

Результат (после ооочень долгого выполнения): 

```text
PLAY RECAP *******************************************************************************************
localhost                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
master1                    : ok=737  changed=144  unreachable=0    failed=0    skipped=1174 rescued=0    ignored=6   
worker1                    : ok=490  changed=90   unreachable=0    failed=0    skipped=788  rescued=0    ignored=1   
worker2                    : ok=490  changed=90   unreachable=0    failed=0    skipped=788  rescued=0    ignored=1   
worker3                    : ok=490  changed=90   unreachable=0    failed=0    skipped=788  rescued=0    ignored=1   
```

(видно, что кое-какие ошибки всё равно были, например, с modeprobe и др.) 

На master-ноде: 

```bash
mkdir -p $HOME/.kube
sudo cp -if /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes -o wide
# Сделаем такой же deployment, как в примере с ручной установкой выше было:
nano nginx-deployment.yaml
kubectl apply -f nginx-deployment.yaml
kubectl get pods -o wide
```

```text
dimka@master1:~$ kubectl get nodes -o wide
NAME      STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready    control-plane   5m34s   v1.28.5   10.128.0.17   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
worker1   Ready    <none>          4m37s   v1.28.5   10.128.0.27   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
worker2   Ready    <none>          4m36s   v1.28.5   10.128.0.9    <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
worker3   Ready    <none>          4m36s   v1.28.5   10.128.0.26   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
dimka@master1:~$ kubectl apply -f nginx-deployment.yaml
deployment.apps/nginx-deployment created
dimka@master1:~$ kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP               NODE      NOMINATED NODE   READINESS GATES
nginx-deployment-749b6d7c7-79zkc   1/1     Running   0          25s   10.233.83.2      worker3   <none>           <none>
nginx-deployment-749b6d7c7-hksxk   1/1     Running   0          25s   10.233.125.2     worker2   <none>           <none>
nginx-deployment-749b6d7c7-qd82r   1/1     Running   0          25s   10.233.83.1      worker3   <none>           <none>
nginx-deployment-749b6d7c7-wvqjt   1/1     Running   0          25s   10.233.105.130   worker1   <none>           <none>
dimka@master1:~$ curl 10.233.105.130:8080
You've hit nginx-deployment-749b6d7c7-wvqjt (IP: 10.233.105.130, STARTED: 2023-12-24 05:56:14 MSK)
dimka@master1:~$ curl 10.233.125.2:8080
You've hit nginx-deployment-749b6d7c7-hksxk (IP: 10.233.125.2, STARTED: 2023-12-24 05:56:14 MSK)
dimka@master1:~$ curl 10.233.83.1:8080
You've hit nginx-deployment-749b6d7c7-qd82r (IP: 10.233.83.1, STARTED: 2023-12-24 05:56:14 MSK)
dimka@master1:~$ curl 10.233.83.2:8080
You've hit nginx-deployment-749b6d7c7-79zkc (IP: 10.233.83.2, STARTED: 2023-12-24 05:56:15 MSK)
```

Но в целом Kubernetes версии v1.28.5 раскатился и работает. 

Наш прикладной деплой также успешно поставился. 

# git checkout, create directory, copy files, pull request:

```
cd ~/kodmandvl_platform/
git pull ; git status
ls
git branch
git checkout -b kubernetes-prod
git branch
mkdir kubernetes-prod
# Копируем файлы из места, где выполнял задание, в ~/kodmandvl_platform/kubernetes-prod/
# Далее:
git status
git add -A
git status
git commit -m "kubernetes-prod"
git push --set-upstream origin kubernetes-prod
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

# Выполнено ДЗ № kubernetes-prod

 - [OK] Основное ДЗ

## В процессе сделано:
 - Все пункты по порядку по методическим указаниям (также описано в README.md)

## Как запустить проект:
 - по шагам и заметкам в README.md

## Как проверить работоспособность:
 - по шагам и заметкам в README.md, выполнить приведенные выше команды kubectl apply, kubectl get и kubectl describe

## PR checklist:
 - [OK] Выставлен label с темой домашнего задания

# ТЕКСТ ДЛЯ ОТПРАВКИ В ЧАТ ПРОВЕРКИ ДЗ:

Добрый день! 

ДЗ № kubernetes-prod отправлено на проверку. 

Ссылка на PR: 

https://github.com/otus-kuber-2023-08/kodmandvl_platform/pull/13 



Спасибо!
С уважением, Корнев Дмитрий
