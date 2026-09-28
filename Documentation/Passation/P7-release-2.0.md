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
| 7.4 | Build 2.0.0 signé, notarisé, DMG, SHA256SUMS | À faire |
| 7.5 | Publication (PR, tag, release, site, cask) — sur accord | À faire |

## Journal

### 28-09-2026 — 7.1

- `Resources/Brand/AppIcon.icon` : document Icon Composer (fond dégradé vert, calques SVG
  pousse et sol en verre, reflet, translucidité) compilé par `actool` dans le paquet
  (`Assets.car` Liquid Glass pour macOS 26+, `AppIcon.icns` pour 14–15).
- `Resources/Brand/Logo/` : symbole et logotype clair/sombre (SVG), icône rendue 1024 px (PNG).
- `make package-release` : identifiant `com.ahmetbsbnr.coretend`, version `2.0.0`, build 200.

## Point d'arrêt

- 7.1, 7.2 livrés. Suite **7.3 dépôt** : README 2.0, CHANGELOG, workflows (réconcilier ceux de `main`), cask 2.0.0, gouvernance.
- 7.4 : `make package-release`, signature, notarisation (Organizer), DMG, SHA256SUMS, nouvelles captures du site, `Website/release.json` rempli.

## Problèmes ouverts

- Le logotype utilise Iowan Old Style par nom de police : sur le web, prévoir une version avec
  le texte vectorisé (pas de police embarquée sous licence).
