# Setapp — dossier de candidature

**État au 07-10-2026 :** prêt à soumettre côté technique ; la candidature et le compte développeur
Setapp sont à faire par le mainteneur (portail développeur Setapp, contrat MacPaw).

Le plan (décision 0005) classait Setapp « à étudier après le lancement », sans compromettre la
gratuité du site. Setapp distribue des apps gratuites ailleurs : la version du site reste gratuite.

## Exigences Setapp et état de CoreTend

| Exigence (documentation Setapp) | CoreTend 2.2 |
|---|---|
| Signée Developer ID et notarisée | Oui (équipe NSCUV5G738) |
| Binaire universel `arm64` + `x86_64` | Oui depuis 2.2 |
| Testée sur la dernière version de macOS | Oui (macOS 27, Apple silicon) |
| Aucune fonction payante, aucun achat intégré, aucune activation ou licence | Oui : tout est gratuit |
| Pas de mécanisme de mise à jour propre (Setapp met à jour) | À faire dans la build Setapp : sans Sparkle (`CORETEND_SPARKLE=0` retire déjà le flux et la clé) |
| Identifiant avec le suffixe `-setapp` | À faire : `com.ahmetbsbnr.coretend-setapp` |
| Setapp Framework et `setappPublicKey.pem` (clé propre à l'app, téléchargée dans le compte développeur) | À faire après acceptation ; le framework est un binaire de MacPaw |

## Ce que la build Setapp changerait

- Identifiant `com.ahmetbsbnr.coretend-setapp`, sans Sparkle, avec le Setapp Framework et la clé
  publique dans `Contents/Resources`.
- Le Setapp Framework serait la deuxième dépendance d'exécution : elle doit être justifiée dans le
  README et ne viser que cette build (cible séparée), pas la version du site.
- Le helper système et le groupe d'apps garderaient leurs identifiants : à vérifier avec l'équipe
  de revue Setapp (une app `-setapp` porte un autre identifiant que celui exigé par le helper).

## Étapes pour le mainteneur

1. Créer le compte développeur Setapp et proposer CoreTend (description, captures du site, lien
   GitHub, mention « gratuit et open source ailleurs »).
2. Après acceptation : télécharger `setappPublicKey.pem` (Developer Account › Apps › Add new
   version) et le transmettre pour la build `-setapp`.
3. Soumettre la build pour revue depuis le portail.

## Points à faire trancher

- Revenu Setapp contre image « gratuit » : la version du site reste identique et gratuite.
- Une dépendance propriétaire dans une build d'un projet Apache 2.0 : la garder hors de `main`
  (branche ou cible séparée).

Sources : documentation Setapp (exigences techniques macOS, identifiant `-setapp`, clé publique),
consultée le 07-10-2026.
