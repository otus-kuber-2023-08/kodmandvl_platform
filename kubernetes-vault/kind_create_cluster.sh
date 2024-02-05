# Script for create kind cluster with kind-config.yml
# 1st argument (optional): cluster name (default: kind)
# 2nd argument (optional): kindest/node version (default: 1.27.3)
# 3rd argument (optional): config file (default: ./kind-config.yml)
# Examples:
# ./kind_create_cluster.sh
# ./kind_create_cluster.sh - - -
# ./kind_create_cluster.sh mykind
# ./kind_create_cluster.sh mykind - -
# ./kind_create_cluster.sh mykind 1.24.15
# ./kind_create_cluster.sh mykind 1.24.15 ~/temp/mykindconfig.yml
CLUSTER=${1}
K8SVER=${2}
CFGFILE=${3}
if [[ "${1}" == "" ]] || [[ "${1}" == "-" ]]; then
CLUSTER=kind
fi
if [[ "${2}" == "" ]] || [[ "${2}" == "-" ]]; then
K8SVER=1.27.3
fi
if [[ "${3}" == "" ]] || [[ "${3}" == "-" ]]; then
CFGFILE=./kind-config.yml
fi
echo
echo "CREATE ${CLUSTER} KIND CLUSTER AFTER 5 SECONDS:"
echo
echo "kind create cluster --name ${CLUSTER} --image kindest/node:v${K8SVER} --config ${CFGFILE}"
echo
sleep 5
kind create cluster --name ${CLUSTER} --image kindest/node:v${K8SVER} --config ${CFGFILE}
echo
