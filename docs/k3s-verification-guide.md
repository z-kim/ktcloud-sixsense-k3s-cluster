# K3s 확인 가이드

이 문서는 현재 클러스터가 떠 있는 상태에서 아래 항목을 확인하는 절차를 정리한 문서입니다.

- Doc Converter 앱에 CPU 부하를 걸었을 때 HPA 가 어떻게 반응하는지
- worker node 장애 또는 drain 상황에서 Pod 가 어떻게 이동하는지
- node-exporter 가 각 노드에 정상적으로 올라가 있는지
- Falcosidekick 이 Falco 이벤트를 실제로 받고 있는지
- Argo CD 핵심 컴포넌트가 정상적으로 떠 있는지
- ModSecurity 가 ingress-nginx 안에서 켜져 있는지
- `fluent-bit-sidecar` 가 ModSecurity audit 로그를 실제로 읽고 있는지

빠르게 전체 상태만 먼저 보고 싶다면 아래 스크립트를 사용할 수 있습니다.

```bash
bash ops-scripts/quick-check-k3s.sh
```

외부 접속 주소 응답까지 같이 보고 싶으면 아래처럼 실행합니다.

```bash
bash ops-scripts/quick-check-k3s.sh --alb-url http://<alb-dns-name>
```

이 스크립트는 아래 항목을 간단히 확인합니다.

- `kubectl` 이 클러스터에 연결되는지
- `ingress-nginx-controller` 가 준비되었는지
- `ingress-nginx` Pod 에 `fluent-bit-sidecar` 가 같이 있는지
- `modsecurity-audit-sidecar-config` ConfigMap 이 있는지
- `falco-falcosidekick` 이 준비되었는지
- `node-exporter` DaemonSet 이 각 노드에 맞게 떠 있는지
- `argocd-server`, `argocd-repo-server` 가 준비되었는지
- `doc-converter` Deployment / Service / Ingress 가 보이는지
- 필요하면 ingress-nginx `/health` 응답이 오는지

## 1. HPA 와 장애 대응 확인


### 1.1 Doc Converter 기본 상태 확인

먼저 아래 명령으로 기본 상태를 확인합니다.

```bash
kubectl get deploy,hpa -n apps
kubectl get pods -n apps -o wide
kubectl get ingress -n apps
kubectl rollout status deployment/doc-converter -n apps
```

확인 포인트는 아래와 같습니다.

- `deployment/doc-converter` 가 `Available` 상태인지 확인합니다.
- `hpa/doc-converter` 가 보이는지 확인합니다.
- Doc Converter Pod 가 worker node 에 올라가 있는지 확인합니다.
- `ingress/doc-converter` 가 생성되어 있는지 확인합니다.

### 1.2 HPA 반응 간단 확인

부하를 걸고 pod가 늘어나는 것을 볼 수 있습니다.

부하 종료 후 시간이 지나 다시 pod가 줄어드는 것을 볼 수 있습니다.

```bash
kubectl get hpa -n apps -w
kubectl get pods -n apps -w
```

다른 터미널에서:

```bash
bash ops-scripts/stress-pods.sh -n apps -l app=doc-converter -p 1 -s 60
```

여기서는 replica 수가 실제로 바뀌는지 정도만 확인하면 충분합니다.

### 1.3 Pod 복구 확인

아래 명령을 사용, 파드를 지웠을 때 복구되는 것을 볼 수 있습니다.

```bash
kubectl delete pod -n apps <pod-name>
kubectl get pods -n apps -w
```

### 1.4 worker 장애 대응 확인

worker node 장애 상황을 보려면 AWS 콘솔에서 worker 인스턴스를 중지하거나 terminate 한 뒤, control-plane 에서 아래 변화를 확인합니다.

```bash
kubectl get nodes -w
kubectl get pods -n apps -o wide -w
kubectl get pods -n ingress-nginx -o wide -w
```

여기서는 다음을 기대합니다.

- 해당 node 가 `NotReady` 또는 `Unreachable` 로 바뀌는 것
- Doc Converter Pod 와 ingress-nginx Pod 가 영향 받는 것
- 대체 worker 가 뜬 뒤 다시 스케줄되는 것

## 2. Node Exporter 확인

node-exporter는 `monitoring` namespace에 Daemonset으로 올라갑니다. Control plane에도 올라갑니다.

- [daemonset.yaml](../cluster/manifests/node-exporter/daemonset.yaml)


### 2.1 DaemonSet 이 떠 있는지 확인

먼저 control-plane 에서 아래 명령을 실행합니다.

