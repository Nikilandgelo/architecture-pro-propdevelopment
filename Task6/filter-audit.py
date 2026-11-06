import argparse
import json


NOISE_PREFIXES = (
    "system:node:",
    "system:kube-",
    "system:apiserver",
    "system:serviceaccount:kube-system:",
)


def has_privileged_container(request_object: dict) -> bool:
    spec = request_object.get("spec") or {}
    containers: list[dict] = (spec.get("containers") or []) + (spec.get("initContainers") or [])
    for container in containers:
        if (container.get("securityContext") or {}).get("privileged"):
            return True

    return False


def classify_event(event: dict) -> str | None:
    obj = event.get("objectRef") or {}
    resource = obj.get("resource")
    subresource = obj.get("subresource")
    verb = event.get("verb")
    request_object = event.get("requestObject") or {}
    response_object = event.get("responseObject") or {}

    if resource == "secrets" and verb in ("get", "list", "watch"):
        return "secrets-access"

    if (
            resource == "pods"
            and verb == "create"
            and not subresource
            and has_privileged_container(request_object)
    ):
        return "privileged-pod"

    if subresource in ("exec", "attach", "portforward"):
        return "pod-exec"

    if resource in ("rolebindings", "clusterrolebindings") and verb in ("create", "update", "patch"):
        role_ref = request_object.get("roleRef") or response_object.get("roleRef") or {}
        if role_ref.get("name") == "cluster-admin":
            return "cluster-admin-binding"

        return "rbac-binding-change"

    target = (event.get("requestURI") or "") + " " + (obj.get("name") or "")
    if "audit-policy" in target.lower():
        return "audit-policy-tamper"

    if event.get("impersonatedUser") and resource == "selfsubjectaccessreviews":
        return "permission-probe"

    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("log", nargs="?", default="audit.log")
    parser.add_argument("output", nargs="?", default="audit-extract.json")
    parser.add_argument(
        "--exclude-user",
        action="append",
        default=["kubernetes-admin", "kubernetes-super-admin", "minikube"],
        help="Пользователи, чьи события нужно пропускать"
    )
    args = parser.parse_args()

    found = []
    with open(args.log, encoding="utf-8") as file:
        for line in file:
            line = line.strip()
            if not line:
                continue

            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue


            if event.get("stage") != "ResponseComplete":
                continue

            user = (event.get("user") or {}).get("username", "")
            if user.startswith(NOISE_PREFIXES) or user in set(args.exclude_user):
                continue

            category = classify_event(event)
            if category is None:
                continue

            obj = event.get("objectRef") or {}
            found.append({
                "category": category,
                "time": event.get("stageTimestamp", ""),
                "user": (event.get("user") or {}).get("username"),
                "impersonated": (event.get("impersonatedUser") or {}).get("username"),
                "verb": event.get("verb"),
                "resource": obj.get("resource"),
                "subresource": obj.get("subresource"),
                "namespace": obj.get("namespace"),
                "name": obj.get("name"),
                "code": (event.get("responseStatus") or {}).get("code"),
                "userAgent": event.get("userAgent"),
                "sourceIPs": event.get("sourceIPs"),
                "auditID": event.get("auditID"),
            })

    found.sort(key=lambda event: event["time"])
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(found, file, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()
