# Script for get credentials of YC managed-kubernetes cluster
# 1st argument: cluster-name
# Example:
# ./yc_k8s_get_cred.sh myk8s
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
echo "GET NODES OF $1 CLUSTER:"
echo
kubectl --context yc-$1 get nodes -o wide
echo
echo "DONE."
echo