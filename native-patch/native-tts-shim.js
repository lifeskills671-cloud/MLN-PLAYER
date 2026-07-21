/* =====================================================================
   native-tts-shim.js
   Web Speech API (speechSynthesis) HAIFANYI KAZI vizuri kwenye Android
   WebView inayotumiwa na Capacitor (japo inafanya kazi Chrome browser).
   Faili hii inaunda "bandia" (shim) ya window.speechSynthesis na
   window.SpeechSynthesisUtterance zinazotumia TTS halisi ya Android
   (kupitia @capacitor-community/text-to-speech), ili code iliyopo ya
   speak() kwenye www/index.html iendelee kufanya kazi bila kubadilika.
   ===================================================================== */

(function(){
  function isNativeApp(){
    return !!(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
  }

  function ready(){
    return !!(window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech);
  }

  if(!isNativeApp()) return; // Kwenye browser ya kawaida, tumia speechSynthesis halisi

  let attempts = 0;
  function install(){
    if(!ready()){
      attempts++;
      if(attempts === 15){ // ~3 sekunde zimepita bila plugin kuonekana
        alert('DEBUG: plugin ya TextToSpeech haijaonekana kwenye window.Capacitor.Plugins baada ya sekunde 3. Capacitor.Plugins ina: ' + (window.Capacitor && window.Capacitor.Plugins ? Object.keys(window.Capacitor.Plugins).join(', ') : 'window.Capacitor haipo kabisa'));
      }
      setTimeout(install, 200);
      return;
    }
    const TTS = window.Capacitor.Plugins.TextToSpeech;
    let currentReject = null;

    function SpeechSynthesisUtteranceShim(text){
      this.text = text || '';
      this.lang = '';
      this.voice = null;
      this.pitch = 1;
      this.rate = 1;
      this.volume = 1;
      this.onend = null;
      this.onerror = null;
    }
    window.SpeechSynthesisUtterance = SpeechSynthesisUtteranceShim;

    window.speechSynthesis = {
      speaking: false,
      pending: false,
      onvoiceschanged: null,
      getVoices: function(){ return []; }, // Sauti za native huchaguliwa na mfumo wa Android
      cancel: function(){
        if(currentReject){ currentReject = null; }
        TTS.stop().catch(function(){});
      },
      speak: function(utter){
        window.speechSynthesis.speaking = true;
        // Android TTS: rate 0.1–2 kawaida, pitch 0.5–2. Tunabana thamani ili zisivunje plugin.
        const clampedRate = Math.max(0.1, Math.min(2, utter.rate || 1));
        const clampedPitch = Math.max(0.5, Math.min(2, utter.pitch || 1));
        const clampedVolume = Math.max(0, Math.min(1, utter.volume == null ? 1 : utter.volume));

        TTS.speak({
          text: utter.text,
          lang: utter.lang || 'sw-TZ',
          rate: clampedRate,
          pitch: clampedPitch,
          volume: clampedVolume,
          category: 'playback'
        }).then(function(){
          window.speechSynthesis.speaking = false;
          if(utter.onend) utter.onend();
        }).catch(function(err){
          window.speechSynthesis.speaking = false;
          alert('DEBUG: TTS.speak() imeshindwa: ' + (err && err.message ? err.message : JSON.stringify(err)));
          if(utter.onerror) utter.onerror(err);
        });
      }
    };
  }

  install();
})();
