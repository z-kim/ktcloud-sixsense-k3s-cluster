
# templates.py
from components import ABOUT_SECTION, API_SECTION

# 상단 UI 및 내비게이션 바
HTML_HEADER = """
<!DOCTYPE html>
<html lang="ko" style="scroll-behavior: smooth;">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SixSense Doc-Converter | 프리미엄 변환 & 병합 서비스</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700;900&family=Poppins:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sortablejs@1.14.0/Sortable.min.js"></script>
    <style>
        :root { --primary: #4F46E5; --primary-dark: #4338CA; --bg-main: #F9FAFB; --text-main: #1F2937; --glass-bg: rgba(255, 255, 255, 0.9); }
        body { font-family: 'Noto Sans KR', sans-serif; background-color: var(--bg-main); color: var(--text-main); }
        .font-poppins { font-family: 'Poppins', sans-serif; }
        .gradient-bg { background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab); background-size: 400% 400%; animation: gradient 15s ease infinite; }
        @keyframes gradient { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        .glass-card { background: var(--glass-bg); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border: 1px solid rgba(255, 255, 255, 0.2); }
        .drop-zone { border: 3px dashed #d1d5db; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); cursor: pointer; min-height: 250px; display: flex; flex-direction: column; justify-content: center; align-items: center; position: relative; border-radius: 1.5rem; }
        .drop-zone.active { border-color: var(--primary); background-color: #EEF2FF; transform: scale(1.02); }
        .tab-btn { transition: all 0.3s ease; border-radius: 9999px; font-weight: 800; padding: 0.75rem 2.5rem; }
        .tab-btn.active { background-color: var(--primary); color: white; box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.4); }
        .tab-btn.inactive { background-color: #E5E7EB; color: #6B7280; }
        .sortable-ghost { opacity: 0.4; background: #EEF2FF !important; border: 2px dashed var(--primary) !important; }

        @keyframes success-pop { 0% { transform: scale(0.5); opacity: 0; } 70% { transform: scale(1.05); } 100% { transform: scale(1); opacity: 1; } }
        .icon-pop { animation: success-pop 0.6s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
        @keyframes slow-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .animate-spin-slow { animation: slow-spin 3s linear infinite; }

        .loader-ring { display: inline-block; width: 80px; height: 80px; position: relative; }
        .loader-ring div { box-sizing: border-box; display: block; position: absolute; width: 64px; height: 64px; margin: 8px; border: 8px solid var(--primary); border-radius: 50%; animation: loader-ring 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite; border-color: var(--primary) transparent transparent transparent; }
        @keyframes loader-ring { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

        /* 🕵️ 시니어 조치: 아이콘을 1.5배 더 키우기 위한 커스텀 클래스를 추가했습니다. (576px = 36rem) */
        .icon-mega-scale { width: 36rem !important; height: auto; }
    </style>
</head>
<body class="min-h-screen">
    <nav class="glass-card sticky top-0 z-50 border-b shadow-sm">
        <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
            <div class="flex items-center space-x-3">
                <img src="/static/sixsenselogo.png" alt="SixSense Logo" class="h-10 w-auto object-contain rounded-lg">
                <span class="text-3xl font-extrabold tracking-tighter text-gray-900 font-poppins">SixSense</span>
            </div>
            <div class="flex items-center space-x-8 text-sm font-bold text-gray-600">
                <a href="#convert" class="hover:text-indigo-600 transition">변환하기</a>
                <a href="#about" class="hover:text-indigo-600 transition">서비스 소개</a>
                <a href="#api" class="hover:text-indigo-600 transition">API 문서</a>
                <button class="bg-indigo-600 text-white px-6 py-2.5 rounded-full shadow-lg">Cloud Native</button>
            </div>
        </div>
    </nav>

    <header class="gradient-bg py-24 text-white text-center">
        <div class="max-w-5xl mx-auto px-6">
            <h1 class="text-6xl font-black tracking-tight leading-tight font-poppins mb-6">단 한 번의 드래그로,<br>모든 문서를 <span class="text-yellow-300">완벽한 PDF</span>로</h1>
            <p class="text-xl font-light opacity-90"> IT 엔지니어를 위한 듀얼 엔진 변환 서비스</p>
        </div>
    </header>

    <main id="convert" class="max-w-7xl mx-auto px-6 -mt-20 space-y-20 pb-32 relative z-10">
        <div class="glass-card p-12 rounded-3xl shadow-2xl">
            <div class="flex justify-center space-x-4 mb-10 bg-gray-100 p-2 rounded-full w-max mx-auto">
                <button id="btnSingle" class="tab-btn active">단일 파일 변환</button>
                <button id="btnMerge" class="tab-btn inactive">다중 파일 병합</button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-12 items-start">
                <div class="md:col-span-1 pr-6 border-r border-gray-100 sticky top-32">
                    <h2 id="guideTitle" class="text-3xl font-black text-gray-900 mb-6">스마트 업로드</h2>
                    <p id="guideDesc" class="text-gray-600 mb-8 leading-relaxed">png, jpg, jpeg, bmp docx, xlsx, pptx, txt 지원 (최대 100MB)</p>

                    <div class="bg-gray-50 p-6 rounded-2xl border border-gray-200 space-y-4 shadow-sm mb-8">
                        <h3 class="font-black text-indigo-900 flex items-center text-sm">🛡️ 워터마크 옵션</h3>
                        <select id="wmType" class="w-full p-3 rounded-xl border-2 border-gray-200 font-bold text-sm focus:border-indigo-500 outline-none">
                            <option value="none">❌ 워터마크 적용 안 함</option>
                            <option value="text">🔠 텍스트 워터마크</option>
                            <option value="image">🖼️ 로고 이미지</option>
                        </select>
                        <div id="wmTextGroup" class="hidden">
                            <input type="text" id="wmText" placeholder="워터마크 문구 입력" class="w-full p-3 rounded-xl border-2 border-gray-200 font-bold text-sm">
                        </div>
                        <div id="wmImageGroup" class="hidden">
                            <input type="file" id="wmImage" accept="image/*" class="w-full text-xs font-bold text-gray-400">
                        </div>
                    </div>

                    <div class="space-y-4">
                        <div class="flex items-center space-x-3 text-sm text-green-700 font-bold bg-green-50 p-4 rounded-xl border border-green-100">✅ 나눔고딕 & Office 완벽 지원</div>
                        <div class="flex items-center space-x-3 text-sm text-indigo-700 font-bold bg-indigo-50 p-4 rounded-xl border border-indigo-100">✅ S3 보안 스토리지 연동</div>
                    </div>
                </div>

                <div class="md:col-span-2">
                    <div id="sectionSingle" class="space-y-6">
                        <div id="dropZoneSingle" class="drop-zone bg-gray-50 hover:bg-white shadow-inner p-10">
                            <div class="text-7xl mb-4">📄</div>
                            <p class="text-2xl font-black text-gray-800">단일 파일을 드래그 또는 클릭하여 업로드하세요.</p>
                            <input type="file" id="inputSingle" class="hidden">
                        </div>
                        <div id="infoSingle" class="hidden bg-white p-6 rounded-2xl border-2 border-indigo-100 flex justify-between items-center shadow-lg">
                            <span id="nameSingle" class="text-indigo-900 font-black text-lg truncate"></span>
                            <button onclick="resetSingle()" class="bg-red-50 text-red-500 p-2 rounded-full">✕</button>
                        </div>
                        <button onclick="handleSingleUpload()" class="w-full bg-indigo-600 text-white font-black py-6 rounded-2xl text-2xl shadow-xl hover:bg-indigo-700 transition transform hover:-translate-y-1">📄 PDF 단일 변환 시작 ✨</button>
                    </div>

                    <div id="sectionMerge" class="hidden space-y-6">
                        <div id="dropZoneMerge" class="drop-zone bg-gray-50 hover:bg-white shadow-inner p-10">
                            <div class="text-7xl mb-4">📑📑</div>
                            <p class="text-2xl font-black text-gray-800">여러 파일을 드래그하거나 클릭하여 업로드하세요.</p>
                            <p class="text-sm text-gray-400 mt-2 font-bold" id="mergeStatus">현재 0 / 10개 선택됨</p>
                            <input type="file" id="inputMerge" class="hidden" multiple>
                        </div>
                        <div id="listMerge" class="hidden space-y-3 p-4 border-2 border-indigo-50 rounded-2xl bg-gray-50/50 max-h-96 overflow-y-auto"></div>
                        <p class="text-xs text-center text-indigo-400 font-bold py-2 italic">💡 마우스로 끌어서 파일의 합쳐질 순서를 바꿀 수 있습니다.</p>
                        <button onclick="handleMergeUpload()" class="w-full bg-indigo-600 text-white font-black py-6 rounded-2xl text-2xl shadow-xl hover:bg-indigo-700 transition transform hover:-translate-y-1">📑 통합 PDF 병합 시작 ⚡</button>
                    </div>
                </div>
            </div>
        </div>
"""

