# K3s · Argo CD GitOps 배포 구성

> [!NOTE]
> ## About this Repository
> kt cloud 클라우드 인프라 부트캠프 2기 심화 프로젝트 `오픈소스 기반 클라우드 네이티브 통합 보안 플랫폼`에서 제가 담당한 `K3s 구성`, `Argo CD GitOps 배포`와 팀과 함께 작업한 `CI` 파이프라인을 정리한 포트폴리오 레포지토리입니다. CI 워크플로우는 전체 흐름을 온전히 보여주기 위해 포함했습니다.
>
> 클라우드 인프라가 준비된 상태를 전제로, 그 위에 올라가는 Kubernetes 레이어를 관리합니다.

이 레포지토리의 핵심 구성은 다음과 같습니다.

- `GitHub Actions`로 `doc-converter` 이미지 빌드, 취약점 스캔, Docker Hub push, Kustomize 이미지 태그 갱신
- `K3s` 위에 올릴 bootstrap 리소스와 공통 클러스터 리소스 구성
- `Argo CD app-of-apps` 구조로 `ingress-nginx`, `node-exporter`, `Falco`, `doc-converter`를 wave 단위로 배포
- `ModSecurity`, `Falco`, `node-exporter`, 앱 메트릭을 연결한 보안/모니터링 흐름 구성

## 주요 설계 포인트

### CI · 배포 파이프라인

- **빌드부터 매니페스트 갱신까지 하나의 워크플로우로 통합했습니다.**  
  `doc-converter` 이미지 빌드 → `Trivy` 취약점 스캔 → `CRITICAL` 발견 시 워크플로 중단 → Docker Hub push → Kustomize 이미지 태그 갱신 순서로 이어집니다. 단순 자동화가 아니라 컨테이너 보안 게이팅을 포함한 배포 경로입니다.

- **GitOps에 이미지 변경을 자동 반영합니다.**  
  빌드된 이미지 태그가 Kustomize overlay에 바로 반영되므로, 실제 배포 기준을 Git만 보면 알 수 있습니다.

### 클러스터 구성 순서

- **K3s bootstrap 순서를 선언적으로 정리했습니다.**  
  `namespace → External Secrets → Argo CD → bootstrap 입력 리소스 → root-app` 순서로 맞춰, 의존성 문제로 sync가 꼬이지 않도록 했습니다.

- **Argo CD 배포 순서를 sync-wave로 제어했습니다.**  
  `app-of-apps` 구조와 `sync-wave`로 wave 1(`ingress-nginx`, `node-exporter`) → wave 2(`Falco`) → wave 3(`doc-converter`) 순서를 보장합니다. 스크립트나 수동 개입 없이 매니페스트만으로 배포 순서가 정의되므로, 앱이 늘어도 같은 방식으로 확장할 수 있습니다.

- **Helm 기반 구성요소는 values가 chart보다 먼저 적용되도록 했습니다.**  
  `ingress-nginx`와 `Falco`는 `HelmChartConfig`를 `HelmChart`보다 앞 wave에 두어 분리했습니다. 보안 설정이나 로그 연계 설정이 빠진 기본값 상태로 chart가 올라가는 문제를 방지합니다.

### 보안

- **private repo 접근에 GitHub App을 사용했습니다.**  
  SSH deploy key, PAT 대신 GitHub App을 선택했습니다. 개인 계정에 묶이지 않아 조직 단위로 관리할 수 있고, 여러 repo로 확장하기 쉽습니다. 매 요청마다 1시간짜리 단기 토큰으로 교환되므로, 유출돼도 노출 범위가 짧습니다. 자격정보는 AWS SSM Parameter Store에 두고 External Secrets Operator로 주입해, 민감 정보를 Git에 올리지 않습니다.

- **Access Key 대신 노드 IAM Role로 AWS에 인증합니다.**  
  control-plane은 SSM Parameter Store에서 Argo CD 자격정보를 읽고, worker node는 애플리케이션이 S3에 접근할 때 사용합니다. Access Key/Secret Key를 Kubernetes Secret에 저장하지 않으므로 키 관리 부담이 없고 유출 위험도 줄어듭니다. IAM 권한 설정 자체는 인프라 계층에서 담당합니다.

