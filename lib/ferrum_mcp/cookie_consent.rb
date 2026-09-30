# frozen_string_literal: true

module FerrumMCP
  # Cookie consent heuristics run inside the page by AcceptCookiesTool.
  #
  # Labels are compared normalized: lowercase, accents and punctuation
  # stripped ("Continuer sans accepter →" -> "continuer sans accepter"). A
  # pattern matches at the start of a word, so "accept" covers "accepter"
  # and "accepted" but not "unacceptable".
  module CookieConsent
    # Accept buttons of known consent platforms. A match still goes through
    # the refusal filter.
    KNOWN_ACCEPT_SELECTORS = [
      '#onetrust-accept-btn-handler', '#accept-recommended-btn-handler',
      '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll', '#CybotCookiebotDialogBodyButtonAccept',
      '#didomi-notice-agree-button',
      '#sp-cc-accept', # Amazon
      '#L2AGLb', # Google
      'button.sp_choice_type_11', # Sourcepoint
      '.qc-cmp2-summary-buttons button[mode="primary"]', # Quantcast
      '#truste-consent-button', '.osano-cm-accept-all', '#cookie-notice-accept', '#consent-accept-all',
      '.cky-btn-accept', '.iubenda-cs-accept-btn', '#axeptio_btn_acceptAll', '#tarteaucitronPersonalize2',
      '.cmpboxbtnyes', '#uc-btn-accept-banner', '[data-testid="uc-accept-all-button"]', '.fc-cta-consent',
      '.cmplz-accept', '#hs-eu-confirmation-button', '.cc-allow'
    ].freeze

    # Accept wordings, strongest first. Tier 1 labels must match exactly.
    ACCEPT_TIERS = {
      3 => ['accept all', 'accept all cookies', 'allow all', 'agree to all', 'tout accepter', 'accepter tout',
            'accepter tous', 'autoriser tout', 'autoriser tous', 'alle akzeptieren', 'alle cookies akzeptieren',
            'allen zustimmen', 'aceptar todo', 'aceptar todas', 'accetta tutto', 'accetta tutti', 'aceitar tudo',
            'aceitar todos', 'alles accepteren', 'accepteer alles'],
      2 => ['accept', 'agree', 'allow', "j'accepte", 'autoris', 'akzeptier', 'zustimm', 'einverstanden', 'acept',
            'accett', 'aceit', 'accepteer', 'consent', 'acconsent', 'concord', 'i consent'],
      1 => ['ok', 'okay', 'got it', "d'accord", 'compris', "j'ai compris", 'understood', 'i understand',
            'verstanden', 'entendido', 'capito', 'yes', 'oui']
    }.freeze

    # A label containing any of these is a refusal, a partial consent or a
    # settings entry, never an acceptance ("Continuer sans accepter",
    # "Accept only necessary", "Personnaliser", "Nicht akzeptieren", ...).
    REJECT_PATTERNS = [
      'refus', 'reject', 'decline', 'deny', 'denied', 'sans accepter', 'without accept', 'without agree',
      'continue without', 'continuer sans', 'no thanks', 'non merci', 'ablehn', 'nicht', 'ohne', 'rechaz',
      'sin acept', 'rifiut', 'senza', 'recus', 'rejeit', 'sem aceit', 'weiger', 'necessar', 'necessair',
      'essential', 'essentiel', 'notwendig', 'necesari', 'only', 'uniquement', 'seulement', 'nur', 'solo',
      'custom', 'personnalis', 'personaliz', 'parametr', 'setting', 'option', 'preferen', 'manage', 'gerer',
      'einstell', 'configur', 'learn more', 'en savoir plus', 'more info', "plus d'info", 'detail', 'mehr',
      'selection', 'auswahl', 'selecci', 'no', 'non', 'nein'
    ].freeze

    # Something in the element's id, class or label that says "consent banner"
    CONSENT_HINT = 'cookie|consent|gdpr|rgpd|privacy|privacidad|datenschutz|cmp|didomi|onetrust|optanon|' \
                   'cookiebot|cybot|usercentrics|axeptio|tarteaucitron|sp_message|sp-cc|qc-cmp|truste|osano|' \
                   'cky-|iubenda|klaro|fc-consent|cookielaw|evidon|borlabs|cmplz|termly|ketch|traceurs'

    # Finds the best accept button in the current document, open shadow
    # roots included, and keeps it in window.__fmcpCookieButton.
    # Returns { label, score, known } or null.
    SCAN_JS = <<~JS
      (function(knownSelectors, tiers, rejectPatterns, hint) {
        const hintRe = new RegExp(hint, 'i');
        const norm = (s) => (s || '').normalize('NFD').replace(/[\\u0300-\\u036f]/g, '').toLowerCase()
          .replace(/[’`]/g, "'").replace(/[^\\p{L}\\p{N}' ]+/gu, ' ').replace(/\\s+/g, ' ').trim();
        const hasWord = (text, pattern) => (' ' + text + ' ').includes(' ' + pattern);
        const hasWholeWord = (text, pattern) => (' ' + text + ' ').includes(' ' + pattern + ' ');
        const parentOf = (el) => el.parentElement || (el.parentNode && el.parentNode.host) || null;
        const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim();

        const all = [];
        const walk = (root) => {
          for (const el of root.querySelectorAll('*')) {
            all.push(el);
            if (el.shadowRoot) walk(el.shadowRoot);
          }
        };
        walk(document);

        const known = new Set();
        const collectKnown = (root) => {
          for (const selector of knownSelectors) {
            try { root.querySelectorAll(selector).forEach((el) => known.add(el)); } catch (e) {}
          }
        };
        collectKnown(document);
        all.forEach((el) => { if (el.shadowRoot) collectKnown(el.shadowRoot); });

        const visible = (el) => {
          const rect = el.getBoundingClientRect();
          if (rect.width <= 0 || rect.height <= 0) return false;
          if (el.checkVisibility) return el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
          const style = getComputedStyle(el);
          return style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0';
        };
        const clickable = (el) => {
          const tag = el.tagName.toLowerCase();
          if (tag === 'button' || tag === 'a') return true;
          if (tag === 'input') return ['submit', 'button'].includes((el.type || '').toLowerCase());
          return el.getAttribute('role') === 'button';
        };
        const names = (el) => [el.innerText, el.tagName === 'INPUT' ? el.value : '',
          el.getAttribute('aria-label'), el.getAttribute('title')].map(clean).filter(Boolean);
        const inTopDocument = window === window.top;
        const inConsentBanner = (el) => {
          let node = el;
          for (let depth = 0; node && depth < 15; depth++) {
            const tag = node.tagName ? node.tagName.toLowerCase() : '';
            if (tag === 'html') break;
            const attrs = [node.id, typeof node.className === 'string' ? node.className : '',
              node.getAttribute && node.getAttribute('aria-label')].join(' ');
            if (hintRe.test(attrs)) return true;
            if (tag === 'body' && inTopDocument) break;
            const text = node.innerText || '';
            if (text.length < 3000 && /cookie|traceurs/i.test(text)) return true;
            node = parentOf(node);
          }
          return false;
        };
        const tierOf = (label) => {
          for (const tier of [3, 2]) {
            if (tiers[tier].some((p) => hasWord(label, p))) return tier;
          }
          return tiers[1].includes(label) ? 1 : 0;
        };
        const refusal = (labels) => labels.some((label) =>
          rejectPatterns.some((p) => (p.length <= 3 ? hasWholeWord(label, p) : hasWord(label, p))));

        let best = null;
        for (const el of all) {
          const isKnown = known.has(el);
          if (!isKnown && !clickable(el)) continue;
          if (!visible(el)) continue;
          const raw = names(el);
          const labels = raw.map(norm).filter(Boolean);
          if (refusal(labels)) continue;
          let tier = Math.max(0, ...labels.map(tierOf));
          if (isKnown) tier = 4;
          if (tier === 0) continue;
          if (!isKnown && !inConsentBanner(el)) continue;
          const score = tier * 10 + (labels.some((l) => l.includes('cookie')) ? 1 : 0);
          if (!best || score > best.score) best = { el: el, label: raw[0] || '', score: score, known: isKnown };
        }
        window.__fmcpCookieButton = best ? best.el : null;
        return best ? { label: best.label, score: best.score, known: best.known } : null;
      })(arguments[0], arguments[1], arguments[2], arguments[3])
    JS

    # true once the clicked button is gone, hidden or faded out
    CLOSED_JS = <<~JS
      (function() {
        const el = window.__fmcpCookieButton;
        if (!el || !el.isConnected) return true;
        const rect = el.getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) return true;
        if (el.checkVisibility) return !el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
        return false;
      })()
    JS

    JS_CLICK = 'window.__fmcpCookieButton && window.__fmcpCookieButton.click()'

    # Consent platforms that are waiting for an answer and expose an
    # "accept all" call, for banners out of reach of a click (closed shadow
    # roots, cross-origin frames). Returns the platform name or null.
    PENDING_CMP_JS = <<~JS
      (function() {
        const shown = (selector) => {
          const el = document.querySelector(selector);
          if (!el) return false;
          const rect = el.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        };
        const checks = {
          Didomi: () => window.Didomi && Didomi.notice && Didomi.notice.isVisible && Didomi.notice.isVisible() &&
            typeof Didomi.setUserAgreeToAll === 'function',
          OneTrust: () => window.OneTrust && typeof OneTrust.AllowAll === 'function' && shown('#onetrust-banner-sdk'),
          Cookiebot: () => window.Cookiebot && Cookiebot.hasResponse === false &&
            typeof Cookiebot.submitCustomConsent === 'function',
          Usercentrics: () => window.UC_UI && typeof UC_UI.isConsentRequired === 'function' &&
            UC_UI.isConsentRequired() === true && typeof UC_UI.acceptAllConsents === 'function',
          tarteaucitron: () => window.tarteaucitron && tarteaucitron.userInterface && shown('#tarteaucitronAlertBig')
        };
        for (const name of Object.keys(checks)) {
          try { if (checks[name]()) return name; } catch (e) {}
        }
        return null;
      })()
    JS

    ACCEPT_CMP_JS = <<~JS
      (function(name) {
        const calls = {
          Didomi: () => Didomi.setUserAgreeToAll(),
          OneTrust: () => OneTrust.AllowAll(),
          Cookiebot: () => Cookiebot.submitCustomConsent(true, true, true),
          Usercentrics: () => UC_UI.acceptAllConsents(),
          tarteaucitron: () => tarteaucitron.userInterface.respondAll(true)
        };
        calls[name]();
        return true;
      })(arguments[0])
    JS
  end
end