```bash
kubectl get ds -n monitoring
kubectl get pods -n monitoring -o wide
kubectl get nodes -o wide
```

확인 포인트는 아래와 같습니다.

- `node-exporter` DaemonSet 이 보이는지 확인합니다.
- `DESIRED`, `CURRENT`, `READY` 가 노드 수와 맞는지 확인합니다.
- Pod 가 control-plane, worker 노드에 각각 올라갔는지 확인합니다.

### 2.2 노드별 메트릭 확인

현재 node-exporter 는 각 노드의 `:9100` 에서 메트릭을 노출합니다. 따라서 control-plane 에서 각 노드 private IP 를 향해 직접 확인할 수 있습니다.

```bash
curl http://<control-plane-private-ip>:9100/metrics | head
curl http://<worker-1-private-ip>:9100/metrics | head
curl http://<worker-2-private-ip>:9100/metrics | head
```

특정 메트릭 계열만 보고 싶으면 아래처럼 확인합니다.

```bash
curl http://<worker-private-ip>:9100/metrics | grep node_cpu
curl http://<worker-private-ip>:9100/metrics | grep node_memory
curl http://<worker-private-ip>:9100/metrics | grep node_filesystem
```

## 3. Falcosidekick 확인

현재 Demonset으로 Falco가, Deployment로 Falcosidekick 이 켜져 있습니다.

- [values.yaml](../cluster/manifests/falco/values.yaml)

Sidekick은 이벤트를 받으면 Kafka 등으로 실시간 전송할 수 있습니다. 필요하면 `debug: true` 를 임시로 켜서 이벤트 흐름을 더 자세히 볼 수 있습니다.

- `falcosidekick.enabled: true`
- `falcosidekick.replicaCount: 2`
- `falcosidekick.config.debug` 는 현재 기본값으로는 꺼져 있고, 필요할 때만 임시로 켜는 쪽이 좋습니다.


### 3.1 Falco 와 Falcosidekick Pod 상태 확인

```bash
kubectl get pods -n falco
```

기대하는 상태는 아래와 같습니다.

- `falco` DaemonSet Pod 들이 보입니다.
- `falco-falcosidekick-*` Deployment Pod 들이 따로 보입니다.
- 현재 값 기준으로는 `falco` Pod 는 `1/1`, `falcosidekick` Pod 도 각각 `1/1` 로 보입니다.

리소스 단위로 보고 싶으면 아래 명령이 더 직접적입니다.

```bash
kubectl get ds,deploy,pods -n falco
```

여기서 보통 아래처럼 이해하면 됩니다.

- `ds/falco`: 노드별 Falco 에이전트
- `deploy/falco-falcosidekick`: 이벤트를 받아 후속 output 으로 넘기는 별도 Deployment

### 3.2 Sidekick 로그 확인

터미널 1 에서 아래 명령으로 Falcosidekick 로그를 확인합니다.

```bash
kubectl logs -n falco deploy/falco-falcosidekick -f
```

replica 가 2개라면 Pod 하나를 찍어서 봐도 됩니다.

```bash
kubectl logs -n falco falco-falcosidekick-55f9487d86-gpxck -f
```

replica 전체 흐름을 같이 보려면 아래처럼 label selector 로 보는 편이 더 낫습니다.

```bash
kubectl logs -n falco -l app.kubernetes.io/name=falcosidekick -f --prefix
```

즉 아래처럼 보면 됩니다.

- Pod 하나만 빠르게 볼 때는 `deploy/falco-falcosidekick`
- 두 replica 중 어느 쪽이 이벤트를 처리하는지까지 보려면 `-l app.kubernetes.io/name=falcosidekick --prefix`

### 3.3 Falcosidekick debug 를 임시로 켜서 보기

조금 더 자세한 이벤트 흐름이 필요하면 [values.yaml](../cluster/manifests/falco/values.yaml) 에서 아래처럼 `debug: true` 를 잠깐 켤 수 있습니다.

```yaml
falcosidekick:
  enabled: true
  replicaCount: 2
  config:
    debug: true
```

적용:

```bash
kubectl apply -f ~/cluster/manifests/falco/values.yaml
kubectl apply -f ~/cluster/manifests/falco/helmchart.yaml
kubectl rollout status deployment/falco-falcosidekick -n falco --timeout=5m
```

확인:

```bash
kubectl logs -n falco -l app.kubernetes.io/name=falcosidekick -f --prefix
```

기대하는 흐름은 아래와 같습니다.

- Falco 에서 넘어온 이벤트 payload 가 더 자세히 보입니다.
- Kafka 전송 시도나 실패 흔적이 더 직접적으로 보일 수 있습니다.
- 두 replica 중 어느 Pod 가 이벤트를 받는지도 더 쉽게 확인할 수 있습니다.

