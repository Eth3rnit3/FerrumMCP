# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # JavaScript evaluated by RecaptchaSolver in the host page and in the
    # reCAPTCHA challenge frame.
    module RecaptchaScripts
      # Evaluated in the challenge frame
      CHALLENGE_STATE_JS = <<~JS
        (() => {
          const shown = (sel) => [...document.querySelectorAll(sel)].some((el) =>
            el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden');
          if (shown('.rc-doscaptcha-header, .rc-doscaptcha-body')) return 'blocked';
          const audio = document.querySelector('#audio-source');
          if (shown('#rc-audio, .rc-audiochallenge-control, #audio-response') && audio && audio.src) return 'audio';
          if (shown('#rc-imageselect, .rc-imageselect-payload')) return 'image';
          return null;
        })()
      JS

      AUDIO_ERROR_JS = <<~JS
        (() => {
          const el = document.querySelector('.rc-audiochallenge-error-message');
          return el && el.getClientRects().length > 0 ? el.innerText.trim() : '';
        })()
      JS

      FETCH_AUDIO_JS = <<~JS
        fetch(arguments[0], { credentials: 'include' })
          .then((response) => response.arrayBuffer())
          .then((buffer) => {
            const bytes = new Uint8Array(buffer);
            let binary = '';
            for (let i = 0; i < bytes.length; i += 0x8000) {
              binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
            }
            arguments[1](btoa(binary));
          })
          .catch(() => arguments[1](null));
      JS

      # Evaluated in the host page: is the challenge popup of this widget shown?
      CHALLENGE_VISIBLE_JS = <<~JS
        (() => {
          const frame = document.querySelector(`iframe[name="${arguments[0]}"]`) ||
                        document.querySelector('iframe[src*="/recaptcha/"][src*="bframe"]');
          if (!frame) return false;
          const rect = frame.getBoundingClientRect();
          return getComputedStyle(frame).visibility !== 'hidden' && rect.width > 0 && rect.height > 0 && rect.bottom > 0;
        })()
      JS

      # Evaluated in the host page: token of the widget whose anchor is
      # arguments[0]. Callback-only integrations have no response textarea;
      # the token is then read through the grecaptcha API (every widget of
      # the page is tried, the first non-empty response wins).
      TOKEN_JS = <<~JS
        (() => {
          let node = document.querySelector(`iframe[name="${arguments[0]}"]`);
          for (let i = 0; node && i < 6; i++, node = node.parentElement) {
            const area = node.querySelector && node.querySelector('textarea[name="g-recaptcha-response"]');
            if (area && area.value) return area.value;
          }
          const any = [...document.querySelectorAll('textarea[name="g-recaptcha-response"]')].find((a) => a.value);
          if (any) return any.value;
          const api = window.grecaptcha && (window.grecaptcha.enterprise || window.grecaptcha);
          if (!api || typeof api.getResponse !== 'function') return null;
          for (const widgetId of [undefined, 0, 1, 2, 3]) {
            try {
              const value = api.getResponse(widgetId);
              if (value) return value;
            } catch (e) {}
          }
          return null;
        })()
      JS

      EXECUTE_INVISIBLE_JS = <<~JS
        (() => {
          const api = window.grecaptcha && (window.grecaptcha.enterprise || window.grecaptcha);
          if (!api || typeof api.execute !== 'function') return false;
          try { api.execute(); return true; } catch (e) { return false; }
        })()
      JS
    end
  end
end
