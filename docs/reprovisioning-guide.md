# 본 리포지토리를 다시 프로비저닝해보고 싶다면

아래 순서로 인프라 생성과 초기 설정을 진행합니다.

## 0. 시작 전에 준비합니다

실행 전에 아래 항목을 먼저 준비합니다.

- AWS 계정과 AWS CLI 인증 정보
- AWS에 등록된 EC2 Key Pair
- 로컬 또는 WSL에 저장된 해당 Key Pair의 `.pem` 파일
- 현재 내 공인 IP 주소
- Terraform, Ansible, Python 3

즉 `terraform.tfvars`에 넣을 `key_name` 값과, 실제 SSH 접속에 사용할 `.pem` 파일이 모두 준비되어 있어야 합니다.

## 프로비저닝에서 Terraform 과 Ansible 이 맡는 범위

이 저장소에서 Terraform 과 Ansible 은 어디까지나 K3s 검증을 편하게 하기 위한 보조 수단입니다.

`terraform apply`는 인프라 틀을 만듭니다.

- VPC
- Public subnet / Private subnet
- ALB
- Bastion host
- NAT instance 또는 NAT gateway
- K3s control-plane EC2
- K3s worker Auto Scaling Group
- MySQL RDS

그 다음 `ansible-playbook`은 생성된 control-plane 과 bastion 에 설정을 적용합니다.

- bastion 운영 패키지 설치
- k3s server 설치
- kubeconfig 배치
- namespace bootstrap
- ingress-nginx bootstrap
- Falco bootstrap
- node-exporter bootstrap
- MySQL RDS를 사용할 경우 DB Secret manifest 생성

## 1. Terraform 변수 준비

```bash
cd infra/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 최소한 아래 값은 현재 환경에 맞게 바꿉니다.

- `key_name`: AWS에 등록한 EC2 key pair 이름
- `admin_cidrs`: 현재 내 공인 IP/32

즉 key pair 이름은 AWS에 존재해야 하고, 로컬에는 그 key pair에 대응되는 `.pem` 파일도 있어야 합니다.

## 2. Terraform 실행

이 단계도 계속 `infra/environments/dev` 디렉터리에서 진행합니다. 초기 한 번만 아래 명령을 실행합니다.

```bash
terraform init
```

그 다음 아래 명령으로 인프라를 생성합니다.

```bash
terraform apply
```

## 3. Terraform output을 Ansible runtime 변수에 넣기

```bash
cd ../../ansible
cp vars/dev-runtime.example.yaml vars/dev-runtime.yaml
```

그 다음 Terraform output 값을 `vars/dev-runtime.yaml`에 채웁니다.

- `k3s_token`
- `mysql_rds_database_url`

예:

```bash
terraform -chdir=../infra/environments/dev output -raw k3s_join_token
terraform -chdir=../infra/environments/dev output -raw mysql_rds_database_url
```

## 4. Ansible 의존성 설치

가상환경 없이 시스템 Python 기준으로 진행합니다.

처음에 한 번 아래 명령을 실행합니다.

```bash
ansible-galaxy collection install -r requirements.yaml
python3 -m pip install boto3 botocore
```

## 5. 셸 환경 변수 설정

현재 셸에서 한 번 아래 환경 변수를 설정합니다.

```bash
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/<terraform.tfvars에 넣은 key pair 이름>.pem
```

WSL에서 `/mnt/c/...` 경로에서 실행한다면 이것도 같이 설정합니다.

```bash
export ANSIBLE_CONFIG=$PWD/ansible.cfg
```

## 6. Playbook 실행

```bash
ansible-playbook -i inventories/dev/aws_ec2.yaml playbooks/site.yaml \
  --extra-vars @vars/dev-runtime.yaml
```

이 inventory는 AWS에서 아래 태그를 가진 EC2를 자동 조회합니다.

- `Project = k3s-security`
- `Environment = dev`
- `Role = bastion`
- `Role = k3s-control-plane`

즉 bastion IP나 k3s server private IP를 inventory 파일에 손으로 적지 않습니다.

## 7. `cluster/` 폴더를 control-plane으로 복사합니다

먼저 bastion public IP와 control-plane private IP를 확인합니다.

```bash
cd ..
terraform -chdir=infra/environments/dev output -raw bastion_public_ip
terraform -chdir=infra/environments/dev output -raw k3s_server_private_ip
```

그 다음 루트 디렉터리의 `cluster/` 폴더를 통째로 control-plane 홈 디렉터리로 복사합니다. WinSCP, Tabby SFTP 같은 도구를 사용해 올려도 되고, `scp` 명령을 사용해도 됩니다.

```bash
scp -r \
  -o ProxyCommand="ssh -i ~/.ssh/<terraform.tfvars에 넣은 key pair 이름>.pem -W %h:%p ubuntu@<bastion_public_ip>" \
  -i ~/.ssh/<terraform.tfvars에 넣은 key pair 이름>.pem \
  cluster ubuntu@<k3s_server_private_ip>:~/
```

## 8. control-plane에서 workload를 배포합니다

control-plane에 접속한 뒤 아래 명령을 실행합니다.

```bash
kubectl apply -k ~/cluster/workloads/apps/checkins/overlays/dev
```

즉 control-plane 초기 설정 단계에서는 bootstrap 리소스가 먼저 올라가고, 이후 `kubectl apply -k ~/cluster/workloads/apps/checkins/overlays/dev` 를 실행할 때 `base` 를 포함한 실제 앱 workload 가 함께 적용됩니다.

앱 이미지를 바꾸고 싶다면 [patch-image.yaml](../cluster/workloads/apps/checkins/overlays/dev/patch-image.yaml) 에서 Docker Hub 이미지 이름과 태그를 바꿔주면 됩니다.

현재는 `cluster/` 폴더 복사와 workload apply를 Ansible에 자동으로 넣어두지 않았습니다. 이후 CI/CD를 연결할 때 Git에서 직접 받아 배포하는 흐름으로 확장할 수 있다고 보았기 때문입니다.

## 9. 인프라와 클러스터가 잘 떴는지 확인합니다

먼저 ALB DNS 이름을 확인합니다.

```bash
cd ..
terraform -chdir=infra/environments/dev output -raw alb_dns_name
```

브라우저에서 아래 주소로 접속해 애플리케이션이 뜨는지 확인합니다.

```text
http://<alb-dns-name>/
```

또는 터미널에서 아래처럼 확인할 수 있습니다.

```bash
curl -i http://<alb-dns-name>/
```

그 다음 control-plane 에 접속해서 `kubectl` 이 정상 동작하는지 확인합니다.

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

즉 최종적으로는 아래 두 가지가 확인되면 됩니다.

- ALB DNS 로 접속했을 때 애플리케이션이 응답하는지
- control-plane 에서 `kubectl` 명령이 정상 동작하는지
