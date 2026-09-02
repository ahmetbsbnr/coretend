/* Ahmet Design System 1.1.0 — motion module (ESM).
   Extracted from the CoreTend product site (ahmetbsbnr/coretend,
   Website/index.html, commit 63cd103). Apache-2.0. See PROVENANCE.md.

   Framework-agnostic primitives: theme, ambient field, Core Bloom logo
   orbits, reveals, scroll systems, pointer flourishes, ticker, FAQ.
   Everything degrades gracefully: under prefers-reduced-motion the content
   is shown immediately and all ambient layers stay off. */

const RM =
  typeof window !== "undefined" && window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)")
    : { matches: false };

export const prefersReducedMotion = () => RM.matches;

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

/* ─── theme ─────────────────────────────────────────────── */
export function initTheme(storageKey = "ahmet-theme") {
  if (typeof window !== "undefined" && window.AhmetTheme)
    return window.AhmetTheme;
  const root = document.documentElement;
  const system = window.matchMedia("(prefers-color-scheme: dark)");
  const allowed = new Set(["system", "light", "dark"]);
  root.classList.add("js");

  let mode = "system";
  try {
    const saved = localStorage.getItem(storageKey);
    if (allowed.has(saved)) mode = saved;
  } catch (_) {}

  const apply = () => {
    root.dataset.themeMode = mode;
    root.dataset.theme =
      mode === "system" ? (system.matches ? "dark" : "light") : mode;
  };

  apply();
  system.addEventListener?.("change", () => {
    if (root.dataset.themeMode === "system") apply();
  });

  const api = {
    get mode() {
      return mode;
    },
    set(next) {
      mode = allowed.has(next) ? next : "system";
      try {
        localStorage.setItem(storageKey, mode);
      } catch (_) {}
      apply();
      return mode;
    },
    cycle() {
      const order = ["system", "light", "dark"];
      return api.set(order[(order.indexOf(mode) + 1) % order.length]);
    },
    apply,
  };
  window.AhmetTheme = api;
  return api;
}

