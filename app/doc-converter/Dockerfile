FROM python:3.10-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LANG=ko_KR.UTF-8
ENV LC_ALL=ko_KR.UTF-8
ENV TZ=Asia/Seoul

# 1. 필수 패키지 및 xauth 설치 (xvfb-run 구동 필수 패키지) 🎖️
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice libreoffice-writer libreoffice-calc \
    libreoffice-l10n-ko libreoffice-java-common default-jre \
    libcairo2 libpangocairo-1.0-0 libpixman-1-0 libfontconfig1 \
    libxrender1 libxtst6 libxi6 libgl1-mesa-dri libglu1-mesa \
    xvfb x11-utils dbus-x11 xauth \
    ghostscript \
    # 🔥 xauth 가 설치되어야 xvfb-run :error 가 해결됩니다 🕵️
    libqpdf-dev qpdf fontconfig \
    fonts-noto-color-emoji fonts-symbola fonts-nanum fonts-nanum-extra \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. 시스템 폰트 매핑 설정 (fontconfig)
RUN mkdir -p /etc/fonts/conf.d && \
    echo '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>\
    <match target="pattern"><test name="family"><string>Segoe UI Emoji</string></test><edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit></match>\
    <match target="pattern"><test name="family"><string>Apple Color Emoji</string></test><edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit></match>\
    <alias><family>sans-serif</family><prefer><family>Noto Color Emoji</family></prefer></alias>\
    </fontconfig>' > /etc/fonts/conf.d/99-emoji-mapping.conf

# 3. 🚀 리브레오피스 앱 내부 폰트 대체 규칙 강제 주입 (가장 중요!) 🎖️
# '맑은 고딕'이나 'Segoe UI'를 만나면 무조건 우리 폰트로 갈아끼우게 만듭니다.
RUN mkdir -p /root/.config/libreoffice/4/user && \
    echo '<?xml version="1.0" encoding="UTF-8"?><oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema">\
    <item oor:path="/org.openoffice.Office.Common/Font/Substitution"><prop oor:name="Replacement" oor:op="fuse"><value>true</value></prop></item>\
    <item oor:path="/org.openoffice.Office.Common/Font/Substitution/FontPairs">\
    <node oor:name="_0" oor:op="replace"><prop oor:name="Always" oor:op="fuse"><value>true</value></prop><prop oor:name="ReplaceFont" oor:op="fuse"><value>Segoe UI Emoji</value></prop><prop oor:name="SubstituteFont" oor:op="fuse"><value>Noto Color Emoji</value></prop></node>\
    <node oor:name="_1" oor:op="replace"><prop oor:name="Always" oor:op="fuse"><value>true</value></prop><prop oor:name="ReplaceFont" oor:op="fuse"><value>Malgun Gothic</value></prop><prop oor:name="SubstituteFont" oor:op="fuse"><value>NanumGothic</value></prop></node>\
    </item>\
    <item oor:path="/org.openoffice.Office.Common/Layout"><prop oor:name="IsKernAsianPunctuation" oor:op="fuse"><value>true</value></prop></item>\
    </oor:items>' > /root/.config/libreoffice/4/user/registrymodifications.xcu

RUN fc-cache -fv

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/temp_storage

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
