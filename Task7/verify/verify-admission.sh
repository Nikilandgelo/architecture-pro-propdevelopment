#!/bin bash
set -uo pipefail

# INIT CONSTANTS
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="audit-zone"
PASSED=0
FAILED=0


# FUNCTION DEFINITIONS
info() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✔\033[0m %s\n' "$*"; PASSED=$((PASSED + 1)); }
bad()  { printf '    \033[31m✘\033[0m %s\n' "$*"; FAILED=$((FAILED + 1)); }

expect_created() {
  local file="$1" out
  if out=$(kubectl apply -f "$file" 2>&1); then
    ok "создан: $(basename "$file")"
  else
    bad "не создан, а должен быть создан: $(basename "$file")"
    sed 's/^/      /' <<<"$out"
  fi
}

expect_rejected() {
  local file="$1" pattern="$2" out
  if out=$(kubectl apply -f "$file" 2>&1); then
    bad "создан, а должен быть отклонён: $(basename "$file")"
  elif grep -q "$pattern" <<<"$out"; then
    ok "отклонён: $(basename "$file")"
    grep -m1 "$pattern" <<<"$out" | sed 's/^/      /'
  else
    bad "отклонён не тем механизмом (нет '$pattern'): $(basename "$file")"
    sed 's/^/      /' <<<"$out"
  fi
}

expect_no_pods() {
  local left
  left=$(kubectl get pods -n "$NS" -o name 2>/dev/null)
  if [ -z "$left" ];
  then
    ok "в $NS нет подов";
  else
    bad "остались поды: $(tr '\n' ' ' <<<"$left")";
  fi
}

expect_ns_label() {
  local expected="$1" actual
  actual=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
  if [ "$actual" = "$expected" ];
  then
    ok "метка pod-security enforce = '${actual:-<нет>}'";
  else
    bad "метка enforce = '${actual:-<нет>}', ожидалось '${expected:-<нет>}'";
  fi
}

wait_ready() {
  if kubectl wait --for=condition=Ready pod --all -n "$NS" --timeout="120s" >/dev/null 2>&1; then
    ok "все поды Ready"
  else
    bad "поды не стали Ready за 120s"
    kubectl get pods -n "$NS" 2>&1 | sed 's/^/      /'
    kubectl get events -n "$NS" --sort-by=.lastTimestamp 2>&1 | tail -n 8 | sed 's/^/      /'
  fi
}

delete_pods() { kubectl delete pods --all -n "$NS" --now --wait=true --ignore-not-found >/dev/null 2>&1; }
delete_ns()   { kubectl delete ns "$NS" --ignore-not-found --wait=true --timeout=180s >/dev/null 2>&1; }



# STARTING WORKFLOW...
trap 'delete_ns' EXIT
echo "kubectl context: $(kubectl config current-context)"

if [ "${1:-}" != "-y" ] && [ -t 0 ]; then
  read -rp "Namespace $NS будет удалён и создан заново. Продолжить? [y/N] " answer
  [[ "$answer" =~ ^[yY]$ ]] || exit 1
fi

if kubectl get -f "$ROOT/gatekeeper/constraint-templates/" -o name 2>/dev/null | grep -q .; then
  echo "Найдены установленные ConstraintTemplate из gatekeeper/constraint-templates/."
  echo "Удалите их (kubectl delete -f gatekeeper/constraint-templates/) или запустите validate-security.sh."
  exit 1
fi

info "Подготовка: удаляем $NS, если он остался с прошлого запуска"
delete_ns

info "Фаза 1: namespace без Pod Security, небезопасные поды должны создаваться"
kubectl apply -f "$ROOT/01-create-namespace.yaml" >/dev/null
expect_ns_label ""

for f in "$ROOT"/insecure-manifests/*.yaml; do
  expect_created "$f";
done

info "Очистка: удаляем поды и namespace"
delete_pods
delete_ns

info "Фаза 2: namespace с Pod Security restricted, небезопасные поды теперь должны отклоняться"
kubectl apply -f "$ROOT/02-create-namespace-admission.yaml" >/dev/null
expect_ns_label "restricted"

for f in "$ROOT"/insecure-manifests/*.yaml; do
  expect_rejected "$f" "violates PodSecurity";
done

expect_no_pods

info "Безопасные поды должны создаваться и запускаться"
for f in "$ROOT"/secure-manifests/*.yaml; do
  expect_created "$f";
done

wait_ready

info "Очистка: удаляем поды и namespace"
delete_pods
delete_ns

info "Итог: успешно $PASSED, с ошибками $FAILED"


# For exit code
[ "$FAILED" -eq 0 ]