- **보안 이벤트를 Kafka 한 곳으로 수집합니다.**  
  `ModSecurity` 감사 로그와 `Falco` 이벤트를 모두 `kafka.logging`으로 전달합니다. 후속 분석 계층이 붙더라도 보안 로그 경로를 일관되게 유지할 수 있습니다.

### 앱 운영

- **앱 배포를 운영 가능한 단위로 구성했습니다.**  
  `doc-converter`는 `Deployment`, `Service`, `Ingress`, `HPA`, `ConfigMap` 주입, metrics NodePort까지 한 묶음으로 관리합니다. 실행 환경값, 확장 정책, 관측 지점을 모두 포함한 워크로드 단위입니다.

- **외부 Prometheus가 scrape할 수 있는 메트릭 접점을 제공합니다.**  
  `node-exporter`를 각 노드에 DaemonSet으로 배치해, 외부 모니터링 시스템이 바로 수집할 수 있도록 했습니다.

## 이 레포지토리가 관리하는 범위

- `cluster/bootstrap`
  - namespace 생성
  - External Secrets Operator bootstrap
  - Argo CD bootstrap
- `cluster/argocd`
  - `root-app`
  - child `Application`
- `cluster/manifests`
  - `ingress-nginx`
  - `falco`
  - `node-exporter`
- `cluster/workloads`
  - 실제 앱 workload 리소스 (현재는 `doc-converter` 중심)
- `cluster/references/bootstrap-inputs`
  - bootstrap 전에 실제값을 채워야 하는 입력 파일
- `.github/workflows`
  - `doc-converter` CI/CD 워크플로우
- `app`
  - 실제 애플리케이션 소스 코드

## 전체 흐름

### 서비스 트래픽

```
ALB → worker NodePort → ingress-nginx → Service → Pod
```

`ingress-nginx`는 worker 노드에 `DaemonSet`으로 배치하며, NodePort는 HTTP `30080` / HTTPS `30443`을 사용합니다.

`doc-converter` 연결 경로:

- Ingress: `/`
- Service: `apps/doc-converter`
- Pod port: `8000`

### 보안/모니터링 흐름

#### ModSecurity audit log

```
Ingress Request → ModSecurity 검사 → audit log 생성 → fluent-bit-sidecar → kafka.logging → 외부 Kafka
```

- `ingress-nginx` controller에 ModSecurity를 활성화했습니다.
- audit log는 `/var/log/audit/modsec_audit.log`에 기록됩니다.
- 같은 Pod의 `fluent-bit-sidecar`가 이 로그를 tail해 `kafka.logging.svc.cluster.local:9092`로 전달합니다.

#### Falco 이벤트

```
Node Runtime Event → Falco → Falcosidekick → kafka.logging → 외부 Kafka
```

#### 노드/앱 메트릭

- 노드 메트릭: `<node-private-ip>:9100` (node-exporter DaemonSet, `hostNetwork: true`)
- 앱 메트릭: `<worker-node-ip>:30081/metrics` (doc-converter metrics NodePort)

## 디렉터리 구조

```text
.
├── .github/workflows/ci.yml
├── app/
│   ├── checkins/
│   └── doc-converter/
├── cluster/
│   ├── bootstrap/
│   ├── argocd/
│   ├── manifests/
│   ├── workloads/
│   └── references/bootstrap-inputs/
└── ops-scripts/
```

현재 설명과 배포 흐름의 초점은 `doc-converter`입니다.

`doc-converter` 기준 주요 파일 위치:

- 앱 코드: `app/doc-converter`
- 이미지 참조: `cluster/workloads/apps/doc-converter/overlays/dev/kustomization.yaml`
- Argo CD app: `cluster/argocd/applications/apps/doc-converter-dev.yaml`

## Bootstrap 순서

```
1.  00-namespaces.yaml
2.  External Secrets values
3.  External Secrets helmchart
4.  ClusterSecretStore
5.  argocd-root-repo ExternalSecret
6.  Argo CD values
7.  Argo CD helmchart
8.  doc-converter-configmap.input.yaml
9.  kafka-alias.yaml
10. root-app
```

`ops-scripts/bootstrap-argocd-after-k3s.sh`도 같은 순서를 따르는 보조 스크립트입니다.

각 단계가 필요한 이유:

