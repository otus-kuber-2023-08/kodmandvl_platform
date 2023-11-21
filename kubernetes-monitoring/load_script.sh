#!/bin/sh
min_i=1
max_i=$1
i=$min_i
ip=`minikube ip`
echo IP OF MINIKUBE NODE: $ip
echo WAITING FOR `expr $max_i \* 3` REQUESTS
echo "=================================================="
while [ $i -le $max_i ]; do
curl $ip:30080 >/dev/null 2>&1
curl $ip:30080/basic_status  >/dev/null 2>&1
curl $ip:30080/kitty.html >/dev/null 2>&1
if [ `expr $i % 100` -eq 0 ]
then
  curl $ip:30080/basic_status
  echo "`expr $i \* 3` REQUESTS..."
  echo "=================================================="
  sleep 1
fi
i=`expr $i + 1`
done
echo TOTAL: `expr $max_i \* 3` REQUESTS.
echo DONE.
