ㅊ argocd CLI automatically." >&2
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

argocd_bootstrap_required="false"
if [[ "$force_bootstrap" == "true" ]]; then
  argocd_bootstrap_required="true"
else
  if [[ -z "$(get_argocd_server_deployment_name)" ]]; then
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
kubectl get ns argocd logging apps
kubectl get configmap doc-converter-config -n apps
kubectl get svc,endpointslice -n logging | grep kafka || true
kubectl get -f "$root_app_file"
