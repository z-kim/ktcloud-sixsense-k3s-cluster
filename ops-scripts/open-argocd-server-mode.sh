#!/usr/bin/env bash

set -euo pipefail

namespace="argocd"
service_name="argocd-server"
local_port="8080"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/open-argocd-server-mode.sh [options]

Options:
  -p, --port <port>       Local port to open (default: 8080)
  -n, --namespace <ns>    Argo CD namespace (default: argocd)
  -h, --help              Show this help

Notes:
  - This script opens Argo CD server mode only while it is running.
  - Press Ctrl-C to close the port-forward.
  - Default day-to-day operation is still `argocd --core ...`.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port)
      local_port="$2"
      shift 2
      ;;
    -n|--namespace)
      namespace="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH." >&2
  exit 1
fi

if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
  echo "port must be an integer between 1 and 65535" >&2
  exit 1
fi

kubectl get svc "${service_name}" -n "${namespace}" >/dev/null

admin_password="$(
  kubectl get secret argocd-initial-admin-secret -n "${namespace}" \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true
)"

printf '== Argo CD Server Mode ==\n'
printf 'URL: https://127.0.0.1:%s\n' "${local_port}"
printf 'Namespace: %s\n' "${namespace}"
printf '\n'
printf 'This port-forward stays open until you press Ctrl-C.\n'

if [[ -n "${admin_password}" ]]; then
  printf '\n'
  printf 'Admin username: admin\n'
  printf 'Admin password: %s\n' "${admin_password}"
fi

if command -v argocd >/dev/null 2>&1; then
  printf '\n'
  printf 'CLI login example:\n'
  printf 'argocd login 127.0.0.1:%s --username admin --password '"'"'%s'"'"' --insecure\n' "${local_port}" "${admin_password:-<password>}"
fi

printf '\n'
printf 'Starting port-forward...\n'

exec kubectl port-forward "svc/${service_name}" -n "${namespace}" "${local_port}:443"
