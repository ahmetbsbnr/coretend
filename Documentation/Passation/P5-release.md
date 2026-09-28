# P5 — Release 2.0

**Objectif :** CoreTend 2.0 signée, notarisée, publiée et installable, `next` fusionnée dans `main`.
**Gate :** G5 — autorisation explicite du mainteneur à chaque étape irréversible.
**Statut de la phase :** À faire — G4 n’est pas passée. Ne pas commencer avant la gate précédente et une demande explicite du mainteneur.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 5.1 | Build signé, notarisé, agrafé ; ZIP/DMG, SHA-256, provenance | À faire |
| 5.2 | Notes de version FR/EN, site hors `noindex`, lien de téléchargement réel | À faire |
| 5.3 | PR `next` → `main` avec revue, tag `v2.0.0`, release GitHub, cask Homebrew | À faire |
| 1.x | Optionnel : 1.0.3 depuis `fix/1.x-trash-sqlite` | À décider |

## Journal

### 28-09-2026 — préparation sans étape irréversible

- Le mainteneur propose de tester sur un second Mac (M5, macOS 27) via TestFlight. **Impossible
  en l'état** : aucune identité de signature Apple sur l'hôte (`security find-identity` : 0),
  TestFlight exige compte Developer, App Store Connect et app signée/sandboxée (5.1). Voie
  retenue : ZIP local non signé par AirDrop, protocole
  `Documentation/Evidence/P4-42-second-mac-protocol.md` (SHA-256 consigné) — preuve 4.2 partielle.
- 5.2 préparé en brouillon : `Documentation/Release/2.0-notes-draft.md` (FR/EN), non publié.
- Rien de signé, tagué, publié, fusionné ni poussé.

### 28-09-2026 — 5.1 commencé : identité de signature et signature locale

- Compte Apple Developer du mainteneur connecté dans Xcode (équipe `NSCUV5G738`, Admin). À sa
  demande, l'agent a créé dans Xcode › Apple Accounts › Manage Certificates le certificat
  **Developer ID Application** ; `security find-identity` : 1 identité valide. Aucun
  identifiant saisi par l'agent.
- Signature locale d'une copie de `Artifacts/CoreTend.app` (`codesign --options runtime
  --timestamp`) : `codesign --verify --strict` valide ; `spctl` : `Unnotarized Developer ID`.
- **Manque pour finir 5.1 :** profil `notarytool` (`xcrun notarytool store-credentials
  coretend-notary …`, mot de passe d'app saisi par le mainteneur) et **son accord pour envoyer
  l'app à Apple** (notarisation), puis agrafage, ZIP/DMG, SHA-256.

### 28-09-2026 — notarisation envoyée (accord du mainteneur : « validé »)

- Le mainteneur ne peut pas créer de profil `notarytool`. Voie retenue : **Xcode Organizer**,
  qui notarise avec le compte déjà connecté, sans mot de passe d'app. L'app SwiftPM signée est
  placée dans une archive faite à la main
  (`~/Library/Developer/Xcode/Archives/2026-09-28/CoreTend 28-09-2026.xcarchive`, Info.plist
  `ApplicationProperties`), puis Distribute App › **Direct Distribution**.
- Envoi à 16:29 ; identifiant de soumission `7FB2F08D-1823-4324-9ED3-E7BD526588FD` ; statut
  « In Progress » au dernier relevé.
- **Reprendre par :** ouvrir Xcode › Window › Organizer › Archives › CoreTend : si « Ready to
  distribute », cliquer **Export Notarized App**, puis `xcrun stapler validate`, `spctl -a -vv`,
  ZIP (`ditto -c -k --keepParent`) et SHA-256, et le consigner ici. Version encore
  `0.1.0-local (1)`, identifiant `local.coretend.reconstruction` : build de test pour le second
  Mac, **pas la release 2.0** (5.3 exigera version et identifiant définitifs).

## Point d’arrêt

**Point d’arrêt actuel :** aucun lot P5 ouvert. Les travaux livrables P4 sont consignés ; G4
reste ouverte (voir `P4-qualification.md` et sa table « Preuves restantes »). Ne préparer
aucune étape P5 tant que cette gate n’est pas passée. La branche `next` n’a pas été poussée
depuis le HEAD distant `1f62627e` : six commits P4 locaux puis trois commits documentaires de clôture.

Identifiants de signature hors dépôt, jamais lus ni affichés. Chaque étape irréversible (push,
tag, publication, fusion ou push vers `main`) attend une autorisation explicite du mainteneur.

## Problèmes ouverts

G4 et autorisation explicite de commencer P5 sont les préalables. Hôtes et preuves manquants
sont listés dans le journal P4 ; ils ne constituent pas une autorisation de les simuler.
