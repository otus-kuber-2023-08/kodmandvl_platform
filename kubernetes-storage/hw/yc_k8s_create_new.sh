# Script for creating YC managed-kubernetes cluster with SSD node group and HDD node group (100% core-fraction, non-preemptible, 2 CPUs, 8 GB RAM)
# 1st argument (mandatory): cluster-name
# 2nd argument (mandatory): kubernetes version
# 3rd argument (mandatory): cluster-ipv4-range
# 4th argument (mandatory): service-ipv4-range
# 5th argument (mandatory): SSD node-group-name
# 6th argument (mandatory): count of nodes in SSD node-group
# 7th argument (optional): HDD node-group-name
# 8th argument (optional): count of nodes in infra node-group
# Examples:
# ./yc_k8s_create_new.sh myk8s 1.27 10.99.0.0/16 10.55.0.0/16 my-node-group 2
# ./yc_k8s_create_new.sh myk8s 1.27 10.99.0.0/16 10.55.0.0/16 ssd-group 1 hdd-group 3
# ./yc_k8s_create_new.sh loghw 1.27 10.99.0.0/16 10.55.0.0/16 default-pool 1 infra-pool 3
# ATTENTION! Before run this script you should create KMS key and set correct values for other parameters in script: kms-key-name, service-account-name, node-service-account-name, your username for SSH, your public key for SSH, zone, subnet-name, version, etc.
echo
echo "CREATING $1 YC MANAGED-KUBERNETES CLUSTER AFTER 5 SECONDS..."
echo
sleep 5
yc managed-kubernetes cluster create --name $1 \
  --description My_K8S_cluster_for_$1 \
  --network-name default \
  --zone ru-central1-a \
  --subnet-name default-ru-central1-a \
  --public-ip \
  --release-channel stable \
  --version $2 \
  --cluster-ipv4-range $3 \
  --service-ipv4-range $4 \
  --kms-key-name my-key \
  --node-ipv4-mask-size 24 \
  --auto-upgrade=false \
  --service-account-name my-k8s-sa \
  --node-service-account-name my-node-sa \
  # end of creating
echo
echo "GET $1 CLUSTER:"
echo
yc managed-kubernetes cluster get $1
echo
echo "GET CREDENTIALS FOR $1 CLUSTER:"
echo
yc managed-kubernetes cluster get-credentials --force --external $1
echo
echo "LIST CLUSTERS:"
echo
yc managed-kubernetes cluster list
echo
echo "CREATING SSD NODE GROUP FOR $1 YC MANAGED-KUBERNETES CLUSTER AFTER 5 SECONDS..."
echo
sleep 5
yc managed-kubernetes node-group create \
  --cluster-name $1 \
  --cores 2 \
  --core-fraction 100 \
  --auto-upgrade=false \
  --disk-size 64 \
  --disk-type network-ssd \
  --fixed-size $6 \
  --memory 8 \
  --name $5 \
  --node-name node{instance.index}-$5 \
  --container-runtime containerd \
  --network-interface subnets=default-ru-central1-a,ipv4-address=nat \
  --version $2 \
  --max-expansion 8 \
  --max-unavailable 8 \
  --platform standard-v3 \
  --metadata ssh-keys='your_user:ssh-rsa your_public_key comment_for_your_public_key' \
  # end of creating
echo
echo "GET $5 NODE GROUP:"
echo
yc managed-kubernetes node-group get --name $5
echo
echo "LIST NODES FROM $5 NODE GROUP:"
echo
yc managed-kubernetes node-group list-nodes $5
if [[ ! "${7}" == "" ]] && [[ ! "${8}" == "" ]]; then
echo
echo "CREATING HDD NODE GROUP FOR $1 YC MANAGED-KUBERNETES CLUSTER AFTER 5 SECONDS..."
echo
sleep 5
yc managed-kubernetes node-group create \
  --cluster-name $1 \
  --cores 2 \
  --core-fraction 100 \
  --auto-upgrade=false \
  --disk-size 64 \
  --disk-type network-hdd \
  --fixed-size $8 \
  --memory 8 \
  --name $7 \
  --node-name node{instance.index}-$7 \
  --container-runtime containerd \
  --network-interface subnets=default-ru-central1-a,ipv4-address=nat \
  --version $2 \
  --max-expansion 8 \
  --max-unavailable 8 \
  --platform standard-v3 \
  --metadata ssh-keys='your_user:ssh-rsa your_public_key comment_for_your_public_key' \
  # end of creating
echo
echo "GET $7 NODE GROUP:"
echo
yc managed-kubernetes node-group get --name $7
echo
echo "LIST NODES FROM $7 NODE GROUP:"
echo
yc managed-kubernetes node-group list-nodes $7
fi
echo
echo "GET NODES OF $1 CLUSTER:"
echo
kubectl --context yc-$1 get nodes -o wide
echo
echo "DONE."
echo
