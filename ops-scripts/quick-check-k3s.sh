#!/usr/bin/env bash

set -euo pipefail

timeout_seconds="10"
alb_url=""

usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/quick-check-k3s.sh [options]

Options:
  -t, --timeout <seconds>   Rollout check timeout in seconds (default: 10)
  -u, --alb-url <url>       Optional ALB URL for app health check
  -h, --help                Show this help message

Examples:
  bash ops-scripts/quick-check-k3s.sh
  bash ops-scripts/quick-check-k3s.sh --alb-url http://my-alb.example.com
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    -u|--alb-url)
      alb_url="$2"
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

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
  echo "timeout must be a positive integer" >&2
  exit 1
fi

status=0

print_header() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  status=1
}

check_resource_exists() {
  local kind="$1"
  local name="$2"
  local namespace="$3"
  local description="$4"

  if kubectl get "$kind" "$name" -n "$namespace" >/dev/null 2>&1; then
    ok "$description"
  else
    fail "$description"
  fi
}

check_container_in_pod() {
  local namespace="$1"
  local label_selector="$2"
  local container_name="$3"
  local description="$4"
  local pod_name=""
  local containers=""

  pod_name="$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

  if [[ -z "$pod_name" ]]; then
    fail "$description"
    return
  fi

  containers="$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"

  if grep -qw "$container_name" <<<"$containers"; then
    ok "$description"
  else
    fail "$description"
  fi
}

run_rollout_check() {
  local kind="$1"
  local name="$2"
  local namespace="$3"
  local description="$4"

  if kubectl rollout status "${kind}/${name}" -n "$namespace" --timeout="${timeout_seconds}s" >/dev/null 2>&1; then
    ok "$description"
  else
    fail "$description"
    kubectl get "$kind" "$name" -n "$namespace" -o wide 2>/dev/null || true
    kubectl get pods -n "$namespace" -o wide 2>/dev/null || true
  fi
}

print_header "Cluster"
if kubectl get nodes -o wide >/dev/null 2>&1; then
  ok "kubectl can reach the cluster"
  kubectl get nodes -o wide
else
  fail "kubectl cannot reach the cluster"
  exit "$status"
fi

print_header "ingress-nginx"
run_rollout_check daemonset ingress-nginx-controller ingress-nginx "ingress-nginx controller DaemonSet is ready"
check_container_in_pod ingress-nginx "app.kubernetes.io/component=controller" fluent-bit-sidecar "ingress-nginx controller Pod includes fluent-bit-sidecar"
check_resource_exists configmap modsecurity-audit-sidecar-config ingress-nginx "modsecurity audit sidecar ConfigMap exists"
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o wide 2>/dev/null || true

print_header "Falcosidekick"
run_rollout_check deployment falco-falcosidekick falco "falcosidekick Deployment is ready"
kubectl get pods -n falco -l app.kubernetes.io/name=falcosidekick -o wide 2>/dev/null || true

print_header "Node Exporter"
desired="$(kubectl get ds node-exporter -n monitoring -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "")"
ready="$(kubectl get ds node-exporter -n monitoring -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "")"

if [[ -n "$desired" && -n "$ready" && "$desired" == "$ready" ]]; then
  ok "node-exporter DaemonSet is ready (${ready}/${desired})"
else
  fail "node-exporter DaemonSet is not fully ready (${ready:-0}/${desired:-0})"
fi
kubectl get ds node-exporter -n monitoring 2>/dev/null || true
kubectl get pods -n monitoring -l app=node-exporter -o wide 2>/dev/null || true

print_header "Argo CD"
run_rollout_check deployment argocd-server argocd "argocd server Deployment is ready"
run_rollout_check deployment argocd-repo-server argocd "argocd repo-server Deployment is ready"
kubectl get pods -n argocd -o wide 2>/dev/null || true

print_header "Checkins App"
run_rollout_check deployment checkins apps "checkins Deployment is ready"
kubectl get pods -n apps -l app=checkins -o wide 2>/dev/null || true
kubectl get svc checkins -n apps 2>/dev/null || true
kubectl get ingress checkins -n apps 2>/dev/null || true

if [[ -n "$alb_url" ]]; then
  print_header "ALB Health"
  if curl -fsS --max-time 5 "${alb_url%/}/health" >/dev/null 2>&1; then
    ok "ALB health endpoint responded: ${alb_url%/}/health"
  else
    fail "ALB health endpoint did not respond: ${alb_url%/}/health"
  fi
fi

print_header "Summary"
if [[ "$status" -eq 0 ]]; then
  ok "All core checks passed"
else
  fail "One or more checks failed"
fi

exit "$status"
