      (function () {
        function rm() {
          try {
            var sel = [
              "a.__framer-badge",
              ".__framer-badge",
              "#__framer-badge-container",
              "div#__framer-badge-container",
              '[data-framer-name="Badge"]',
              '[data-framer-appear-id][class*="__framer-badge"]',
              '[class*="__framer-badge"]',
              'div[id^="__framer-badge"]',
              'div[class^="framer-"][class*="__framer-badge"]',
              "#__framer-editorbar-container",
              "#__framer-editorbar-button",
              "#__framer-editorbar-label",
              '[id^="__framer-editorbar"]',
              'div[id^="__framer-editorbar"]',
            ];
            document.querySelectorAll(sel.join(",")).forEach(function (n) {
              try {
                n.remove();
              } catch (_) {}
            });
          } catch (e) {}
        }
        rm();
        var mo = new MutationObserver(function () {
          rm();
        });
        try {
          mo.observe(document.documentElement || document.body, {
            childList: true,
            subtree: true,
          });
        } catch (_) {}
        window.addEventListener("load", rm);
      })();
