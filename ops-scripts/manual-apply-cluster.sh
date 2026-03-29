#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_dir="${repo_root}/cluster"
timeout_seconds="300"
skip_prereqs="false"
prereqs_only="false"
secret_file=""
allow_missing_secret="false"
default_secret_file="${cluster_dir}/workloads/apps/checkins/overlays/dev/checkins-secret.local.yaml"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/manual-apply-cluster.sh [options]

Options:
  -t, --timeout <seconds>   Rollout timeout in seconds (default: 300)
  --skip-prereqs            Assume namespaces, checkins-secret, and kafka-alias are already handled
  --prereqs-only            Apply only namespaces, checkins-secret, and kafka-alias, then exit
  --secret-file <path>      Apply this checkins secret manifest before Checkins
  --allow-missing-secret    Apply Checkins even when checkins-secret is missing
  -h, --help                Show this help message

Notes:
  - Assumes the repository's cluster/ directory is present on the machine.
  - If --secret-file is omitted, the script auto-uses cluster/workloads/apps/checkins/overlays/dev/checkins-secret.local.yaml when present.
  - By default, Checkins is skipped when checkins-secret is missing.
  - Prereqs means namespace bootstrap + checkins-secret + logging/kafka alias.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --skip-prereqs)
      skip_prereqs="true"
      shift
      ;;
    --prereqs-only)
      prereqs_only="true"
      shift
      ;;
    --secret-file)
      secret_file="$2"
      shift 2
      ;;
    --allow-missing-secret)
      allow_missing_secret="true"
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

required_paths=(
  "${cluster_dir}/bootstrap/00-namespaces.yaml"
  "${cluster_dir}/manifests/ingress-nginx/values.yaml"
  "${cluster_dir}/manifests/ingress-nginx/helmchart.yaml"
  "${cluster_dir}/manifests/kafka-alias/kafka-alias.yaml"
  "${cluster_dir}/manifests/falco/values.yaml"
  "${cluster_dir}/manifests/falco/helmchart.yaml"
  "${cluster_dir}/manifests/node-exporter/daemonset.yaml"
  "${cluster_dir}/workloads/apps/checkins/overlays/dev/kustomization.yaml"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "required path not found: $path" >&2
    exit 1
  fi
done

if [[ -z "$secret_file" && -e "$default_secret_file" ]]; then
  secret_file="$default_secret_file"
fi

if [[ -n "$secret_file" && ! -e "$secret_file" ]]; then
  echo "secret file not found: $secret_file" >&2
  exit 1
fi

print_header() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

wait_for_resource() {
  local kind="$1"
  local name="$2"
  local namespace="$3"
  local seconds_left="$timeout_seconds"

  while ! kubectl get "${kind}" "${name}" -n "${namespace}" >/dev/null 2>&1; do
    if [[ "$seconds_left" -le 0 ]]; then
      echo "Timed out waiting for ${kind}/${name} in namespace ${namespace}." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done
}

apply_prereqs() {
  print_header "Prerequisites"
  kubectl apply -f "${cluster_dir}/bootstrap/00-namespaces.yaml"
  kubectl get ns ingress-nginx falco monitoring logging apps >/dev/null

  if [[ -n "$secret_file" ]]; then
    kubectl apply -f "$secret_file"
  fi

  kubectl apply -f "${cluster_dir}/manifests/kafka-alias/kafka-alias.yaml"
}

if [[ "$skip_prereqs" == "true" ]]; then
  print_header "Prerequisites"
  warn "Skipping namespace bootstrap, checkins-secret apply, and kafka-alias apply."
  kubectl get ns ingress-nginx falco monitoring logging apps >/dev/null
else
  apply_prereqs
fi

if [[ "$prereqs_only" == "true" ]]; then
  print_header "Summary"
  kubectl get ns ingress-nginx falco monitoring logging apps
  kubectl get secret checkins-secret -n apps 2>/dev/null || true
  kubectl get svc,endpointslice -n logging
  exit 0
fi

print_header "ingress-nginx"
kubectl apply -f "${cluster_dir}/manifests/ingress-nginx/values.yaml"
kubectl get helmchartconfig ingress-nginx -n kube-system >/dev/null
kubectl apply -f "${cluster_dir}/manifests/ingress-nginx/modsecurity-audit-sidecar-config.yaml"
kubectl get configmap modsecurity-audit-sidecar-config -n ingress-nginx >/dev/null
kubectl apply -f "${cluster_dir}/manifests/ingress-nginx/helmchart.yaml"
wait_for_resource daemonset ingress-nginx-controller ingress-nginx
kubectl rollout status daemonset/ingress-nginx-controller -n ingress-nginx --timeout="${timeout_seconds}s"

print_header "Falco"
kubectl apply -f "${cluster_dir}/manifests/falco/values.yaml"
kubectl get helmchartconfig falco -n kube-system >/dev/null
kubectl apply -f "${cluster_dir}/manifests/falco/helmchart.yaml"
wait_for_resource deployment falco-falcosidekick falco
kubectl rollout status deployment/falco-falcosidekick -n falco --timeout="${timeout_seconds}s"

print_header "Node Exporter"
kubectl apply -f "${cluster_dir}/manifests/node-exporter/daemonset.yaml"
wait_for_resource daemonset node-exporter monitoring

print_header "Checkins"
if kubectl get secret checkins-secret -n apps >/dev/null 2>&1; then
  kubectl apply -k "${cluster_dir}/workloads/apps/checkins/overlays/dev"
  kubectl rollout status deployment/checkins -n apps --timeout="${timeout_seconds}s"
else
  if [[ "$allow_missing_secret" == "true" ]]; then
    warn "checkins-secret not found in apps namespace; applying Checkins anyway."
    warn "The Deployment will not become Ready until you create the secret and restart it."
    kubectl apply -k "${cluster_dir}/workloads/apps/checkins/overlays/dev"
  else
    warn "checkins-secret not found in apps namespace; skipping Checkins."
    warn "Apply your secret first, then rerun this script with --skip-prereqs."
    warn "Or pass --secret-file <path> to apply the secret in the same run."
  fi
fi

print_header "Summary"
kubectl get ds,deploy,rs -n ingress-nginx
kubectl get pods -n ingress-nginx -o wide
kubectl get svc,endpointslice -n logging
kubectl get ds,pods -n logging
kubectl get ds,deploy,pods -n falco
kubectl get ds -n monitoring
kubectl get pods -n monitoring -o wide
kubectl get deploy,hpa,svc,ingress -n apps
kubectl get pods -n apps -o wide
