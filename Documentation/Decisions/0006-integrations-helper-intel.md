# 0006 — Intégrations, helper système et Mac Intel

**Date :** 07-10-2026 · **Statut :** acceptée par le mainteneur · **Complète :** 0005

## Décision

CoreTend 2.2 ouvre l'app au reste du Mac et à tous les Mac :

- **Mac Intel** : un seul binaire universel (Apple silicon et Intel), macOS 14 ou plus récent.
  Les fichiers de release s'appellent `CoreTend-<version>-universal.{dmg,zip}`.
- **Raccourcis et Siri** : trois actions App Intents, toutes en lecture (« Obtenir l'espace
  libre », « Obtenir l'espace à libérer », « Ouvrir CoreTend »). Aucune ne déplace un fichier :
  nettoyer reste une revue dans l'app.
- **Widget** (WidgetKit, sandboxé) : espace libre du volume et total de la dernière analyse
  Nettoyer, partagé par le groupe d'apps `NSCUV5G738.com.ahmetbsbnr.coretend` (un nombre et une
  date, jamais un chemin).
- **Finder** (extension Finder Sync, sandboxée) : « Analyser avec CoreTend » sur un dossier. Elle
  ne lit rien et ne déplace rien ; elle passe le chemin à l'app par `coretend://scan`.
- **Dock** : un dossier déposé sur l'icône ouvre sa carte.
- **Helper système optionnel** : un démon launchd (`SMAppService`), installé seulement quand la
  personne l'active dans Réglages › Système, et retiré quand elle le désactive. Il répond par XPC,
  uniquement à CoreTend signé par l'équipe `NSCUV5G738` (exigence de signature vérifiée par le
  système), et uniquement à cette liste :
  1. lister les caches de `/Library/Caches` (sauf ceux d'Apple) avec leur taille ;
  2. mettre l'un d'eux dans la Corbeille de la personne qui demande (`SafetyCore.SystemCacheTrasher`
     : un `renameatx_np` sans écrasement entre deux dossiers ouverts sans suivre les liens) ;
  3. le remettre en place (`TrashRestorer`) ;
  4. lister les services tiers de `/Library/LaunchDaemons` ;
  5. les désactiver ou réactiver (`launchctl disable|enable system/<label>`), sans toucher à leur
     fichier.
  Chaque demande est vérifiée contre ce que le helper liste lui-même : l'app ne peut nommer ni un
  chemin ni un label arbitraire.

## Ce qui ne change pas

- Tout part à la Corbeille, jamais d'effacement définitif. Pour cette raison, CoreTend n'efface pas
  les instantanés locaux Time Machine (`tmutil thinlocalsnapshots` les supprimerait pour de bon) ;
  macOS les réduit déjà seul quand l'espace manque.
- Aucune télémétrie, aucun réseau ajouté : les extensions et le helper n'ouvrent aucune connexion.
- Rien ne se déplace sans revue et confirmation, y compris par le helper.

## Garde-fous vérifiés par `make qualify`

- `Scripts/audit_safety.py` : le seul déplacement du helper est celui de `SystemCacheTrasher`
  (gardes exigées) ; le seul programme lancé est `/bin/launchctl`, depuis
  `Sources/CoreTendHelper/Launchctl.swift`.
- Tests : `SystemCacheTrasherTests` (caches Apple, liens, éléments profonds, Corbeille d'un autre
  propriétaire ou remplacée par un lien, jamais d'écrasement), `HelperProtocolTests`,
  `ExternalLinkTests`.

## Limites connues

- Le widget, l'extension Finder et le helper n'existent que dans la version publiée (signée) ; un
  paquet local non signé n'a ni groupe d'apps ni démon.
- Vider la Corbeille après avoir rangé un cache système demande le mot de passe administrateur
  (l'élément reste à root).
- Testé sur un Mac Apple silicon (macOS 27) ; aucun Mac Intel physique n'a été essayé.
