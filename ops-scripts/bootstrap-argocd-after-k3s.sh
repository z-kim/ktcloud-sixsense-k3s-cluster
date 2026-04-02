#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_dir="${repo_root}/cluster"
timeout_seconds="300"
force_bootstrap="false"

namespace_file="${cluster_dir}/bootstrap/00-namespaces.yaml"
external_secrets_values_file="${cluster_dir}/bootstrap/external-secrets/values.yaml"
external_secrets_helmchart_file="${cluster_dir}/bootstrap/external-secrets/helmchart.yaml"
external_secrets_clustersecretstore_file="${cluster_dir}/bootstrap/external-secrets/clustersecretstore.yaml"
external_secrets_argocd_repo_file="${cluster_dir}/bootstrap/external-secrets/argocd-root-repo.externalsecret.yaml"
argocd_values_file="${cluster_dir}/bootstrap/argocd/values.yaml"
argocd_helmchart_file="${cluster_dir}/bootstrap/argocd/helmchart.yaml"
root_app_file=""
doc_converter_configmap_file="${cluster_dir}/references/bootstrap-inputs/doc-converter-configmap.input.yaml"
kafka_alias_file="${cluster_dir}/references/bootstrap-inputs/kafka-alias.yaml"
legacy_doc_converter_configmap_file="${cluster_dir}/references/bootstrap-inputs/doc-converter-configmap.yaml"
legacy_doc_converter_configmap_typo_file="${cluster_dir}/references/bootstrap-inputs/docker-converter-configmap.yaml"
argocd_cli_install_path="/usr/local/bin/argocd"
argocd_cli_download_path="/tmp/argocd-linux-amd64"
argocd_cli_port_forward_port="18080"
argocd_cli_port_forward_log="/tmp/argocd-cli-port-forward.log"
argocd_server_selector="app.kubernetes.io/part-of=argocd,app.kubernetes.io/component=server"
external_secrets_controller_deployment_name="external-secrets"
external_secrets_webhook_deployment_name="external-secrets-webhook"
external_secrets_webhook_service_name="external-secrets-webhook"
argocd_repo_secret_name="argocd-root-repo"
argocd_repo_secret_namespace="argocd"
usage() {
  cat <<'EOF'
Usage:
  bash ops-scripts/bootstrap-argocd-after-k3s.sh [options]

Options:
  -t, --timeout <seconds>          Rollout timeout in seconds (default: 300)
  --cluster-dir <path>             Cluster directory path
  --root-app-file <path>           Root application manifest path
  --doc-converter-configmap-file <path>
                                   Hardcoded doc-converter ConfigMap manifest path
  --kafka-alias-file <path>        Hardcoded kafka alias manifest path
  --force-bootstrap                Re-apply namespace and Argo CD bootstrap even if argocd-server exists
  -h, --help                       Show this help

Notes:
  - This script assumes K3s is already installed and kubectl can reach the local cluster.
  - It mirrors the post-K3s part of external-ref Ansible:
    namespace/bootstrap -> external-secrets -> argocd -> doc-converter-config -> kafka-alias -> root-app
  - If the argocd CLI is missing, the script downloads and installs it after argocd-server becomes available.
  - Default operational mode is `argocd --core ...`. Server mode/UI access can be opened separately only when needed.
  - For now, doc-converter-config and kafka-alias are applied from hardcoded reference manifests.
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
    --root-app-file)
      root_app_file="$2"
      shift 2
      ;;
    --doc-converter-configmap-file)
      doc_converter_configmap_file="$2"
      shift 2
      ;;
    --kafka-alias-file)
      kafka_alias_file="$2"
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
external_secrets_values_file="${cluster_dir}/bootstrap/external-secrets/values.yaml"
external_secrets_helmchart_file="${cluster_dir}/bootstrap/external-secrets/helmchart.yaml"
external_secrets_clustersecretstore_file="${cluster_dir}/bootstrap/external-secrets/clustersecretstore.yaml"
external_secrets_argocd_repo_file="${cluster_dir}/bootstrap/external-secrets/argocd-root-repo.externalsecret.yaml"
argocd_values_file="${cluster_dir}/bootstrap/argocd/values.yaml"
argocd_helmchart_file="${cluster_dir}/bootstrap/argocd/helmchart.yaml"
root_app_file="${root_app_file:-${cluster_dir}/argocd/applications/root.yaml}"

print_header() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

