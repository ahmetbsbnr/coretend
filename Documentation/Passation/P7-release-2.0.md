# P7 — Sortie publique CoreTend 2.0

**Objectif :** CoreTend 2.0, nouvelle version de CoreTend (identifiant `com.ahmetbsbnr.coretend`,
version `2.0.0`), avec sa marque, son site entièrement refait et un dépôt retravaillé.
**Gate :** G7 — accord explicite du mainteneur avant chaque étape publique (fusion, tag,
release, site, cask).
**Statut :** En cours depuis le 28-09-2026.

## Décisions du mainteneur (28-09-2026)

- « le num de version sera 2.0 et sera juste une nouvelle version » → `2.0.0`, même identifiant
  que la 1.x.
- Logo SVG et icône depuis Icon Composer, Liquid Glass si faisable.
- Site recréé en entier, avec ses motions et animations.
- Dépôt retravaillé en entier.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 7.1 | Marque : icône Icon Composer (Liquid Glass) + logotypes SVG | Livré (`a23fcd99`) |
| 7.2 | Site 2.0 recréé (serre vivante, animations CSS, sans script) | Livré (`67bd00a3`) — captures 2.0 à refaire en 7.4 |
| 7.3 | Dépôt : README, changelog, gouvernance, workflows, cask | Livré (`dbad205a`) — workflows de release 1.x non repris (publication locale via Organizer) |
| 7.4 | Build 2.0.0 signé, notarisé, ZIP + DMG, SHA256SUMS, captures du site | Livré — DMG signé mais non notarisé (voir journal) |
| 7.5 | Publication (fusion, tag, release, site, cask) — sur accord | Livré le 28-09-2026 (fusion, tag, release, site, tap Homebrew) |

## Journal

### 28-09-2026 — 7.1

- `Resources/Brand/AppIcon.icon` : document Icon Composer (fond dégradé vert, calques SVG
  pousse et sol en verre, reflet, translucidité) compilé par `actool` dans le paquet
  (`Assets.car` Liquid Glass pour macOS 26+, `AppIcon.icns` pour 14–15).
- `Resources/Brand/Logo/` : symbole et logotype clair/sombre (SVG), icône rendue 1024 px (PNG).
- `make package-release` : identifiant `com.ahmetbsbnr.coretend`, version `2.0.0`, build 200.

### 28-09-2026 — 7.4

- Site : 32 captures 2.0 réelles (8 destinations × FR/EN × clair/sombre, 2240 × 1520) copiées de
  `Artifacts/Captures/2026-09-28/` après relecture ; `settings-bottom-*` retirées ; commit `5cbea3ab`.
- `make package-release` : `com.ahmetbsbnr.coretend` 2.0.0 (200). Signé par empreinte
  `02A57D6E…FAAB` (`--options runtime --timestamp`), archive manuelle
  `~/Library/Developer/Xcode/Archives/2026-09-28/CoreTend 2.0.0.xcarchive`.