- namespaced resource를 apply하려면 namespace가 먼저 있어야 합니다.
- `HelmChartConfig(values)`가 `HelmChart`보다 먼저 들어가야 chart가 처음부터 원하는 값으로 설치됩니다.
- Argo CD가 repo를 읽으려면 `argocd-root-repo` Secret이 먼저 준비돼 있어야 합니다.
- `doc-converter-config`는 `doc-converter` Pod보다 먼저 있어야 합니다.
- `kafka-alias`는 `ingress-nginx` sidecar와 `Falco`가 참조하는 이름이므로, child app sync 전에 준비돼 있어야 합니다.
- `root-app`은 마지막에 apply해야 child app들이 선행 리소스를 볼 수 있습니다.

## HelmChart 리소스 순서 제어

`ingress-nginx`와 `falco`는 `HelmChartConfig + HelmChart` 구조를 사용합니다. values가 chart보다 먼저 적용돼야 하므로 sync-wave로 순서를 분리했습니다.

- `HelmChartConfig`와 선행 `ConfigMap`: `sync-wave: "-1"`
- `HelmChart`: `sync-wave: "0"`

관련 파일:

- `cluster/manifests/ingress-nginx/values.yaml`
- `cluster/manifests/ingress-nginx/modsecurity-audit-sidecar-config.yaml`
- `cluster/manifests/ingress-nginx/helmchart.yaml`
- `cluster/manifests/falco/values.yaml`
- `cluster/manifests/falco/helmchart.yaml`

## Argo CD sync-wave 설계

| Wave | Application |
|------|-------------|
| 1 | `ingress-nginx`, `node-exporter` |
| 2 | `falco` |
| 3 | `doc-converter-dev` |

외부 트래픽을 받는 ingress와 노드 메트릭 수집기를 먼저 올리고, 그 뒤 런타임 보안인 Falco, 마지막으로 앱 워크로드가 배포됩니다. 같은 wave의 Application은 동시에 sync됩니다.

## CI/CD 연결

GitHub Actions 워크플로우 트리거:

- branch: `main`
- path: `app/doc-converter/**`, `.github/workflows/ci.yml`

워크플로우 단계:

1. `app/doc-converter` 기준으로 Docker image build
2. Trivy 취약점 스캔 (`CRITICAL` 발견 시 중단)
3. Docker Hub에 `latest`와 `github.sha` 태그로 push
4. `cluster/workloads/apps/doc-converter/overlays/dev/kustomization.yaml` 이미지 태그를 `github.sha`로 갱신
5. 수정된 `kustomization.yaml`을 commit/push

배포 전체 흐름:

```
app/doc-converter 코드 변경 → GitHub Actions build/push → overlay image tag 갱신 → Argo CD가 Git 변경 감지 → 앱 배포
```

필요한 GitHub Actions Secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## 다른 환경에서 사용할 때

### Docker Hub 이미지 이름

`cluster/workloads/apps/doc-converter/overlays/dev/kustomization.yaml`의 `newName`을 수정합니다.

```yaml
images:
  - name: doc-converter-image
    newName: <your-dockerhub-username>/doc-converter
```

`ci.yml`은 `DOCKERHUB_USERNAME` secret을 참조하므로 그대로 둬도 됩니다.

### GitHub repo URL

Argo CD가 바라보는 `repoURL`을 아래 파일에서 수정합니다.

- `cluster/argocd/applications/root.yaml`
- `cluster/argocd/applications/apps/*.yaml`
- `cluster/bootstrap/external-secrets/argocd-root-repo.externalsecret.yaml`

## Bootstrap 전 실제값 설정

### 1. `doc-converter-configmap.input.yaml`

예시 파일을 복사해 실제값을 채웁니다.

- 예시: `cluster/references/bootstrap-inputs/doc-converter-configmap.input.yaml.example`
- 적용: `cluster/references/bootstrap-inputs/doc-converter-configmap.input.yaml`

```yaml
data:
  S3_BUCKET_NAME: <your-s3-bucket-name>
```

`doc-converter`는 `S3_BUCKET_NAME`을 환경변수로 읽고, readiness probe도 이 값을 확인합니다.

### 2. `kafka-alias.yaml`

외부에 도달 가능한 Kafka 클러스터가 먼저 준비돼 있어야 합니다. 보안 로그(ModSecurity, Falco)가 이 Kafka로 전달됩니다.

경로: `cluster/references/bootstrap-inputs/kafka-alias.yaml`

