#!/usr/bin/env bash

set -euo pipefail

namespace="apps"
container=""

usage() {
  cat <<'EOF'
Usage: bash ops-scripts/kill-pod-process.sh [options] <pod-name>

Options:
  -n, --namespace <namespace>   Kubernetes namespace (default: apps)
  -c, --container <name>        Container name when the Pod has multiple containers
  -h, --help                    Show this help message

Example:
  bash ops-scripts/kill-pod-process.sh -n apps checkins-6d9c7f6f87-abcde
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      namespace="$2"
      shift 2
      ;;
    -c|--container)
      container="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

pod_name="$1"
kubectl_args=(-n "$namespace" exec "$pod_name")

if [[ -n "$container" ]]; then
  kubectl_args+=(-c "$container")
fi

kubectl_args+=(-- sh -c "kill 1")

echo "Sending SIGTERM to PID 1 in pod '$pod_name' in namespace '$namespace'..."
kubectl "${kubectl_args[@]}"
echo "Signal sent to pod '$pod_name'."
