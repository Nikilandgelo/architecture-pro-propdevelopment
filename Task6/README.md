#### How to get `audit.log` after running a bash file for simulating incidents:
```shell
kubectl -n kube-system logs kube-apiserver-minikube | grep '"audit.k8s.io/v1"' > audit.log
```