```yaml
endpoints:
  - addresses:
      - <your-external-kafka-private-ip>  # 예: 192.168.x.x
```

이 값을 수정하지 않으면 `ingress-nginx` ModSecurity sidecar와 `Falcosidekick`이 Kafka를 찾지 못합니다.

### 3. Argo CD 레포지토리 자격정보

Argo CD가 private repo를 읽으려면 GitHub App 자격정보가 필요합니다.

먼저 다음을 준비합니다.

1. 대상 organization 또는 계정에 GitHub App 생성 (권한: `Contents: Read`)
2. 대상 repo에 App 설치
3. 발급된 `app-id`, `installation-id`, `private-key`를 AWS SSM Parameter Store에 저장

`cluster/bootstrap/external-secrets/argocd-root-repo.externalsecret.yaml`은 Parameter Store의 아래 키를 참조합니다.

- `/sixsense/argocd/github-app/app-id`
- `/sixsense/argocd/github-app/installation-id`
- `/sixsense/argocd/github-app/private-key`

bootstrap을 그대로 사용하려면 다음도 준비돼 있어야 합니다.

- control-plane에서 AWS SSM Parameter Store를 읽을 수 있는 IAM 권한
- 위 3개의 Parameter Store 값

## 앱 설정 (doc-converter)

### 기본 정보

`doc-converter`는 문서 파일을 변환해 S3에 업로드하는 FastAPI 기반 내부 서비스입니다.

- 경로: `app/doc-converter`
- 런타임: FastAPI
- 컨테이너 포트: `8000`
- 주요 endpoint: `/`, `/health`, `/ready`, `/metrics`
- 사용 환경변수: `S3_BUCKET_NAME`

### Kubernetes 리소스

- **Deployment**: worker node 스케줄, anti-affinity + topology spread, `doc-converter-config` ConfigMap 주입, startup/readiness/liveness probe, `maxUnavailable: 0` / `maxSurge: 1`의 create-first rolling update
- **Service**: port `80 → 8000`
- **Ingress**: `/` 경로
- **HPA**: minReplicas `2`, maxReplicas `4`, CPU target `60%`
- **dev overlay**: 이미지 이름/태그, 리소스 request/limit, dead node toleration, runtime info env, metrics NodePort `30081`

현재 기본 이미지 설정:

```yaml
images:
  - name: doc-converter-image
    newName: z33hyo/doc-converter
    newTag: "0.4"
```

CI가 실행될 때마다 `newTag`는 `github.sha`로 갱신됩니다.

## Bootstrap 방법

실제 환경에서는 인프라 담당이 별도 Ansible 플레이북으로 설치합니다. 이 레포지토리만으로 동일 순서를 재현하고 싶다면 `ops-scripts/bootstrap-argocd-after-k3s.sh`를 사용할 수 있습니다.

전제 조건:

- K3s가 설치돼 있고 `kubectl`로 클러스터에 접근 가능
- `cluster/references/bootstrap-inputs/doc-converter-configmap.input.yaml`에 실제 `S3_BUCKET_NAME` 입력 완료
- `cluster/references/bootstrap-inputs/kafka-alias.yaml`에 실제 Kafka IP 입력 완료
- ExternalSecret 방식을 그대로 사용한다면 AWS SSM Parameter Store와 IAM 권한까지 준비 완료

```bash
bash ops-scripts/bootstrap-argocd-after-k3s.sh
```

## Future Work

- `AWS Node Termination Handler`를 통해 Spot interruption, 예정된 인스턴스 종료, scale-in 상황에서 worker node `cordon/drain` 자동화
- `aws-cloud-controller-manager` 연동 또는 기존 cleanup 스크립트 자동화로 scale-in 또는 node 종료 이후 남아 있는 `NotReady` node와 Pod 정리 자동화
- 리소스 여유가 확보되면 `descheduler`를 도입해 노드 장애 복구 후 한 노드에 몰린 Pod 재균형 자동화
- `Cluster Autoscaler` 연동으로 worker 증감과 스케줄링을 더 자연스럽게 연결
- 단일 control-plane 구조를 multi control-plane K3s HA 구성으로 확장
- node IAM role에 의존하지 않고 ServiceAccount/OIDC 기반의 Pod 단위 IAM 권한 분리 방식 검토
- 앱 이미지 CI와 별도로 Argo CD/Kustomize manifest 변경에 대한 검증 CI 추가