HTML_FOOTER = """
        <p class="text-center text-gray-400 font-bold mt-12 font-poppins">© 2026 SixSense Project | Built for Infrastructure Engineers</p>
    </main>

    <div id="loadingScreen" class="hidden fixed inset-0 bg-gray-900 bg-opacity-80 flex items-center justify-center z-50 backdrop-blur-md">
        <div class="bg-white p-12 rounded-3xl text-center shadow-2xl max-w-md w-full mx-6">
            <div class="loader-ring mx-auto mb-8"><div></div></div>
            <div class="space-y-4">
                <div class="flex justify-between items-end mb-1">
                    <p id="loadingStatus" class="text-sm font-black text-indigo-600">엔진 시동 중...</p>
                    <p id="percentText" class="text-2xl font-black text-gray-800 font-poppins">0%</p>
                </div>
                <div class="w-full bg-gray-100 rounded-full h-4 overflow-hidden border border-gray-100">
                    <div id="progressBar" class="bg-indigo-600 h-full w-0 transition-all duration-500 ease-out shadow-[0_0_15px_rgba(79,70,229,0.5)]"></div>
                </div>
                <p id="loadingSubText" class="text-xs text-gray-400 font-bold">인프라 자원을 할당받고 있습니다...</p>
            </div>
        </div>
    </div>

    <div id="resultArea" class="hidden fixed inset-0 bg-gray-900/60 flex items-center justify-center z-50 backdrop-blur-xl transition-all duration-500">
        <div class="absolute inset-0 overflow-hidden pointer-events-none">
            <div class="absolute -top-[10%] -left-[10%] w-[50%] h-[50%] rounded-full bg-indigo-500/15 blur-[120px] animate-pulse"></div>
            <div class="absolute -bottom-[10%] -right-[10%] w-[50%] h-[50%] rounded-full bg-emerald-500/15 blur-[120px] animate-pulse" style="animation-delay: 1.5s;"></div>
        </div>

        <div class="p-16 rounded-[3.5rem] text-center shadow-[0_35px_60px_-15px_rgba(0,0,0,0.3)] border border-white/40 max-w-2xl w-full mx-6 relative z-10 icon-pop"
             style="background: rgba(255, 255, 255, 0.7); backdrop-filter: blur(50px);">

            <div class="flex justify-center mb-6">
                <img src="/static/convert.png" alt="Success" class="icon-mega-scale object-contain animate-bounce bg-transparent pointer-events-none">
            </div>

            <h2 class="text-6xl font-black text-gray-900 tracking-tighter mb-4">변환 완료!</h2>
            <p class="text-xl text-gray-600 font-bold mb-8 opacity-90">pdf 파일 변환 및 S3 보관 완료</p>

            <div class="inline-flex items-center space-x-3 px-8 py-3 rounded-full bg-white/50 border border-gray-200 text-gray-700 font-black mb-12 shadow-sm">
                <span class="text-2xl animate-spin-slow">⏱️</span>
                <span id="expiryTimer" class="text-lg">05:00 후 자동 파기</span>
            </div>

            <div class="space-y-5">
                <a id="downloadLink" href="#" download class="flex items-center justify-center bg-indigo-600 text-white font-black p-6 w-full rounded-2xl text-3xl shadow-lg hover:bg-indigo-700 transition transform hover:-translate-y-1 active:scale-95">
                    <span>PDF 다운로드 </span>
                </a>
                <button onclick="copyToClipboard()" id="copyBtn" class="flex items-center justify-center space-x-3 bg-white/80 text-gray-700 font-bold p-5 w-full rounded-2xl border border-gray-200 shadow-sm hover:bg-white transition active:scale-95 text-lg">
                    <span>🔗</span> <span id="copyBtnText">S3 PDF 공유 링크 복사</span>
                </button>
            </div>
            <button onclick="location.reload()" class="mt-12 text-gray-400 hover:text-indigo-600 text-base font-bold underline transition-colors">새 문서 변환하기</button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script>
        const btnSingle = document.getElementById('btnSingle');
        const btnMerge = document.getElementById('btnMerge');
        const sectionSingle = document.getElementById('sectionSingle');
        const sectionMerge = document.getElementById('sectionMerge');
        const guideTitle = document.getElementById('guideTitle');
        const guideDesc = document.getElementById('guideDesc');
        const wmType = document.getElementById('wmType');
        const wmTextGroup = document.getElementById('wmTextGroup');
        const wmImageGroup = document.getElementById('wmImageGroup');

        let currentDownloadUrl = "";
        let timerInterval = null;
        let progressInterval = null;

        function validateFile(file) {
            const fileName = file.name.toLowerCase();
            const allowedExtensions = ['.png', '.jpg', '.jpeg', '.pdf', '.docx', '.doc', '.xlsx', '.xls', '.pptx', '.ppt', '.hwp', '.txt'];
            const hasValidExt = allowedExtensions.some(ext => fileName.endsWith(ext));
            if (!hasValidExt) {
                showSystemToast(`[${file.name}] 보안 규격 미달 포맷입니다. 🚫`);
                return false;
            }
            return true;
        }

        async function copyToClipboard() {
            try {
                if (navigator.clipboard && window.isSecureContext) {
                    await navigator.clipboard.writeText(currentDownloadUrl);
                } else {
                    const textArea = document.createElement("textarea");
                    textArea.value = currentDownloadUrl;
                    textArea.style.position = "fixed"; textArea.style.left = "-9999px"; textArea.style.top = "0";
                    document.body.appendChild(textArea);
                    textArea.focus(); textArea.select();
                    document.execCommand('copy');
                    document.body.removeChild(textArea);
                }
                const btn = document.getElementById('copyBtn');
                const txt = document.getElementById('copyBtnText');
                btn.style.backgroundColor = "#10B981"; btn.style.color = "white";
                txt.textContent = "복사 완료! ✅";
                setTimeout(() => {
                    btn.style.backgroundColor = ""; btn.style.color = "";
                    txt.textContent = "S3 공유 링크 복사";
                }, 2000);
            } catch (err) { alert("복사 기능을 실행할 수 없습니다."); }
        }

        function startExpiryTimer(durationSeconds) {
            if (timerInterval) clearInterval(timerInterval);
            let timer = durationSeconds;
            const display = document.getElementById('expiryTimer');
            const downloadBtn = document.getElementById('downloadLink');
            const copyBtn = document.getElementById('copyBtn');

            timerInterval = setInterval(() => {
                let minutes = parseInt(timer / 60, 10);
                let seconds = parseInt(timer % 60, 10);
                minutes = minutes < 10 ? "0" + minutes : minutes;
                seconds = seconds < 10 ? "0" + seconds : seconds;
                display.textContent = minutes + ":" + seconds + " 후 자동 파기";

                if (--timer < 0) {
                    clearInterval(timerInterval);
                    display.textContent = "⚠️ 링크가 만료되었습니다.";
                    downloadBtn.classList.add('opacity-50', 'pointer-events-none');
                    copyBtn.classList.add('opacity-50', 'pointer-events-none');
                }
            }, 1000);
        }

        function showSystemToast(message) {
            const toast = document.createElement('div');
            toast.className = "fixed top-20 left-1/2 transform -translate-x-1/2 z-[9999] bg-gray-900 text-white px-6 py-4 rounded-2xl shadow-2xl border-2 border-red-500 flex items-center space-x-3 animate-bounce";
            toast.innerHTML = `<span class="text-2xl">🛡️</span><span class="font-bold text-sm">${message}</span><span class="text-red-500 ml-2">⚠️</span>`;
            document.body.appendChild(toast);
            setTimeout(() => { toast.style.opacity = "0"; setTimeout(() => toast.remove(), 500); }, 3000);
        }

        function updateProgress(targetPercent, statusText, subText) {
            const bar = document.getElementById('progressBar');
            const percentText = document.getElementById('percentText');
            const status = document.getElementById('loadingStatus');
            const sub = document.getElementById('loadingSubText');

            status.textContent = statusText;
            sub.textContent = subText;
            bar.style.width = targetPercent + '%';
            percentText.textContent = targetPercent + '%';
        }

        function startFakeProgress() {
            let current = 0;
            updateProgress(5, "엔진 초기화", "LibreOffice 인스턴스를 생성합니다...");
            if (progressInterval) clearInterval(progressInterval);
            progressInterval = setInterval(() => {
                if (current < 30) {
                    current += Math.floor(Math.random() * 3) + 1;
                    updateProgress(current, "문서 분석 중", "파일 구조를 스캔하고 있습니다.");
                } else if (current < 65) {
                    current += Math.floor(Math.random() * 2) + 1;
                    updateProgress(current, "PDF 레이어 변환", "고성능 Ghostscript 엔진 최적화 중...");
                } else if (current < 92) {
                    current += 1;
                    updateProgress(current, "보안 워터마크 합성", "SixSense Secured 레이어를 입히는 중...");
                }
            }, 700);
        }

        wmType.onchange = () => {
            wmTextGroup.classList.toggle('hidden', wmType.value !== 'text');
            wmImageGroup.classList.toggle('hidden', wmType.value !== 'image');
        };

        btnSingle.onclick = () => {
            btnSingle.className = "tab-btn active"; btnMerge.className = "tab-btn inactive";
            sectionSingle.classList.remove('hidden'); sectionMerge.classList.add('hidden');
            guideTitle.textContent = "스마트 업로드"; guideDesc.textContent = "PNG, JPG, DOCX, XLSX, PPTX, HWP, TXT 지원 (최대 100MB)";
        };

        btnMerge.onclick = () => {
            btnMerge.className = "tab-btn active"; btnSingle.className = "tab-btn inactive";
            sectionMerge.classList.remove('hidden'); sectionSingle.classList.add('hidden');
            guideTitle.textContent = "다중 병합 모드"; guideDesc.textContent = "여러 문서를 순서대로 합쳐 하나의 PDF로 생성합니다. (최대 10개)";
        };

        const inputSingle = document.getElementById('inputSingle');
        const infoSingle = document.getElementById('infoSingle');
        const nameSingle = document.getElementById('nameSingle');
        let singleFile = null;

        document.getElementById('dropZoneSingle').onclick = () => inputSingle.click();
        inputSingle.onchange = (e) => {
            const file = e.target.files[0];
            if(file && validateFile(file)) {
                singleFile = file; nameSingle.textContent = file.name; infoSingle.classList.remove('hidden');
            }
        };

        function resetSingle() { singleFile = null; inputSingle.value = ''; infoSingle.classList.add('hidden'); }

        async function handleSingleUpload() {
            if(!singleFile) return alert('파일을 선택해주세요.');
            const formData = new FormData();
            formData.append('file', singleFile);
            formData.append('wm_type', wmType.value);
            formData.append('wm_text', document.getElementById('wmText').value);
            const wmImgInput = document.getElementById('wmImage');
            if(wmType.value === 'image' && wmImgInput.files[0]) formData.append('wm_image', wmImgInput.files[0]);

            document.getElementById('loadingScreen').classList.remove('hidden');
            startFakeProgress();

            try {
                const res = await axios.post('/convert-single/', formData);
                clearInterval(progressInterval);
                updateProgress(100, "완료!", "S3 업로드에 성공했습니다. ✨");
                setTimeout(() => showResult(res.data.download_url), 600);
            } catch (err) {
                clearInterval(progressInterval);
                alert('변환 실패!');
            } finally {
                setTimeout(() => document.getElementById('loadingScreen').classList.add('hidden'), 1000);
            }
        }

        const listMerge = document.getElementById('listMerge');
        let mergeFiles = [];

        new Sortable(listMerge, {
            animation: 150, ghostClass: 'sortable-ghost',
            onEnd: () => {
                const newOrder = Array.from(listMerge.querySelectorAll('.file-item')).map(el => parseFloat(el.dataset.id));
                mergeFiles = newOrder.map(id => mergeFiles.find(f => f.uniqueId === id));
                updateMergeList(false);
            }
        });

        document.getElementById('dropZoneMerge').onclick = () => document.getElementById('inputMerge').click();
        document.getElementById('inputMerge').onchange = (e) => {
            Array.from(e.target.files).forEach(file => {
                if (mergeFiles.length < 10 && validateFile(file)) {
                    file.uniqueId = Date.now() + Math.random();
                    mergeFiles.push(file);
                }
            });
            updateMergeList(true);
            document.getElementById('inputMerge').value = '';
        };

        window.removeFileFromMerge = (uid) => {
            mergeFiles = mergeFiles.filter(f => f.uniqueId !== uid);
            updateMergeList(true);
        };

        function updateMergeList(reRender = true) {
            document.getElementById('mergeStatus').textContent = `현재 ${mergeFiles.length} / 10개 선택됨`;
            if(mergeFiles.length > 0) {
                listMerge.classList.remove('hidden');
                if(reRender) {
                    listMerge.innerHTML = mergeFiles.map((f, i) => {
                        const ext = f.name.split('.').pop().toLowerCase();
                        const icon = ['jpg','png','jpeg'].includes(ext) ? '🖼️' : (['xlsx','xls'].includes(ext) ? '📊' : (['pptx','ppt'].includes(ext) ? '💡' : (['docx','doc'].includes(ext) ? '📝' : '📄')));
                        return `
                            <div class="file-item bg-white border-2 border-gray-100 p-4 rounded-2xl flex justify-between items-center shadow-sm hover:border-indigo-400 transition" data-id="${f.uniqueId}">
                                <div class="flex items-center space-x-3 truncate">
                                    <span class="idx-label bg-indigo-50 text-indigo-600 w-6 h-6 flex items-center justify-center rounded-full text-[10px] font-black">${i+1}</span>
                                    <span>${icon}</span>
                                    <span class="font-bold text-gray-700 truncate text-sm">${f.name}</span>
                                </div>
                                <button onclick="removeFileFromMerge(${f.uniqueId})" class="text-gray-300 hover:text-red-500 font-black text-xl px-2">✕</button>
                            </div>
                        `;
                    }).join('');
                } else {
                    listMerge.querySelectorAll('.idx-label').forEach((el, i) => el.textContent = i + 1);
                }
            } else { listMerge.classList.add('hidden'); }
        }

        async function handleMergeUpload() {
            if(mergeFiles.length < 2) return alert('병합을 위해 최소 2개 이상의 파일을 선택해주세요.');
            const formData = new FormData();
            mergeFiles.forEach(f => formData.append('files', f));
            formData.append('wm_type', wmType.value);
            formData.append('wm_text', document.getElementById('wmText').value);
            const wmImgInput = document.getElementById('wmImage');
            if(wmType.value === 'image' && wmImgInput.files[0]) formData.append('wm_image', wmImgInput.files[0]);

            document.getElementById('loadingScreen').classList.remove('hidden');
            startFakeProgress();

            try {
                const res = await axios.post('/convert-merge/', formData);
                clearInterval(progressInterval);
                updateProgress(100, "병합 완료!", "최종 PDF가 생성되었습니다. ✨");
                setTimeout(() => showResult(res.data.download_url), 600);
            } catch (err) {
                clearInterval(progressInterval);
                alert('병합 실패!');
            } finally {
                setTimeout(() => document.getElementById('loadingScreen').classList.add('hidden'), 1000);
            }
        }

        function showResult(url) {
            currentDownloadUrl = url;
            document.getElementById('downloadLink').href = url;
            const ra = document.getElementById('resultArea');
            ra.classList.remove('hidden');
            startExpiryTimer(300);
        }

        [document.getElementById('dropZoneSingle'), document.getElementById('dropZoneMerge')].forEach(dz => {
            dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('active'); });
            dz.addEventListener('dragleave', () => dz.classList.remove('active'));
            dz.addEventListener('drop', (e) => {
                e.preventDefault(); dz.classList.remove('active');
                const dropped = Array.from(e.dataTransfer.files);
                if(dz.id === 'dropZoneSingle') {
                    if(validateFile(dropped[0])) { singleFile = dropped[0]; nameSingle.textContent = singleFile.name; infoSingle.classList.remove('hidden'); }
                } else {
                    dropped.forEach(f => { if(mergeFiles.length < 10 && validateFile(f)) { f.uniqueId = Date.now()+Math.random(); mergeFiles.push(f); } });
                    updateMergeList(true);
                }
            });
        });
    </script>
</body>
</html>
"""

