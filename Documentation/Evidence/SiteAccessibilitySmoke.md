# Site browser accessibility smoke

**Date:** 2026-09-27
**Host:** local Chrome DevTools, macOS 27.0
**Scope:** generated local `Website/` routes, EN/FR, loopback HTTP only. This is automated browser evidence, not human accessibility sign-off or release qualification.

## Observed

- Lighthouse mobile navigation audit reran after the site restyle and meta-description change on all 11 pages: language chooser, five English pages, and five French pages. Every page scored Accessibility 100, Best Practices 100, and Agentic Browsing 100; SEO scored 60. Each content route passed 42 audits; language chooser passed 35. Generated pages carry a non-empty meta description, enforced by `Scripts/check_site.py`.
- Current local Chrome emulation checked all ten EN/FR content pages at both 640 × 900 and 320 × 800 CSS pixels, device scale factor 1. Each page loaded the expected document language, had a non-empty meta description and document/body scroll width equal to the viewport at both widths. No horizontal overflow observed. These are emulated viewport checks, not browser zoom or Dynamic Type evidence.
- On each of those ten pages, first Tab focused the localized skip link; its `#main` target existed and focus outline was solid 3 px.
- `Website/site.css` contains a `prefers-reduced-motion: reduce` rule that disables smooth scrolling and reduces animation/transition duration.
- `make site-check` now tests that contract: the media query must disable smooth scrolling and set minimal animation/transition durations with `!important`; fixtures reject a missing query or protection.

## Limits

- Browser viewport width is only a proxy for 200% zoom. Actual browser zoom, operating-system text scaling, contrast in all states, and screen-reader use were not verified. The current DevTools viewport emulation held the CSS width fixed despite browser-zoom shortcuts.
- Reduced-motion CSS was not runtime-emulated; the available Chrome DevTools interface does not expose media-preference emulation. Deployed headers, another browser, and public release behavior remain untested.
- FR-15 is `VÉRIFIÉ` for scoped static bilingual content and generated-site checks. Browser/OS accessibility and deployment checks remain open under NFR-11/NFR-14. SEO 60 does not change publication status: preview intentionally remains `noindex,nofollow`.


## P4 — lot 4.5 — 28-09-2026

Base `644c1eab`, macOS 27.0 (26A428), Chrome **154.0.8037.57**, second moteur WebKit
via WKWebView natif (stockage `.nonPersistent()`, HOME/CFFIXED_USER_HOME/TMPDIR temporaires).
Ni le profil Chrome habituel ni le profil Safari n’ont été utilisés. Aucun réglage hôte changé.

- `make build-site site-check` : PASS. Menu étroit toujours visible, sans bouton de masquage
  ni JavaScript : solution Serre livrée et acceptée conservée.
- **Chrome : 20 PASS**, dix pages FR/EN × clair/sombre, zoom navigateur réel 200 % dans
  un profil temporaire. Zoom réglé par `chrome.settingsPrivate.setDefaultZoom` depuis la page
  interne des réglages, pas par viewport simulé, pinch ni CSS `zoom`.
  Source API : https://chromium.googlesource.com/chromium/src/+/main/chrome/common/extensions/api/settings_private.idl
  Fenêtre 1280 px inchangée ; viewport 1280 → 640, DPR 1 → 2. Chargement fichier local,
  car navigation Chrome vers HTTP loopback a expiré lors du premier essai.
- Premier Tab avant défilement atteint `#main` avec contour visible. Langues correctes,
  toutes images chargées après défilement vers chaque image lazy, aucun script, aucun
  débordement horizontal ; Reduce Motion **émulé** : animation logo `0s`.
- **WebKit : 40 PASS**, mêmes dix pages × clair/sombre × `WKWebView.pageZoom` 1 et 2.
  Navigation HTTP loopback ; viewport 1280/640, images chargées après défilement,
  couleurs réellement distinguées par `prefers-color-scheme`, scripts 0, pas de débordement.
  Cela qualifie un second moteur ; le shell complet Safari et sa navigation clavier ne sont
  pas assimilés à ce WKWebView. Aucun VoiceOver parlé exercé.
- Captures Chrome à 200 % FR/EN clair/sombre ouvertes et relues :
  `Artifacts/SiteReview/P4-45/chrome-{fr,en}-{light,dark}-zoom200.png`. Les captures montrent
  le premier focus et le menu, pas toutes les pages à toutes les positions de scroll.
- Données brutes : `P4-45-chrome-2026-09-28.json` et `P4-45-webkit-2026-09-28.json`.
  Sondes temporaires : `/tmp/coretend-p4-45-chrome.py`, `/tmp/coretend-p4-webkit.swift`,
  `/tmp/coretend-p4-45-webkit.py` ; log `/tmp/coretend-p4-45-webkit.log`.
  Premiers essais non retenus : HTTP Chrome timeout ; images lazy non encore chargées ;
  premier Tab mesuré après défilement (point de départ clavier déplacé). Sondes corrigées,
  aucune modification produit requise.

### En-têtes publics observés

URL déclarée par le dépôt GitHub : `https://coretend.ahmetbsbnr.com`.
`curl -sIL https://coretend.ahmetbsbnr.com/fr` : HTTP 200 le 28-09-2026, CSP,
`nosniff`, Referrer-Policy `no-referrer`, Permissions-Policy, HSTS et X-Frame-Options DENY
présents. CSP publique autorise les scripts self ; CSP locale Next exige `script-src 'none'`.
Last-Modified public : 25-09-2026 ; HTML 44 798 octets, SHA-256
`ab4f93de8e47965646bd548324114f2b049b3c8af9609c3e05db9320d433860b`, titre
« CoreTend — Voyez ce que votre Mac conserve ». **Ce site public antérieur ne prouve pas
le déploiement de Website Next.** Aucun déploiement entrepris ; recontrôler les en-têtes
sur l’artefact Next réellement publié lors de P5.

NFR-11 reste PARTIEL : VoiceOver parlé, shell Safari complet et déploiement Next ouverts.
Les contrôles locaux de zoom et les deux moteurs sont réalisés ; aucun statut du registre promu.

`make qualify` final 4.5 PASS, code 0 (`/tmp/coretend-p4-45-qualify.log`) ;
`git diff --check` PASS. Aucun code site modifié pour obtenir ces preuves.
