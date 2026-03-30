#!/bin/bash
# rebuild.sh 🚀

echo "♻️  1. 기존 컨테이너 및 이미지 삭제..."
sudo docker stop sixsense-final-test 2>/dev/null
sudo docker rm sixsense-final-test 2>/dev/null
sudo docker rmi doc-converter:v2 --force 2>/dev/null

echo "📦 2. 빌드 시작 (--progress=plain으로 상세 로그 출력) 🕵️"
sudo docker build --no-cache --progress=plain -t doc-converter:v2 .

echo "🔍 3. 이미지 내부 xauth 정밀 검증"
# find 명령어로 모든 경로를 다 뒤집니다. 🕵️
CHECK_PATH=$(sudo docker run --rm doc-converter:v2 find / -name "xauth" 2>/dev/null)

if [ -z "$CHECK_PATH" ]; then
    echo "❌ 에러: 이미지 어디에도 xauth가 없습니다! 빌드 로그를 확인하세요."
    exit 1
else
    echo "✅ 확인: xauth가 다음 경로에서 발견되었습니다: $CHECK_PATH"
fi

echo "🚀 4. 컨테이너 실행"
sudo docker run -d -p 8000:8000 --env-file .env --name sixsense-final-test doc-converter:v2

echo "📋 5. 로그 확인 중..."
sudo docker logs -f sixsense-final-test
