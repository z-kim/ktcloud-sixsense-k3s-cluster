import os
import uuid
import shutil
import logging
import boto3
import time
import subprocess
from typing import Optional, List
from botocore.config import Config

from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.responses import Response

# 모니터링 라이브러리 (Prometheus)
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Counter, Histogram

# 사용자 정의 모듈 (PDF 처리 및 템플릿)
from processor import PDFProcessor
from templates import HTML_CONTENT

# [운영 포인트] 로깅 설정 - 서버의 동작 상태를 실시간으로 추적합니다.
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("SixSense-Converter")

# [인프라 포인트] S3 버킷 설정 (Terraform에서 생성된 버킷명을 환경변수로 받음)
S3_BUCKET = os.getenv("S3_BUCKET_NAME", "sixsense-pdf-storage")

# 🕵️ [보안 핵심] 시니어의 IAM Role 기반 S3 클라이언트 설정
# 이제 Access Key/Secret Key를 코드에 적지 않습니다. 
# EC2 인스턴스에 부여된 IAM 역할을 통해 안전하게 인증을 처리합니다.
s3_client = boto3.client(
    's3',
    region_name="ap-northeast-2"
)

# --- FastAPI 앱 초기화 ---
app = FastAPI(title="SixSense Doc Converter")

# [인프라 포인트] 로고 등 정적 파일 서빙을 위한 설정
if not os.path.exists("static"):
    os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# [모니터링 포인트] Prometheus 계측기 활성화
Instrumentator().instrument(app).expose(app)

# [보안 포인트] Rate Limiter 설정 (무분별한 API 호출 방지)
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# --- 커스텀 메트릭 정의 (Grafana 연동용) ---
CONVERSION_STATS = Counter(
    "sixsense_conversion_total",
    "Total count of PDF conversions",
    ["mode", "status"]
)
S3_UPLOAD_LATENCY = Histogram(
    "sixsense_s3_upload_duration_seconds",
    "Duration of S3 upload in seconds"
)

# 임시 저장소 설정
TEMP_DIR = os.path.join(os.path.dirname(__file__), "temp_storage")
os.makedirs(TEMP_DIR, exist_ok=True)

# --- 유틸리티 함수 ---
def compress_pdf_high_quality(input_path, output_path):
    """Ghostscript 엔진을 활용한 고성능 PDF 압축 최적화"""
    if not os.path.exists(input_path):
        return False
    gs_command = [
        "gs", "-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.4",
        "-dPDFSETTINGS=/printer", "-dNOPAUSE", "-dQUIET", "-dBATCH",
        "-dDetectDuplicateImages=true", "-dDownsampleColorImages=true",
        "-dColorImageResolution=300", f"-sOutputFile={output_path}", input_path
    ]
    try:
        subprocess.run(gs_command, check=True)
        return True
    except Exception as e:
        logger.error(f"❌ PDF 압축 실패: {e}")
        return False

def cleanup(path):
    """서버 자원 관리를 위한 임시 파일 즉시 삭제"""
    if path and os.path.exists(path):
        if os.path.isfile(path): os.remove(path)
        else: shutil.rmtree(path)

# --- API 엔드포인트 ---

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    """프론트엔드 메인 페이지 렌더링"""
    return HTML_CONTENT