get_argocd_server_deployment_name() {
  local deployment_name=""

  deployment_name="$(
    kubectl get deployment -n argocd -l "${argocd_server_selector}" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"

  if [[ -z "${deployment_name}" ]]; then
    deployment_name="$(
      kubectl get deployment argocd-server -n argocd \
        -o jsonpath='{.metadata.name}' 2>/dev/null || true
    )"
  fi

  printf '%s' "${deployment_name}"
}

get_argocd_server_service_name() {
  local service_name=""

  service_name="$(
    kubectl get svc -n argocd -l "${argocd_server_selector}" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"

  if [[ -z "${service_name}" ]]; then
    service_name="$(
      kubectl get svc argocd-server -n argocd \
        -o jsonpath='{.metadata.name}' 2>/dev/null || true
    )"
  fi

  printf '%s' "${service_name}"
}

print_argocd_bootstrap_diagnostics() {
  warn "Current argocd namespace resources:"
  kubectl get deploy,svc -n argocd --show-labels 2>/dev/null || true
  kubectl get all -n argocd 2>/dev/null || true
}

print_external_secrets_bootstrap_diagnostics() {
  warn "Current external-secrets namespace resources:"
  kubectl get deploy,svc -n external-secrets --show-labels 2>/dev/null || true
  kubectl get all -n external-secrets 2>/dev/null || true
}

print_argocd_repo_secret_diagnostics() {
  warn "Current Argo CD repo secret resources:"
  kubectl get externalsecret "${argocd_repo_secret_name}" -n "${argocd_repo_secret_namespace}" -o yaml 2>/dev/null || true
  kubectl get secret "${argocd_repo_secret_name}" -n "${argocd_repo_secret_namespace}" -o yaml 2>/dev/null || true
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "required file not found: $path" >&2
    exit 1
  fi
}