### 3.4 확인이 끝난 뒤 원복

`debug: true` 는 평소에 계속 켜 두기보다, 확인이 끝나면 다시 주석 처리하거나 제거하는 편이 좋습니다.

```yaml
falcosidekick:
  enabled: true
  replicaCount: 2
  config:
    # debug: true
```

그 다음 다시 적용합니다.

```bash
kubectl apply -f ~/cluster/manifests/falco/values.yaml
kubectl apply -f ~/cluster/manifests/falco/helmchart.yaml
kubectl rollout status deployment/falco-falcosidekick -n falco --timeout=5m
```

### 3.5 Falco 로그 참고 확인

터미널 2 에서 아래 명령으로 Falco 로그를 볼 수 있습니다.

```bash
kubectl logs -n falco ds/falco -f
```

다만 Falco 쪽 로그는 상황에 따라 Falcosidekick 로그보다 덜 즉각적으로 보일 수 있으므로, 현재 확인의 중심은 `falcosidekick` 로그가 잘 뜨는지에 두는 편이 좋습니다.

### 3.6 재현 쉬운 Falco 이벤트 만들기

터미널 3 에서 아래처럼 임시 BusyBox Pod 를 만들어 `exec` 합니다. 또는 파드 내에서 `cat /etc/shadow`를 실행해볼 수 있습니다.

```bash
kubectl run busybox-shell-test --image=busybox -- sleep 3600
kubectl exec -it busybox-shell-test -- sh
kubectl delete pod busybox-shell-test
```

또는 아래처럼 Kubernetes API 접근 시도를 테스트할 수도 있습니다.

```bash
kubectl run busybox-api-test --image=busybox -- sleep 3600
kubectl exec busybox-api-test -- wget -qO- --no-check-certificate https://kubernetes.default.svc
kubectl delete pod busybox-api-test
```


### 3.7 확인 포인트

성공적으로 이어지면 보통 아래 흐름을 기대합니다.

1. Falco 쪽에서 rule 이 탐지됩니다.
2. Falcosidekick 로그에도 이벤트 처리 흔적이 보입니다.


## 4. ModSecurity 확인

현재 구조에서 ingress-nginx 안에서 동작합니다.

- [values.yaml](../cluster/manifests/ingress-nginx/values.yaml)
- [ingress.yaml](../cluster/workloads/apps/doc-converter/base/ingress.yaml)
- 자세한 sidecar 검증 흐름은 [fluent-bit-test-without-kafka-guide.md](./fluent-bit-test-without-kafka-guide.md) 에 따로 정리되어 있습니다.

### 4.1 ingress-nginx Pod 확인

```bash
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o wide
kubectl get svc -n ingress-nginx
```

### 4.2 ingress 내부 nginx 설정에 ModSecurity 가 반영됐는지 확인

먼저 ingress Pod 이름을 하나 확인합니다.

