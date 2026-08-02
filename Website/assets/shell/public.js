(() => {
  "use strict";

  const root = document.documentElement;
  const body = document.body;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const finePointer = window.matchMedia("(pointer: fine)");
  const $ = (selector, scope = document) => scope.querySelector(selector);
  const $$ = (selector, scope = document) => [...scope.querySelectorAll(selector)];
  const clamp = (value, minimum, maximum) => Math.min(maximum, Math.max(minimum, value));
  const language = root.lang === "fr" ? "fr" : "en";

  const labels = {
    en: {
      theme: {
        system: "Appearance follows the system. Activate light appearance",
        light: "Light appearance active. Activate dark appearance",
        dark: "Dark appearance active. Follow the system",
      },
      copied: "Technical information copied",
      results: count => `${count} license entr${count === 1 ? "y" : "ies"}`,
    },
    fr: {
      theme: {
        system: "L’apparence suit le système. Activer l’apparence claire",
        light: "Apparence claire active. Activer l’apparence sombre",
        dark: "Apparence sombre active. Suivre le système",
      },
      copied: "Informations techniques copiées",
      results: count => `${count} licence${count === 1 ? "" : "s"}`,
    },
  }[language];

  let toastTimer = 0;
  function toast(message) {
    const element = $("#toast");
    if (!element) return;
    element.textContent = message;
    element.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => element.classList.remove("show"), 2200);
  }

  function theme() {
    const button = $("#theme");
    if (!button) return;
    const order = ["system", "light", "dark"];

    const syncLabel = () => {
      const mode = root.dataset.themeMode || "system";
      button.dataset.mode = mode;
      button.setAttribute("aria-label", labels.theme[mode]);
      button.title = labels.theme[mode];
    };

    syncLabel();
    button.addEventListener("click", () => {
      const current = root.dataset.themeMode || "system";
      const next = order[(order.indexOf(current) + 1) % order.length];
      const box = button.getBoundingClientRect();
      root.style.setProperty("--theme-x", `${box.left + box.width / 2}px`);
      root.style.setProperty("--theme-y", `${box.top + box.height / 2}px`);
      const apply = () => {
        window.CoreTendTheme?.set(next);
        syncLabel();
      };
      if (!reduceMotion.matches && document.startViewTransition) document.startViewTransition(apply);
      else apply();
    });
  }

  function logos() {
    const logos = $$(".ct-logo");
    if (!logos.length || reduceMotion.matches) {
      logos.forEach(logo => logo.classList.remove("is-initializing"));
      return;
    }

    const specs = [
      [".ct-arc-outer", 20000, 1, 0],
      [".ct-arc-middle", 15000, -1, 160],
      [".ct-arc-inner", 10000, 1, 320],
    ];

    const records = logos.map(logo => {
      const animations = specs.map(([selector, duration, direction, offset]) => {
        const arc = $(selector, logo);
        const animation = arc.animate(
          [{ transform: "rotate(0deg)" }, { transform: `rotate(${direction * 360}deg)` }],
          { duration, delay: 1750 + offset, iterations: Infinity, easing: "linear" },
        );
        animation.pause();
        return { arc, animation };
      });
      const record = { logo, animations, visible: false, settled: false, rate: 1, frame: 0 };
      logo._ctOrbit = record;
      window.setTimeout(() => logo.classList.remove("is-initializing"), 2300);
      return record;
    });

    const setRate = (record, target, duration = 420) => {
      cancelAnimationFrame(record.frame);
      const start = record.rate;
      const started = performance.now();
      const update = now => {
        const progress = clamp((now - started) / duration, 0, 1);
        const eased = 1 - Math.pow(1 - progress, 4);
        record.rate = start + (target - start) * eased;
        record.animations.forEach(({ animation }) => { animation.playbackRate = record.rate; });
        if (progress < 1) record.frame = requestAnimationFrame(update);
      };
      record.frame = requestAnimationFrame(update);
    };

    const sync = record => {
      record.animations.forEach(({ animation }) => {
        if (record.visible && !document.hidden && !record.settled) animation.play();
        else animation.pause();
      });
    };

    const settle = record => {
      if (record.settled) return;
      record.settled = true;
      setRate(record, 0.18, 520);
      window.setTimeout(() => {
        record.animations.forEach(({ arc, animation }) => {
          arc.style.transform = getComputedStyle(arc).transform;
          animation.cancel();
        });
        requestAnimationFrame(() => record.logo.classList.add("is-settled"));
      }, 620);
    };

    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        const record = entry.target._ctOrbit;
        record.visible = entry.isIntersecting;
        sync(record);
        if (entry.isIntersecting && entry.target.classList.contains("ct-logo--footer")) {
          window.setTimeout(() => settle(record), 520);
        }
      });
    }, { rootMargin: "80px", threshold: 0.05 });

    records.forEach(record => {
      observer.observe(record.logo);
      const owner = record.logo.closest(".wordmark,.info-mark");
      if (!owner) return;
      const accelerate = () => setRate(record, 1.55, 300);
      const calm = () => setRate(record, 1, 700);
      owner.addEventListener("mouseenter", accelerate);
      owner.addEventListener("mouseleave", calm);
      owner.addEventListener("focusin", accelerate);
      owner.addEventListener("focusout", calm);
    });

    document.addEventListener("visibilitychange", () => records.forEach(sync));
    window.addEventListener("pagehide", () => {
      observer.disconnect();
      records.forEach(record => {
        cancelAnimationFrame(record.frame);
        record.animations.forEach(({ animation }) => animation.cancel());
      });
    }, { once: true });
  }

  function scrollSystems() {
    const bar = $("#bar");
    const progress = $("#progress");
    if (!bar || !progress) return;
    let scheduled = false;
    const update = () => {
      const maximum = document.documentElement.scrollHeight - innerHeight;
      progress.style.transform = `scaleX(${clamp(maximum ? scrollY / maximum : 0, 0, 1)})`;
      bar.classList.toggle("stuck", scrollY > 24);
      scheduled = false;
    };
    addEventListener("scroll", () => {
      if (!scheduled) {
        scheduled = true;
        requestAnimationFrame(update);
      }
    }, { passive: true });
    update();
  }

  function pointer() {
    if (!finePointer.matches) return;
    body.classList.add("pointer-fine");
    addEventListener("pointermove", event => {
      root.style.setProperty("--mx", `${event.clientX}px`);
      root.style.setProperty("--my", `${event.clientY}px`);
    }, { passive: true });
  }

  function field() {
    const canvas = $("#field");
    if (!canvas || reduceMotion.matches) return;
    const context = canvas.getContext("2d", { alpha: true });
    const page = body.dataset.page || "privacy";
    let width = 0;
    let height = 0;
    let ratio = 1;
    let frame = 0;
    let last = 0;
    let phase = 0;

    const resize = () => {
      ratio = Math.min(devicePixelRatio || 1, 2);
      width = innerWidth;
      height = innerHeight;
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    };

    const palette = () => root.dataset.theme === "dark"
      ? { ink: "237,236,229", cobalt: "142,158,240" }
      : { ink: "23,25,29", cobalt: "34,64,226" };

    const dotGrid = colors => {
      const step = width < 680 ? 42 : 36;
      for (let x = step / 2; x < width; x += step) {
        for (let y = step / 2; y < height; y += step) {
          context.fillStyle = `rgba(${colors.ink},.045)`;
          context.fillRect(x, y, 1.1, 1.1);
        }
      }
    };

    const ring = (x, y, radius, start, length, color, alpha = 0.12) => {
      context.beginPath();
      context.arc(x, y, radius, start, start + length);
      context.strokeStyle = `rgba(${color},${alpha})`;
      context.lineWidth = 1.25;
      context.lineCap = "round";
      context.stroke();
    };

    const draw = now => {
      frame = requestAnimationFrame(draw);
      if (document.hidden || now - last < (width < 680 ? 40 : 24)) return;
      last = now;
      phase += 0.006;
      const colors = palette();
      context.clearRect(0, 0, width, height);
      dotGrid(colors);
      const x = width * (width < 700 ? 0.82 : 0.78);
      const y = height * 0.26;
      const scale = Math.min(width, height);

      if (page === "privacy") {
        for (let index = 0; index < 18; index++) {
          const angle = (index / 18) * Math.PI * 2 + phase * 0.28;
          const radius = scale * (0.12 + ((index * 29) % 15) / 80);
          const progress = (phase * 0.22 + index / 18) % 1;
          const px = x + Math.cos(angle) * radius * (1 - progress);
          const py = y + Math.sin(angle) * radius * (1 - progress);
          context.beginPath();
          context.arc(px, py, 1.2 + progress, 0, Math.PI * 2);
          context.fillStyle = `rgba(${colors.cobalt},${0.08 + progress * 0.22})`;
          context.fill();
        }
        ring(x, y, scale * 0.22, phase * 0.2, Math.PI * 1.3, colors.cobalt);
        ring(x, y, scale * 0.15, -phase * 0.24, Math.PI * 1.05, colors.ink, 0.09);
      } else if (page === "support") {
        [0.11, 0.18, 0.25].forEach((value, index) => ring(
          x, y, scale * value, phase * (index % 2 ? -0.34 : 0.3), Math.PI * (1.25 - index * 0.12),
          index === 0 ? colors.cobalt : colors.ink, index === 0 ? 0.18 : 0.08,
        ));
        const angle = phase * 0.52;
        context.beginPath();
        context.moveTo(x, y);
        context.lineTo(x + Math.cos(angle) * scale * 0.29, y + Math.sin(angle) * scale * 0.29);
        context.strokeStyle = `rgba(${colors.cobalt},.2)`;
        context.stroke();
      } else if (page === "legal") {
        for (let index = 0; index < 9; index++) {
          const yy = 96 + index * 72 - ((scrollY * 0.025) % 72);
          context.beginPath();
          context.moveTo(width * 0.58, yy);
          context.lineTo(width - 32, yy);
          context.strokeStyle = `rgba(${colors.ink},.055)`;
          context.stroke();
        }
        ring(x, y, scale * 0.19, phase * 0.08, Math.PI * 1.15, colors.cobalt, 0.08);
      } else if (page === "licenses") {
        const nodes = [[0, 0], [-0.19, 0.12], [0.18, 0.15], [-0.08, -0.2], [0.24, -0.1]];
        nodes.slice(1).forEach(([nx, ny]) => {
          context.beginPath();
          context.moveTo(x, y);
          context.lineTo(x + nx * scale, y + ny * scale);
          context.strokeStyle = `rgba(${colors.ink},.08)`;
          context.stroke();
        });
        nodes.forEach(([nx, ny], index) => {
          context.beginPath();
          context.arc(x + nx * scale, y + ny * scale, index ? 3 : 5, 0, Math.PI * 2);
          context.fillStyle = `rgba(${index ? colors.ink : colors.cobalt},${index ? 0.22 : 0.42})`;
          context.fill();
        });
      } else {
        [0.12, 0.2, 0.28].forEach((value, index) => ring(
          x, y, scale * value, phase * (index % 2 ? -0.3 : 0.42), Math.PI * (0.72 + index * 0.12),
          index === 0 ? colors.cobalt : colors.ink, 0.14 - index * 0.02,
        ));
      }
    };

    resize();
    addEventListener("resize", resize, { passive: true });
    frame = requestAnimationFrame(draw);
    document.addEventListener("visibilitychange", () => {
      cancelAnimationFrame(frame);
      if (!document.hidden) frame = requestAnimationFrame(draw);
    });
    addEventListener("pagehide", () => cancelAnimationFrame(frame), { once: true });
  }

  function copies() {
    $$('[data-copy-target]').forEach(button => button.addEventListener("click", async () => {
      const target = document.getElementById(button.dataset.copyTarget);
      if (!target) return;
      const value = target.innerText.trim();
      try {
        await navigator.clipboard.writeText(value);
      } catch (_) {
        const area = document.createElement("textarea");
        area.value = value;
        area.setAttribute("readonly", "");
        body.appendChild(area);
        area.select();
        document.execCommand("copy");
        area.remove();
      }
      toast(labels.copied);
    }));
  }

  function licenseFilter() {
    const input = $("#license-filter");
    const result = $("#license-result");
    if (!input || !result) return;
    const items = $$("[data-license]");
    const update = () => {
      const query = input.value.trim().toLocaleLowerCase(language);
      let visible = 0;
      items.forEach(item => {
        const matches = !query || item.textContent.toLocaleLowerCase(language).includes(query);
        item.hidden = !matches;
        if (matches) visible++;
      });
      result.textContent = labels.results(visible);
    };
    input.addEventListener("input", update);
    update();
  }

  theme();
  logos();
  scrollSystems();
  pointer();
  field();
  copies();
  licenseFilter();
})();
