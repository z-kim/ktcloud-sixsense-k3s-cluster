# K3s 구성 리포지토리 (임시 README)

본래는 단위 테스트를 위해 프로비저닝 절차까지 함께 구현했던 저장소가 있었는데,
본 리포지토리는 팀에서 사용하는 Terraform / Ansible 구성에 맞추어, K3s 및 클러스터 리소스 구성 부분만 분리해 가져온 리포지토리입니다.

- 원본 리포지토리: `https://github.com/z-kim/ktcloud-sixsense-k3s.git`

현재 아래 항목은 계속 테스트 및 정리 중입니다.

- ModSecurity 로그 수집 및 전달
- Argo CD를 통한 GitHub 저장소 연동 및 배포 흐름


## 이 리포지토리에서 보여주고 싶은 것

- K3s 기반 클러스터 리소스 구성 방식
- ingress-nginx, Falco, Fluent Bit, node-exporter 등의 배치 방식
  - ModSecurity, Falco 등의 로그는 Fluent Bit과 Falcosidekick을 통해 별도 Kafka 서버로 전송됩니다.
- Argo CD app-of-apps 구조 적용 방식
- ArgoCD를 통한 Github 저장소 연동 및 배포 흐름
- GitOps 적용을 고려한 리소스 설계
- Terraform / Ansible 과 Kubernetes 리소스 구성의 경계 분리

## 현재 구성 핵심

이 저장소는 이미 준비된 환경 위에 K3s 클러스터 리소스를 올리기 위한 저장소입니다.

현재 주요 디렉터리는 아래와 같습니다.

- `cluster/bootstrap`
  - namespace, Argo CD bootstrap 리소스
- `cluster/argocd`
  - Argo CD가 관찰할 github 주소 및 app
- `cluster/manifests`
  - ingress-nginx, falco, fluent-bit, node-exporter 등 공통 클러스터 리소스
- `cluster/workloads`
  - 예시/테스트용 애플리케이션 리소스
- `ops-scripts`
  - k3s 운영시 관리 및 테스트 관련 각종 보조 스크립트
- `docs`
  - 문서 초안

## 설치/적용하는 것

이 저장소에서 현재 다루는 설치 대상은 주로 아래와 같습니다.

- Argo CD
- ingress-nginx (+modsecurity),
- Fluent Bit
- Falco
- node-exporter
- doc-converter(우리가 서비스할 앱으로, 다른 팀원이 개발)

## Checkins 앱에 대해 (deprecated)

`checkins` 앱은임시 확인 및 예시 배포용으로 포함된 리소스입니다.

- 애플리케이션을 K3s 위에 어떤 방식으로 배포하는지
- Secret / ConfigMap / Ingress / HPA / Probe 등을 어떻게 구성하는지

`checkins` 관련 리소스와 YAML은 이후 변경될 수 있으며, 다른 애플리케이션으로 교체될 수도 있습니다.

현재 `checkins` 관련 리소스는 아래 경로에서 볼 수 있습니다.

- [base kustomization](./cluster/workloads/apps/checkins/base/kustomization.yaml)
- [Deployment](./cluster/workloads/apps/checkins/base/deployment.yaml)
- [Service](./cluster/workloads/apps/checkins/base/service.yaml)
- [Ingress](./cluster/workloads/apps/checkins/base/ingress.yaml)
- [HPA](./cluster/workloads/apps/checkins/base/hpa.yaml)
- [dev overlay kustomization](./cluster/workloads/apps/checkins/overlays/dev/kustomization.yaml)
- [image patch](./cluster/workloads/apps/checkins/overlays/dev/patch-image.yaml)
- [resource patch](./cluster/workloads/apps/checkins/overlays/dev/patch-resources.yaml)
- [replica patch](./cluster/workloads/apps/checkins/overlays/dev/patch-replicas.yaml)
- [toleration patch](./cluster/workloads/apps/checkins/overlays/dev/patch-tolerations.yaml)

## 현재 상태

현재 이 저장소는 아래 방향으로 계속 정리 중입니다.

- README 재작성
- 문서 및 디렉토리 구조 정리
- Argo CD 배포 흐름 안정화
- ModSecurity 로그 전달 방식 검증
- 수동 설치 / 삭제 절차 정리
