#!/bin bash
set -uo pipefail

# INIT CONSTANTS
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="audit-zone"
TEMPLATES="$ROOT/gatekeeper/constraint-templates"
CONSTRAINTS="$ROOT/gatekeeper/constraints"
TIMEOUT="${TIMEOUT:-120s}"
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
    grep "$pattern" <<<"$out" | sed 's/^/      /'
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

wait_ready() {
  if kubectl wait --for=condition=Ready pod --all -n "$NS" --timeout="$TIMEOUT" >/dev/null 2>&1; then
    ok "все поды Ready"
  else
    bad "поды не стали Ready за $TIMEOUT"
    kubectl get pods -n "$NS" 2>&1 | sed 's/^/      /'
    kubectl get events -n "$NS" --sort-by=.lastTimestamp 2>&1 | tail -n 8 | sed 's/^/      /'
  fi
}

apply_retry() {
  local target="$1" out i
  for i in $(seq 1 20); do
    if out=$(kubectl apply -f "$target" 2>&1);
    then
      return 0;
    fi
    sleep 3
  done

  echo "$out" | sed 's/^/      /'
  return 1
}

constraints_enforced() {
  local out
  out=$(kubectl get -f "$CONSTRAINTS" -o jsonpath='{range .items[*]}{.status.byPod[*].enforced}{"\n"}{end}' 2>/dev/null) || return 1
  [ -n "$out" ] || return 1
  grep -q '^$' <<<"$out" && return 1
  grep -q false <<<"$out" && return 1
  return 0
}

wait_enforced() {
  local i
  for i in $(seq 1 30); do
    if constraints_enforced; then sleep 3; return 0; fi
    sleep 2
  done
  return 1
}

delete_pods()     { kubectl delete pods --all -n "$NS" --now --wait=true --ignore-not-found >/dev/null 2>&1; }
delete_ns()       { kubectl delete ns "$NS" --ignore-not-found --wait=true --timeout=180s >/dev/null 2>&1; }
delete_policies() {
  kubectl delete -f "$TEMPLATES" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1
  sleep 3
}

cleanup() {
  delete_ns
  delete_policies
}



# STARTING WORKFLOW...
trap cleanup EXIT
echo "kubectl context: $(kubectl config current-context)"

if [ "${1:-}" != "-y" ] && [ -t 0 ]; then
  read -rp "Namespace $NS и шаблоны из gatekeeper/ будут удалены и созданы заново. Продолжить? [y/N] " answer
  [[ "$answer" =~ ^[yY]$ ]] || exit 1
fi

info "Проверяем, что Gatekeeper установлен и работает"
if ! kubectl -n gatekeeper-system wait --for=condition=Available deploy --all --timeout="$TIMEOUT" >/dev/null 2>&1; then
  echo "Gatekeeper не готов в namespace gatekeeper-system. Установите его (helm install gatekeeper ...) и повторите."
  trap - EXIT
  exit 1
fi
ok "Gatekeeper запущен"

info "Подготовка: убираем остатки прошлого запуска"
delete_policies
delete_ns

info "Фаза 1: политик нет, небезопасные поды должны создаваться"
kubectl apply -f "$ROOT/01-create-namespace.yaml" >/dev/null

for f in "$ROOT"/insecure-manifests/*.yaml; do
  expect_created "$f";
done

delete_pods

info "Фаза 2: применяем шаблоны и ограничения"
if apply_retry "$TEMPLATES";
then
  ok "шаблоны применены";
else
  bad "не удалось применить шаблоны";
fi

if apply_retry "$CONSTRAINTS";
then
  ok "ограничения применены";
else
  bad "не удалось применить ограничения";
fi

if wait_enforced; then
  ok "все ограничения активны (enforced)"
else
  bad "ограничения не стали активными"
  kubectl get constrainttemplates 2>&1 | sed 's/^/      /'
fi

info "Небезопасные поды должны отклоняться Gatekeeper"
for f in "$ROOT"/insecure-manifests/*.yaml; do
  expect_rejected "$f" "validation.gatekeeper.sh";
done

expect_no_pods

info "Безопасные поды должны создаваться и запускаться"
for f in "$ROOT"/secure-manifests/*.yaml; do
  expect_created "$f";
done

wait_ready

info "Очистка: удаляем поды, namespace и политики"
delete_pods
cleanup
trap - EXIT

info "Итог: успешно $PASSED, с ошибками $FAILED"


# For exit code
[ "$FAILED" -eq 0 ]
