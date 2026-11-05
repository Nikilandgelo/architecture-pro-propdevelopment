#!/bin/bash
set -e
read -rp "Enter your cluster name: " CLUSTER_NAME
echo ""

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ -z "$CA_DATA" ]; then
    # Minikube references the CA by file path instead of embedding it
    CA_FILE=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority}')
    if [ -z "$CA_FILE" ] || [ ! -f "$CA_FILE" ]; then
        echo "Не удалось получить CA кластера из kubeconfig" >&2
        exit 1
    fi
    CA_DATA=$(base64 < "$CA_FILE" | tr -d '\n')
fi

OUTPUT_FILE="./test/rbac-test-kubeconfig.yaml"
echo "==> Генерация ключей и CSR для пользователей..."

ROOT_DIR="$(pwd)"
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

users_list=()

for file in "$ROOT_DIR"/manifests/csr/*.yaml; do
    filename=$(basename "$file")
    user="${filename%.*}"
    users_list+=("$user")
    echo "Обработка пользователя: $user (из файла $filename)"

    openssl genrsa -out "${user}.key" 2048
    openssl req -new -key "${user}.key" -out "${user}.csr" -subj "/CN=${user}"
    CSR_BASE64=$(cat "${user}.csr" | base64 | tr -d '\n')
    CSR_NAME="${user}-csr"

    kubectl delete csr "$CSR_NAME" --ignore-not-found=true
    sed -e "s|PLACEHOLDER_REQUEST|$CSR_BASE64|g" \
     -e "s|PLACEHOLDER_NAME|$CSR_NAME|g" \
     "$file" | kubectl apply -f -

    kubectl certificate approve "$CSR_NAME"
    kubectl get csr "$CSR_NAME" -o jsonpath='{.status.certificate}' | base64 --decode > "${user}.crt"
    echo ""
done

echo "==> Сборка единого kubeconfig в файл: $OUTPUT_FILE..."
cd "$ROOT_DIR"

cat << EOF > "$OUTPUT_FILE"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_DATA
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
EOF

for user in "${users_list[@]}"; do
    cat << EOF >> "$OUTPUT_FILE"
- context:
    cluster: $CLUSTER_NAME
    user: $user
  name: ${user}-context
EOF
done

cat << EOF >> "$OUTPUT_FILE"
current-context: ${users_list[0]}-context
users:
EOF

for user in "${users_list[@]}"; do
    cert_data=$(cat "$WORK_DIR/${user}.crt" | base64 | tr -d '\n')
    key_data=$(cat "$WORK_DIR/${user}.key" | base64 | tr -d '\n')
    cat << EOF >> "$OUTPUT_FILE"
- name: $user
  user:
    client-certificate-data: $cert_data
    client-key-data: $key_data
EOF
done

rm -rf "$WORK_DIR"
echo "==> Единый kubeconfig успешно создан: $OUTPUT_FILE"