@app.post("/convert-single/")
@limiter.limit("10/minute")
async def convert_single(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    wm_type: str = Form("none"),
    wm_text: Optional[str] = Form(None),
    wm_image: Optional[UploadFile] = File(None)
):
    """단일 파일 PDF 변환 및 S3 업로드 파이프라인"""
    ext = file.filename.split(".")[-1].lower()
    file_id = str(uuid.uuid4())
    input_path = os.path.join(TEMP_DIR, f"{file_id}.{ext}")
    temp_output_path = os.path.join(TEMP_DIR, f"{file_id}_raw.pdf")
    final_output_path = os.path.join(TEMP_DIR, f"{file_id}.pdf")
    wm_image_path = None

    try:
        # 1. 업로드 파일 로컬 저장
        with open(input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 2. 이미지 워터마크 처리 (선택 시)
        if wm_type == "image" and wm_image and wm_image.filename:
            wm_ext = wm_image.filename.split(".")[-1].lower()
            wm_image_path = os.path.join(TEMP_DIR, f"wm_{file_id}.{wm_ext}")
            with open(wm_image_path, "wb") as wm_buffer:
                shutil.copyfileobj(wm_image.file, wm_buffer)

        # 3. PDF 변환 및 워터마크 합성
        proc = PDFProcessor(TEMP_DIR)
        actual_wm_type = wm_type if wm_type != "none" else None
        proc.process_merge([input_path], temp_output_path, actual_wm_type, wm_text, wm_image_path)

        # 4. 용량 최적화 (압축)
        if not compress_pdf_high_quality(temp_output_path, final_output_path):
            shutil.copy(temp_output_path, final_output_path)

        # 5. S3 업로드 (성능 메트릭 수집 포함)
        with S3_UPLOAD_LATENCY.time():
            s3_key = f"single/{file_id}.pdf"
            # 🎖️ 별도의 인증 키 없이 IAM Role로 자동 인증됨
            s3_client.upload_file(final_output_path, S3_BUCKET, s3_key)

        CONVERSION_STATS.labels(mode="single", status="success").inc()

        # 6. 보안 링크(Pre-signed URL) 생성 (5분 유효)
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET, 'Key': s3_key},
            ExpiresIn=300
        )

        # 7. 백그라운드 태스크로 임시 파일 정리 (사용자 응답 속도 최적화)
        background_tasks.add_task(cleanup, input_path)
        background_tasks.add_task(cleanup, temp_output_path)
        background_tasks.add_task(cleanup, final_output_path)
        if wm_image_path: background_tasks.add_task(cleanup, wm_image_path)

        return JSONResponse({"download_url": url})
    except Exception as e:
        CONVERSION_STATS.labels(mode="single", status="fail").inc()
        logger.error(f"Error during single conversion: {e}")
        cleanup(input_path); cleanup(temp_output_path); cleanup(final_output_path)
        if wm_image_path: cleanup(wm_image_path)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/convert-merge/")
@limiter.limit("5/minute")
async def convert_merge(
    request: Request,
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    wm_type: str = Form("none"),
    wm_text: Optional[str] = Form(None),
    wm_image: Optional[UploadFile] = File(None)
):
    """다중 파일 병합 및 PDF 변환 파이프라인 (최대 10개)"""
    if len(files) > 10:
        raise HTTPException(status_code=400, detail="최대 10개의 파일까지만 병합 가능합니다.")

    merge_id = str(uuid.uuid4())
    input_paths = []
    temp_output_path = os.path.join(TEMP_DIR, f"{merge_id}_raw.pdf")
    final_output_path = os.path.join(TEMP_DIR, f"{merge_id}_merged.pdf")
    wm_image_path = None

    try:
        # 1. 모든 파일 로컬 임시 저장
        for file in files:
            ext = file.filename.split(".")[-1].lower()
            path = os.path.join(TEMP_DIR, f"{uuid.uuid4()}.{ext}")
            with open(path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            input_paths.append(path)

        if wm_type == "image" and wm_image and wm_image.filename:
            wm_ext = wm_image.filename.split(".")[-1].lower()
            wm_image_path = os.path.join(TEMP_DIR, f"wm_m_{merge_id}.{wm_ext}")
            with open(wm_image_path, "wb") as wm_buffer:
                shutil.copyfileobj(wm_image.file, wm_buffer)

        # 2. 다중 파일 병합 실행
        proc = PDFProcessor(TEMP_DIR)
        actual_wm_type = wm_type if wm_type != "none" else None
        proc.process_merge(input_paths, temp_output_path, actual_wm_type, wm_text, wm_image_path)

        # 3. 최적화 및 S3 업로드
        if not compress_pdf_high_quality(temp_output_path, final_output_path):
            shutil.copy(temp_output_path, final_output_path)

        with S3_UPLOAD_LATENCY.time():
            s3_key = f"merged/{merge_id}.pdf"
            s3_client.upload_file(final_output_path, S3_BUCKET, s3_key)

        CONVERSION_STATS.labels(mode="merge", status="success").inc()

        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET, 'Key': s3_key},
            ExpiresIn=300
        )

        # 4. 임시 파일 정리
        for p in input_paths: background_tasks.add_task(cleanup, p)
        background_tasks.add_task(cleanup, temp_output_path)
        background_tasks.add_task(cleanup, final_output_path)
        if wm_image_path: background_tasks.add_task(cleanup, wm_image_path)

        return JSONResponse({"download_url": url})
    except Exception as e:
        CONVERSION_STATS.labels(mode="merge", status="fail").inc()
        logger.error(f"Merge Error: {e}")
        for p in input_paths: cleanup(p)
        cleanup(temp_output_path); cleanup(final_output_path)
        if wm_image_path: cleanup(wm_image_path)
        raise HTTPException(status_code=500, detail=str(e))
