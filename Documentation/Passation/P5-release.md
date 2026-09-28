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

_(une entrée datée par lot : commits, vérifications PASS/FAIL/NON LANCÉ, résultat de recette)_

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
