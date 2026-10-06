# Vercel audit — 30-09-2026

Audit en lecture seule de l’équipe Vercel `Ahmet's projects`, puis publication ciblée du site
CoreTend. Aucun projet existant n’a été supprimé ni renommé.

## Site CoreTend

- Projet `coretend` (`prj_hwACffIdxpNjzM0QTa1IZy8cX4XH`), racine `.`, lié au dépôt GitHub
  `ahmetbsbnr/coretend`, branche de production `main`. Le domaine personnalisé
  `coretend.ahmetbsbnr.com` est associé à ce projet.
- Cause des pannes : des redirections `/en → /en/index` et `/fr → /fr/index` se combinaient
  avec `cleanUrls`, ce qui créait une boucle. Après suppression de ces redirections, les liens
  relatifs des pages EN/FR d’accueil perdaient leur préfixe de langue. Le générateur produit
  maintenant des liens root-relative (`/en/features`, `/fr/features`, etc.) et le contrôle
  statique vérifie le contrat.
- Déploiement production final : `dpl_65AVX5VgY33RUCB3rBRRK235h31t`, READY, aliasé explicitement
  vers le domaine personnalisé le 30-09. Le déploiement provient de `next` avec modifications
  locales (`gitDirty=1`) ; aucun push Git n’a été effectué.
- Routes testées après déploiement : racine, accueil et six pages EN/FR, avec et sans suffixe
  `index.html` : HTTP 200 ; une redirection canonique attendue de `index.html` vers `/en` ou
  `/fr`. 51 URL de même origine extraites des pages (liens et ressources) : aucune erreur.
- En-têtes publics observés : CSP sans script, `nosniff`, `no-referrer`, Permissions-Policy,
  HSTS et X-Frame-Options DENY.
- Vérifications locales : génération, 3 tests du contrat reduced-motion, `check_site.py` et
  `git diff --check` PASS.
- `.vercelignore` exclut les caches Swift de `.build` (dont des fichiers clairsemés de 25,7 Go),
  `Artifacts`, la documentation et les fichiers de clés/environnements du transfert Vercel.

## Projets de l’équipe observés

| Projet | Source/config observée | Domaine ou état | Conclusion |
|---|---|---|---|
| `coretend` | `ahmetbsbnr/coretend`, `main`, racine `.` | `coretend.ahmetbsbnr.com`, production READY | Site principal ; conserver. |
| `app` | Même dépôt CoreTend, `main`, racine `.` | Sans domaine personnalisé ; URL `app-flame-beta-71.vercel.app` sert le même choix de langue | Projet Vercel en double de CoreTend ; raison de sa création non établie. Pas supprimé. |
| `stagepilot` | Dépôt privé `ahmetbsbnr/stagepilot`, Next.js | `stage.ahmetbsbnr.com`, HTTP 200, titre StagePilot | Projet produit indépendant ; conserver. |
| `dash-stage` | Dépôt `ahmetbsbnr/dash-stage`, `main` | Aucun déploiement de production listé ; `dash-stage.ahmetbsbnr.com` renvoie HTTP 404 | Projet de staging sans livraison disponible ; ne pas supprimer sans confirmation. |
| `ahmetbsbnrportfolio` | Dépôt privé du portfolio, Next.js | `ahmetbsbnr.com`, HTTP 200 | Portfolio indépendant ; conserver. |
| `coretend-static-project.any8` | Configuration historique `python3 Website/build.py --output Website/dist` | Sans domaine personnalisé ; ancienne page CoreTend publique sous `*.vercel.app` | Ancien projet statique distinct du site courant ; ne pas supprimer sans confirmation. |

Les multiples URL de déploiement `coretend-*` pour des branches/commits sont des aperçus et
l’historique des déploiements, pas des projets ni domaines publics supplémentaires. Les projets
`app` et `coretend-static-project.any8` sont des doublons historiques possibles ; ils n’affectent
pas le domaine canonique. Leur suppression ou désactivation reste une décision de compte, pas
nécessaire à la réparation du site.

Le dépôt `ahmetbsbnr/ahmetbsbnr` visible sur le profil GitHub est le dépôt spécial du README de
profil, pas une autre source CoreTend. Sa description provisoire a été remplacée par
« GitHub profile README for Ahmet Basbunar » ; il n’a pas été supprimé.
