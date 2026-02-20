      !(function () {
        var l = "framer_variant";
        function u(a, r) {
          let n = r.indexOf("#"),
            e = n === -1 ? r : r.substring(0, n),
            o = n === -1 ? "" : r.substring(n),
            t = e.indexOf("?"),
            m = t === -1 ? e : e.substring(0, t),
            d = t === -1 ? "" : e.substring(t),
            s = new URLSearchParams(d),
            h = new URLSearchParams(a);
          for (let [i, g] of h) s.has(i) || (i !== l && s.append(i, g));
          let c = s.toString();
          return c === "" ? e + o : m + "?" + c + o;
        }
        var w =
            'div#main a[href^="#"],div#main a[href^="/"],div#main a[href^="."]',
          f = "div#main a[data-framer-preserve-params]",
          p = document.currentScript?.hasAttribute(
            "data-preserve-internal-params",
          );
        if (
          window.location.search &&
          !navigator.webdriver &&
          !/bot|-google|google-|yandex|ia_archiver|crawl|spider/iu.test(
            navigator.userAgent,
          )
        ) {
          let a = document.querySelectorAll(p ? `${w},${f}` : f);
          for (let r of a) {
            let n = u(window.location.search, r.href);
            r.setAttribute("href", n);
          }
        }
      })();
