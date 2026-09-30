# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Find elements by their visible text
    class FindByTextTool < BaseTool
      tool_name 'find_by_text'
      description 'Find the innermost elements whose visible text contains (or equals) a text, and return ' \
                  'a unique selector and a ref (ref:eN) to act on them'

      param :text, type: :string, required: true,
                   description: 'Text to search for (case-insensitive substring, or exact with exact: true)'
      param :tag, type: :string, default: '*',
                  description: 'HTML tag to search within (e.g. "button", "a"). "*" for any tag (default)'
      param :exact, type: :boolean, default: false,
                    description: 'Match the whole visible text exactly, case included (default: false)'
      param :multiple, type: :boolean, default: false,
                       description: 'Return all matching elements (true) or just the first visible one (false)'

      MAX_RESULTS = 50
      TEXT_LIMIT = 200

      def perform(params)
        ensure_browser_active
        text = params[:text].to_s
        tag = params[:tag].to_s.match?(/\A[\w*-]+\z/) ? params[:tag] : '*'
        logger.info "Finding elements with text: '#{text}' in <#{tag}> (exact: #{params[:exact]})"

        found = page.evaluate(FIND_JS, text, tag, params[:exact] == true, MAX_RESULTS, TEXT_LIMIT)
        elements = found['elements'].map { |e| e.transform_keys(&:to_sym) }
        return error_response("No elements found with text: '#{text}'") if elements.empty?

        success_response(build_result(elements, found['total'], params[:multiple]))
      end

      def build_result(elements, total, multiple)
        return { found: total, elements: elements.each_with_index.map { |e, i| e.merge(index: i) } } if multiple

        (elements.find { |e| e[:visible] } || elements.first).merge(total_found: total)
      end
      private :build_result

      # Innermost elements whose rendered text matches: an element is left
      # out when one of its descendants matches too, so <html> and wrappers
      # never come back. Text inside script/style is not rendered, hence
      # never matched. Each result gets a snapshot ref and a CSS selector
      # checked to match that element only.
      FIND_JS = <<~JS.freeze
        (function(text, tag, exact, maxResults, textLimit) {
          const ATTR = '#{REF_ATTRIBUTE}';
          if (typeof window.__fmcpRefCounter !== 'number') window.__fmcpRefCounter = 0;
          const SKIP = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'HEAD', 'TITLE', 'META', 'LINK']);
          const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim();
          const needle = exact ? clean(text) : clean(text).toLowerCase();
          const ownText = (el) => clean(el.innerText !== undefined ? el.innerText : el.textContent);
          const matches = (el) => {
            if (SKIP.has(el.tagName) || el.closest('script, style, noscript, template, head')) return false;
            // cheap pre-filter before innerText, which lays the page out
            if (!(el.textContent || '').toLowerCase().includes(needle.toLowerCase().split(' ')[0])) return false;
            const value = ownText(el);
            return exact ? value === needle : value.toLowerCase().includes(needle);
          };
          const visible = (el) => {
            const rect = el.getBoundingClientRect();
            if (rect.width <= 0 || rect.height <= 0) return false;
            return el.checkVisibility ? el.checkVisibility({ checkVisibilityCSS: true }) : true;
          };
          const uniqueSelector = (el) => {
            if (el.id && document.querySelectorAll('#' + CSS.escape(el.id)).length === 1) return '#' + CSS.escape(el.id);
            const parts = [];
            for (let node = el; node && node.nodeType === 1; node = node.parentElement) {
              let part = node.tagName.toLowerCase();
              if (node.id && document.querySelectorAll('#' + CSS.escape(node.id)).length === 1) {
                parts.unshift('#' + CSS.escape(node.id));
              } else {
                const parent = node.parentElement;
                if (parent) {
                  const same = Array.from(parent.children).filter((c) => c.tagName === node.tagName);
                  if (same.length > 1) part += ':nth-of-type(' + (same.indexOf(node) + 1) + ')';
                }
                parts.unshift(part);
              }
              const selector = parts.join(' > ');
              if (document.querySelectorAll(selector).length === 1) return selector;
              if (parts[0].startsWith('#')) return selector;
            }
            return parts.join(' > ');
          };

          const candidates = Array.from(document.body ? document.body.querySelectorAll('*') : []).filter(matches);
          const set = new Set(candidates);
          const innermost = candidates.filter((el) => {
            for (const other of el.querySelectorAll('*')) if (set.has(other)) return false;
            return true;
          });
          const wanted = tag === '*' ? innermost
            : candidates.filter((el) => el.tagName.toLowerCase() === tag.toLowerCase() &&
                !Array.from(el.querySelectorAll(tag)).some((d) => set.has(d)));

          const elements = wanted.slice(0, maxResults).map((el) => {
            let ref = el.getAttribute(ATTR);
            if (!ref) { ref = 'e' + (++window.__fmcpRefCounter); el.setAttribute(ATTR, ref); }
            let value = ownText(el);
            if (value.length > textLimit) value = value.slice(0, textLimit) + '...';
            return { tag: el.tagName.toLowerCase(), text: value, visible: visible(el),
                     selector: uniqueSelector(el), ref: 'ref:' + ref };
          });
          return { elements: elements, total: wanted.length };
        })(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4])
      JS
    end
  end
end
