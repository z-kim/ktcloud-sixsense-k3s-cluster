import os
import subprocess
import logging
import time
import shutil
from PIL import Image

logger = logging.getLogger("SixSense-Converter")

def run_libreoffice(input_file, outdir, env):
    """
    LibreOffice를 실행하여 문서를 PDF로 변환합니다.
    표 레이아웃 무너짐을 방지하기 위해 독립된 프로필과 인쇄용 필터를 사용합니다.
    """
    ts = str(int(time.time() * 1000))
    #  각 작업마다 독립된 사용자 프로필 폴더를 생성하여 설정 충돌 방지
    user_profile = os.path.join(env["HOME"], f"profile_{ts}")
    
    cmd = [
        "xvfb-run", 
        "-a", 
        #  가상 디스플레이 설정을 강화하여 그래픽 객체(표) 인식률 향상
        "-s", "-screen 0 1920x1080x24 -ac +extension GLX +render -noreset",
        "libreoffice",
        f"-env:UserInstallation=file://{user_profile}",
        "--headless",
        "--invisible",
        "--nodefault",
        "--nofirststartwizard",
        "--nolockcheck",
        "--nologo",
        "--norestore",
        #  핵심: 단순 'pdf'가 아닌 'writer_pdf_Export' 필터를 써야 표 선과 위치가 잡힙니다.
        "--convert-to", "pdf:writer_pdf_Export",
        "--outdir", outdir,
        input_file
    ]

    try:
        result = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=180
        )

        if result.returncode != 0:
            logger.error("=== LibreOffice 변환 엔진 오류 ===")
            logger.error(f"STDOUT: {result.stdout}")
            logger.error(f"STDERR: {result.stderr}")
            raise RuntimeError(f"LibreOffice 실행 실패 (Exit Code: {result.returncode})")
            
    finally:
        # 작업 완료 후 임시 프로필 폴더 삭제
        if os.path.exists(user_profile):
            shutil.rmtree(user_profile, ignore_errors=True)


def process_conversion(input_path, output_path, ext, temp_dir):
    """
    이미지 및 문서 파일 변환 로직의 메인 프로세스입니다.
    """
    try:
        #  1. 이미지 파일 처리 (PIL 사용)
        if ext in ["png", "jpg", "jpeg", "bmp"]:
            with Image.open(input_path) as img:
                if img.mode != "RGB":
                    img = img.convert("RGB")
                img.save(output_path, "PDF")
            return

        #  2. 문서 파일 처리 (LibreOffice 사용)
        elif ext in ["docx", "txt", "hwp"]:
            abs_temp_dir = os.path.abspath(temp_dir)
            ts = str(int(time.time() * 1000))

            # 파일명에 한글/특수문자가 있으면 엔진이 오작동하므로 안전한 이름으로 복사
            safe_input = os.path.join(abs_temp_dir, f"work_{ts}.{ext}")
            shutil.copy2(input_path, safe_input)

            # 독립 실행 환경(HOME) 폴더 구성
            profile_dir = os.path.join(abs_temp_dir, f"env_{ts}")
            os.makedirs(profile_dir, exist_ok=True)

            # 환경 변수 설정 (자소 분리 및 렌더링 엔진 해결 핵심)
            env = os.environ.copy()
            env["HOME"] = profile_dir
            env["LANG"] = "ko_KR.UTF-8"
            env["LC_ALL"] = "ko_KR.UTF-8"
            env["LANGUAGE"] = "ko_KR:ko"
            
            #  표 깨짐 방지를 위해 가장 안정적인 'gen' 엔진 사용
            env["SAL_USE_VCLPLUGIN"] = "gen"
            env["FONTCONFIG_PATH"] = "/etc/fonts"

            # TXT 파일의 경우 인코딩 보정
            if ext == "txt":
                with open(safe_input, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                with open(safe_input, "w", encoding="utf-8") as f:
                    f.write(content)

            # LibreOffice 변환 실행
            run_libreoffice(safe_input, abs_temp_dir, env)

            # 생성된 PDF 파일명 매칭 (LibreOffice는 입력 파일명과 동일한 PDF를 만듦)
            pdf_name = f"work_{ts}.pdf"
            generated_pdf = os.path.join(abs_temp_dir, pdf_name)

            # 결과 파일 생성 대기 (최대 20초)
            for _ in range(20):
                if os.path.exists(generated_pdf) and os.path.getsize(generated_pdf) > 0:
                    shutil.move(generated_pdf, output_path)
                    # 작업 완료 후 환경 폴더 및 임시 입력 파일 삭제
                    shutil.rmtree(profile_dir, ignore_errors=True)
                    if os.path.exists(safe_input): os.remove(safe_input)
                    return
                time.sleep(1)

            raise FileNotFoundError(f"PDF 생성 실패: {pdf_name} 결과물이 없습니다.")

        else:
            raise ValueError(f"지원하지 않는 확장자입니다: {ext}")

    except Exception as e:
        logger.error(f"Conversion Error [{ext}]: {str(e)}")
        raise e

    finally:
        # 원본 업로드 파일 삭제
        if os.path.exists(input_path):
            try:
                os.remove(input_path)
            except:
                pass
