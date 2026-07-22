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

echo "==> Patch imekamilika."
