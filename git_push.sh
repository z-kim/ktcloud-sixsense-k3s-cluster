#!/bin/bash

# 1. 프로젝트 루트로 이동 (스크립트 위치 기준)
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "--------------------------------------------------"
echo "🚀 SixSense 프로젝트 Git Push 시작"
echo "📍 위치: $PROJECT_ROOT"
echo "--------------------------------------------------"

# 2. Git 초기 설정 (새 환경이라면 확인 필요 🎖️)
# git config --global user.name "yutju"
# git config --global user.email "본인_이메일"

# 3. .gitignore 기반으로 변경사항 정리
# (이미 올라간 로그나 캐시 파일이 있다면 인덱스에서 제거)
echo "🔍 1. Git 캐시 정리 및 변경사항 감지 중..."
git rm -r --cached . > /dev/null 2>&1
git add .

# 4. 커밋 메시지 입력 (인자가 없으면 기본 메시지 사용)
COMMIT_MSG=$1
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Update: Infra & App deployment ($(date '+%Y-%m-%d %H:%M:%S')) 🎖️"
fi

echo "📝 2. 커밋 메시지: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# 5. 원격 저장소로 푸시
echo "📤 3. GitHub로 전송 중 (main 브랜치)..."
git push origin main

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------"
    echo "✅ 푸시 성공! GitHub Actions가 실행됩니다."
    echo "--------------------------------------------------"
else
    echo "--------------------------------------------------"
    echo "❌ 푸시 실패! 네트워크 상태나 권한을 확인하세요."
    echo "--------------------------------------------------"
    exit 1
fi
