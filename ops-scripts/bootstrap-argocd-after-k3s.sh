#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_dir="${repo_root}/cluster"
render_dir="/tmp/sixsense-bootstrap-rendered"
timeout_seconds="300"
force_bootstrap="false"

namespace_file="${cluster_dir}/bootstrap/00-namespaces.yaml"
argocd_values_file="${cluster_dir}/bootstrap/argocd/values.yaml"
argocd_helmchart_file="${cluster_dir}/bootstrap/argocd/helmchart.yaml"
checkins_secret_file="${cluster_dir}/references/bootstrap-inputs/checkins-secret.input.yaml"
kafka_alias_file="${cluster_dir}/references/bootstrap-inputs/kafka-alias.yaml"

root_app_name="root-app"
root_repo_url="https://github.com/z-kim/ktcloud-sixsense-k3s-cluster.git"
root_target_revision="main"
root_path="cluster/argocd/applications/apps"
root_destination_server="https://kubernetes.default.svc"
root_destination_namespace="argocd"

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/bootstrap-argocd-after-k3s.sh [options]

Options:
  -t, --timeout <seconds>          Rollout timeout in seconds (default: 300)
  --cluster-dir <path>             Cluster directory path
  --checkins-secret-file <path>    Hardcoded checkins Secret manifest path
  --kafka-alias-file <path>        Hardcoded kafka alias manifest path
  --root-repo-url <url>            Root app repo URL
  --root-target-revision <rev>     Root app target revision (default: main)
  --root-path <path>               Root app source path
  --root-app-name <name>           Root application name
  --force-bootstrap                Re-apply namespace and Argo CD bootstrap even if argocd-server exists
  -h, --help                       Show this help

Notes:
  - This script assumes K3s is already installed and kubectl can reach the local cluster.
  - It mirrors the post-K3s part of external-ref Ansible:
    namespace/bootstrap -> checkins-secret -> kafka-alias -> root-app
  - For now, checkins-secret and kafka-alias are applied from hardcoded reference manifests.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --cluster-dir)
      cluster_dir="$2"
      shift 2
      ;;
    --checkins-secret-file)
      checkins_secret_file="$2"
      shift 2
      ;;
    --kafka-alias-file)
      kafka_alias_file="$2"
      shift 2
      ;;
    --root-repo-url)
      root_repo_url="$2"
      shift 2
      ;;
    --root-target-revision)
      root_target_revision="$2"
      shift 2
      ;;
    --root-path)
      root_path="$2"
      shift 2
      ;;
    --root-app-name)
      root_app_name="$2"
      shift 2
      ;;
    --force-bootstrap)
      force_bootstrap="true"
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

namespace_file="${cluster_dir}/bootstrap/00-namespaces.yaml"
argocd_values_file="${cluster_dir}/bootstrap/argocd/values.yaml"
argocd_helmchart_file="${cluster_dir}/bootstrap/argocd/helmchart.yaml"

print_header() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "required file not found: $path" >&2
    exit 1
  fi
}

validate_checkins_secret() {
  if [[ ! -f "$checkins_secret_file" ]]; then
    echo "checkins secret file not found: $checkins_secret_file" >&2
    echo "Hint: copy ${cluster_dir}/references/bootstrap-inputs/checkins-secret.input.yaml.example to checkins-secret.input.yaml and fill database-url." >&2
    exit 1
  fi

  if ! grep -Eq '^[[:space:]]*database-url:' "$checkins_secret_file"; then
    echo "checkins secret file must contain a hardcoded database-url before apply: $checkins_secret_file" >&2
    exit 1
  fi
}

ensure_kubeconfig() {
  if [[ -n "${KUBECONFIG:-}" && -f "${KUBECONFIG}" ]]; then
    return 0
  fi

  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
    return 0
  fi

  if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
    mkdir -p "${HOME}/.kube"
    cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
    chmod 600 "${HOME}/.kube/config"
    export KUBECONFIG="${HOME}/.kube/config"
    return 0
  fi

  echo "kubeconfig not found. Set KUBECONFIG or ensure /etc/rancher/k3s/k3s.yaml exists." >&2
  exit 1
}

wait_for_argocd() {
  local seconds_left="$timeout_seconds"

  while ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; do
    if [[ "$seconds_left" -le 0 ]]; then
      echo "Timed out waiting for deployment/argocd-server in namespace argocd." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  kubectl rollout status deployment/argocd-server -n argocd --timeout="${timeout_seconds}s"
}

render_root_app() {
  mkdir -p "$render_dir"

  cat > "${render_dir}/root-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${root_app_name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${root_repo_url}
    targetRevision: ${root_target_revision}
    path: ${root_path}
    directory:
      include: "*.yaml"
  destination:
    server: ${root_destination_server}
    namespace: ${root_destination_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: false
EOF
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH." >&2
  exit 1
fi

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
  echo "timeout must be a positive integer" >&2
  exit 1
fi

require_file "$namespace_file"
require_file "$argocd_values_file"
require_file "$argocd_helmchart_file"
require_file "$kafka_alias_file"
validate_checkins_secret

if [[ ! -x /usr/local/bin/k3s && ! -x /usr/local/bin/kubectl ]]; then
  echo "K3s does not appear to be installed on this server." >&2
  exit 1
fi

ensure_kubeconfig

print_header "Kubernetes"
kubectl get nodes >/dev/null

argocd_bootstrap_required="false"
if [[ "$force_bootstrap" == "true" ]]; then
  argocd_bootstrap_required="true"
else
  if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    argocd_bootstrap_required="true"
  fi
fi

if [[ "$argocd_bootstrap_required" == "true" ]]; then
  print_header "Bootstrap"
  kubectl apply -f "$namespace_file"
  kubectl apply -f "$argocd_values_file"
  kubectl apply -f "$argocd_helmchart_file"
  wait_for_argocd
else
  print_header "Bootstrap"
  warn "argocd-server already exists. Skipping namespace/Argo CD bootstrap."
fi

print_header "Checkins Secret"
kubectl apply -f "$checkins_secret_file"

print_header "Kafka Alias"
kubectl apply -f "$kafka_alias_file"

print_header "Root App"
render_root_app
kubectl apply -f "${render_dir}/root-app.yaml"

print_header "Summary"
kubectl get ns argocd logging apps
kubectl get secret checkins-secret -n apps
kubectl get svc,endpointslice -n logging | grep kafka || true
kubectl get application "${root_app_name}" -n argocd
