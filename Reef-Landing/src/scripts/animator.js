      var animator = (() => {
        var O = (e, r, t) => (t > r ? r : t < e ? e : t);
        var j = () => {};
        function W(e) {
          let r;
          return () => (r === void 0 && (r = e()), r);
        }
        var q = (e) => e;
        var V = (e) => e * 1e3,
          D = (e) => e / 1e3;
        function X(e, r) {
          return r ? e * (1e3 / r) : 0;
        }
        var Y = (e) => Array.isArray(e) && typeof e[0] == "number";
        var H = { value: null, addProjectionMetrics: null };
        var Z = { layout: 0, mainThread: 0, waapi: 0 };
        var L = (e, r, t = 10) => {
          let o = "",
            s = Math.max(Math.round(r / t), 2);
          for (let n = 0; n < s; n++)
            o += Math.round(e(n / (s - 1)) * 1e4) / 1e4 + ", ";
          return `linear(${o.substring(0, o.length - 2)})`;
        };
        function R(e) {
          let r = 0,
            t = 50,
            o = e.next(r);
          for (; !o.done && r < 2e4; ) ((r += t), (o = e.next(r)));
          return r >= 2e4 ? 1 / 0 : r;
        }
        function fe(e, r = 100, t) {
          let o = t({ ...e, keyframes: [0, r] }),
            s = Math.min(R(o), 2e4);
          return {
            type: "keyframes",
            ease: (n) => o.next(s * n).value / r,
            duration: D(s),
          };
        }
        var Ee = 5;
        function ce(e, r, t) {
          let o = Math.max(r - Ee, 0);
          return X(t - e(o), r - o);
        }
        var u = {
          stiffness: 100,
          damping: 10,
          mass: 1,
          velocity: 0,
          duration: 800,
          bounce: 0.3,
          visualDuration: 0.3,
          restSpeed: { granular: 0.01, default: 2 },
          restDelta: { granular: 0.005, default: 0.5 },
          minDuration: 0.01,
          maxDuration: 10,
          minDamping: 0.05,
          maxDamping: 1,
        };
        var _ = 0.001;
        function le({
          duration: e = u.duration,
          bounce: r = u.bounce,
          velocity: t = u.velocity,
          mass: o = u.mass,
        }) {
          let s, n;
          j(
            e <= V(u.maxDuration),
            "Spring duration must be 10 seconds or less",
            "spring-duration-limit",
          );
          let i = 1 - r;
          ((i = O(u.minDamping, u.maxDamping, i)),
            (e = O(u.minDuration, u.maxDuration, D(e))),
            i < 1
              ? ((s = (m) => {
                  let p = m * i,
                    c = p * e,
                    l = p - t,
                    x = z(m, i),
                    g = Math.exp(-c);
                  return _ - (l / x) * g;
                }),
                (n = (m) => {
                  let c = m * i * e,
                    l = c * t + t,
                    x = Math.pow(i, 2) * Math.pow(m, 2) * e,
                    g = Math.exp(-c),
                    y = z(Math.pow(m, 2), i);
                  return ((-s(m) + _ > 0 ? -1 : 1) * ((l - x) * g)) / y;
                }))
              : ((s = (m) => {
                  let p = Math.exp(-m * e),
                    c = (m - t) * e + 1;
                  return -_ + p * c;
                }),
                (n = (m) => {
                  let p = Math.exp(-m * e),
                    c = (t - m) * (e * e);
                  return p * c;
                })));
          let f = 5 / e,
            a = Ce(s, n, f);
          if (((e = V(e)), isNaN(a)))
            return { stiffness: u.stiffness, damping: u.damping, duration: e };
          {
            let m = Math.pow(a, 2) * o;
            return {
              stiffness: m,
              damping: i * 2 * Math.sqrt(o * m),
              duration: e,
            };
          }
        }
        var ke = 12;
        function Ce(e, r, t) {
          let o = t;
          for (let s = 1; s < ke; s++) o = o - e(o) / r(o);
          return o;
        }
        function z(e, r) {
          return e * Math.sqrt(1 - r * r);
        }
        var Be = ["duration", "bounce"],
          Ie = ["stiffness", "damping", "mass"];
        function ue(e, r) {
          return r.some((t) => e[t] !== void 0);
        }
        function Ke(e) {
          let r = {
            velocity: u.velocity,
            stiffness: u.stiffness,
            damping: u.damping,
            mass: u.mass,
            isResolvedFromDuration: !1,
            ...e,
          };
          if (!ue(e, Ie) && ue(e, Be))
            if (e.visualDuration) {
              let t = e.visualDuration,
                o = (2 * Math.PI) / (t * 1.2),
                s = o * o,
                n = 2 * O(0.05, 1, 1 - (e.bounce || 0)) * Math.sqrt(s);
              r = { ...r, mass: u.mass, stiffness: s, damping: n };
            } else {
              let t = le(e);
              ((r = { ...r, ...t, mass: u.mass }),
                (r.isResolvedFromDuration = !0));
            }
          return r;
        }
        function v(e = u.visualDuration, r = u.bounce) {
          let t =
              typeof e != "object"
                ? { visualDuration: e, keyframes: [0, 1], bounce: r }
                : e,
            { restSpeed: o, restDelta: s } = t,
            n = t.keyframes[0],
            i = t.keyframes[t.keyframes.length - 1],
            f = { done: !1, value: n },
            {
              stiffness: a,
              damping: m,
              mass: p,
              duration: c,
              velocity: l,
              isResolvedFromDuration: x,
            } = Ke({ ...t, velocity: -D(t.velocity || 0) }),
            g = l || 0,
            y = m / (2 * Math.sqrt(a * p)),
            T = i - n,
            h = D(Math.sqrt(a / p)),
            K = Math.abs(T) < 5;
          (o || (o = K ? u.restSpeed.granular : u.restSpeed.default),
            s || (s = K ? u.restDelta.granular : u.restDelta.default));
          let S;
          if (y < 1) {
            let d = z(h, y);
            S = (A) => {
              let b = Math.exp(-y * h * A);
              return (
                i -
                b *
                  (((g + y * h * T) / d) * Math.sin(d * A) +
                    T * Math.cos(d * A))
              );
            };
          } else if (y === 1)
            S = (d) => i - Math.exp(-h * d) * (T + (g + h * T) * d);
          else {
            let d = h * Math.sqrt(y * y - 1);
            S = (A) => {
              let b = Math.exp(-y * h * A),
                G = Math.min(d * A, 300);
              return (
                i -
                (b * ((g + y * h * T) * Math.sinh(G) + d * T * Math.cosh(G))) /
                  d
              );
            };
          }
          let P = {
            calculatedDuration: (x && c) || null,
            next: (d) => {
              let A = S(d);
              if (x) f.done = d >= c;
              else {
                let b = d === 0 ? g : 0;
                y < 1 && (b = d === 0 ? V(g) : ce(S, d, A));
                let G = Math.abs(b) <= o,
                  Oe = Math.abs(i - A) <= s;
                f.done = G && Oe;
              }
              return ((f.value = f.done ? i : A), f);
            },
            toString: () => {
              let d = Math.min(R(P), 2e4),
                A = L((b) => P.next(d * b).value, d, 30);
              return d + "ms " + A;
            },
            toTransition: () => {},
          };
          return P;
        }
        v.applyToOptions = (e) => {
          let r = fe(e, 100, v);
          return (
            (e.ease = r.ease),
            (e.duration = V(r.duration)),
            (e.type = "keyframes"),
            e
          );
        };
        var xe = [
            "transformPerspective",
            "x",
            "y",
            "z",
            "translateX",
            "translateY",
            "translateZ",
            "scale",
            "scaleX",
            "scaleY",
            "rotate",
            "rotateX",
            "rotateY",
            "rotateZ",
            "skew",
            "skewX",
            "skewY",
          ],
          Q = new Set(xe);
        var de = {};
        function ge(e, r) {
          let t = W(e);
          return () => de[r] ?? t();
        }
        var ye = ge(() => {
          try {
            document
              .createElement("div")
              .animate({ opacity: 0 }, { easing: "linear(0, 1)" });
          } catch {
            return !1;
          }
          return !0;
        }, "linearEasing");
        var w = ([e, r, t, o]) => `cubic-bezier(${e}, ${r}, ${t}, ${o})`;
        var J = {
          linear: "linear",
          ease: "ease",
          easeIn: "ease-in",
          easeOut: "ease-out",
          easeInOut: "ease-in-out",
          circIn: w([0, 0.65, 0.55, 1]),
          circOut: w([0.55, 0, 1, 0.45]),
          backIn: w([0.31, 0.01, 0.66, -0.59]),
          backOut: w([0.33, 1.53, 0.69, 0.99]),
        };
        function ee(e, r) {
          if (e)
            return typeof e == "function"
              ? ye()
                ? L(e, r)
                : "ease-out"
              : Y(e)
                ? w(e)
                : Array.isArray(e)
                  ? e.map((t) => ee(t, r) || J.easeOut)
                  : J[e];
        }
        function F(
          e,
          r,
          t,
          {
            delay: o = 0,
            duration: s = 300,
            repeat: n = 0,
            repeatType: i = "loop",
            ease: f = "easeOut",
            times: a,
          } = {},
          m = void 0,
        ) {
          let p = { [r]: t };
          a && (p.offset = a);
          let c = ee(f, s);
          (Array.isArray(c) && (p.easing = c), H.value && Z.waapi++);
          let l = {
            delay: o,
            duration: s,
            easing: Array.isArray(c) ? "linear" : c,
            fill: "both",
            iterations: n + 1,
            direction: i === "reverse" ? "alternate" : "normal",
          };
          m && (l.pseudoElement = m);
          let x = e.animate(p, l);
          return (
            H.value &&
              x.finished.finally(() => {
                Z.waapi--;
              }),
            x
          );
        }
        function Ae(e) {
          return e.replace(/([A-Z])/g, (r) => `-${r.toLowerCase()}`);
        }
        var N = "framerAppearId",
          re = "data-" + Ae(N);
        function te(e) {
          return e.props[re];
        }
        var M = new Map(),
          E = new Map();
        var k = (e, r) => {
          let t = Q.has(r) ? "transform" : r;
          return `${e}: ${t}`;
        };
        function oe(e, r, t) {
          let o = k(e, r),
            s = M.get(o);
          if (!s) return null;
          let { animation: n, startTime: i } = s;
          function f() {
            window.MotionCancelOptimisedAnimation?.(e, r, t);
          }
          return (
            (n.onfinish = f),
            i === null || window.MotionHandoffIsComplete?.(e) ? (f(), null) : i
          );
        }
        var $,
          C,
          ne = new Set();
        function Ge() {
          (ne.forEach((e) => {
            (e.animation.play(), (e.animation.startTime = e.startTime));
          }),
            ne.clear());
        }
        function ie(e, r, t, o, s) {
          if (window.MotionIsMounted) return;
          let n = e.dataset[N];
          if (!n) return;
          window.MotionHandoffAnimation = oe;
          let i = k(n, r);
          C ||
            ((C = F(e, r, [t[0], t[0]], { duration: 1e4, ease: "linear" })),
            M.set(i, { animation: C, startTime: null }),
            (window.MotionHandoffAnimation = oe),
            (window.MotionHasOptimisedAnimation = (a, m) => {
              if (!a) return !1;
              if (!m) return E.has(a);
              let p = k(a, m);
              return !!M.get(p);
            }),
            (window.MotionHandoffMarkAsComplete = (a) => {
              E.has(a) && E.set(a, !0);
            }),
            (window.MotionHandoffIsComplete = (a) => E.get(a) === !0),
            (window.MotionCancelOptimisedAnimation = (a, m, p, c) => {
              let l = k(a, m),
                x = M.get(l);
              x &&
                (p && c === void 0
                  ? p.postRender(() => {
                      p.postRender(() => {
                        x.animation.cancel();
                      });
                    })
                  : x.animation.cancel(),
                p && c
                  ? (ne.add(x), p.render(Ge))
                  : (M.delete(l),
                    M.size ||
                      (window.MotionCancelOptimisedAnimation = void 0)));
            }),
            (window.MotionCheckAppearSync = (a, m, p) => {
              let c = te(a);
              if (!c) return;
              let l = window.MotionHasOptimisedAnimation?.(c, m),
                x = a.props.values?.[m];
              if (!l || !x) return;
              let g = p.on("change", (y) => {
                x.get() !== y &&
                  (window.MotionCancelOptimisedAnimation?.(c, m), g());
              });
              return g;
            }));
          let f = () => {
            C.cancel();
            let a = F(e, r, t, o);
            ($ === void 0 && ($ = performance.now()),
              (a.startTime = $),
              M.set(i, { animation: a, startTime: $ }),
              s && s(a));
          };
          (E.set(n, !1), C.ready ? C.ready.then(f).catch(q) : f());
        }
        var ae = [
            "transformPerspective",
            "x",
            "y",
            "z",
            "translateX",
            "translateY",
            "translateZ",
            "scale",
            "scaleX",
            "scaleY",
            "rotate",
            "rotateX",
            "rotateY",
            "rotateZ",
            "skew",
            "skewX",
            "skewY",
          ],
          Le = {
            x: "translateX",
            y: "translateY",
            z: "translateZ",
            transformPerspective: "perspective",
          },
          Re = {
            translateX: "px",
            translateY: "px",
            translateZ: "px",
            x: "px",
            y: "px",
            z: "px",
            perspective: "px",
            transformPerspective: "px",
            rotate: "deg",
            rotateX: "deg",
            rotateY: "deg",
          };
        function Te(e, r) {
          let t = Re[e];
          return !t || (typeof r == "string" && r.endsWith(t)) ? r : `${r}${t}`;
        }
        function se(e) {
          return ae.includes(e);
        }
        var ze = (e, r) => ae.indexOf(e) - ae.indexOf(r);
        function he({ transform: e, transformKeys: r }, t) {
          let o = {},
            s = !0,
            n = "";
          r.sort(ze);
          for (let i of r) {
            let f = e[i],
              a = !0;
            (typeof f == "number"
              ? (a = f === (i.startsWith("scale") ? 1 : 0))
              : (a = parseFloat(f) === 0),
              a || ((s = !1), (n += `${Le[i] || i}(${e[i]}) `)),
              t && (o[i] = e[i]));
          }
          return ((n = n.trim()), t ? (n = t(o, n)) : s && (n = "none"), n);
        }
        function pe(e, r) {
          let t = new Set(Object.keys(e));
          for (let o in r) t.add(o);
          return Array.from(t);
        }
        function me(e, r) {
          let t = r - e.length;
          if (t <= 0) return e;
          let o = new Array(t).fill(e[e.length - 1]);
          return e.concat(o);
        }
        function B(e) {
          return e * 1e3;
        }
        var be = { duration: 0.001 },
          I = {
            opacity: 1,
            scale: 1,
            translateX: 0,
            translateY: 0,
            translateZ: 0,
            x: 0,
            y: 0,
            z: 0,
            rotate: 0,
            rotateX: 0,
            rotateY: 0,
          };
        function De(e, r, t, o, s) {
          return (
            t.delay && (t.delay = B(t.delay)),
            t.type === "spring" ? Ne(e, r, t, o, s) : je(e, r, t, o, s)
          );
        }
        function Fe(e, r, t) {
          let o = {},
            s = 0,
            n = 0;
          for (let i of pe(e, r)) {
            let f = e[i] ?? I[i],
              a = r[i] ?? I[i];
            if (
              f === void 0 ||
              a === void 0 ||
              (i !== "transformPerspective" && f === a && f === I[i])
            )
              continue;
            i === "transformPerspective" && (o[i] = [f, a]);
            let m = He(f, a, t),
              { duration: p, keyframes: c } = m;
            p === void 0 ||
              c === void 0 ||
              (p > s && ((s = p), (n = c.length)), (o[i] = c));
          }
          return {
            keyframeValuesByProps: o,
            longestDuration: s,
            longestLength: n,
          };
        }
        function Ne(e, r, t, o, s) {
          let n = {},
            {
              keyframeValuesByProps: i,
              longestDuration: f,
              longestLength: a,
            } = Fe(e, r, t);
          if (!a) return n;
          let m = { ease: "linear", duration: f, delay: t.delay },
            p = s ? be : m,
            c = {};
          for (let [x, g] of Object.entries(i))
            se(x)
              ? (c[x] = me(g, a))
              : (n[x] = {
                  keyframes: me(g, a),
                  options: x === "opacity" ? m : p,
                });
          let l = ve(c, o);
          return (l && (n.transform = { keyframes: l, options: p }), n);
        }
        function $e(e) {
          let { type: r, duration: t, ...o } = e;
          return { duration: B(t), ...o };
        }
        function je(e, r, t, o, s) {
          let n = $e(t);
          if (!n) return;
          let i = {},
            f = s ? be : n,
            a = {};
          for (let p of pe(e, r)) {
            let c = e[p] ?? I[p],
              l = r[p] ?? I[p];
            c === void 0 ||
              l === void 0 ||
              (p !== "transformPerspective" && c === l) ||
              (se(p)
                ? (a[p] = [c, l])
                : (i[p] = {
                    keyframes: [c, l],
                    options: p === "opacity" ? n : f,
                  }));
          }
          let m = ve(a, o);
          return (m && (i.transform = { keyframes: m, options: f }), i);
        }
        var We = ["duration", "bounce"],
          qe = ["stiffness", "damping", "mass"];
        function Ve(e) {
          return qe.some((r) => r in e) ? !1 : We.some((r) => r in e);
        }
        function Xe(e, r, t) {
          return Ve(t)
            ? `${e}-${r}-${t.duration}-${t.bounce}`
            : `${e}-${r}-${t.damping}-${t.stiffness}-${t.mass}`;
        }
        function Ye(e) {
          return Ve(e) ? { ...e, duration: B(e.duration) } : e;
        }
        var Me = new Map(),
          Se = 10;
        function He(e, r, t) {
          let o = Xe(e, r, t),
            s = Me.get(o);
          if (s) return s;
          let n = [e, r],
            i = v({ ...Ye(t), keyframes: n }),
            f = { done: !1, value: n[0] },
            a = [],
            m = 0;
          for (; !f.done && m < B(10); )
            ((f = i.next(m)), a.push(f.value), (m += Se));
          n = a;
          let p = m - Se,
            l = { keyframes: n, duration: p, ease: "linear" };
          return (Me.set(o, l), l);
        }
        function ve(e, r) {
          let t = [],
            o = Object.values(e)[0]?.length;
          if (!o) return;
          let s = Object.keys(e);
          for (let n = 0; n < o; n++) {
            let i = {};
            for (let [a, m] of Object.entries(e)) {
              let p = m[n];
              p !== void 0 && (i[a] = Te(a, p));
            }
            let f = he({ transform: i, transformKeys: s }, r);
            t.push(f);
          }
          return t;
        }
        function Ze(e, r) {
          if (!r)
            for (let t in e) {
              let o = e[t];
              return o?.legacy === !0 ? o : void 0;
            }
        }
        function we(e, r, t, o, s, n) {
          for (let [i, f] of Object.entries(e)) {
            let a = n ? f[n] : void 0;
            if (a === null || (!a && f.default === null)) continue;
            let m = a ?? f.default ?? Ze(f, n);
            if (!m) continue;
            let { initial: p, animate: c, transformTemplate: l } = m;
            if (!p || !c) continue;
            let { transition: x, ...g } = c,
              y = De(p, g, x, Ue(l, o), s);
            if (!y) continue;
            let T = {},
              h = {};
            for (let [S, P] of Object.entries(y))
              ((T[S] = P.keyframes), (h[S] = P.options));
            let K = n ? `:not(.hidden-${n}) ` : "";
            r(`${K}[${t}="${i}"]`, T, h);
          }
        }
        function Ue(e, r) {
          if (!(!e || !r)) return (t, o) => e.replace(r, o);
        }
        function Pe(e) {
          return e
            ? e.find((t) =>
                t.mediaQuery
                  ? window.matchMedia(t.mediaQuery).matches === !0
                  : !1,
              )?.hash
            : void 0;
        }
        var zt = {
          animateAppearEffects: we,
          getActiveVariantHash: Pe,
          spring: v,
          startOptimizedAppearAnimation: ie,
        };
        return zt;
      })();
