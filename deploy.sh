
#!/bin/bash

# 1. 기존 컨테이너 정리
echo " Cleaning up old container..."
sudo docker stop sixsense-final-test 2>/dev/null
sudo docker rm sixsense-final-test 2>/dev/null

# 2. 도커 이미지 빌드 (최신 코드 반영을 위해 캐시 무시)
echo "Building Docker image WITHOUT CACHE..."
sudo docker build --no-cache -t doc-converter:latest .

# 3. IAM Role 기반 컨테이너 실행
# 버킷 이름만 직접 환경변수로 넘겨줍니다.
echo " Starting container with IAM Role (No Keys needed)..."
sudo docker run -d \
  -p 8000:8000 \
  -e S3_BUCKET_NAME="sixsense-pdf-storage-8aourm" \
  --name sixsense-final-test \
  doc-converter:latest

# 4. 로그 실시간 확인
echo "Showing real-time logs..."
echo "'Found credentials in environment variables' 메시지가 없는지 확인하세요!"
sudo docker logs -f sixsense-final-test
