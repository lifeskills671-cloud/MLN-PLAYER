#!/bin/bash
set -e

PKG_PATH="android/app/src/main/java/com/jpplayer/app"
mkdir -p "$PKG_PATH"

echo "==> Kubandika MediaScannerPlugin.java na MainActivity.java"
cp native-patch/MediaScannerPlugin.java "$PKG_PATH/MediaScannerPlugin.java"
cp native-patch/MainActivity.java "$PKG_PATH/MainActivity.java"

# Futa MainActivity.java ya default iliyotengenezwa na 'cap add android' kama
# ipo kwenye njia tofauti (Capacitor kawaida huitengeneza papo hapo, hivyo
# kuandika juu yake hapo juu tayari kunatosha).

MANIFEST="android/app/src/main/AndroidManifest.xml"
echo "==> Kuongeza ruhusa za READ_MEDIA_AUDIO / READ_MEDIA_VIDEO kwenye $MANIFEST"

python3 - "$MANIFEST" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

perms = (
    '    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />\n'
    '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="32" />\n'
)

if 'READ_MEDIA_AUDIO' not in content:
    content = content.replace('<application', perms + '\n    <application', 1)
    with open(path, 'w') as f:
        f.write(content)
    print("Ruhusa zimeongezwa.")
else:
    print("Ruhusa tayari zipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kusahihisha mantiki ya kusoma manukuu kwa mfumo wa foleni (hakuna mstari utakaokatwa)"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

old_block = """  video.addEventListener('timeupdate', () => {
    if(!cues.length) return;
    const idx = findCueIndex(video.currentTime);
    if(idx !== currentIndex){
      currentIndex = idx;
      renderCueAtIndex(idx);
    }

    // Video haisimami kamwe. Mzungumzaji mpya (mstari mpya) "hautambuliwi"/hautasemwa
    // mpaka sauti ya mstari wa sasa imemaliza kusomwa — hivyo sauti mbili hazichanganyiki.
    if(
      autoSpeak.checked &&
      currentIndex !== -1 &&
      currentIndex !== lastSpokenIndex &&
      !isSpeaking &&
      !video.paused
    ){
      lastSpokenIndex = currentIndex;
      isSpeaking = true;
      speak(translatedCues[currentIndex] || cues[currentIndex].text, tgtSel.value, cues[currentIndex].text, () => {
        isSpeaking = false;
      });
    }
  });"""

new_block = """  // Foleni ya mistari ya kusoma — HAKUNA mstari utakaokatwa au kurukwa,
  // hata kama video itaendelea mbele zaidi ya sauti. Kila mstari
  // utasemwa kikamilifu kwa zamu yake.
  const speechLineQueue = [];

  function speakNextInQueue(){
    if(!speechLineQueue.length){
      isSpeaking = false;
      return;
    }
    isSpeaking = true;
    const next = speechLineQueue.shift();
    speak(next.text, next.lang, next.rawText, () => {
      speakNextInQueue();
    });
  }

  video.addEventListener('timeupdate', () => {
    if(!cues.length) return;
    const idx = findCueIndex(video.currentTime);
    if(idx !== currentIndex){
      currentIndex = idx;
      renderCueAtIndex(idx);
    }

    // Mstari mpya unaongezwa kwenye foleni mara moja tu (haujarudiwa),
    // na utasomwa kikamilifu zamu yake ikifika — hakuna kukatwa/kurukwa.
    if(
      autoSpeak.checked &&
      currentIndex !== -1 &&
      currentIndex !== lastSpokenIndex &&
      !video.paused
    ){
      lastSpokenIndex = currentIndex;
      speechLineQueue.push({
        text: translatedCues[currentIndex] || cues[currentIndex].text,
        lang: tgtSel.value,
        rawText: cues[currentIndex].text
      });
      if(!isSpeaking){
        speakNextInQueue();
      }
    }
  });"""

if old_block in html:
    html = html.replace(old_block, new_block, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print("Mfumo wa foleni ya kusoma manukuu umewekwa.")
else:
    print("ONYO: mstari wa awali haukupatikana — hakuna kilichobadilika (angalia kama index.html imebadilika).")
PYEOF

echo "==> Kunakili native-tts-shim.js na media-scanner-bridge.js kama faili tofauti ndani ya www/"
cp native-patch/native-tts-shim.js www/native-tts-shim.js
cp native-patch/media-scanner-bridge.js www/media-scanner-bridge.js

echo "==> Kuongeza kitufe cha 'Storage Scanner' ndani ya Mipangilio"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "storageScannerToggle"
if marker not in html:
    anchor = '''      <button type="button" class="theme-toggle-switch" id="themeToggleBtn" title="Badilisha Mandhari" data-i18n-title role="switch" aria-checked="false"></button>
    </div>'''

    insertion = anchor + '''
    <label class="toggle" style="margin-bottom:14px; display:block; margin-top:14px;">
      <input type="checkbox" id="storageScannerToggle">
      <span data-i18n>Storage Scanner</span>
      <div class="d" style="font-size:12px; color:var(--muted); margin-top:2px;" data-i18n>Ukiwasha, itatafuta sauti na video zilizomo kwenye kifaa chako na kuzionyesha kwenye sehemu za Video na Sauti</div>
    </label>'''

    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("Kitufe cha Storage Scanner kimeongezwa kwenye Mipangilio.")
    else:
        print("ONYO: mahali pa kuongeza hakikupatikana — hakuna kilichobadilika.")
else:
    print("Kitufe tayari kipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza tags za <script src> kabla ya </body> (njia salama, haiguzi JS)"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "native-tts-shim.js"
if marker not in html:
    tag = (
        '<script src="native-tts-shim.js"></script>\n'
        '<script src="media-scanner-bridge.js"></script>\n'
        '</body>'
    )
    if "</body>" in html:
        html = html.replace("</body>", tag, 1)
    else:
        html += tag
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print("Tags za <script src> zimeongezwa kwenye www/index.html.")
else:
    print("Tag tayari ipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza CSS ya uteuzi/checkbox kwa mtazamo wa Orodha (list) wa Sauti"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "audio-list.select-mode .vg-checkbox"
if marker not in html:
    anchor = "  .vg-card.list-item.selected .vg-checkbox svg{ color:#06251F; }"
    insertion = anchor + """
  .audio-list.select-mode .vg-checkbox{ display:flex; position:static; background:var(--card); border-color:var(--line); margin-right:10px; }
  .audio-row.selected{ border-color:var(--accent); }
  .audio-row.selected .vg-checkbox{ background:var(--accent); border-color:var(--accent); }
  .audio-row.selected .vg-checkbox svg{ display:block; color:#06251F; }"""
    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("CSS ya uteuzi wa sauti imeongezwa.")
    else:
        print("ONYO: anchor ya CSS haikupatikana.")
else:
    print("CSS tayari ipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza kitufe cha 'Chagua Nyingi' kwenye toolbar ya Sauti"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "audioSelectToggleBtn"
if marker not in html:
    anchor = """      <button type="button" class="view-toggle-btn" data-view="list" title="Mtazamo wa Orodha" data-i18n-title>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>
      </button>
      <span class="vb-toolbar-spacer"></span>
      <select class="vb-sort-select" id="audioSortSelect" title="Panga sauti kwa" data-i18n-title>"""

    insertion = """      <button type="button" class="view-toggle-btn" data-view="list" title="Mtazamo wa Orodha" data-i18n-title>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>
      </button>
      <button type="button" class="view-toggle-btn" id="audioSelectToggleBtn" title="Chagua Nyingi" data-i18n-title>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>
      </button>
      <span class="vb-toolbar-spacer"></span>
      <select class="vb-sort-select" id="audioSortSelect" title="Panga sauti kwa" data-i18n-title>"""

    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("Kitufe cha Chagua Nyingi kimeongezwa kwenye toolbar ya Sauti.")
    else:
        print("ONYO: anchor ya toolbar haikupatikana.")
else:
    print("Kitufe tayari kipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza upau wa 'zimechaguliwa / Futa' chini ya kichwa cha Sauti"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "audioSelectBar"
if marker not in html:
    anchor = """      <div>
        <div class="vb-header-title" id="audioBrowserHeaderTitle">Sauti</div>
        <div class="vb-header-sub" id="audioBrowserHeaderSub"></div>
      </div>
    </div>
    <div class="audio-list" id="audioGrid"></div>"""

    insertion = """      <div>
        <div class="vb-header-title" id="audioBrowserHeaderTitle">Sauti</div>
        <div class="vb-header-sub" id="audioBrowserHeaderSub"></div>
      </div>
    </div>
    <div class="video-select-bar" id="audioSelectBar">
      <span class="vsb-count" id="audioSelectCount">0 zimechaguliwa</span>
      <div class="vsb-actions">
        <button type="button" id="audioSelectAllBtn" data-i18n>Chagua Zote</button>
        <button type="button" class="vsb-delete" id="audioDeleteSelectedBtn" disabled>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>
          <span data-i18n>Futa</span>
        </button>
      </div>
    </div>
    <div class="audio-list" id="audioGrid"></div>"""

    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("Upau wa uteuzi wa Sauti umeongezwa.")
    else:
        print("ONYO: anchor ya upau haikupatikana.")
else:
    print("Upau tayari upo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza state variables za uteuzi wa sauti"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "let audioSelectMode"
if marker not in html:
    anchor = """  let deviceAudioFiles = [];
  let audioGroups = {};"""
    insertion = anchor + """
  let audioSelectMode = false;
  let audioSelectedKeys = new Set();
  let audioCurrentViewItems = [];"""
    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("State variables za uteuzi wa sauti zimeongezwa.")
    else:
        print("ONYO: anchor ya state variables haikupatikana.")
else:
    print("Variables tayari zipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kuongeza DOM refs za vitufe vipya vya uteuzi wa Sauti"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "audioSelectToggleBtn = document"
if marker not in html:
    anchor = "  const audioSortSelect = document.getElementById('audioSortSelect');"
    insertion = anchor + """
  const audioSelectToggleBtn = document.getElementById('audioSelectToggleBtn');
  const audioSelectBar = document.getElementById('audioSelectBar');
  const audioSelectCount = document.getElementById('audioSelectCount');
  const audioSelectAllBtn = document.getElementById('audioSelectAllBtn');
  const audioDeleteSelectedBtn = document.getElementById('audioDeleteSelectedBtn');"""
    if anchor in html:
        html = html.replace(anchor, insertion, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("DOM refs za uteuzi wa sauti zimeongezwa.")
    else:
        print("ONYO: anchor ya DOM refs haikupatikana.")
else:
    print("DOM refs tayari zipo, hakuna kilichobadilika.")
PYEOF

echo "==> Kusasisha renderAudioGrid() na kuongeza uwezo wa 'kuchagua sauti kadhaa na kuziondoa kwa pamoja'"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "function toggleAudioSelection"
if marker not in html:
    old_block = """  function renderAudioGrid(){
    audioGrid.innerHTML = '';
    const q = audioSearchQuery.trim().toLowerCase();
    const isGrid = audioViewMode === 'grid';
    audioGrid.className = isGrid ? 'video-grid' : 'audio-list';

    if(audioActiveGroupKey === null){
      // Ngazi ya juu: onyesha folda za hifadhi (zenye sauti ndani)
      audioBrowserHeader.style.display = 'none';
      const keys = sortGroupKeysByMode(audioGroups, audioSortMode).filter(key => {
        if(!q) return true;
        const groupFiles = audioGroups[key];
        if(groupFiles.length === 1) return stripAudioExt(groupFiles[0].name).toLowerCase().includes(q);
        return key.toLowerCase().includes(q) || groupFiles.some(f => f.name.toLowerCase().includes(q));
      });
      keys.forEach(key => {
        const groupFiles = audioGroups[key];
        const isSingle = groupFiles.length === 1;
        const isActive = isSingle && groupFiles[0] === activeAudioFile;
        const item = document.createElement('div');
        const onClick = () => {
          if(isSingle){
            playAudioFile(groupFiles[0], item, [groupFiles[0]], 0);
          } else {
            audioActiveGroupKey = key;
            renderAudioGrid();
          }
        };
        const eqBarsHtml = '<span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span>';
        if(isGrid){
          item.className = 'vg-card' + (isActive ? ' active' : '');
          item.innerHTML = `
            <div class="vg-thumbwrap">
              <div class="vg-thumb"><span class="vg-icon">${noteIconSvg}</span>${isSingle ? '' : `<span class="vg-badge">${folderIconSvg}</span>`}</div>
              <div class="vg-eq">${eqBarsHtml}</div>
            </div>
            <div class="vg-title">${escapeHtml(isSingle ? stripAudioExt(groupFiles[0].name) : key)}</div>
            <div class="vg-sub">(${groupFiles.length})</div>`;
        } else {
          item.className = 'audio-row' + (isActive ? ' active' : '');
          item.innerHTML = `
            <div class="audio-row-thumbwrap">
              <div class="audio-row-thumb">${noteIconSvg}${isSingle ? '' : `<span class="audio-row-badge">${folderIconSvg}</span>`}</div>
              <div class="row-eq">${eqBarsHtml}</div>
            </div>
            <div class="audio-row-main">
              <div class="audio-row-title">${escapeHtml(isSingle ? stripAudioExt(groupFiles[0].name) : key)}</div>
            </div>
            <div class="audio-row-count">(${groupFiles.length})</div>`;
        }
        const thumbEl = item.querySelector(isGrid ? '.vg-thumb' : '.audio-row-thumb');
        if(thumbEl) generateAudioThumbnail(groupFiles[0], thumbEl, isSingle ? groupFiles[0] : null);
        if(thumbEl && isSingle) renderProgressMark(thumbEl, groupFiles[0]);
        item.addEventListener('click', onClick);
        audioGrid.appendChild(item);
      });
      if(keys.length === 0){
        audioGrid.innerHTML = `<div class="vb-empty" data-i18n>${q ? 'Hakuna kilicholingana na utafutaji.' : 'Hakuna sauti zilizopatikana kwenye hifadhi hii.'}</div>`;
        if(!q) applyAppLanguage(currentAppLang, audioGrid);
      }
    } else {
      // Ndani ya folda: onyesha sauti moja moja
      const allGroupFiles = sortFilesByMode(audioGroups[audioActiveGroupKey] || [], audioSortMode);
      const groupFiles = q ? allGroupFiles.filter(f => f.name.toLowerCase().includes(q)) : allGroupFiles;
      audioBrowserHeader.style.display = 'flex';
      audioBrowserHeaderTitle.textContent = audioActiveGroupKey;
      setDynText(audioBrowserHeaderSub, '{n} sauti', { n: groupFiles.length });
      groupFiles.forEach(file => {
        const isActive = file === activeAudioFile;
        const item = document.createElement('div');
        const eqBarsHtml = '<span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span>';
        if(isGrid){
          item.className = 'vg-card' + (isActive ? ' active' : '');
          item.innerHTML = `
            <div class="vg-thumbwrap">
              <div class="vg-thumb"><span class="vg-icon">${noteIconSvg}</span></div>
              <div class="vg-eq">${eqBarsHtml}</div>
            </div>
            <div class="vg-title">${escapeHtml(stripAudioExt(file.name))}</div>
            <div class="vg-sub">${formatFileSize(file.size)}</div>`;
        } else {
          item.className = 'audio-row' + (isActive ? ' active' : '');
          item.innerHTML = `
            <div class="audio-row-thumbwrap">
              <div class="audio-row-thumb">${noteIconSvg}</div>
              <div class="row-eq">${eqBarsHtml}</div>
            </div>
            <div class="audio-row-main">
              <div class="audio-row-title">${escapeHtml(stripAudioExt(file.name))}</div>
              <div class="audio-row-sub">${escapeHtml(audioActiveGroupKey)}</div>
            </div>
            <div class="audio-row-count">${formatFileSize(file.size)}</div>`;
        }
        const thumbEl = item.querySelector(isGrid ? '.vg-thumb' : '.audio-row-thumb');
        if(thumbEl) generateAudioThumbnail(file, thumbEl, file);
        if(thumbEl) renderProgressMark(thumbEl, file);
        item.addEventListener('click', () => playAudioFile(file, item, allGroupFiles, allGroupFiles.indexOf(file)));
        audioGrid.appendChild(item);
      });
      if(groupFiles.length === 0 && q){
        audioGrid.innerHTML = '<div class="vb-empty">Hakuna kilicholingana na utafutaji.</div>';
      }
    }
    requestAnimationFrame(() => applyGridRowLimit(audioGrid));
  }"""

    new_block = """  function renderAudioGrid(){
    audioGrid.innerHTML = '';
    const q = audioSearchQuery.trim().toLowerCase();
    const isGrid = audioViewMode === 'grid';
    audioGrid.className = (isGrid ? 'video-grid' : 'audio-list') + (audioSelectMode ? ' select-mode' : '');

    if(audioActiveGroupKey === null){
      // Ngazi ya juu: onyesha folda za hifadhi (zenye sauti ndani)
      audioBrowserHeader.style.display = 'none';
      const keys = sortGroupKeysByMode(audioGroups, audioSortMode).filter(key => {
        if(!q) return true;
        const groupFiles = audioGroups[key];
        if(groupFiles.length === 1) return stripAudioExt(groupFiles[0].name).toLowerCase().includes(q);
        return key.toLowerCase().includes(q) || groupFiles.some(f => f.name.toLowerCase().includes(q));
      });
      audioCurrentViewItems = keys;
      keys.forEach(key => {
        const groupFiles = audioGroups[key];
        const isSingle = groupFiles.length === 1;
        const isActive = isSingle && groupFiles[0] === activeAudioFile;
        const isSelected = audioSelectedKeys.has(key);
        const item = document.createElement('div');
        const onClick = () => {
          if(audioSelectMode){
            toggleAudioSelection(key, item);
            return;
          }
          if(isSingle){
            playAudioFile(groupFiles[0], item, [groupFiles[0]], 0);
          } else {
            audioActiveGroupKey = key;
            renderAudioGrid();
          }
        };
        const eqBarsHtml = '<span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span>';
        if(isGrid){
          item.className = 'vg-card' + (isActive ? ' active' : '') + (isSelected ? ' selected' : '');
          item.innerHTML = `
            <div class="vg-checkbox">${checkIconSvg}</div>
            <div class="vg-thumbwrap">
              <div class="vg-thumb"><span class="vg-icon">${noteIconSvg}</span>${isSingle ? '' : `<span class="vg-badge">${folderIconSvg}</span>`}</div>
              <div class="vg-eq">${eqBarsHtml}</div>
            </div>
            <div class="vg-title">${escapeHtml(isSingle ? stripAudioExt(groupFiles[0].name) : key)}</div>
            <div class="vg-sub">(${groupFiles.length})</div>`;
        } else {
          item.className = 'audio-row' + (isActive ? ' active' : '') + (isSelected ? ' selected' : '');
          item.innerHTML = `
            <div class="vg-checkbox">${checkIconSvg}</div>
            <div class="audio-row-thumbwrap">
              <div class="audio-row-thumb">${noteIconSvg}${isSingle ? '' : `<span class="audio-row-badge">${folderIconSvg}</span>`}</div>
              <div class="row-eq">${eqBarsHtml}</div>
            </div>
            <div class="audio-row-main">
              <div class="audio-row-title">${escapeHtml(isSingle ? stripAudioExt(groupFiles[0].name) : key)}</div>
            </div>
            <div class="audio-row-count">(${groupFiles.length})</div>`;
        }
        const thumbEl = item.querySelector(isGrid ? '.vg-thumb' : '.audio-row-thumb');
        if(thumbEl) generateAudioThumbnail(groupFiles[0], thumbEl, isSingle ? groupFiles[0] : null);
        if(thumbEl && isSingle) renderProgressMark(thumbEl, groupFiles[0]);
        item.addEventListener('click', onClick);
        audioGrid.appendChild(item);
      });
      if(keys.length === 0){
        audioGrid.innerHTML = `<div class="vb-empty" data-i18n>${q ? 'Hakuna kilicholingana na utafutaji.' : 'Hakuna sauti zilizopatikana kwenye hifadhi hii.'}</div>`;
        if(!q) applyAppLanguage(currentAppLang, audioGrid);
      }
    } else {
      // Ndani ya folda: onyesha sauti moja moja
      const allGroupFiles = sortFilesByMode(audioGroups[audioActiveGroupKey] || [], audioSortMode);
      const groupFiles = q ? allGroupFiles.filter(f => f.name.toLowerCase().includes(q)) : allGroupFiles;
      audioCurrentViewItems = groupFiles;
      audioBrowserHeader.style.display = 'flex';
      audioBrowserHeaderTitle.textContent = audioActiveGroupKey;
      setDynText(audioBrowserHeaderSub, '{n} sauti', { n: groupFiles.length });
      groupFiles.forEach(file => {
        const isActive = file === activeAudioFile;
        const isSelected = audioSelectedKeys.has(file);
        const item = document.createElement('div');
        const eqBarsHtml = '<span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span><span class="eq-bar"></span>';
        if(isGrid){
          item.className = 'vg-card' + (isActive ? ' active' : '') + (isSelected ? ' selected' : '');
          item.innerHTML = `
            <div class="vg-checkbox">${checkIconSvg}</div>
            <div class="vg-thumbwrap">
              <div class="vg-thumb"><span class="vg-icon">${noteIconSvg}</span></div>
              <div class="vg-eq">${eqBarsHtml}</div>
            </div>
            <div class="vg-title">${escapeHtml(stripAudioExt(file.name))}</div>
            <div class="vg-sub">${formatFileSize(file.size)}</div>`;
        } else {
          item.className = 'audio-row' + (isActive ? ' active' : '') + (isSelected ? ' selected' : '');
          item.innerHTML = `
            <div class="vg-checkbox">${checkIconSvg}</div>
            <div class="audio-row-thumbwrap">
              <div class="audio-row-thumb">${noteIconSvg}</div>
              <div class="row-eq">${eqBarsHtml}</div>
            </div>
            <div class="audio-row-main">
              <div class="audio-row-title">${escapeHtml(stripAudioExt(file.name))}</div>
              <div class="audio-row-sub">${escapeHtml(audioActiveGroupKey)}</div>
            </div>
            <div class="audio-row-count">${formatFileSize(file.size)}</div>`;
        }
        const thumbEl = item.querySelector(isGrid ? '.vg-thumb' : '.audio-row-thumb');
        if(thumbEl) generateAudioThumbnail(file, thumbEl, file);
        if(thumbEl) renderProgressMark(thumbEl, file);
        item.addEventListener('click', () => {
          if(audioSelectMode){
            toggleAudioSelection(file, item);
            return;
          }
          playAudioFile(file, item, allGroupFiles, allGroupFiles.indexOf(file));
        });
        audioGrid.appendChild(item);
      });
      if(groupFiles.length === 0 && q){
        audioGrid.innerHTML = '<div class="vb-empty">Hakuna kilicholingana na utafutaji.</div>';
      }
    }
    updateAudioSelectBar();
    requestAnimationFrame(() => applyGridRowLimit(audioGrid));
  }

  // ---------- Vitendo vya uteuzi wa sauti nyingi (select multiple) na kufuta kwa pamoja ----------
  function toggleAudioSelection(itemKey, itemEl){
    if(audioSelectedKeys.has(itemKey)){
      audioSelectedKeys.delete(itemKey);
      itemEl.classList.remove('selected');
    } else {
      audioSelectedKeys.add(itemKey);
      itemEl.classList.add('selected');
    }
    updateAudioSelectBar();
  }

  function updateAudioSelectBar(){
    if(!audioSelectBar) return;
    audioSelectBar.classList.toggle('show', audioSelectMode);
    const n = audioSelectedKeys.size;
    if(audioSelectCount) setDynText(audioSelectCount, '{n} zimechaguliwa', { n });
    if(audioDeleteSelectedBtn) audioDeleteSelectedBtn.disabled = n === 0;
  }

  function setAudioSelectMode(on){
    audioSelectMode = on;
    audioSelectedKeys = new Set();
    if(audioSelectToggleBtn) audioSelectToggleBtn.classList.toggle('active', on);
    renderAudioGrid();
  }

  if(audioSelectToggleBtn){
    audioSelectToggleBtn.addEventListener('click', () => setAudioSelectMode(!audioSelectMode));
  }

  if(audioSelectAllBtn){
    audioSelectAllBtn.addEventListener('click', () => {
      const allSelected = audioCurrentViewItems.length > 0 && audioCurrentViewItems.every(item => audioSelectedKeys.has(item));
      audioSelectedKeys = allSelected ? new Set() : new Set(audioCurrentViewItems);
      renderAudioGrid();
    });
  }

  function syncFetchAllAudioLabelCounts(){
    const fetchAllAudioBtnLabel = document.getElementById('fetchAllAudioBtnLabel');
    const audioLabelEl = document.getElementById('audioLabel');
    const audioSubEl = document.getElementById('audioSub');
    if(deviceAudioFiles.length){
      if(fetchAllAudioBtnLabel) fetchAllAudioBtnLabel.textContent = `Ongeza Sauti Zaidi (Jumla: ${deviceAudioFiles.length})`;
      if(audioLabelEl) audioLabelEl.textContent = `Sauti ${deviceAudioFiles.length} zimepakiwa`;
      if(audioSubEl) audioSubEl.textContent = `Jumla ya sauti zilizopakiwa kwenye kifaa: ${deviceAudioFiles.length}`;
    } else {
      if(fetchAllAudioBtnLabel) fetchAllAudioBtnLabel.textContent = 'Pakia Sauti';
      if(audioLabelEl) audioLabelEl.textContent = 'Hakuna sauti iliyopakiwa bado';
      if(audioBrowser) audioBrowser.classList.remove('show');
    }
  }

  function removeAudioFilesBulk(filesToRemove){
    if(!filesToRemove || !filesToRemove.length) return;
    const removingActive = filesToRemove.includes(activeAudioFile);
    deviceAudioFiles = deviceAudioFiles.filter(f => !filesToRemove.includes(f));
    audioGroups = buildVideoGroups(deviceAudioFiles);
    if(typeof currentQueue !== 'undefined' && currentQueue && currentQueue.length && currentQueue.some(f => filesToRemove.includes(f))){
      currentQueue = [];
      currentQueueIndex = -1;
    }
    if(audioActiveGroupKey !== null && !audioGroups[audioActiveGroupKey]) audioActiveGroupKey = null;
    if(removingActive && typeof stopAudioPlayback === 'function') stopAudioPlayback();
    syncFetchAllAudioLabelCounts();
    setStatus(`Sauti ${filesToRemove.length} zimeondolewa kwenye orodha.`, 'ok');
  }

  if(audioDeleteSelectedBtn){
    audioDeleteSelectedBtn.addEventListener('click', () => {
      if(audioSelectedKeys.size === 0) return;
      const n = audioSelectedKeys.size;
      if(!window.confirm(`Futa sauti ${n} zilizochaguliwa kwenye orodha? Kitendo hiki hakiwezi kutenduliwa.`)) return;
      let filesToRemove = [];
      if(audioActiveGroupKey === null){
        audioSelectedKeys.forEach(key => {
          filesToRemove = filesToRemove.concat(audioGroups[key] || []);
        });
      } else {
        filesToRemove = Array.from(audioSelectedKeys);
      }
      removeAudioFilesBulk(filesToRemove);
      setAudioSelectMode(false);
      renderAudioGrid();
    });
  }"""

    if old_block in html:
        html = html.replace(old_block, new_block, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        print("Kipengele cha kuchagua/kuondoa sauti nyingi kimewekwa.")
    else:
        print("ONYO: renderAudioGrid ya awali haikupatikana kwa usahihi — hakuna kilichobadilika.")
else:
    print("Kipengele tayari kipo, hakuna kilichobadilika.")
PYEOF

echo "==> Patch imekamilika."