```bash
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

그 다음 아래 명령을 실행합니다.

```bash
kubectl exec -n ingress-nginx <ingress-pod-name> -- sh -c "grep -i modsecurity /etc/nginx/nginx.conf"
```

여기서 `modsecurity on;` 같은 설정이 보이면 ModSecurity 가 ingress-nginx 안에 반영된 것입니다.

### 4.3 간단한 SQLi / XSS 요청으로 동작 확인

실제 요청에서 ModSecurity 가 반응하는지도 간단히 볼 수 있습니다. 아래 예시는 harmless test payload 를 query string 으로 보내는 방식입니다.

먼저 외부 접속 주소나 ingress 로 접근 가능한 URL 을 준비합니다.

```bash
export APP_URL=http://<external-address>
```

SQLi 성격의 요청 예시:

- 원문: `1 OR 1=1`
- URL 인코딩 형태: `1%20OR%201%3D1`

```bash
curl -i "${APP_URL}/?q=1%20OR%201%3D1"
```

XSS 성격의 요청 예시:

- 원문: `<script>alert(1)</script>`
- URL 인코딩 형태: `%3Cscript%3Ealert(1)%3C%2Fscript%3E`

```bash
curl -i "${APP_URL}/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
```

기대하는 반응은 아래 둘 중 하나입니다.

- ModSecurity / CRS 룰에 걸려 `403` 이 반환됨
- 응답은 통과되더라도 ingress-nginx 쪽 로그에 ModSecurity 탐지 흔적이 남음

즉 `403` 이 반드시 나와야만 성공이라고 보기보다는, 실제 탐지 또는 차단이 발생하는지까지 함께 보는 편이 좋습니다.

### 4.4 ingress-nginx 로그에서 ModSecurity 흔적 확인

요청을 보낸 직후 ingress-nginx controller 로그를 확인합니다.

```bash
kubectl logs -n ingress-nginx ds/ingress-nginx-controller -f | grep -i modsecurity
```

또는 특정 controller Pod 하나만 보고 싶다면:

```bash
kubectl logs -n ingress-nginx <ingress-pod-name> -f | grep -i modsecurity
```

여기서 `ModSecurity` 관련 로그가 보이면 실제 요청 경로에서 룰이 동작한 것으로 볼 수 있습니다.

## 5. Fluent Bit Sidecar 확인

현재 구조에서는 `ingress-nginx controller` 가 ModSecurity audit JSON 을 `/var/log/audit/modsec_audit.log` 에 쓰고, 같은 Pod 안의 `fluent-bit-sidecar` 가 이 파일을 읽어 Kafka 로 보내는 역할을 합니다.

즉 ingress-nginx 안에 ModSecurity 가 켜져 있어도, sidecar 가 안 떠 있거나 audit 파일을 못 읽으면 보안 이벤트 파이프라인은 끝까지 이어지지 않습니다.

### 5.1 sidecar 컨테이너가 같이 떠 있는지 확인

```bash
kubectl get pods -n ingress-nginx -o wide
kubectl get pod -n ingress-nginx <pod-name> -o jsonpath='{.spec.containers[*].name}'
```

여기서 `controller` 와 `fluent-bit-sidecar` 가 같이 보여야 합니다.

### 5.2 sidecar ConfigMap 과 핵심 설정 확인

```bash
kubectl get configmap modsecurity-audit-sidecar-config -n ingress-nginx -o yaml
```

최소한 아래 항목은 보이는 것이 좋습니다.

- `Path /var/log/audit/modsec_audit.log`
- `Parser modsecurity_json`
- `Brokers kafka.logging.svc.cluster.local:9092`

즉 sidecar 가 어느 파일을 읽고, 어떤 parser 를 쓰며, 어디로 보내는지까지 한 번에 확인하는 단계입니다.

### 5.3 controller 안 audit 파일 생성 확인

```bash
kubectl exec -n ingress-nginx <pod-name> -c controller -- \
  sh -c 'ls -l /var/log/audit/modsec_audit.log'

kubectl exec -n ingress-nginx <pod-name> -c controller -- \
  sh -c 'tail -n 5 /var/log/audit/modsec_audit.log'
```

여기서 JSON 한 줄씩 누적되는 것이 보이면 ModSecurity audit 파일 자체는 정상적으로 생성되고 있다고 볼 수 있습니다.

### 5.4 sidecar 로그 확인

```bash
kubectl logs -n ingress-nginx <pod-name> -c fluent-bit-sidecar --tail=200
```

현재 Kafka 가 아직 열려 있지 않다면 아래 같은 로그가 보일 수 있습니다.

- `inotify_fs_add()`
- `No route to host`
- `message delivery failed`

이 경우에도 input 이 살아 있고 audit 파일 감시가 시작됐다면 sidecar 자체는 정상에 가깝습니다.

### 5.5 실제 이벤트가 sidecar 까지 올라오는지 확인

간단한 ModSecurity 테스트 요청을 보낸 뒤:

```bash
curl -i "${APP_URL}/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
```

또는 JSON POST 엔드포인트가 있다면:

```bash
curl -i -X POST "${APP_URL}/<json-post-path>" \
  -H 'Content-Type: application/json' \
  --data '{"name":"1 OR 1=1"}'
```

그 다음 아래 둘 중 하나를 확인합니다.

```bash
kubectl exec -n ingress-nginx <pod-name> -c controller -- \
  sh -c "grep -E '942100|949110|\\\"method\\\":\\\"POST\\\"' /var/log/audit/modsec_audit.log | tail -10"
```

```bash
kubectl logs -n ingress-nginx \
  -l app.kubernetes.io/component=controller \
  -c fluent-bit-sidecar \
  --since=1m --prefix --max-log-requests=10
```

여기서 기대하는 것은 아래 둘 중 하나입니다.

- audit 파일에 실제 탐지 이벤트가 기록된다.
- sidecar 로그에서 audit JSON 처리 또는 Kafka 전송 시도 흔적이 보인다.

즉 `ModSecurity 탐지 -> audit 파일 기록 -> fluent-bit-sidecar 처리` 까지 이어지면 현재 구조 검증은 충분히 된 것입니다.
