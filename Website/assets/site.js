/* CoreTend — site behaviour.
   Mirrors the portfolio's motion system without shipping GSAP: the same
   reveal geometry (28px rise, 720ms, out-expo, fires once near the bottom
   of the viewport), the same magnetic pointer follow on primary calls to
   action, and the same overlay menu behaviour. Everything degrades to
   plain, fully visible content when JavaScript or motion is unavailable. */
(function () {
  "use strict";

  document.documentElement.classList.remove("no-js");

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)");

  /* ------------------------------------------------------------- reveal */
  var revealables = document.querySelectorAll("[data-reveal]");

  if (!("IntersectionObserver" in window) || reduced.matches) {
    Array.prototype.forEach.call(revealables, function (el) {
      el.classList.add("in");
    });
  } else {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          // Stagger siblings the way the portfolio's Reveal delay prop does.
          var delay = parseFloat(el.getAttribute("data-reveal-delay") || "0");
          if (delay > 0) el.style.transitionDelay = delay + "ms";
          el.classList.add("in");
          observer.unobserve(el);
        });
      },
      // "top 88%" in ScrollTrigger terms: fire once the element's top has
      // risen past 88% of the viewport height.
      { rootMargin: "0px 0px -12% 0px", threshold: 0 }
    );
    Array.prototype.forEach.call(revealables, function (el) {
      observer.observe(el);
    });
  }

  /* ----------------------------------------------------------- magnetic */
  if (!reduced.matches && window.matchMedia("(hover: hover)").matches) {
    Array.prototype.forEach.call(
      document.querySelectorAll("[data-magnetic]"),
      function (el) {
        var strength = 0.25;
        var raf = null;
        var tx = 0;
        var ty = 0;
        var cx = 0;
        var cy = 0;

        function tick() {
          // Eased settle towards the target: visually the same landing as
          // gsap.quickTo(duration 0.45, power3.out).
          cx += (tx - cx) * 0.18;
          cy += (ty - cy) * 0.18;
          el.style.transform =
            "translate(" + cx.toFixed(2) + "px," + cy.toFixed(2) + "px)";
          if (Math.abs(tx - cx) > 0.1 || Math.abs(ty - cy) > 0.1) {
            raf = requestAnimationFrame(tick);
          } else {
            el.style.transform = "translate(" + tx + "px," + ty + "px)";
            raf = null;
          }
        }
        function start() {
          if (raf === null) raf = requestAnimationFrame(tick);
        }
        el.addEventListener("pointermove", function (e) {
          var r = el.getBoundingClientRect();
          tx = (e.clientX - r.left - r.width / 2) * strength;
          ty = (e.clientY - r.top - r.height / 2) * strength;
          start();
        });
        el.addEventListener("pointerleave", function () {
          tx = 0;
          ty = 0;
          start();
        });
      }
    );
  }

  /* -------------------------------------------------------- mobile menu */
  var toggle = document.querySelector(".nav-toggle");
  var menu = document.querySelector(".mobile-menu");
  var closeBtn = document.querySelector(".mobile-menu-close");

  function setMenu(open) {
    if (!menu || !toggle) return;
    menu.setAttribute("data-open", open ? "true" : "false");
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    document.body.style.overflow = open ? "hidden" : "";
    if (open) {
      var first = menu.querySelector("a, button");
      if (first) first.focus();
    } else {
      toggle.focus();
    }
  }

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      setMenu(menu.getAttribute("data-open") !== "true");
    });
    if (closeBtn) {
      closeBtn.addEventListener("click", function () {
        setMenu(false);
      });
    }
    menu.addEventListener("click", function (e) {
      if (e.target.closest("a")) setMenu(false);
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && menu.getAttribute("data-open") === "true") {
        setMenu(false);
      }
    });
  }

  /* ------------------------------------------------------- product loop */
  /* Autoplay is a request, not a guarantee: Safari refuses it under Low
     Power Mode and some data-saver setups. When the promise rejects the
     poster frame simply stays put — no play button is ever drawn over it,
     and nothing shifts. */
  Array.prototype.forEach.call(
    document.querySelectorAll("video[data-loop]"),
    function (video) {
      video.muted = true;
      video.defaultMuted = true;
      video.playsInline = true;
      if (reduced.matches) {
        video.removeAttribute("autoplay");
        video.pause();
        return;
      }
      var attempt = video.play();
      if (attempt && typeof attempt.catch === "function") {
        attempt.catch(function () {
          /* Poster remains; deliberately silent. */
        });
      }
      // Pause off-screen loops so they cost nothing while not visible.
      if ("IntersectionObserver" in window) {
        new IntersectionObserver(
          function (entries) {
            entries.forEach(function (entry) {
              if (entry.isIntersecting) {
                var p = video.play();
                if (p && typeof p.catch === "function") p.catch(function () {});
              } else {
                video.pause();
              }
            });
          },
          { threshold: 0.15 }
        ).observe(video);
      }
    }
  );
})();
