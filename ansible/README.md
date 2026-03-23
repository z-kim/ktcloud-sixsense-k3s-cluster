# Ansible Layout

이 디렉터리는 bastion과 K3s server 같은 "고정 노드" 설정을 Terraform에서 분리해 관리하기 위한 시작 구조다.

현재 목적:

- Bastion 운영 패키지와 보안 도구를 Ansible role로 관리
- K3s server 설치와 bootstrap 로직을 Ansible로 옮길 준비
- Worker ASG와 NAT instance는 Terraform에 남김

Ansible 자체 개념은 [docs/ansible-basics-guide.md](../docs/ansible-basics-guide.md) 에 정리했다.

## 디렉터리

```text
ansible/
  ansible.cfg
  requirements.yaml
  inventories/
    dev/
      aws_ec2.yaml
      group_vars/
        all.yaml
        bastion.yaml
        k3s_server.yaml
  playbooks/
    site.yaml
    bastion.yaml
    k3s_server.yaml
  vars/
    dev-runtime.example.yaml
  roles/
    common/
    bastion/
    k3s_server/
```

## Get Started

처음부터 한 번 돌릴 때는 아래 순서로 진행하면 된다.

### 1. Terraform으로 인프라 생성

```bash
cd infra/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 최소한 아래 값은 현재 환경에 맞게 바꾼다.

- `key_name`: AWS에 등록한 EC2 key pair 이름
- `admin_cidrs`: 현재 내 공인 IP/32

즉 key pair 이름은 AWS에 있어야 하고, 로컬에는 그 key pair에 대응되는 `.pem` 파일도 있어야 한다.

초기 한 번만:

```bash
terraform init
```

적용:

```bash
terraform apply
```

### 2. Terraform output을 Ansible runtime 변수에 넣기

```bash
cd ../../ansible
cp vars/dev-runtime.example.yaml vars/dev-runtime.yaml
```

그 다음 Terraform output 값을 `vars/dev-runtime.yaml`에 채운다.

- `k3s_token`
- `mysql_rds_database_url`

예:

```bash
terraform -chdir=../infra/environments/dev output -raw k3s_join_token
terraform -chdir=../infra/environments/dev output -raw mysql_rds_database_url
```

`vars/dev-runtime.yaml`은 커밋하지 않도록 `.gitignore`에 제외해 두었다.

### 3. Ansible 의존성 설치

가상환경 없이 시스템 Python 기준으로 진행한다.

처음에 한 번:

```bash
ansible-galaxy collection install -r requirements.yaml
python3 -m pip install boto3 botocore
```

### 4. 셸 환경 변수 설정

현재 셸에서 한 번:

```bash
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/<terraform.tfvars에 넣은 key pair 이름>.pem
```

WSL에서 `/mnt/c/...` 경로에서 실행한다면 이것도 같이 설정한다.

```bash
export ANSIBLE_CONFIG=$PWD/ansible.cfg
```

### 5. Playbook 실행

```bash
ansible-playbook -i inventories/dev/aws_ec2.yaml playbooks/site.yaml \
  --extra-vars @vars/dev-runtime.yaml
```

이 inventory는 AWS에서 아래 태그를 가진 EC2를 자동 조회한다.

- `Project = k3s-security`
- `Environment = dev`
- `Role = bastion`
- `Role = k3s-control-plane`

즉 bastion IP나 k3s server private IP를 inventory 파일에 손으로 적지 않는다. AWS 조회는 현재 셸의 `AWS_PROFILE` 또는 표준 AWS 자격 증명 환경 변수를 그대로 사용한다.

## 권장 순서

1. Bastion role부터 확장
2. K3s server role로 K3s 설치/설정 이동
3. Terraform `user_data`는 최소 bootstrap만 남김

## 주의

- 이 골격은 시작점이다
- `roles/k3s_server`는 아직 placeholder 상태다
- worker ASG는 Ansible push 대신 launch template bootstrap을 유지한다
