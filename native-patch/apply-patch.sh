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

echo "==> Kunakili media-scanner-bridge.js kama faili tofauti ndani ya www/"
cp native-patch/media-scanner-bridge.js www/media-scanner-bridge.js

echo "==> Kuongeza <script src> moja tu kabla ya </body> (njia salama, haiguzi JS)"
python3 - <<'PYEOF'
path = "www/index.html"
with open(path, encoding="utf-8") as f:
    html = f.read()

marker = "media-scanner-bridge.js"
if marker not in html:
    tag = '<script src="media-scanner-bridge.js"></script>\n</body>'
    if "</body>" in html:
        html = html.replace("</body>", tag, 1)
    else:
        html += tag
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print("Tag ya <script src> imeongezwa kwenye www/index.html.")
else:
    print("Tag tayari ipo, hakuna kilichobadilika.")
PYEOF

echo "==> Patch imekamilika."
