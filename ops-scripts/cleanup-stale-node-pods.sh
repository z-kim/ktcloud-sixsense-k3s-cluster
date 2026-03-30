#!/usr/bin/env bash

set -euo pipefail

dry_run="false"
delete_all_terminating="false"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/cleanup-stale-node-pods.sh [options]

Options:
  --dry-run                 Show what would be deleted without deleting it
  --all-terminating         Also force delete all Terminating pods, even if node lookup is empty
  -h, --help                Show this help message

What it cleans:
  - Pods scheduled on NotReady nodes
  - Pods whose spec.nodeName points to a node that no longer exists
  - Optionally, all Terminating pods

It also prints whether these bootstrap resources still exist:
  - logging/kafka Service and EndpointSlice
  - apps/checkins-secret
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run="true"
      shift
      ;;
    --all-terminating)
      delete_all_terminating="true"
      shift
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

print_header() {
  printf '\n== %s ==\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

run_delete() {
  local namespace="$1"
  local pod_name="$2"
  local reason="$3"

  if [[ "$dry_run" == "true" ]]; then
    printf '[DRY-RUN] kubectl delete pod %s -n %s --grace-period=0 --force  # %s\n' "$pod_name" "$namespace" "$reason"
    return 0
  fi

  printf '[DELETE] %s/%s (%s)\n' "$namespace" "$pod_name" "$reason"
  kubectl delete pod "$pod_name" -n "$namespace" --grace-period=0 --force >/dev/null 2>&1 || true
}

print_header "Node Status"
kubectl get nodes -o wide

not_ready_nodes="$(
  kubectl get nodes --no-headers 2>/dev/null \
    | awk '$2 !~ /^Ready/ {print $1}'
)"

if [[ -n "$not_ready_nodes" ]]; then
  warn "Found NotReady or otherwise non-Ready nodes:"
  printf '%s\n' "$not_ready_nodes"
else
  info "No NotReady nodes found."
fi

all_current_nodes="$(
  kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}'
)"

print_header "Candidate Pods"

candidate_count=0

while read -r namespace pod_name pod_phase deletion_ts node_name; do
  [[ -z "$namespace" || -z "$pod_name" ]] && continue

  reason=""

  if [[ -n "$node_name" ]]; then
    if [[ -n "$not_ready_nodes" ]] && grep -Fxq "$node_name" <<<"$not_ready_nodes"; then
      reason="node-not-ready:${node_name}"
    elif [[ -n "$all_current_nodes" ]] && ! grep -Fxq "$node_name" <<<"$all_current_nodes"; then
      reason="node-missing:${node_name}"
    fi
  fi

  if [[ -z "$reason" && "$delete_all_terminating" == "true" && "$deletion_ts" != "<none>" ]]; then
    reason="terminating"
  fi

  if [[ -n "$reason" ]]; then
    candidate_count=$((candidate_count + 1))
    run_delete "$namespace" "$pod_name" "$reason"
  fi
done < <(
  kubectl get pods -A --no-headers \
    -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,DELETION:.metadata.deletionTimestamp,NODE:.spec.nodeName'
)

if [[ "$candidate_count" -eq 0 ]]; then
  info "No stale pods matched cleanup conditions."
fi

print_header "Bootstrap Resource Check"

if kubectl get svc kafka -n logging >/dev/null 2>&1; then
  info "logging/kafka Service exists"
  kubectl get svc kafka -n logging
else
  warn "logging/kafka Service not found"
fi

if kubectl get endpointslice -n logging -l kubernetes.io/service-name=kafka >/dev/null 2>&1; then
  info "logging/kafka EndpointSlice exists"
  kubectl get endpointslice -n logging -l kubernetes.io/service-name=kafka -o wide
else
  warn "logging/kafka EndpointSlice not found"
fi

if kubectl get secret checkins-secret -n apps >/dev/null 2>&1; then
  info "apps/checkins-secret exists"
  kubectl get secret checkins-secret -n apps
else
  warn "apps/checkins-secret not found"
fi

print_header "Remaining Terminating Pods"
kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="Terminating" {print $0}' || true