- **Notarisation sans interface** (écran indisponible pour l'Organizer) :
  `xcodebuild -exportArchive` avec `method=developer-id`, `destination=upload`,
  `-allowProvisioningUpdates` (compte connecté dans Xcode, aucun mot de passe), puis
  `xcodebuild -exportNotarizedApp` dès l'acceptation. Soumission
  `2E6918E2-944D-4ED7-AA42-DD5532C569FB`, acceptée en ~1 min.
- Vérifié : `stapler validate` OK ; `spctl -a -vv` : accepted, `Notarized Developer ID` ;
  `codesign --verify --strict --deep` OK ; ZIP extrait puis revalidé (ticket agrafé présent).
- Artefacts dans `~/Documents/CoreTend-2.0.0/` :
  - `CoreTend-2.0.0-arm64.zip` — SHA-256 `3fd2548cf988fdecc0749f0c170764cccaf3541aa02c840c4e5c58adafcfefef` (**artefact principal**) ;
  - `CoreTend-2.0.0-arm64.dmg` — SHA-256 `b7e3c51c49a106ddfc864702269785cdcfe6874ff02f7ce8460d28f0467be79f`,
    signé Developer ID mais **non notarisé** (`spctl -t open` : Unnotarized) : notariser un DMG
    demande `notarytool`, que le mainteneur ne peut pas configurer ;
  - `SHA256SUMS`.
- Conséquence : cask, README et page Télécharger pointent sur le ZIP. `Scripts/make_release_dmg.sh`
  reste disponible pour un DMG notarisé plus tard.
- Non vérifié : VineSweep à l'écran et ouverture Gatekeeper d'un téléchargement réel
  (écran indisponible pour le contrôle).

### 28-09-2026 — 7.5 (accord du mainteneur : « commence une par une », puis « connecté, continue »)

- **Fusion :** `main` a avancé jusqu'à `b35180fb` (depuis `14d2daa8`, sans nouveau commit de fusion), une fois la CI `qualify`
  verte sur ce commit. Les 3 vérifications 1.x attendues par `main` ont été contournées (admin).
  Effet de bord : Vercel a déployé le site 2.0 en production (état « bientôt publiée »).
- **Tag :** `v2.0.0` annoté sur `b35180fb` (source du build notarisé).
- **Release :** https://github.com/ahmetbsbnr/coretend/releases/tag/v2.0.0 — `CoreTend-2.0.0-arm64.zip`
  + `SHA256SUMS`, notes `Documentation/Release/2.0-notes.md`, marquée latest ; DMG non joint
  (non notarisé). ZIP retéléchargé : même SHA-256.
- **Site :** `Website/release.json` publié (URL, SHA-256, date), cask rempli, CHANGELOG daté ;
  `62546f5d` sur `next` et `main` (CI verte), déployé par Vercel ; la page Télécharger en ligne
  montre le lien du ZIP et son SHA-256.
- La commande `brew install --cask coretend` n'est plus annoncée : aucun cask officiel
  (API Homebrew : 404) ni tap n'existe. La 1.x l'annonçait déjà à tort.

- **Homebrew** (accord : « validé, continue ») : le cask officiel est hors de portée (1 étoile,
  critères de notoriété). Tap public créé : https://github.com/ahmetbsbnr/homebrew-coretend
  (`Casks/coretend.rb`). `brew style` et `brew audit --cask --online --strict` : 0 ; retapé
  depuis GitHub, `brew fetch` : ZIP téléchargé, SHA-256 vérifié. Remarques corrigées : desc sans
  « Mac », ordre des stanzas, `depends_on macos: :sonoma`, `verified:` obsolète retiré. Pas
  d'installation d'essai : elle remplacerait l'app du mainteneur (même identifiant).
  Commande réannoncée : `brew install --cask ahmetbsbnr/coretend/coretend` (README, site).

## Point d'arrêt

- **P7 terminée : CoreTend 2.0.0 est publiée** (release GitHub, site, tap Homebrew).
- À chaque nouvelle version : `make package-release`, signature par empreinte, archive manuelle,
  `xcodebuild -exportArchive` (upload) puis `-exportNotarizedApp`, ZIP + `SHA256SUMS`, tag et
  release, `Website/release.json`, `homebrew/coretend.rb` recopié dans le tap.
- 28-09-2026 : tests visuels validés par le mainteneur (« tout les test visuel sont validé »).
- Suite : `Documentation/Project/Roadmap-2.x.md` — Q0 DMG notarisé (clé API App Store Connect
  à créer par le mainteneur ; `Scripts/make_release_dmg.sh --notary-profile` prêt), puis 2.0.1,
  2.1. Réserves ouvertes : macOS 14 et VoiceOver non testés sur un vrai Mac.

## Problèmes ouverts

- Le logotype utilise Iowan Old Style par nom de police : sur le web, prévoir une version avec
  le texte vectorisé (pas de police embarquée sous licence).
