#!/usr/bin/env bash

set -euo pipefail

dry_run="false"
delete_all_terminating="false"
delete_notready_nodes="false"
notready_minutes="10"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/cleanup-stale-node-pods.sh [options]

Options:
  --dry-run                 Show what would be deleted without deleting it
  --all-terminating         Also force delete all Terminating pods, even if node lookup is empty
  --delete-notready-nodes   Delete NotReady node objects after pod cleanup
  --notready-minutes <n>    Minimum minutes a node must remain NotReady before deletion (default: 10)
  -h, --help                Show this help message

What it cleans:
  - Pods scheduled on NotReady nodes
  - Pods whose spec.nodeName points to a node that no longer exists
  - Optionally, all Terminating pods
  - Optionally, NotReady node objects that stayed stale long enough

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
    --delete-notready-nodes)
      delete_notready_nodes="true"
      shift
      ;;
    --notready-minutes)
      notready_minutes="$2"
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

if ! [[ "$notready_minutes" =~ ^[0-9]+$ ]]; then
  echo "notready-minutes must be a non-negative integer" >&2
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

run_delete_node() {
  local node_name="$1"
  local reason="$2"

  if [[ "$dry_run" == "true" ]]; then
    printf '[DRY-RUN] kubectl delete node %s  # %s\n' "$node_name" "$reason"
    return 0
  fi

  printf '[DELETE] node/%s (%s)\n' "$node_name" "$reason"
  kubectl delete node "$node_name" >/dev/null 2>&1 || true
}

get_notready_age_minutes() {
  local node_name="$1"
  local ready_condition last_transition now_epoch transition_epoch

  ready_condition="$(
    kubectl get node "$node_name" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{"|"}{.lastTransitionTime}{"\n"}{end}' 2>/dev/null \
      | head -n1
  )"

  if [[ -z "$ready_condition" ]]; then
    echo "-1"
    return 0
  fi

  last_transition="${ready_condition#*|}"
  if [[ -z "$last_transition" ]]; then
    echo "-1"
    return 0
  fi

  now_epoch="$(date -u +%s)"
  transition_epoch="$(date -u -d "$last_transition" +%s 2>/dev/null || true)"
  if [[ -z "$transition_epoch" ]]; then
    echo "-1"
    return 0
  fi

  echo $(((now_epoch - transition_epoch) / 60))
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

if [[ "$delete_notready_nodes" == "true" ]]; then
  print_header "Delete Stale NotReady Nodes"

  if [[ -z "$not_ready_nodes" ]]; then
    info "No NotReady nodes to delete."
  else
    while IFS= read -r node_name; do
      [[ -z "$node_name" ]] && continue

      age_minutes="$(get_notready_age_minutes "$node_name")"
      if [[ "$age_minutes" -lt 0 ]]; then
        warn "Could not determine NotReady age for node/$node_name. Skipping."
        continue
      fi

      if [[ "$age_minutes" -lt "$notready_minutes" ]]; then
        info "Skipping node/$node_name because it has been NotReady for ${age_minutes} minute(s), below ${notready_minutes}."
        continue
      fi

      run_delete_node "$node_name" "not-ready-for-${age_minutes}m"
    done <<<"$not_ready_nodes"
  fi
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
