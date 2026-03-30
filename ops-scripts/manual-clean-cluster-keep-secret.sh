#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_dir="${repo_root}/cluster"
timeout_seconds="300"
delete_all="false"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/manual-clean-cluster-keep-secret.sh [options]

Options:
  -t, --timeout <seconds>   Namespace deletion timeout in seconds (default: 300)
  --delete-all              Also delete apps/checkins-secret and related namespaces
  -h, --help                Show this help message

Notes:
  - Default behavior deletes cluster resources while keeping namespaces, apps/checkins-secret, and logging/kafka alias.
  - Use --delete-all when you also want apps/checkins-secret, logging/kafka alias, and related namespaces removed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --delete-all)
      delete_all="true"
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

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
  echo "timeout must be a positive integer" >&2
  exit 1
fi

if [[ ! -e "${cluster_dir}/workloads/apps/checkins/overlays/dev/kustomization.yaml" ]]; then
  echo "cluster directory not found under ${cluster_dir}" >&2
  exit 1
fi

print_header() {
  printf '\n== %s ==\n' "$1"
}

wait_for_namespace_delete() {
  local namespace="$1"
  local seconds_left="$timeout_seconds"

  while kubectl get namespace "$namespace" >/dev/null 2>&1; do
    if [[ "$seconds_left" -le 0 ]]; then
      echo "Timed out waiting for namespace/$namespace to be deleted." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done
}

print_header "Stop Argo Applications"
for app in root-app kafka-alias ingress-nginx fluent-bit falco node-exporter checkins-dev; do
  kubectl delete application "$app" -n argocd --ignore-not-found >/dev/null 2>&1 || true
done

print_header "Delete Checkins Resources But Keep Secret"
kubectl delete -k "${cluster_dir}/workloads/apps/checkins/overlays/dev" --ignore-not-found

print_header "Delete Node Exporter"
kubectl delete -f "${cluster_dir}/manifests/node-exporter/daemonset.yaml" --ignore-not-found >/dev/null 2>&1 || true

print_header "Delete ingress-nginx Sidecar Config"
kubectl delete -f "${cluster_dir}/manifests/ingress-nginx/modsecurity-audit-sidecar-config.yaml" --ignore-not-found >/dev/null 2>&1 || true

print_header "Delete HelmChart Resources"
for chart in argocd ingress-nginx fluent-bit falco; do
  kubectl delete helmchart "$chart" -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete helmchartconfig "$chart" -n kube-system --ignore-not-found >/dev/null 2>&1 || true
done

if command -v helm >/dev/null 2>&1; then
  helm uninstall argocd -n argocd >/dev/null 2>&1 || true
  helm uninstall ingress-nginx -n ingress-nginx >/dev/null 2>&1 || true
  helm uninstall fluent-bit -n logging >/dev/null 2>&1 || true
  helm uninstall falco -n falco >/dev/null 2>&1 || true
fi

print_header "Delete Helm Release Secrets"
kubectl delete secret -n kube-system -l owner=helm,name=argocd --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n kube-system -l owner=helm,name=ingress-nginx --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n kube-system -l owner=helm,name=fluent-bit --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n kube-system -l owner=helm,name=falco --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n argocd -l owner=helm,name=argocd --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n ingress-nginx -l owner=helm,name=ingress-nginx --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n logging -l owner=helm,name=fluent-bit --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret -n falco -l owner=helm,name=falco --ignore-not-found >/dev/null 2>&1 || true

if [[ "$delete_all" == "true" ]]; then
  print_header "Delete Kafka Alias"
  kubectl delete -f "${cluster_dir}/references/bootstrap-inputs/kafka-alias.yaml" --ignore-not-found >/dev/null 2>&1 || true

  print_header "Delete Namespaces"
  kubectl delete secret checkins-secret -n apps --ignore-not-found >/dev/null 2>&1 || true

  for namespace in ingress-nginx logging falco monitoring argocd apps; do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done

  for namespace in ingress-nginx logging falco monitoring argocd apps; do
    wait_for_namespace_delete "$namespace"
  done
else
  print_header "Keep Namespaces, Secret, And Kafka Alias"
  echo "[INFO] Keeping ingress-nginx, logging, falco, monitoring, argocd, and apps namespaces."
  echo "[INFO] Keeping apps/checkins-secret."
  echo "[INFO] Keeping logging/kafka alias."
  echo "[INFO] Cleaning legacy standalone fluent-bit resources too, if they still exist."
fi

print_header "Clean Completed Helm Install Pods"
kubectl get pods -n kube-system -o name 2>/dev/null \
  | grep -E 'pod/helm-install-(argocd|ingress-nginx|fluent-bit|falco)-' \
  | xargs -r kubectl delete -n kube-system >/dev/null 2>&1 || true

print_header "Summary"
kubectl get secret checkins-secret -n apps 2>/dev/null || true
kubectl get svc,endpointslice -n logging 2>/dev/null | grep kafka || true
kubectl get pods -A