# 최종 조립
HTML_CONTENT = HTML_HEADER + ABOUT_SECTION + API_SECTION + HTML_FOOTER

# templates.py
from components import ABOUT_SECTION, API_SECTION

# 상단 UI 및 내비게이션 바
HTML_HEADER = """
<!DOCTYPE html>
<html lang="ko" style="scroll-behavior: smooth;">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SixSense Doc-Converter | 프리미엄 변환 & 병합 서비스</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700;900&family=Poppins:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sortablejs@1.14.0/Sortable.min.js"></script>
    <style>
        :root { --primary: #4F46E5; --primary-dark: #4338CA; --bg-main: #F9FAFB; --text-main: #1F2937; --glass-bg: rgba(255, 255, 255, 0.9); }
        body { font-family: 'Noto Sans KR', sans-serif; background-color: var(--bg-main); color: var(--text-main); }
        .font-poppins { font-family: 'Poppins', sans-serif; }
        .gradient-bg { background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab); background-size: 400% 400%; animation: gradient 15s ease infinite; }
        @keyframes gradient { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        .glass-card { background: var(--glass-bg); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border: 1px solid rgba(255, 255, 255, 0.2); }
        .drop-zone { border: 3px dashed #d1d5db; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); cursor: pointer; min-height: 250px; display: flex; flex-direction: column; justify-content: center; align-items: center; position: relative; border-radius: 1.5rem; }
        .drop-zone.active { border-color: var(--primary); background-color: #EEF2FF; transform: scale(1.02); }
        .tab-btn { transition: all 0.3s ease; border-radius: 9999px; font-weight: 800; padding: 0.75rem 2.5rem; }
        .tab-btn.active { background-color: var(--primary); color: white; box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.4); }
        .tab-btn.inactive { background-color: #E5E7EB; color: #6B7280; }
        .sortable-ghost { opacity: 0.4; background: #EEF2FF !important; border: 2px dashed var(--primary) !important; }

        @keyframes success-pop { 0% { transform: scale(0.5); opacity: 0; } 70% { transform: scale(1.05); } 100% { transform: scale(1); opacity: 1; } }
        .icon-pop { animation: success-pop 0.6s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
        @keyframes slow-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .animate-spin-slow { animation: slow-spin 3s linear infinite; }

        .loader-ring { display: inline-block; width: 80px; height: 80px; position: relative; }
        .loader-ring div { box-sizing: border-box; display: block; position: absolute; width: 64px; height: 64px; margin: 8px; border: 8px solid var(--primary); border-radius: 50%; animation: loader-ring 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite; border-color: var(--primary) transparent transparent transparent; }
        @keyframes loader-ring { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

        /* 🕵️ 시니어 조치: 아이콘을 1.5배 더 키우기 위한 커스텀 클래스를 추가했습니다. (576px = 36rem) */
        .icon-mega-scale { width: 36rem !important; height: auto; }
    </style>
</head>
<body class="min-h-screen">
    <nav class="glass-card sticky top-0 z-50 border-b shadow-sm">
        <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
            <div class="flex items-center space-x-3">
                <img src="/static/sixsenselogo.png" alt="SixSense Logo" class="h-10 w-auto object-contain rounded-lg">
                <span class="text-3xl font-extrabold tracking-tighter text-gray-900 font-poppins">SixSense</span>
            </div>
            <div class="flex items-center space-x-8 text-sm font-bold text-gray-600">
                <a href="#convert" class="hover:text-indigo-600 transition">변환하기</a>
                <a href="#about" class="hover:text-indigo-600 transition">서비스 소개</a>
                <a href="#api" class="hover:text-indigo-600 transition">API 문서</a>
                <button class="bg-indigo-600 text-white px-6 py-2.5 rounded-full shadow-lg">Cloud Native</button>
            </div>
        </div>
    </nav>

    <header class="gradient-bg py-24 text-white text-center">
        <div class="max-w-5xl mx-auto px-6">
            <h1 class="text-6xl font-black tracking-tight leading-tight font-poppins mb-6">단 한 번의 드래그로,<br>모든 문서를 <span class="text-yellow-300">완벽한 PDF</span>로</h1>
            <p class="text-xl font-light opacity-90"> IT 엔지니어를 위한 듀얼 엔진 변환 서비스</p>
        </div>
    </header>

    <main id="convert" class="max-w-7xl mx-auto px-6 -mt-20 space-y-20 pb-32 relative z-10">
        <div class="glass-card p-12 rounded-3xl shadow-2xl">
            <div class="flex justify-center space-x-4 mb-10 bg-gray-100 p-2 rounded-full w-max mx-auto">
                <button id="btnSingle" class="tab-btn active">단일 파일 변환</button>
                <button id="btnMerge" class="tab-btn inactive">다중 파일 병합</button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-12 items-start">
                <div class="md:col-span-1 pr-6 border-r border-gray-100 sticky top-32">
                    <h2 id="guideTitle" class="text-3xl font-black text-gray-900 mb-6">스마트 업로드</h2>
                    <p id="guideDesc" class="text-gray-600 mb-8 leading-relaxed">png, jpg, jpeg, bmp docx, xlsx, pptx, txt 지원 (최대 100MB)</p>

                    <div class="bg-gray-50 p-6 rounded-2xl border border-gray-200 space-y-4 shadow-sm mb-8">
                        <h3 class="font-black text-indigo-900 flex items-center text-sm">🛡️ 워터마크 옵션</h3>
                        <select id="wmType" class="w-full p-3 rounded-xl border-2 border-gray-200 font-bold text-sm focus:border-indigo-500 outline-none">
                            <option value="none">❌ 워터마크 적용 안 함</option>
                            <option value="text">🔠 텍스트 워터마크</option>
                            <option value="image">🖼️ 로고 이미지</option>
                        </select>
                        <div id="wmTextGroup" class="hidden">
                            <input type="text" id="wmText" placeholder="워터마크 문구 입력" class="w-full p-3 rounded-xl border-2 border-gray-200 font-bold text-sm">
                        </div>
                        <div id="wmImageGroup" class="hidden">
                            <input type="file" id="wmImage" accept="image/*" class="w-full text-xs font-bold text-gray-400">
                        </div>
                    </div>

                    <div class="space-y-4">
                        <div class="flex items-center space-x-3 text-sm text-green-700 font-bold bg-green-50 p-4 rounded-xl border border-green-100">✅ 나눔고딕 & Office 완벽 지원</div>
                        <div class="flex items-center space-x-3 text-sm text-indigo-700 font-bold bg-indigo-50 p-4 rounded-xl border border-indigo-100">✅ S3 보안 스토리지 연동</div>
                    </div>
                </div>

                <div class="md:col-span-2">
                    <div id="sectionSingle" class="space-y-6">
                        <div id="dropZoneSingle" class="drop-zone bg-gray-50 hover:bg-white shadow-inner p-10">
                            <div class="text-7xl mb-4">📄</div>
                            <p class="text-2xl font-black text-gray-800">단일 파일을 드래그 또는 클릭하여 업로드하세요.</p>
                            <input type="file" id="inputSingle" class="hidden">
                        </div>
                        <div id="infoSingle" class="hidden bg-white p-6 rounded-2xl border-2 border-indigo-100 flex justify-between items-center shadow-lg">
                            <span id="nameSingle" class="text-indigo-900 font-black text-lg truncate"></span>
                            <button onclick="resetSingle()" class="bg-red-50 text-red-500 p-2 rounded-full">✕</button>
                        </div>
                        <button onclick="handleSingleUpload()" class="w-full bg-indigo-600 text-white font-black py-6 rounded-2xl text-2xl shadow-xl hover:bg-indigo-700 transition transform hover:-translate-y-1">📄 PDF 단일 변환 시작 ✨</button>
                    </div>

                    <div id="sectionMerge" class="hidden space-y-6">
                        <div id="dropZoneMerge" class="drop-zone bg-gray-50 hover:bg-white shadow-inner p-10">
                            <div class="text-7xl mb-4">📑📑</div>
                            <p class="text-2xl font-black text-gray-800">여러 파일을 드래그하거나 클릭하여 업로드하세요.</p>
                            <p class="text-sm text-gray-400 mt-2 font-bold" id="mergeStatus">현재 0 / 10개 선택됨</p>
                            <input type="file" id="inputMerge" class="hidden" multiple>
                        </div>
                        <div id="listMerge" class="hidden space-y-3 p-4 border-2 border-indigo-50 rounded-2xl bg-gray-50/50 max-h-96 overflow-y-auto"></div>
                        <p class="text-xs text-center text-indigo-400 font-bold py-2 italic">💡 마우스로 끌어서 파일의 합쳐질 순서를 바꿀 수 있습니다.</p>
                        <button onclick="handleMergeUpload()" class="w-full bg-indigo-600 text-white font-black py-6 rounded-2xl text-2xl shadow-xl hover:bg-indigo-700 transition transform hover:-translate-y-1">📑 통합 PDF 병합 시작 ⚡</button>
                    </div>
                </div>
            </div>
        </div>
"""

