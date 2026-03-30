#!/bin/bash

# 색상 정의 (출력을 예쁘게 하기 위함)
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}   SixSense Docker System Cleanup Tool    ${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. 청소 전 용량 확인
echo -e "\n${GREEN}[1/4] 현재 도커 용량 상태 확인 중...${NC}"
BEFORE_DISK=$(docker system df | grep "Total" -A 4)
echo "$BEFORE_DISK"

# 2. 사용자 확인 (실수로 지우는 것 방지, -y 옵션 주면 바로 실행)
if [[ "$1" != "-y" ]]; then
    read -p "진짜로 불필요한 컨테이너, 이미지, 캐시를 모두 삭제할까요? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${RED}작업이 취소되었습니다.${NC}"
        exit 1
    fi
fi

# 3. 본격적인 청소 시작 (정밀 타격)
echo -e "\n${GREEN}[2/4] 불순물 제거 시작...${NC}"

# - 중지된 모든 컨테이너 삭제
# - 사용되지 않는 네트워크 삭제
# - 이름 없는(Dangling) 이미지 삭제
# - 빌드 캐시 삭제
docker system prune -f

# 추가로 사용되지 않는 볼륨까지 삭제 (데이터가 날아갈 수 있으니 주의!)
# docker volume prune -f 

echo -e "\n${GREEN}[3/4] 최적화 완료!${NC}"

# 4. 결과 리포팅
echo -e "\n${GREEN}[4/4] 청소 후 최종 용량 상태:${NC}"
AFTER_DISK=$(docker system df | grep "Total" -A 4)
echo "$AFTER_DISK"

echo -e "\n${BLUE}==========================================${NC}"
echo -e "${GREEN}🎖️ 인프라가 다시 깨끗해졌습니다! 🚀${NC}"
echo -e "${BLUE}==========================================${NC}"
