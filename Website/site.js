"use strict";

// Progressive enhancement for the compact site navigation only.
(() => {
  const button = document.querySelector(".menu-toggle");
  const navigation = document.querySelector("#primary-navigation");
  if (!button || !navigation) return;

  const compact = window.matchMedia("(max-width: 780px)");
  const setOpen = (open) => {
    button.setAttribute("aria-expanded", String(open));
    navigation.dataset.collapsed = String(!open);
  };
  const syncLayout = () => setOpen(false);

  document.documentElement.classList.add("js");
  syncLayout();
  button.addEventListener("click", () => {
    setOpen(button.getAttribute("aria-expanded") !== "true");
  });
  navigation.addEventListener("click", (event) => {
    if (event.target.closest("a")) setOpen(false);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && button.getAttribute("aria-expanded") === "true") {
      setOpen(false);
      button.focus();
    }
  });
  compact.addEventListener("change", syncLayout);
})();
