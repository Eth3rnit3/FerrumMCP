# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Compact, LLM-friendly view of the page: interactive elements with stable
    # refs that other tools accept as selectors ("ref:e12").
    class SnapshotTool < BaseTool
      tool_name 'snapshot'
      description <<~DESC.strip
        Get a compact snapshot of the page: interactive elements (links, buttons, inputs, ...) and headings,
        each with a stable ref (e.g. e12) usable as selector "ref:e12" in click, fill_form, get_text, etc.
        Much cheaper than get_html for deciding what to do next.
      DESC

      param :mode, type: :string, default: 'interactive', enum: %w[interactive full],
                   description: 'interactive: controls and headings (default); full: also images, alerts, ' \
                                'labels and paragraphs'
      param :selector, type: :string, description: 'Optional: CSS selector to restrict the snapshot to a subtree'
      param :include_hidden, type: :boolean, default: false, description: 'Include hidden elements (default: false)'
      param :max_elements, type: :integer, default: 200, description: 'Maximum number of elements (default: 200)'
      param :format, type: :string, default: 'text', enum: %w[text json],
                     description: 'text: one line per element (default); json: structured elements'

      def perform(params)
        ensure_browser_active
        logger.info "Taking page snapshot (mode: #{params[:mode]})"

        raw = page.evaluate(SNAPSHOT_SCRIPT, params[:mode], params[:include_hidden] ? true : false,
                            params[:max_elements].to_i.clamp(1, 5000), params[:selector])
        elements = raw['elements'].map { |e| e.transform_keys(&:to_sym) }

        data = { url: page.url, title: page.title, count: elements.length,
                 total: raw['total'], truncated: raw['truncated'] }
        captcha = detected_captcha
        data[:captcha] = captcha if captcha.any?
        if params[:format] == 'json'
          success_response(data.merge(elements: elements))
        else
          lines = elements.map { |e| format_line(e) }
          lines.unshift("CAPTCHA detected: #{captcha.join(', ')} (solve_captcha)") if captcha.any?
          success_response(data.merge(snapshot: lines.join("\n")))
        end
      end

      # CAPTCHA widgets on the page ("turnstile", ...), so the agent knows
      # about the wall from the snapshot it takes anyway.
      def detected_captcha
        Captcha::Detector.detect(page).map(&:to_s)
      end
      private :detected_captcha

      def format_line(element)
        role = element[:role]
        role = "heading(#{element[:level]})" if role == 'heading' && element[:level]
        parts = ["[#{element[:ref]}]", role, element[:name].to_s.inspect]
        parts << "type=#{element[:type]}" if element[:type]
        parts << "href=#{element[:href]}" if element[:href]
        parts << "placeholder=#{element[:placeholder].inspect}" if element[:placeholder]
        parts << "value=#{element[:value].inspect}" if element[:value]
        parts << 'checked' if element[:checked]
        parts << 'disabled' if element[:disabled]
        parts << 'multiple' if element[:multiple]
        parts.join(' ')
      end
      private :format_line

      SNAPSHOT_SCRIPT = <<~JS
        (function(mode, includeHidden, maxElements, scope) {
          const ATTR = 'data-fmcp-ref';
          const root = scope ? document.querySelector(scope) : document.body;
          if (!root) throw new Error('Scope element not found: ' + scope);
          if (typeof window.__fmcpRefCounter !== 'number') window.__fmcpRefCounter = 0;

          const INTERACTIVE = 'a[href], button, input, select, textarea, summary, [contenteditable="true"], ' +
            '[role="button"], [role="link"], [role="checkbox"], [role="radio"], [role="tab"], [role="menuitem"], ' +
            '[role="menuitemcheckbox"], [role="menuitemradio"], [role="option"], [role="switch"], [role="textbox"], ' +
            '[role="combobox"], [role="searchbox"], [role="slider"], [onclick], [tabindex]:not([tabindex="-1"]), ' +
            'h1, h2, h3, h4, h5, h6';
          const FULL = INTERACTIVE + ', img[alt], label, p, [role="alert"], [role="status"], [role="dialog"], [aria-live]';
          const candidates = Array.from(root.querySelectorAll(mode === 'full' ? FULL : INTERACTIVE));

          const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim().slice(0, 120);
          const visible = (el) => {
            if (el.type === 'hidden') return false;
            if (includeHidden) return true;
            const rect = el.getBoundingClientRect();
            const style = getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
          };
          const roleOf = (el) => {
            const explicit = el.getAttribute('role');
            if (explicit) return explicit;
            const tag = el.tagName.toLowerCase();
            if (tag === 'a') return 'link';
            if (tag === 'button' || tag === 'summary') return 'button';
            if (tag === 'select') return el.multiple ? 'listbox' : 'combobox';
            if (tag === 'textarea') return 'textbox';
            if (/^h[1-6]$/.test(tag)) return 'heading';
            if (tag === 'img') return 'img';
            if (tag === 'label') return 'label';
            if (tag === 'p') return 'paragraph';
            if (tag === 'input') {
              const type = (el.type || 'text').toLowerCase();
              if (type === 'checkbox' || type === 'radio') return type;
              if (['submit', 'button', 'reset', 'image'].includes(type)) return 'button';
              if (type === 'file') return 'file';
              if (type === 'range') return 'slider';
              return 'textbox';
            }
            if (el.isContentEditable) return 'textbox';
            return 'generic';
          };
          const labelText = (el) => {
            const byId = el.id ? document.querySelector('label[for="' + CSS.escape(el.id) + '"]') : null;
            const label = byId || el.closest('label');
            return label ? clean(label.innerText || label.textContent) : '';
          };
          const nameOf = (el, role) => {
            const aria = el.getAttribute('aria-label');
            if (aria) return clean(aria);
            const labelledBy = el.getAttribute('aria-labelledby');
            if (labelledBy) {
              const text = labelledBy.split(/\\s+/).map(id => { const n = document.getElementById(id); return n ? n.innerText || n.textContent : ''; }).join(' ');
              if (clean(text)) return clean(text);
            }
            const tag = el.tagName.toLowerCase();
            if (tag === 'img') return clean(el.getAttribute('alt'));
            if (['input', 'select', 'textarea'].includes(tag)) {
              return labelText(el) || clean(el.placeholder) || clean(el.name) || clean(el.title) ||
                (el.type !== 'password' && ['button', 'checkbox', 'radio'].includes(role) ? clean(el.value) : '') || clean(el.id);
            }
            return clean(el.innerText || el.textContent) || clean(el.title) || clean(el.value) || clean(el.id);
          };
          const selectorFor = (el) => {
            if (el.id) return '#' + CSS.escape(el.id);
            const tag = el.tagName.toLowerCase();
            if (el.name && document.querySelectorAll(tag + '[name="' + CSS.escape(el.name) + '"]').length === 1) {
              return tag + '[name="' + el.name + '"]';
            }
            const path = [];
            let node = el;
            while (node && node.nodeType === 1 && node !== document.body && path.length < 6) {
              let part = node.tagName.toLowerCase();
              if (node.id) { path.unshift('#' + CSS.escape(node.id)); break; }
              const siblings = Array.from(node.parentNode ? node.parentNode.children : []).filter(s => s.tagName === node.tagName);
              if (siblings.length > 1) part += ':nth-of-type(' + (siblings.indexOf(node) + 1) + ')';
              path.unshift(part);
              node = node.parentNode;
            }
            return path.join(' > ');
          };

          // Listed for their text only: without one they are noise
          const TEXT_ROLES = ['heading', 'paragraph', 'label', 'img'];

          const elements = [];
          let total = 0;
          let truncated = false;
          for (const el of candidates) {
            if (!visible(el)) continue;
            const role = roleOf(el);
            const name = nameOf(el, role);
            if (!name && TEXT_ROLES.includes(role)) continue;
            total += 1;
            if (elements.length >= maxElements) { truncated = true; continue; }
            let ref = el.getAttribute(ATTR);
            if (!ref) { ref = 'e' + (++window.__fmcpRefCounter); el.setAttribute(ATTR, ref); }
            const tag = el.tagName.toLowerCase();
            const item = { ref: ref, role: role, tag: tag, name: name, selector: selectorFor(el) };
            const value = el.type === 'password' ? '' : clean(el.value);
            if (role === 'heading') item.level = parseInt(tag[1], 10) || null;
            if (tag === 'a' && el.getAttribute('href')) item.href = el.getAttribute('href');
            if (tag === 'input' && el.type && !['text', 'checkbox', 'radio'].includes(el.type)) item.type = el.type;
            if (el.placeholder) item.placeholder = clean(el.placeholder);
            if ((role === 'textbox' || role === 'combobox' || role === 'listbox' || role === 'slider') && value) item.value = value;
            if (role === 'radio' && tag === 'input' && value && value !== 'on') item.value = value;
            if (role === 'checkbox' || role === 'radio' || role === 'switch') {
              item.checked = el.checked === true || el.getAttribute('aria-checked') === 'true';
            }
            if (el.disabled || el.getAttribute('aria-disabled') === 'true') item.disabled = true;
            if (el.multiple) item.multiple = true;
            elements.push(item);
          }
          return { elements: elements, total: total, truncated: truncated };
        })(arguments[0], arguments[1], arguments[2], arguments[3])
      JS
    end
  end
end
