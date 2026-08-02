(() => {
  "use strict";

  const root = document.documentElement;
  const system = window.matchMedia("(prefers-color-scheme: dark)");
  const allowed = new Set(["system", "light", "dark"]);

  root.classList.add("js");

  let mode = "system";
  try {
    const saved = localStorage.getItem("coretend-theme");
    if (allowed.has(saved)) mode = saved;
  } catch (_) {}

  const apply = () => {
    root.dataset.themeMode = mode;
    root.dataset.theme = mode === "system" ? (system.matches ? "dark" : "light") : mode;
  };

  apply();
  system.addEventListener?.("change", () => {
    if (root.dataset.themeMode === "system") apply();
  });

  window.CoreTendTheme = {
    get mode() { return mode; },
    set(next) {
      mode = allowed.has(next) ? next : "system";
      try { localStorage.setItem("coretend-theme", mode); } catch (_) {}
      apply();
      return mode;
    },
    apply,
  };

  if (root.dataset.build === "public" && location.pathname === "/") {
    let savedLanguage = null;
    try { savedLanguage = localStorage.getItem("coretend-language"); } catch (_) {}
    const preferredLanguage = savedLanguage === "en" || savedLanguage === "fr"
      ? savedLanguage
      : (navigator.languages || [navigator.language || "en"])
          .some(language => String(language).toLowerCase().startsWith("fr")) ? "fr" : "en";
    location.replace(`/${preferredLanguage}${location.hash || ""}`);
  }
})();