/* ─── ambient field (dot grid + arcs + radar + motes) ───── */
export function initField(canvas) {
  const cv = canvas || $("#field");
  if (!cv || RM.matches) return () => {};
  const ctx = cv.getContext("2d", { alpha: true });
  const root = document.documentElement;
  let w = 0,
    h = 0,
    dpr = 1,
    motes = [],
    t = 0,
    sy = 0,
    raf = 0;
  const mouse = { x: -999, y: -999 };

  const size = () => {
    dpr = Math.min(devicePixelRatio || 1, 2);
    w = innerWidth;
    h = innerHeight;
    cv.width = w * dpr;
    cv.height = h * dpr;
    cv.style.width = w + "px";
    cv.style.height = h + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    motes = Array.from({ length: w < 700 ? 14 : 30 }, () => ({
      x: Math.random() * w,
      y: Math.random() * h,
      r: Math.random() * 1.6 + 0.5,
      vx: (Math.random() - 0.5) * 0.12,
      vy: -(Math.random() * 0.12 + 0.03),
      a: Math.random() * 0.4 + 0.15,
    }));
  };
  size();

  const onResize = () => size();
  const onMouse = (e) => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  };
  const onScroll = () => {
    sy = scrollY;
  };
  addEventListener("resize", onResize, { passive: true });
  addEventListener("mousemove", onMouse, { passive: true });
  addEventListener("scroll", onScroll, { passive: true });

  const draw = () => {
    const dark = root.dataset.theme
      ? root.dataset.theme === "dark"
      : window.matchMedia("(prefers-color-scheme: dark)").matches;
    const ink = dark ? "237,236,229" : "23,25,29";
    const cob = dark ? "142,158,240" : "34,64,226";
    ctx.clearRect(0, 0, w, h);
    t += 0.006;

    const step = 34;
    for (let x = step / 2; x < w; x += step) {
      for (let y = step / 2 - ((sy * 0.04) % step); y < h; y += step) {
        const d = Math.hypot(x - mouse.x, y - mouse.y);
        const near = d < 170 ? 1 - d / 170 : 0;
        ctx.fillStyle =
          near > 0.02
            ? `rgba(${cob},${0.06 + near * 0.5})`
            : `rgba(${ink},.055)`;
        const s = 1.2 + near * 2.2;
        ctx.fillRect(x - s / 2, y - s / 2, s, s);
      }
    }

    const cx = w * 0.82,
      cy = h * 0.2 - sy * 0.05;
    const rings = [
      [Math.min(w, h) * 0.46, 0.35, cob],
      [Math.min(w, h) * 0.34, 0.25, ink],
      [Math.min(w, h) * 0.23, 0.55, ink],
    ];
    rings.forEach(([r, spd, col], i) => {
      ctx.beginPath();
      const a0 = t * spd * (i % 2 ? -1 : 1);
      ctx.arc(cx, cy, r, a0, a0 + Math.PI * (1.1 - i * 0.22));
      ctx.strokeStyle = `rgba(${col},${dark ? 0.13 : 0.085})`;
      ctx.lineWidth = 1.4;
      ctx.lineCap = "round";
      ctx.stroke();
    });

    const ang = (t * 0.55) % (Math.PI * 2),
      R = Math.min(w, h) * 0.5;
    const g = ctx.createLinearGradient(
      cx,
      cy,
      cx + Math.cos(ang) * R,
      cy + Math.sin(ang) * R
    );
    g.addColorStop(0, `rgba(${cob},${dark ? 0.22 : 0.16})`);
    g.addColorStop(1, `rgba(${cob},0)`);
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(ang) * R, cy + Math.sin(ang) * R);
    ctx.strokeStyle = g;
    ctx.lineWidth = 1.6;
    ctx.stroke();

    motes.forEach((m) => {
      m.x += m.vx;
      m.y += m.vy;
      if (m.y < -10) {
        m.y = h + 10;
        m.x = Math.random() * w;
      }
      if (m.x < -10) m.x = w + 10;
      if (m.x > w + 10) m.x = -10;
      ctx.beginPath();
      ctx.arc(m.x, m.y, m.r, 0, 7);
      ctx.fillStyle = `rgba(${cob},${m.a * (dark ? 0.6 : 0.38)})`;
      ctx.fill();
    });

    raf = requestAnimationFrame(draw);
  };
  raf = requestAnimationFrame(draw);

  const onVisibility = () => {
    cancelAnimationFrame(raf);
    if (!document.hidden) raf = requestAnimationFrame(draw);
  };
  document.addEventListener("visibilitychange", onVisibility);

  return () => {
    cancelAnimationFrame(raf);
    removeEventListener("resize", onResize);
    removeEventListener("mousemove", onMouse);
    removeEventListener("scroll", onScroll);
    document.removeEventListener("visibilitychange", onVisibility);
  };
}

