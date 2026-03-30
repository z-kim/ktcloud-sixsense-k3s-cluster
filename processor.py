import os
import subprocess
import time
import shutil
import random
import uuid
import logging
from io import BytesIO
from PIL import Image
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import pikepdf

logger = logging.getLogger("SixSense-Converter")

FONT_NAME = "NanumGothic"
FONT_PATH = '/usr/share/fonts/truetype/nanum/NanumGothic.ttf'

def register_fonts():
    try:
        if os.path.exists(FONT_PATH):
            pdfmetrics.registerFont(TTFont(FONT_NAME, FONT_PATH))
            return True
    except: return False
    return False

HAS_NANUM = register_fonts()

class PDFProcessor:
    def __init__(self, temp_dir):
        self.temp_dir = temp_dir

    # 🕵️ 개별 파일 변환 로직
    def _convert_to_pdf_fragment(self, input_path):
        ext = input_path.rsplit('.', 1)[-1].lower()
        tmp_pdf = os.path.join(self.temp_dir, f"frag_{uuid.uuid4()}.pdf")

        # 1. 이미지 처리
        if ext in ["png", "jpg", "jpeg", "bmp"]:
            with Image.open(input_path) as img:
                if img.mode != "RGB": img = img.convert("RGB")
                img.save(tmp_pdf, "PDF")
            return tmp_pdf

        # 2. 문서 처리 (LibreOffice)
        ts = str(int(time.time() * 1000))
        profile_dir = os.path.join(self.temp_dir, f"env_{ts}_{uuid.uuid4().hex[:6]}")
        os.makedirs(profile_dir, exist_ok=True)

        env = os.environ.copy()
        env.update({
            "HOME": profile_dir, "LANG": "ko_KR.UTF-8", "LC_ALL": "ko_KR.UTF-8",
            "SAL_USE_VCLPLUGIN": "base", "SAL_VCL_QT5_USE_CAIRO": "1"
        })

        lo_cmd = ["xvfb-run", "-a", "libreoffice", "--headless", "--invisible",
                  "--convert-to", "pdf", "--outdir", profile_dir, input_path]

        try:
            subprocess.run(lo_cmd, env=env, timeout=120, check=True)
            gen_pdf = os.path.join(profile_dir, f"{os.path.basename(input_path).rsplit('.', 1)[0]}.pdf")
            if os.path.exists(gen_pdf):
                shutil.move(gen_pdf, tmp_pdf)
                return tmp_pdf
        finally:
            shutil.rmtree(profile_dir, ignore_errors=True)
        return None

    # [메인] 다중 파일 병합 실행 함수
    def process_merge(self, input_paths, output_path, wm_type="none", wm_text="SIX SENSE", wm_image_path=None):
        fragments = []
        try:
            # 1. 모든 파일을 PDF 조각으로 변환
            for path in input_paths:
                frag = self._convert_to_pdf_fragment(path)
                if frag: fragments.append(frag)

            if not fragments:
                raise Exception("변환할 수 있는 파일이 없습니다.")

            # 2. 고성능 병합 (pikepdf 사용)
            with pikepdf.new() as merged:
                for frag in fragments:
                    with pikepdf.open(frag) as src:
                        merged.pages.extend(src.pages)

                if not wm_type or wm_type == "none":
                    merged.save(output_path)
                    return

                intermediate_pdf = os.path.join(self.temp_dir, f"merged_{uuid.uuid4()}.pdf")
                merged.save(intermediate_pdf)

            # 3. 병합된 PDF에 워터마크 입히기
            reader = PdfReader(intermediate_pdf)
            writer = PdfWriter()
            active_font = FONT_NAME if HAS_NANUM else "Helvetica"

            self.add_custom_watermark(reader, writer, active_font, wm_type, wm_text, wm_image_path)

            with open(output_path, "wb") as f:
                writer.write(f)

            if os.path.exists(intermediate_pdf): os.remove(intermediate_pdf)

        finally:
            for frag in fragments:
                if os.path.exists(frag): os.remove(frag)

    # 워터마크 농도 및 가독성 업그레이드 로직
    def add_custom_watermark(self, reader, writer, active_font, wm_type, wm_text, wm_image_path):
        width, height = A4
        for i, page in enumerate(reader.pages):
            packet = BytesIO()
            can = canvas.Canvas(packet, pagesize=A4)

            if wm_type == "text" and wm_text:
                can.saveState()
                can.setFont(active_font, 60)
                can.setFillColorRGB(0.7, 0.7, 0.7, alpha=0.3)
                can.translate(width/2, height/2)
                can.rotate(45)
                can.drawCentredString(0, 0, wm_text)
                can.restoreState()

            elif wm_type == "image" and wm_image_path:
                can.saveState()
                img_w, img_h = 130*mm, 130*mm
                can.translate(width/2, height/2)
                can.rotate(45)
                can.setFillAlpha(0.2)
                can.drawImage(wm_image_path, -img_w/2, -img_h/2, width=img_w, height=img_h, mask='auto', preserveAspectRatio=True)
                can.restoreState()

            # 하단 페이지 정보
            can.setFont(active_font, 10)
            can.setFillColorRGB(0.5, 0.5, 0.5, alpha=0.5)
            can.drawRightString(width - 20, 30, f"SixSense Secured | Page {i+1} / {len(reader.pages)}")

            can.save()
            packet.seek(0)
            overlay = PdfReader(packet)
            page.merge_page(overlay.pages[0])
            writer.add_page(page)