validate_doc_converter_configmap() {
  if [[ ! -f "$doc_converter_configmap_file" ]]; then
    if [[ -f "$legacy_doc_converter_configmap_file" ]]; then
      warn "Using legacy doc-converter config path: ${legacy_doc_converter_configmap_file}"
      doc_converter_configmap_file="$legacy_doc_converter_configmap_file"
    elif [[ -f "$legacy_doc_converter_configmap_typo_file" ]]; then
      warn "Using legacy doc-converter config path: ${legacy_doc_converter_configmap_typo_file}"
      doc_converter_configmap_file="$legacy_doc_converter_configmap_typo_file"
    fi
  fi

  if [[ ! -f "$doc_converter_configmap_file" ]]; then
    echo "doc-converter configmap file not found: $doc_converter_configmap_file" >&2
    echo "Hint: copy ${cluster_dir}/references/bootstrap-inputs/doc-converter-configmap.input.yaml.example to doc-converter-configmap.input.yaml and fill S3_BUCKET_NAME." >&2
    exit 1
  fi

  if ! grep -Eq '^[[:space:]]*S3_BUCKET_NAME:' "$doc_converter_configmap_file"; then
    echo "doc-converter configmap file must contain a hardcoded S3_BUCKET_NAME before apply: $doc_converter_configmap_file" >&2
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

ensure_shell_kubeconfig_default() {
  local bashrc="${HOME}/.bashrc"
  local start_marker="# >>> sixsense kubeconfig >>>"
  local end_marker="# <<< sixsense kubeconfig <<<"

  touch "${bashrc}"

  if grep -Fq "${start_marker}" "${bashrc}"; then
    return 0
  fi

  cat >> "${bashrc}" <<'EOF'

# >>> sixsense kubeconfig >>>
if [ -z "${KUBECONFIG:-}" ] && [ -f "$HOME/.kube/config" ]; then
  export KUBECONFIG="$HOME/.kube/config"
fi
# <<< sixsense kubeconfig <<<
EOF

  info "Added KUBECONFIG default to ${bashrc}. Re-login or run: source ~/.bashrc"
}

wait_for_argocd() {
  local seconds_left="$timeout_seconds"
  local deployment_name=""

  while true; do
    deployment_name="$(get_argocd_server_deployment_name)"
    if [[ -n "${deployment_name}" ]]; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_argocd_bootstrap_diagnostics
      echo "Timed out waiting for Argo CD server deployment in namespace argocd." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected Argo CD server deployment: ${deployment_name}"
  kubectl rollout status "deployment/${deployment_name}" -n argocd --timeout="${timeout_seconds}s"
}

wait_for_external_secrets() {
  local seconds_left="$timeout_seconds"

  while true; do
    if kubectl get deployment "${external_secrets_controller_deployment_name}" -n external-secrets >/dev/null 2>&1; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_external_secrets_bootstrap_diagnostics
      echo "Timed out waiting for External Secrets controller deployment in namespace external-secrets." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected External Secrets controller deployment: ${external_secrets_controller_deployment_name}"
  kubectl rollout status "deployment/${external_secrets_controller_deployment_name}" -n external-secrets --timeout="${timeout_seconds}s"

  seconds_left="$timeout_seconds"
  while true; do
    if kubectl get deployment "${external_secrets_webhook_deployment_name}" -n external-secrets >/dev/null 2>&1; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_external_secrets_bootstrap_diagnostics
      echo "Timed out waiting for External Secrets webhook deployment in namespace external-secrets." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected External Secrets webhook deployment: ${external_secrets_webhook_deployment_name}"
  kubectl rollout status "deployment/${external_secrets_webhook_deployment_name}" -n external-secrets --timeout="${timeout_seconds}s"
}

wait_for_external_secrets_crds() {
  local seconds_left="$timeout_seconds"

  while true; do
    if kubectl get crd clustersecretstores.external-secrets.io externalsecrets.external-secrets.io >/dev/null 2>&1 &&
      kubectl wait --for=condition=Established \
        crd/clustersecretstores.external-secrets.io \
        crd/externalsecrets.external-secrets.io \
        --timeout=30s >/dev/null 2>&1 &&
      kubectl get --raw /apis/external-secrets.io/v1 2>/dev/null | grep -q '"name":"clustersecretstores"' &&
      kubectl get --raw /apis/external-secrets.io/v1 2>/dev/null | grep -q '"name":"externalsecrets"'; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_external_secrets_bootstrap_diagnostics
      kubectl get crd | grep 'external-secrets.io' || true
      kubectl get --raw /apis/external-secrets.io/v1 2>/dev/null || true
      echo "Timed out waiting for External Secrets CRDs to be established." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected External Secrets CRDs: clustersecretstores.external-secrets.io, externalsecrets.external-secrets.io"

  seconds_left="$timeout_seconds"
  while true; do
    if [[ -n "$(
      kubectl get endpoints "${external_secrets_webhook_service_name}" -n external-secrets \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true
    )" ]]; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_external_secrets_bootstrap_diagnostics
      kubectl get endpoints "${external_secrets_webhook_service_name}" -n external-secrets -o yaml 2>/dev/null || true
      echo "Timed out waiting for External Secrets webhook endpoints to be ready." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected External Secrets webhook endpoints: ${external_secrets_webhook_service_name}"
}

wait_for_argocd_repo_secret() {
  local seconds_left="$timeout_seconds"
  local github_app_id=""
  local github_app_installation_id=""
  local github_app_private_key=""

  while true; do
    github_app_id="$(
      kubectl get secret "${argocd_repo_secret_name}" -n "${argocd_repo_secret_namespace}" \
        -o jsonpath='{.data.githubAppID}' 2>/dev/null || true
    )"
    github_app_installation_id="$(
      kubectl get secret "${argocd_repo_secret_name}" -n "${argocd_repo_secret_namespace}" \
        -o jsonpath='{.data.githubAppInstallationID}' 2>/dev/null || true
    )"
    github_app_private_key="$(
      kubectl get secret "${argocd_repo_secret_name}" -n "${argocd_repo_secret_namespace}" \
        -o jsonpath='{.data.githubAppPrivateKey}' 2>/dev/null || true
    )"

    if [[ -n "${github_app_id}" && -n "${github_app_installation_id}" && -n "${github_app_private_key}" ]]; then
      break
    fi

    if [[ "$seconds_left" -le 0 ]]; then
      print_argocd_repo_secret_diagnostics
      echo "Timed out waiting for Argo CD repo Secret ${argocd_repo_secret_namespace}/${argocd_repo_secret_name} to be created by External Secrets." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  info "Detected Argo CD repo Secret: ${argocd_repo_secret_namespace}/${argocd_repo_secret_name}"
}

