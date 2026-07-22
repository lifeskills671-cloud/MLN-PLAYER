/* =====================================================================
   media-scanner-bridge.js
   Ongeza faili hii (au bandika maudhui yake) kabla ya mstari wa mwisho wa tag ya script
   ndani ya www/index.html (JP_Player.html), BAADA ya kazi kama
   buildAudioGroups/buildVideoGroups, renderAudioGrid/renderVideoGrid,
   deviceAudioFiles/deviceVideoFiles kuwa zimeshatangazwa.
   ===================================================================== */

// ---------- 1) Ni app halisi (Capacitor/Android) au browser ya kawaida? ----------
function isNativeApp(){
  return !!(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
}

// ---------- 2) Helper: pata URL inayochezeka kwa faili (native au File ya kawaida) ----------
// TUMIA HII badala ya URL.createObjectURL(file) MAHALI POTE kwenye code iliyopo
// (kuna sehemu ~4, tafuta "URL.createObjectURL(file)"), mfano:
//   BADALI:  audioObjectUrl = URL.createObjectURL(file);
//   IWE:     audioObjectUrl = getPlayableUrl(file);
// Kwa faili za kawaida (zilizopakiwa kwa <input type="file">) tabia haibadiliki.
// Kwa faili za native (kutoka MediaScanner), tunatumia Capacitor.convertFileSrc
// ambayo inaruhusu WebView kucheza moja kwa moja kutoka kwenye hifadhi ya kifaa
// bila kuvuta byte zote kwenye kumbukumbu (RAM) — muhimu sana kwa video kubwa.
function getPlayableUrl(file){
  if(file && file.nativeUri && window.Capacitor && window.Capacitor.convertFileSrc){
    return window.Capacitor.convertFileSrc(file.nativeUri);
  }
  return URL.createObjectURL(file);
}

// ---------- 3) Tengeneza "File-like" wrapper kutoka kwenye matokeo ya native scan ----------
// Hii SIYO Blob halisi (hatuvuti byte zote mapema) — ina name/size/type za kutosha
// kwa isAudioFile()/isVideoFile()/stripAudioExt() na UI, pamoja na .nativeUri
// ambayo getPlayableUrl() inaitumia kuunda src ya kuchezea.
function makeNativeFileRef(item, kind){
  const guessedType = kind === 'audio' ? 'audio/*' : 'video/*';
  return {
    name: item.name || 'Bila jina',
    size: item.size || 0,
    type: guessedType,
    nativeUri: item.uri,
    webkitRelativePath: item.folder ? (item.folder + item.name) : '',
    lastModified: 0
  };
}

// ---------- 4) Auto-scan kamili ya sauti + video kwenye kifaa ----------
async function autoScanDeviceMedia(){
  if(!isNativeApp()){
    // Tuko ndani ya browser ya kawaida (siyo APK) — hatuwezi ku-autoscan,
    // tunaacha tabia ya sasa (kitufe cha "Pakia") ibaki kama ilivyo.
    return;
  }
  if(!(window.Capacitor.Plugins && window.Capacitor.Plugins.MediaScanner)){
    setStatus('MediaScanner plugin haijapatikana — angalia usajili wake kwenye MainActivity.', 'err');
    return;
  }
  try{
    setStatus('Inascan sauti na video kwenye kifaa…', 'ok');
    const result = await window.Capacitor.Plugins.MediaScanner.scanMedia();

    // ---- Sauti ----
    const audioItems = (result.audio || []).map(item => makeNativeFileRef(item, 'audio'));
    if(audioItems.length){
      deviceAudioFiles = deviceAudioFiles.concat(audioItems);
      audioGroups = buildVideoGroups(deviceAudioFiles); // ndiyo, kazi hii hii inatumika kwa sauti pia (angalia karibu na audioInput.addEventListener('change', ...))
      renderAudioGrid();
      if(typeof audioLabelEl !== 'undefined' && audioLabelEl) audioLabelEl.textContent = `Sauti ${deviceAudioFiles.length} zimepakiwa`;
    }

    // ---- Video ----
    const videoItems = (result.video || []).map(item => makeNativeFileRef(item, 'video'));
    if(videoItems.length){
      deviceVideoFiles = deviceVideoFiles.concat(videoItems);
      videoGroups = buildVideoGroups(deviceVideoFiles);
      if(activeGroupKey === null || !videoGroups[activeGroupKey]){
        const firstKey = sortedGroupKeys(videoGroups)[0];
        activeGroupKey = (firstKey && videoGroups[firstKey].length > 1) ? firstKey : null;
      }
      renderVideoGrid();
      syncFetchAllVideosLabelCounts();
    }

    setStatus(`Auto-scan imekamilika: sauti ${audioItems.length}, video ${videoItems.length}.`, 'ok');
  }catch(e){
    setStatus('Auto-scan imeshindikana: ' + (e && e.message ? e.message : e), 'err');
  }
}

// ---------- 5) "Storage Scanner" — auto-scan HUANZA TU mtumiaji akiwasha
//    swichi ndani ya Mipangilio (storageScannerToggle), siyo kiotomatiki
//    kila app inapofunguka. Hii inampa mtumiaji udhibiti kamili.
function wireStorageScannerToggle(){
  const toggle = document.getElementById('storageScannerToggle');
  if(!toggle) return;
  toggle.addEventListener('change', () => {
    if(!isNativeApp()){
      setStatus('Storage Scanner inapatikana kwenye app iliyosakinishwa pekee, siyo kwenye kivinjari.', 'err');
      toggle.checked = false;
      return;
    }
    if(toggle.checked){
      autoScanDeviceMedia();
    }
  });
}
wireStorageScannerToggle();

/* =====================================================================
   MAJUKUMU YANAYOBAKI KWAKO (yanahitaji Android Studio + majaribio):

   A) Badilisha URL.createObjectURL(file) -> getPlayableUrl(file) kwenye
      kazi zinazofungua video/audio (tafuta neno "createObjectURL" ndani
      ya JP_Player.html, kuna karibu sehemu 3-4).

   B) generateAudioThumbnail() na generateThumbnail() zinatumia jsmediatags
      / video element kusoma faili moja kwa moja kama Blob — kwa faili za
      native (zenye .nativeUri) hazitapata "album art" moja kwa moja.
      Suluhisho rahisi la mwanzo: ongeza mstari huu mwanzoni mwa kazi hizo
      mbili kuruka faili za native (zitatumia ikoni ya jumla badala yake):
          if(file && file.nativeUri) { audioThumbCache.set(file, null); return; }
      (Baadaye tunaweza kuboresha ili kuvuta thumbnail kwa kutumia
      getPlayableUrl(file) + <video>/<canvas> badala ya jsmediatags.)

   C) Kitufe cha "Pakia Sauti"/"Pakia Video" (fetchAllAudioBtn/fetchAllVideosBtn)
      kinaweza kubaki kama "Scan Upya" kwa ajili ya browser ya kawaida (fallback),
      au ukificha kabisa wakati isNativeApp() ni kweli, kwa mfano:
          if(isNativeApp()){ fetchAllAudioBtn.style.display = 'none'; fetchAllVideosBtn.style.display = 'none'; }
   ===================================================================== */
