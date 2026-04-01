#!/usr/bin/env bash

set -euo pipefail

namespace="apps"
seconds="60"
container=""
selector="app=doc-converter"
count=""

is_stressable_pod() {
  local pod_name="$1"
  local pod_status
  local phase
  local deletion_timestamp

  pod_status="$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}{"|"}{.metadata.deletionTimestamp}')"
  phase="${pod_status%%|*}"
  deletion_timestamp="${pod_status#*|}"

  [[ "$phase" == "Running" && -z "$deletion_timestamp" ]]
}

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/stress-pods.sh [options] <pod-name> [<pod-name> ...]
  bash ops-scripts/stress-pods.sh [options] --count <count>

Options:
  -n, --namespace <namespace>   Kubernetes namespace (default: apps)
  -s, --seconds <seconds>       CPU burn duration in seconds (default: 60)
  -c, --container <name>        Container name when Pods have multiple containers
  -l, --selector <selector>     Label selector for automatic Pod lookup (default: app=doc-converter)
  -p, --count <count>           Number of running Pods to stress automatically
  -h, --help                    Show this help message

Examples:
  bash ops-scripts/stress-pods.sh -n apps -s 90 doc-converter-pod-a
  bash ops-scripts/stress-pods.sh -n apps -s 90 doc-converter-pod-a doc-converter-pod-b
  bash ops-scripts/stress-pods.sh -n apps -l app=doc-converter -p 2 -s 90
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      namespace="$2"
      shift 2
      ;;
    -s|--seconds)
      seconds="$2"
      shift 2
      ;;
    -c|--container)
      container="$2"
      shift 2
      ;;
    -l|--selector)
      selector="$2"
      shift 2
      ;;
    -p|--count)
      count="$2"
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

if ! [[ "$seconds" =~ ^[0-9]+$ ]] || [[ "$seconds" -lt 1 ]]; then
  echo "seconds must be a positive integer" >&2
  exit 1
fi

if [[ -n "$count" ]] && { ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 ]]; }; then
  echo "count must be a positive integer" >&2
  exit 1
fi

if [[ -n "$count" ]] && [[ $# -gt 0 ]]; then
  echo "Provide either Pod names or --count, not both." >&2
  exit 1
fi

pods=()
pids=()

if [[ $# -gt 0 ]]; then
  pods=("$@")
elif [[ -n "$count" ]]; then
  mapfile -t pods < <(
    kubectl get pods \
      -n "$namespace" \
      -l "$selector" \
      --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' |
      awk -F'|' '$2 == "" { print $1 }'
  )

  if [[ "${#pods[@]}" -lt "$count" ]]; then
    echo "Requested $count Pods, but only found ${#pods[@]} running non-terminating Pods in namespace '$namespace' with selector '$selector'." >&2
    exit 1
  fi

  pods=("${pods[@]:0:$count}")
else
  usage >&2
  exit 1
fi

for pod_name in "${pods[@]}"; do
  if ! is_stressable_pod "$pod_name"; then
    echo "Pod '$pod_name' is not a running non-terminating Pod in namespace '$namespace'." >&2
    exit 1
  fi
done

echo "Target Pods: ${pods[*]}"

for pod_name in "${pods[@]}"; do
  kubectl_args=(-n "$namespace" exec "$pod_name")

  if [[ -n "$container" ]]; then
    kubectl_args+=(-c "$container")
  fi

  kubectl_args+=(-- python -c "import time; end=time.time()+$seconds
while time.time() < end:
    sum(i*i for i in range(200000))")

  echo "Starting CPU burn on pod '$pod_name' in namespace '$namespace' for ${seconds}s..."
  kubectl "${kubectl_args[@]}" &
  pids+=("$!")
done

failed=0

for index in "${!pids[@]}"; do
  if ! wait "${pids[$index]}"; then
    echo "CPU burn failed on pod '${pods[$index]}'." >&2
    failed=1
  else
    echo "CPU burn completed on pod '${pods[$index]}'."
  fi
done

exit "$failed"
