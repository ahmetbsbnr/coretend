# CoreTend 2.2 — kit de lancement

Textes prêts à publier, en anglais et en français. **Rien n'est publié automatiquement** : chaque
publication se fait depuis le compte du mainteneur. Règles du plan : pas de chiffre inventé, pas
de peur, un exemple chiffré est daté et dit que c'est un exemple.

Faits vérifiables à citer : gratuit, Apache 2.0, signé Developer ID et notarisé, universel (Apple
silicon et Intel), macOS 14+, aucune télémétrie, tout passe par la Corbeille avec Annuler.
Exemple réel : sur le Mac de test le 06-10-2026, Nettoyer a trouvé 7,11 Go (exemple, pas une
promesse).

Liens : site https://coretend.ahmetbsbnr.com · GitHub https://github.com/ahmetbsbnr/coretend ·
Homebrew `brew install --cask ahmetbsbnr/coretend/coretend` · npm `npx -y coretend mcp`.

## Calendrier (plan « Lancement », 2 semaines)

| Jour | Action |
|---|---|
| J-7 | Kit presse en ligne (`/en/press`, `/fr/press`), captures à jour, vidéo de 60 s |
| J0, mardi ~15 h (heure de Paris) | Show HN, Product Hunt, Reddit r/macapps ; répondre en direct |
| J0 | X / Bluesky, LinkedIn (FR) |
| J+1 | Pitch presse FR (MacGeneration, iGeneration, Mac4Ever, Numerama) et EN (9to5Mac, MacStories) |
| J+1 à J+7 | Répondre à chaque commentaire ; corriger vite ; publier une 2.2.x visible |
| J+14 | Bilan public : téléchargements GitHub, étoiles, retours (statistiques publiques seulement) |

---

## Show HN (EN)

**Title:** Show HN: CoreTend – a free, open-source Mac cleaner that only uses the Trash

**Text:**

I built CoreTend because every Mac "cleaner" I tried either scared me ("your Mac is slow!") or
deleted things I could not get back.

CoreTend shows what fills your disk and lets you clear it, with three rules it never breaks:
everything goes to the macOS Trash (and Undo puts it back), nothing moves without a review, and
there is no telemetry or account.

What it does:
- A map of your whole home folder (Full Disk Access is asked once, never required).
- Clean reads 14 rules at once: app caches and logs, Xcode build files, simulators, npm, pnpm,
  Gradle, Cargo, Mail attachments, iPhone backups — grouped by risk.
- Complete uninstall: the app and the files it left, each with the evidence that ties it to the app.
- A CLI and a read-only MCP server, so you can ask Claude or Cursor what fills your disk
  (`npx -y coretend mcp`).
- 2.2 adds Intel Macs, a widget, Shortcuts actions, a Finder menu, and an optional signed helper
  for /Library/Caches and system services (fixed list of requests, still Trash only).

Swift 6 / SwiftUI, Apache 2.0, one dependency (Sparkle for signed updates). The only file-moving
code lives in one module, and the CI audits that.

I'd love feedback, especially on what it should never touch.

https://github.com/ahmetbsbnr/coretend

## Product Hunt (EN)

- **Name:** CoreTend
- **Tagline (≤ 60):** See what fills your Mac. Clear it safely — to the Trash.
- **Description (≤ 260):** A free, open-source Mac storage app. Map your whole disk, clean caches
  and developer files in one review, uninstall apps completely. Everything goes to the Trash with
  Undo. No telemetry, no account. Apple silicon and Intel.
- **Topics:** Mac, Productivity, Developer Tools, Open Source
- **First comment:** Hi! I made CoreTend because cleaners either scare you or delete for good.
  CoreTend shows, explains and lets you decide; everything is recoverable from the Trash. New in
  2.2: Intel support, a widget, Shortcuts, a Finder menu and an MCP server for AI assistants.
  What should a cleaner never touch? I'd love to hear it.

## Reddit r/macapps (EN)

**Title:** [Free, open source] CoreTend 2.2 — see what fills your Mac and clear it to the Trash, with Undo

I make CoreTend, a free (Apache 2.0) storage app for macOS 14+, now universal (Apple silicon and
Intel). Map your disk, clean caches and dev files in one review, uninstall apps with their
leftovers. Everything goes to the Trash; Undo puts it back. No telemetry, no account, signed and
notarized. New: widget, Shortcuts actions, Finder « Analyze with CoreTend ».
Site: https://coretend.ahmetbsbnr.com — feedback welcome, especially what it got wrong.

## X / Bluesky (EN)

1. CoreTend 2.2 is out: see what fills your Mac, clear it safely. Free, open source, now on Intel
   Macs too. Everything goes to the Trash, with Undo. https://coretend.ahmetbsbnr.com
2. New: a widget, Shortcuts actions, « Analyze with CoreTend » in the Finder, and an optional signed
   helper for /Library/Caches.
3. For developers: Xcode, simulators, npm, pnpm, Gradle, Cargo in one review — and
   `npx -y coretend mcp` to ask your AI assistant what fills your disk.

---

## LinkedIn (FR)

CoreTend 2.2 est sorti. C'est une app Mac gratuite et open source qui montre ce qui remplit le
disque et le libère sans risque : tout part à la Corbeille, et « Annuler » remet tout en place.
Aucune télémétrie, aucun compte.

Nouveau : les Mac Intel (app universelle), un widget, des actions Raccourcis, « Analyser avec
CoreTend » dans le Finder, et un assistant système optionnel pour les caches de /Library/Caches.

Swift 6, SwiftUI, Apache 2.0. Conçue et construite avec Claude, sous ma supervision.
https://coretend.ahmetbsbnr.com

## Pitch presse (FR) — objet et corps

**Objet :** CoreTend 2.2, un nettoyeur Mac gratuit qui ne supprime rien pour de bon

Bonjour,

CoreTend est une app Mac gratuite et open source (Apache 2.0) qui montre ce qui remplit le disque
et le libère sans risque : tout passe par la Corbeille, avec un vrai « Annuler ». Pas de score
alarmiste, pas de télémétrie, pas de compte.

La version 2.2, sortie le 7 octobre, devient universelle (Apple silicon et Intel) et ajoute un
widget, des actions Raccourcis, un menu Finder et un assistant système optionnel. Elle est signée
et notarisée par Apple, disponible sur le site, GitHub et Homebrew.

Kit presse (logo, captures, textes) : https://coretend.ahmetbsbnr.com/fr/press
Je reste disponible pour une démo ou des questions.

Ahmet Basbunar — contact@ahmetbsbnr.com

## Press pitch (EN) — subject and body

**Subject:** CoreTend 2.2 — a free Mac cleaner that never deletes for good

Hi,

CoreTend is a free, open-source (Apache 2.0) Mac app that shows what fills the disk and clears it
safely: everything goes through the Trash, with a real Undo. No scare score, no telemetry, no
account.

Version 2.2 (October 7) is universal (Apple silicon and Intel) and adds a widget, Shortcuts
actions, a Finder menu and an optional system helper. Signed and notarized; on the website,
GitHub and Homebrew.

Press kit (logo, screenshots, copy): https://coretend.ahmetbsbnr.com/en/press

Ahmet Basbunar — contact@ahmetbsbnr.com

## Annuaires (plan, priorité 2–3)

- Registres MCP : fiche du serveur `coretend mcp` (npm `coretend`), outils en lecture seule.
- Homebrew officiel (`homebrew/cask`) dès que le dépôt atteint les critères de notoriété.
- MacUpdate, Softpedia, AlternativeTo : fiches qui pointent vers le site.
