# CoreTend Next — reconstruction ouverte

**État : aperçu local non publié.** Cette branche prépare la prochaine version du projet public [CoreTend](https://github.com/ahmetbsbnr/coretend). La version publique 1.x et ses tags restent sur `main`. Aucun binaire, signature, notarisation ou release de cette reconstruction n’est annoncé.

## Ce qui tourne déjà

- Application macOS SwiftUI, navigation des huit destinations et préférence de langue EN/FR. Overview et Performance lisent des mesures système datées; aucune note santé ni extrapolation.
- Explore : lecture seule d’un dossier choisi explicitement.
- Doublons : SHA-256 progressif, exclusion des hard links, exemplaire à garder et revue des copies sélectionnées avant Corbeille. Images similaires : paires consultatives heuristiques, sans action.
- SafetyCore : approbation limitée dans le temps, revalidation de chemin/volume/identité et API Trash macOS unique. Échec sans fallback destructif.
- SQLite local versionné; écran Record filtre, exporte CSV/JSON et efface l’historique après confirmation. Son chemin greenfield `CoreTend-Reconstruction/records.sqlite` ne réutilise pas l’ancien store. CLI ouvre un store explicitement indiqué en lecture seule.
- CLI lecture seule; scan avec `--root` obligatoire, historique avec `--store` obligatoire.
- Cahier QQOQCCP, MoSCoW, RACI, baseline, plan d’exécution, traçabilité et site statique EN/FR.

Applications inventorie les bundles d’un dossier choisi, permet le déplacement confirmé du seul bundle choisi vers la Corbeille, présente des noms de fichiers associés à titre consultatif et affiche un éventuel flux HTTPS déclaré sans vérifier les versions. Les données associées et héritées restent en place. Les autres vues restent incomplètes. Consultez `Documentation/Traceability.csv` avant toute hypothèse de parité.

## Construire et vérifier

Requis : Swift 6, macOS 14 ou ultérieur.

```sh
make qualify
swift run CoreTendCLI help
```

Les tests utilisent des dossiers temporaires synthétiques. Ils ne lisent ni store CoreTend ni Corbeille réelle.

## Projet et contributions

- [Cahier des charges](Documentation/Project/Cahier-des-charges.md), [stratégie du dépôt](Documentation/Project/Repository-strategy.md), [passation courante](passation.md) et [traçabilité](Documentation/Traceability.csv).
- [Contribuer](CONTRIBUTING.md), [sécurité](SECURITY.md), [licences](Documentation/LICENSING.md).

## Limites actuelles

Cleanup, Doublons et le bundle Applications ont des parcours de revue/Corbeille, l’historique est relié aux actions, la migration d’un format synthétique reconnu est disponible et un ZIP local non signé se construit. Attribution sûre des reliquats, désinstallation complète des composants liés, qualification native d’accessibilité et distribution signée restent ouvertes. Rien de cette reconstruction n’est publié.