install_argocd_cli() {
  local pf_pid=""
  local seconds_left="$timeout_seconds"
  local download_url="https://127.0.0.1:${argocd_cli_port_forward_port}/download/argocd-linux-amd64"
  cleanup_argocd_cli_install() {
    if [[ -n "${pf_pid}" ]]; then
      kill "${pf_pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${argocd_cli_download_path}"
  }

  if command -v argocd >/dev/null 2>&1; then
    info "argocd CLI already exists in PATH."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found. Cannot install argocd CLI automatically." >&2
    exit 1
  fi

  print_header "Argo CD CLI"
  info "argocd CLI not found. Downloading it from argocd-server."
  trap cleanup_argocd_cli_install RETURN

  local server_service_name=""
  server_service_name="$(get_argocd_server_service_name)"
  if [[ -z "${server_service_name}" ]]; then
    print_argocd_bootstrap_diagnostics
    echo "Could not detect Argo CD server service in namespace argocd." >&2
    exit 1
  fi

  kubectl port-forward "svc/${server_service_name}" -n argocd "${argocd_cli_port_forward_port}:443" >"${argocd_cli_port_forward_log}" 2>&1 &
  pf_pid=$!

  while ! curl -kfsS -o /dev/null "$download_url"; do
    if [[ "$seconds_left" -le 0 ]]; then
      echo "Timed out waiting for argocd CLI download endpoint." >&2
      exit 1
    fi
    sleep 5
    seconds_left=$((seconds_left - 5))
  done

  curl -kSL -o "${argocd_cli_download_path}" "$download_url"
  chmod 0755 "${argocd_cli_download_path}"

  if [[ -w "$(dirname "${argocd_cli_install_path}")" ]]; then
    install -m 0755 "${argocd_cli_download_path}" "${argocd_cli_install_path}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo install -m 0755 "${argocd_cli_download_path}" "${argocd_cli_install_path}"
  else
    echo "Cannot write ${argocd_cli_install_path}. Re-run with sufficient privileges or install argocd manually." >&2
    exit 1
  fi

  trap - RETURN
  cleanup_argocd_cli_install
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
require_file "$external_secrets_values_file"
require_file "$external_secrets_helmchart_file"
require_file "$external_secrets_clustersecretstore_file"
require_file "$external_secrets_argocd_repo_file"
require_file "$argocd_values_file"
require_file "$argocd_helmchart_file"
require_file "$root_app_file"
require_file "$kafka_alias_file"
validate_doc_converter_configmap

if [[ ! -x /usr/local/bin/k3s && ! -x /usr/local/bin/kubectl ]]; then
  echo "K3s does not appear to be installed on this server." >&2
  exit 1
fi

ensure_kubeconfig
ensure_shell_kubeconfig_default

print_header "Kubernetes"
kubectl get nodes >/dev/null

namespace_bootstrap_required="false"
eso_bootstrap_required="false"
argocd_bootstrap_required="false"
if [[ "$force_bootstrap" == "true" ]]; then
  namespace_bootstrap_required="true"
  eso_bootstrap_required="true"
  argocd_bootstrap_required="true"
else
  namespace_bootstrap_required="true"
  if ! kubectl get deployment "${external_secrets_controller_deployment_name}" -n external-secrets >/dev/null 2>&1; then
    eso_bootstrap_required="true"
  fi
  if [[ -z "$(get_argocd_server_deployment_name)" ]]; then
    argocd_bootstrap_required="true"
  fi
fi

print_header "Bootstrap"

if [[ "$namespace_bootstrap_required" == "true" ]]; then
  kubectl apply -f "$namespace_file"
fi

if [[ "$eso_bootstrap_required" == "true" ]]; then
  kubectl apply -f "$external_secrets_values_file"
  kubectl apply -f "$external_secrets_helmchart_file"
  wait_for_external_secrets
else
  warn "External Secrets controller deployment already exists. Skipping External Secrets bootstrap."
fi

print_header "External Secrets Resources"
wait_for_external_secrets_crds
kubectl apply -f "$external_secrets_clustersecretstore_file"
kubectl apply -f "$external_secrets_argocd_repo_file"
wait_for_argocd_repo_secret

if [[ "$argocd_bootstrap_required" == "true" ]]; then
  kubectl apply -f "$argocd_values_file"
  kubectl apply -f "$argocd_helmchart_file"
  wait_for_argocd
else
  warn "Argo CD server deployment already exists. Skipping namespace/Argo CD bootstrap."
fi

install_argocd_cli

print_header "Doc Converter Config"
kubectl apply -f "$doc_converter_configmap_file"

print_header "Kafka Alias"
kubectl apply -f "$kafka_alias_file"

print_header "Root App"
kubectl apply -f "$root_app_file"

print_header "Summary"
kubectl get ns argocd external-secrets logging apps
kubectl get deploy external-secrets -n external-secrets 2>/dev/null || true
kubectl get clustersecretstore sixsense-parameter-store 2>/dev/null || true
kubectl get externalsecret argocd-root-repo -n argocd 2>/dev/null || true
kubectl get configmap doc-converter-config -n apps
kubectl get svc,endpointslice -n logging | grep kafka || true
kubectl get -f "$root_app_file"