HTML_FOOTER = """
        <p class="text-center text-gray-400 font-bold mt-12 font-poppins">© 2026 SixSense Project | Built for Infrastructure Engineers</p>
    </main>

    <div id="loadingScreen" class="hidden fixed inset-0 bg-gray-900 bg-opacity-80 flex items-center justify-center z-50 backdrop-blur-md">
        <div class="bg-white p-12 rounded-3xl text-center shadow-2xl max-w-md w-full mx-6">
            <div class="loader-ring mx-auto mb-8"><div></div></div>
            <div class="space-y-4">
                <div class="flex justify-between items-end mb-1">
                    <p id="loadingStatus" class="text-sm font-black text-indigo-600">엔진 시동 중...</p>
                    <p id="percentText" class="text-2xl font-black text-gray-800 font-poppins">0%</p>
                </div>
                <div class="w-full bg-gray-100 rounded-full h-4 overflow-hidden border border-gray-100">
                    <div id="progressBar" class="bg-indigo-600 h-full w-0 transition-all duration-500 ease-out shadow-[0_0_15px_rgba(79,70,229,0.5)]"></div>
                </div>
                <p id="loadingSubText" class="text-xs text-gray-400 font-bold">인프라 자원을 할당받고 있습니다...</p>
            </div>
        </div>
    </div>

    <div id="resultArea" class="hidden fixed inset-0 bg-gray-900/60 flex items-center justify-center z-50 backdrop-blur-xl transition-all duration-500">
        <div class="absolute inset-0 overflow-hidden pointer-events-none">
            <div class="absolute -top-[10%] -left-[10%] w-[50%] h-[50%] rounded-full bg-indigo-500/15 blur-[120px] animate-pulse"></div>
            <div class="absolute -bottom-[10%] -right-[10%] w-[50%] h-[50%] rounded-full bg-emerald-500/15 blur-[120px] animate-pulse" style="animation-delay: 1.5s;"></div>
        </div>

        <div class="p-16 rounded-[3.5rem] text-center shadow-[0_35px_60px_-15px_rgba(0,0,0,0.3)] border border-white/40 max-w-2xl w-full mx-6 relative z-10 icon-pop"
             style="background: rgba(255, 255, 255, 0.7); backdrop-filter: blur(50px);">

            <div class="flex justify-center mb-6">
                <img src="/static/convert.png" alt="Success" class="icon-mega-scale object-contain animate-bounce bg-transparent pointer-events-none">
            </div>

            <h2 class="text-6xl font-black text-gray-900 tracking-tighter mb-4">변환 완료!</h2>
            <p class="text-xl text-gray-600 font-bold mb-8 opacity-90">pdf 파일 변환 및 S3 보관 완료</p>

            <div class="inline-flex items-center space-x-3 px-8 py-3 rounded-full bg-white/50 border border-gray-200 text-gray-700 font-black mb-12 shadow-sm">
                <span class="text-2xl animate-spin-slow">⏱️</span>
                <span id="expiryTimer" class="text-lg">05:00 후 자동 파기</span>
            </div>

            <div class="space-y-5">
                <a id="downloadLink" href="#" download class="flex items-center justify-center bg-indigo-600 text-white font-black p-6 w-full rounded-2xl text-3xl shadow-lg hover:bg-indigo-700 transition transform hover:-translate-y-1 active:scale-95">
                    <span>PDF 다운로드 </span>
                </a>
                <button onclick="copyToClipboard()" id="copyBtn" class="flex items-center justify-center space-x-3 bg-white/80 text-gray-700 font-bold p-5 w-full rounded-2xl border border-gray-200 shadow-sm hover:bg-white transition active:scale-95 text-lg">
                    <span>🔗</span> <span id="copyBtnText">S3 PDF 공유 링크 복사</span>
                </button>
            </div>
            <button onclick="location.reload()" class="mt-12 text-gray-400 hover:text-indigo-600 text-base font-bold underline transition-colors">새 문서 변환하기</button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script>
        const btnSingle = document.getElementById('btnSingle');
        const btnMerge = document.getElementById('btnMerge');
        const sectionSingle = document.getElementById('sectionSingle');
        const sectionMerge = document.getElementById('sectionMerge');
        const guideTitle = document.getElementById('guideTitle');
        const guideDesc = document.getElementById('guideDesc');
        const wmType = document.getElementById('wmType');
        const wmTextGroup = document.getElementById('wmTextGroup');
        const wmImageGroup = document.getElementById('wmImageGroup');

        let currentDownloadUrl = "";
        let timerInterval = null;
        let progressInterval = null;

        function validateFile(file) {
            const fileName = file.name.toLowerCase();
            const allowedExtensions = ['.png', '.jpg', '.jpeg', '.pdf', '.docx', '.doc', '.xlsx', '.xls', '.pptx', '.ppt', '.hwp', '.txt'];
            const hasValidExt = allowedExtensions.some(ext => fileName.endsWith(ext));
            if (!hasValidExt) {
                showSystemToast(`[${file.name}] 보안 규격 미달 포맷입니다. 🚫`);
                return false;
            }
            return true;
        }

        async function copyToClipboard() {
            try {
                if (navigator.clipboard && window.isSecureContext) {
                    await navigator.clipboard.writeText(currentDownloadUrl);
                } else {
                    const textArea = document.createElement("textarea");
                    textArea.value = currentDownloadUrl;
                    textArea.style.position = "fixed"; textArea.style.left = "-9999px"; textArea.style.top = "0";
                    document.body.appendChild(textArea);
                    textArea.focus(); textArea.select();
                    document.execCommand('copy');
                    document.body.removeChild(textArea);
                }
                const btn = document.getElementById('copyBtn');
                const txt = document.getElementById('copyBtnText');
                btn.style.backgroundColor = "#10B981"; btn.style.color = "white";
                txt.textContent = "복사 완료! ✅";
                setTimeout(() => {
                    btn.style.backgroundColor = ""; btn.style.color = "";
                    txt.textContent = "S3 공유 링크 복사";
                }, 2000);
            } catch (err) { alert("복사 기능을 실행할 수 없습니다."); }
        }

        function startExpiryTimer(durationSeconds) {
            if (timerInterval) clearInterval(timerInterval);
            let timer = durationSeconds;
            const display = document.getElementById('expiryTimer');
            const downloadBtn = document.getElementById('downloadLink');
            const copyBtn = document.getElementById('copyBtn');

            timerInterval = setInterval(() => {
                let minutes = parseInt(timer / 60, 10);
                let seconds = parseInt(timer % 60, 10);
                minutes = minutes < 10 ? "0" + minutes : minutes;
                seconds = seconds < 10 ? "0" + seconds : seconds;
                display.textContent = minutes + ":" + seconds + " 후 자동 파기";

                if (--timer < 0) {
                    clearInterval(timerInterval);
                    display.textContent = "⚠️ 링크가 만료되었습니다.";
                    downloadBtn.classList.add('opacity-50', 'pointer-events-none');
                    copyBtn.classList.add('opacity-50', 'pointer-events-none');
                }
            }, 1000);
        }

        function showSystemToast(message) {
            const toast = document.createElement('div');
            toast.className = "fixed top-20 left-1/2 transform -translate-x-1/2 z-[9999] bg-gray-900 text-white px-6 py-4 rounded-2xl shadow-2xl border-2 border-red-500 flex items-center space-x-3 animate-bounce";
            toast.innerHTML = `<span class="text-2xl">🛡️</span><span class="font-bold text-sm">${message}</span><span class="text-red-500 ml-2">⚠️</span>`;
            document.body.appendChild(toast);
            setTimeout(() => { toast.style.opacity = "0"; setTimeout(() => toast.remove(), 500); }, 3000);
        }

        function updateProgress(targetPercent, statusText, subText) {
            const bar = document.getElementById('progressBar');
            const percentText = document.getElementById('percentText');
            const status = document.getElementById('loadingStatus');
            const sub = document.getElementById('loadingSubText');

            status.textContent = statusText;
            sub.textContent = subText;
            bar.style.width = targetPercent + '%';
            percentText.textContent = targetPercent + '%';
        }

        function startFakeProgress() {
            let current = 0;
            updateProgress(5, "엔진 초기화", "LibreOffice 인스턴스를 생성합니다...");
            if (progressInterval) clearInterval(progressInterval);
            progressInterval = setInterval(() => {
                if (current < 30) {
                    current += Math.floor(Math.random() * 3) + 1;
                    updateProgress(current, "문서 분석 중", "파일 구조를 스캔하고 있습니다.");
                } else if (current < 65) {
                    current += Math.floor(Math.random() * 2) + 1;
                    updateProgress(current, "PDF 레이어 변환", "고성능 Ghostscript 엔진 최적화 중...");
                } else if (current < 92) {
                    current += 1;
                    updateProgress(current, "보안 워터마크 합성", "SixSense Secured 레이어를 입히는 중...");
                }
            }, 700);
        }

        wmType.onchange = () => {
            wmTextGroup.classList.toggle('hidden', wmType.value !== 'text');
            wmImageGroup.classList.toggle('hidden', wmType.value !== 'image');
        };

        btnSingle.onclick = () => {
            btnSingle.className = "tab-btn active"; btnMerge.className = "tab-btn inactive";
            sectionSingle.classList.remove('hidden'); sectionMerge.classList.add('hidden');
            guideTitle.textContent = "스마트 업로드"; guideDesc.textContent = "PNG, JPG, DOCX, XLSX, PPTX, HWP, TXT 지원 (최대 100MB)";
        };

        btnMerge.onclick = () => {
            btnMerge.className = "tab-btn active"; btnSingle.className = "tab-btn inactive";
            sectionMerge.classList.remove('hidden'); sectionSingle.classList.add('hidden');
            guideTitle.textContent = "다중 병합 모드"; guideDesc.textContent = "여러 문서를 순서대로 합쳐 하나의 PDF로 생성합니다. (최대 10개)";
        };

        const inputSingle = document.getElementById('inputSingle');
        const infoSingle = document.getElementById('infoSingle');
        const nameSingle = document.getElementById('nameSingle');
        let singleFile = null;

        document.getElementById('dropZoneSingle').onclick = () => inputSingle.click();
        inputSingle.onchange = (e) => {
            const file = e.target.files[0];
            if(file && validateFile(file)) {
                singleFile = file; nameSingle.textContent = file.name; infoSingle.classList.remove('hidden');
            }
        };

        function resetSingle() { singleFile = null; inputSingle.value = ''; infoSingle.classList.add('hidden'); }

        async function handleSingleUpload() {
            if(!singleFile) return alert('파일을 선택해주세요.');
            const formData = new FormData();
            formData.append('file', singleFile);
            formData.append('wm_type', wmType.value);
            formData.append('wm_text', document.getElementById('wmText').value);
            const wmImgInput = document.getElementById('wmImage');
            if(wmType.value === 'image' && wmImgInput.files[0]) formData.append('wm_image', wmImgInput.files[0]);

            document.getElementById('loadingScreen').classList.remove('hidden');
            startFakeProgress();

            try {
                const res = await axios.post('/convert-single/', formData);
                clearInterval(progressInterval);
                updateProgress(100, "완료!", "S3 업로드에 성공했습니다. ✨");
                setTimeout(() => showResult(res.data.download_url), 600);
            } catch (err) {
                clearInterval(progressInterval);
                alert('변환 실패!');
            } finally {
                setTimeout(() => document.getElementById('loadingScreen').classList.add('hidden'), 1000);
            }
        }

        const listMerge = document.getElementById('listMerge');
        let mergeFiles = [];

        new Sortable(listMerge, {
            animation: 150, ghostClass: 'sortable-ghost',
            onEnd: () => {
                const newOrder = Array.from(listMerge.querySelectorAll('.file-item')).map(el => parseFloat(el.dataset.id));
                mergeFiles = newOrder.map(id => mergeFiles.find(f => f.uniqueId === id));
                updateMergeList(false);
            }
        });

        document.getElementById('dropZoneMerge').onclick = () => document.getElementById('inputMerge').click();
        document.getElementById('inputMerge').onchange = (e) => {
            Array.from(e.target.files).forEach(file => {
                if (mergeFiles.length < 10 && validateFile(file)) {
                    file.uniqueId = Date.now() + Math.random();
                    mergeFiles.push(file);
                }
            });
            updateMergeList(true);
            document.getElementById('inputMerge').value = '';
        };

        window.removeFileFromMerge = (uid) => {
            mergeFiles = mergeFiles.filter(f => f.uniqueId !== uid);
            updateMergeList(true);
        };

        function updateMergeList(reRender = true) {
            document.getElementById('mergeStatus').textContent = `현재 ${mergeFiles.length} / 10개 선택됨`;
            if(mergeFiles.length > 0) {
                listMerge.classList.remove('hidden');
                if(reRender) {
                    listMerge.innerHTML = mergeFiles.map((f, i) => {
                        const ext = f.name.split('.').pop().toLowerCase();
                        const icon = ['jpg','png','jpeg'].includes(ext) ? '🖼️' : (['xlsx','xls'].includes(ext) ? '📊' : (['pptx','ppt'].includes(ext) ? '💡' : (['docx','doc'].includes(ext) ? '📝' : '📄')));
                        return `
                            <div class="file-item bg-white border-2 border-gray-100 p-4 rounded-2xl flex justify-between items-center shadow-sm hover:border-indigo-400 transition" data-id="${f.uniqueId}">
                                <div class="flex items-center space-x-3 truncate">
                                    <span class="idx-label bg-indigo-50 text-indigo-600 w-6 h-6 flex items-center justify-center rounded-full text-[10px] font-black">${i+1}</span>
                                    <span>${icon}</span>
                                    <span class="font-bold text-gray-700 truncate text-sm">${f.name}</span>
                                </div>
                                <button onclick="removeFileFromMerge(${f.uniqueId})" class="text-gray-300 hover:text-red-500 font-black text-xl px-2">✕</button>
                            </div>
                        `;
                    }).join('');
                } else {
                    listMerge.querySelectorAll('.idx-label').forEach((el, i) => el.textContent = i + 1);
                }
            } else { listMerge.classList.add('hidden'); }
        }

        async function handleMergeUpload() {
            if(mergeFiles.length < 2) return alert('병합을 위해 최소 2개 이상의 파일을 선택해주세요.');
            const formData = new FormData();
            mergeFiles.forEach(f => formData.append('files', f));
            formData.append('wm_type', wmType.value);
            formData.append('wm_text', document.getElementById('wmText').value);
            const wmImgInput = document.getElementById('wmImage');
            if(wmType.value === 'image' && wmImgInput.files[0]) formData.append('wm_image', wmImgInput.files[0]);

            document.getElementById('loadingScreen').classList.remove('hidden');
            startFakeProgress();

            try {
                const res = await axios.post('/convert-merge/', formData);
                clearInterval(progressInterval);
                updateProgress(100, "병합 완료!", "최종 PDF가 생성되었습니다. ✨");
                setTimeout(() => showResult(res.data.download_url), 600);
            } catch (err) {
                clearInterval(progressInterval);
                alert('병합 실패!');
            } finally {
                setTimeout(() => document.getElementById('loadingScreen').classList.add('hidden'), 1000);
            }
        }

        function showResult(url) {
            currentDownloadUrl = url;
            document.getElementById('downloadLink').href = url;
            const ra = document.getElementById('resultArea');
            ra.classList.remove('hidden');
            startExpiryTimer(300);
        }

        [document.getElementById('dropZoneSingle'), document.getElementById('dropZoneMerge')].forEach(dz => {
            dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('active'); });
            dz.addEventListener('dragleave', () => dz.classList.remove('active'));
            dz.addEventListener('drop', (e) => {
                e.preventDefault(); dz.classList.remove('active');
                const dropped = Array.from(e.dataTransfer.files);
                if(dz.id === 'dropZoneSingle') {
                    if(validateFile(dropped[0])) { singleFile = dropped[0]; nameSingle.textContent = singleFile.name; infoSingle.classList.remove('hidden'); }
                } else {
                    dropped.forEach(f => { if(mergeFiles.length < 10 && validateFile(f)) { f.uniqueId = Date.now()+Math.random(); mergeFiles.push(f); } });
                    updateMergeList(true);
                }
            });
        });
    </script>
</body>
</html>
"""

# 최종 조립
HTML_CONTENT = HTML_HEADER + ABOUT_SECTION + API_SECTION + HTML_FOOTER

