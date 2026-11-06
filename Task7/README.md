### Проверка Pod Security Admission (без Gatekeeper):
```shell
bash ./verify/verify-admission.sh
```
1. создается namespace без меток, затем создаются небезопасные поды
2. создается namespace с меткой restricted: небезопасные поды отклоняются, безопасные создаются


### Проверка OPA Gatekeeper (в namespace без Pod Security Admission, чтобы отказы давал именно Gatekeeper).
```shell
bash ./verify/validate-security.sh
```
1. CRD нет, поэтому небезопасные поды создаются
2. CRD созданы и применены: небезопасные поды отклоняются, безопасные запускаются