/* ─── Core Bloom logo orbits ────────────────────────────── */
export function initLogos(rootEl = document) {
  const logos = $$(".ct-logo", rootEl);
  if (!logos.length || RM.matches) {
    logos.forEach((logo) => logo.classList.remove("is-initializing"));
    return () => {};
  }

  const specs = [
    [".ct-arc-outer", 20000, 1, 0],
    [".ct-arc-middle", 15000, -1, 160],
    [".ct-arc-inner", 10000, 1, 320],
  ];
  const records = logos.map((logo) => {
    const animations = specs.map(([selector, duration, direction, offset]) => {
      const arc = $(selector, logo);
      const animation = arc.animate(
        [
          { transform: "rotate(0deg)" },
          { transform: `rotate(${direction * 360}deg)` },
        ],
        {
          duration,
          delay: 1750 + offset,
          iterations: Infinity,
          easing: "linear",
        }
      );
      animation.pause();
      return { arc, animation };
    });
    const record = {
      logo,
      animations,
      visible: false,
      settled: false,
      rate: 1,
      raf: 0,
    };
    logo._ahmetOrbit = record;
    setTimeout(() => logo.classList.remove("is-initializing"), 2300);
    return record;
  });

  const setRate = (record, target, duration = 420) => {
    cancelAnimationFrame(record.raf);
    const start = record.rate,
      started = performance.now();
    const update = (now) => {
      const p = clamp((now - started) / duration, 0, 1);
      const eased = 1 - Math.pow(1 - p, 4);
      record.rate = start + (target - start) * eased;
      record.animations.forEach(
        ({ animation }) => (animation.playbackRate = record.rate)
      );
      if (p < 1) record.raf = requestAnimationFrame(update);
    };
    record.raf = requestAnimationFrame(update);
  };

  const sync = (record) => {
    record.animations.forEach(({ animation }) => {
      if (record.visible && !document.hidden && !record.settled)
        animation.play();
      else animation.pause();
    });
  };

  const settleFooter = (record) => {
    if (record.settled) return;
    record.settled = true;
    setRate(record, 0.18, 520);
    setTimeout(() => {
      record.animations.forEach(({ arc, animation }) => {
        arc.style.transform = getComputedStyle(arc).transform;
        animation.cancel();
      });
      requestAnimationFrame(() => record.logo.classList.add("is-settled"));
    }, 620);
  };

  const io = new IntersectionObserver(
    (entries) =>
      entries.forEach((entry) => {
        const record = entry.target._ahmetOrbit;
        record.visible = entry.isIntersecting;
        sync(record);
        if (
          entry.isIntersecting &&
          entry.target.classList.contains("ct-logo--footer")
        ) {
          setTimeout(() => settleFooter(record), 520);
        }
      }),
    { rootMargin: "80px", threshold: 0.05 }
  );
  records.forEach((record) => io.observe(record.logo));

  records.forEach((record) => {
    const owner = record.logo.closest(".wordmark,.hero-mark");
    if (!owner) return;
    const accelerate = () => setRate(record, 1.55, 300);
    const calm = () => setRate(record, 1, 700);
    owner.addEventListener("mouseenter", accelerate);
    owner.addEventListener("mouseleave", calm);
    owner.addEventListener("focusin", accelerate);
    owner.addEventListener("focusout", calm);
  });

  const onVisibility = () => records.forEach(sync);
  document.addEventListener("visibilitychange", onVisibility);

  window.AhmetLogoState = (state) => {
    const record = $(".ct-logo--app", rootEl)?._ahmetOrbit;
    if (!record) return;
    if (state === "paused") setRate(record, 0.08, 260);
    else if (state === "complete" || state === "cancelled")
      setRate(record, 0.22, 600);
    else setRate(record, 1.85, 260);
  };

  return () => {
    io.disconnect();
    document.removeEventListener("visibilitychange", onVisibility);
    records.forEach((record) =>
      record.animations.forEach(({ animation }) => animation.cancel())
    );
  };
}

/* ─── reveals, scramble, counters ───────────────────────── */
const GLYPH = "ABCDEF0123456789/_.$#";

export function scramble(el) {
  const target = el.textContent,
    len = target.length;
  let f = 0;
  const id = setInterval(() => {
    f++;
    el.textContent = target
      .split("")
      .map((c, i) =>
        i < f * 1.2 || c === " " ? c : GLYPH[(Math.random() * GLYPH.length) | 0]
      )
      .join("");
    if (f > len) {
      clearInterval(id);
      el.textContent = target;
    }
  }, 26);
}

export function countTo(el, to, dur = 1400) {
  const from = 0,
    t0 = performance.now();
  const step = (now) => {
    const p = clamp((now - t0) / dur, 0, 1),
      e = 1 - Math.pow(1 - p, 3);
    el.textContent = Math.round(from + (to - from) * e);
    if (p < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

export function sparkline(svg) {
  const path = $(".spark", svg);
  if (!path) return;
  const pts = Array.from({ length: 22 }, (_, i) => [
    i * (120 / 21),
    34 - (Math.sin(i * 0.7) * 7 + Math.random() * 12 + 4),
  ]);
  path.setAttribute(
    "d",
    "M" + pts.map((p) => p.map((n) => n.toFixed(1)).join(" ")).join(" L")
  );
  requestAnimationFrame(() => {
    path.style.strokeDashoffset = "0";
  });
}

export function initReveals(rootEl = document) {
  const io = new IntersectionObserver(
    (es) =>
      es.forEach((e) => {
        if (!e.isIntersecting) return;
        const el = e.target;
        el.classList.add("in");
        if (el.hasAttribute("data-scramble") && !RM.matches) {
          const s = el.querySelector("span");
          if (s) scramble(s);
        }
        if (el.dataset.gauge) {
          const c = $("[data-count]", el);
          if (c) countTo(c, +c.dataset.count);
          const bar = $(".bar i", el);
          if (bar)
            setTimeout(() => (bar.style.width = bar.dataset.fill + "%"), 120);
          const sv = $("svg", el);
          if (sv) sparkline(sv);
        }
        io.unobserve(el);
      }),
    { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
  );
  $$("[data-reveal],[data-scramble],[data-gauge]", rootEl).forEach((el) =>
    io.observe(el)
  );
  return () => io.disconnect();
}

/* ─── scroll systems (bar, progress, steps, rail) ───────── */
export function initScrollSystems({
  bar = $("#bar"),
  progress = $("#progress"),
  stepsList = $("#steps"),
  rail = $(".rail"),
} = {}) {
  const steps = stepsList ? $$(":scope > li", stepsList) : [];
  const railLinks = rail ? $$("a", rail) : [];
  const secs = railLinks.map((a) => $(a.getAttribute("href")));
  let tick = false;

  const run = () => {
    const y = scrollY,
      max = document.body.scrollHeight - innerHeight;
    if (progress)
      progress.style.transform = `scaleX(${clamp(max ? y / max : 0, 0, 1)})`;
    if (bar) bar.classList.toggle("stuck", y > 24);

    if (stepsList && steps.length) {
      const list = stepsList.getBoundingClientRect();
      const p = clamp((innerHeight * 0.62 - list.top) / list.height, 0, 1);
      stepsList.style.setProperty("--h", p * 100 + "%");
      steps.forEach((li) => {
        const r = li.getBoundingClientRect();
        li.classList.toggle(
          "hot",
          r.top < innerHeight * 0.66 && r.bottom > innerHeight * 0.22
        );
      });
    }
    secs.forEach((s, i) => {
      if (!s) return;
      const r = s.getBoundingClientRect();
      railLinks[i].classList.toggle(
        "on",
        r.top < innerHeight * 0.5 && r.bottom > innerHeight * 0.5
      );
    });
    tick = false;
  };
  const onScroll = () => {
    if (!tick) {
      tick = true;
      requestAnimationFrame(run);
    }
  };
  addEventListener("scroll", onScroll, { passive: true });
  run();
  return () => removeEventListener("scroll", onScroll);
}

/* ─── pointer flourishes (spot, magnetic, tilt) ─────────── */
export function initPointer(rootEl = document) {
  if (!matchMedia("(pointer:fine)").matches) return () => {};
  document.body.classList.add("pointer-fine");
  const onMove = (e) => {
    document.documentElement.style.setProperty("--mx", e.clientX + "px");
    document.documentElement.style.setProperty("--my", e.clientY + "px");
  };
  addEventListener("mousemove", onMove, { passive: true });

  if (RM.matches) return () => removeEventListener("mousemove", onMove);

  $$("[data-magnetic]", rootEl).forEach((w) => {
    w.addEventListener("mousemove", (e) => {
      const r = w.getBoundingClientRect();
      w.style.transform = `translate(${(e.clientX - r.left - r.width / 2) * 0.22}px,${(e.clientY - r.top - r.height / 2) * 0.32}px)`;
    });
    w.addEventListener("mouseleave", () => (w.style.transform = ""));
  });

  $$("[data-tilt]", rootEl).forEach((c) => {
    c.addEventListener("mousemove", (e) => {
      const r = c.getBoundingClientRect(),
        px = (e.clientX - r.left) / r.width,
        py = (e.clientY - r.top) / r.height;
      const amp = c.classList.contains("mod") ? 5 : 3.2;
      c.style.transform = `perspective(1100px) rotateY(${(px - 0.5) * amp}deg) rotateX(${(0.5 - py) * amp}deg) translateY(-3px)`;
      c.style.setProperty("--gx", px * 100 + "%");
      c.style.setProperty("--gy", py * 100 + "%");
    });
    c.addEventListener("mouseleave", () => (c.style.transform = ""));
  });

  return () => removeEventListener("mousemove", onMove);
}

/* ─── headline word split ───────────────────────────────── */
export function splitHeadline(h) {
  if (!h || RM.matches) return;
  let i = 0;
  const walk = (node) => {
    [...node.childNodes].forEach((n) => {
      if (n.nodeType === 3) {
        const frag = document.createDocumentFragment();
        n.textContent.split(/(\s+)/).forEach((part) => {
          if (!part.trim()) {
            frag.appendChild(document.createTextNode(part));
            return;
          }
          const s = document.createElement("span");
          s.className = "word";
          const it = document.createElement("i");
          it.textContent = part;
          it.style.setProperty("--d", i++ * 55 + 1650 + "ms");
          s.appendChild(it);
          frag.appendChild(s);
        });
        node.replaceChild(frag, n);
      } else if (n.nodeType === 1) walk(n);
    });
  };
  walk(h);
}

/* ─── ticker ────────────────────────────────────────────── */
export function initTicker(el, items) {
  if (!el) return () => {};
  const ul = () => `<ul>${items.map((i) => `<li>${i}</li>`).join("")}</ul>`;
  el.innerHTML = ul() + ul();
  const io = new IntersectionObserver(
    (es) =>
      es.forEach((e) => el.classList.toggle("is-visible", e.isIntersecting)),
    { threshold: 0.1 }
  );
  io.observe(el);
  return () => io.disconnect();
}

/* ─── faq disclosures ───────────────────────────────────── */
export function initFaq(rootEl = document) {
  $$(".faq details", rootEl).forEach((d) => {
    $("summary", d).addEventListener("click", (e) => {
      e.preventDefault();
      if (!d.open) {
        d.open = true;
        return;
      }
      d.classList.add("closing");
      const done = () => {
        d.open = false;
        d.classList.remove("closing");
      };
      const ans = $(".ans", d);
      let fired = false;
      ans.addEventListener(
        "transitionend",
        () => {
          fired = true;
          done();
        },
        { once: true }
      );
      setTimeout(() => {
        if (!fired) done();
      }, 600);
    });
  });
}

/* ─── toast ─────────────────────────────────────────────── */
export function showToast(msg, el = $("#toast")) {
  if (!el) return;
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.remove("show"), 2200);
}

/* ─── smooth in-page anchors ────────────────────────────── */
export function initAnchors(rootEl = document) {
  $$('a[href^="#"]', rootEl).forEach((a) =>
    a.addEventListener("click", (e) => {
      const t = $(a.getAttribute("href"));
      if (!t) return;
      e.preventDefault();
      t.scrollIntoView({
        behavior: RM.matches ? "auto" : "smooth",
        block: "start",
      });
    })
  );
}
