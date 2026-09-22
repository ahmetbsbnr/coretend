<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend 2.0 — plan directeur

Déduit du rapport de projet du 22 septembre 2026 (`CoreTend 2.0 — rapport de
projet`, 19 pages) et recoupé avec l'état mesuré du dépôt. Ce document est
**décidé**, pas dérivé : il cesse d'être ce qu'on veut, jamais de décrire ce
qui est. Il se relit et se corrige à la revue, il n'a pas de garde `--check`.

État à la rédaction : version publiée **1.0.2** (Developer ID, notarisée) ;
chantier **`develop/v2`**, PRE-ALPHA, 241 commits d'avance sur `main`.

---

## 0. La prémisse

Le rapport mesure deux files de tâches :

| File | Fermées | Ouvertes | Partielles | Bloquées | Taux |
|---|---|---|---|---|---|
| `CORETEND_VNEXT_TASKS.md` — exécution | 84 | 9 | 3 | 3 | **87 %** |
| `docs/CORETEND_V2_TODO.md` — programme | 8 | 24 | 2 | 4 | **21 %** |

L'écart n'est pas une contradiction, c'est le diagnostic. Le travail fait est
du travail de fond — correction, gardes, outillage, structure. Le travail qui
reste est celui de la **différence visible**.

La conséquence, et c'est la seule règle d'ordonnancement de ce plan :

> Aucun lot de fond ne passe avant le lot 1, sauf s'il est strictement
> parallélisable en fichiers.

Ce que la 2.0 a déjà, et qui tient : dix modules d'interface répondant et
couverts par des tests d'interface et d'accessibilité ; 110 fichiers source
(22 588 lignes) pour 78 fichiers de test (11 488 lignes) et 700 tests verts ;
un build release sans avertissement ; trois langues complètes à 702 clés ; un
site à 32 contrôles dont Axe WCAG A et AA ; une chaîne de release automatisée
qui vérifie les octets retéléchargés.

Ce qui manque est nommé sans détour par le rapport : **la différence
générationnelle n'est pas là**. Un utilisateur de 1.0.1 qui ouvrirait la 2.0
verrait une application mieux construite — pas une application manifestement
nouvelle.

---

## 1. Lot 0 — Débloquer

Trois décisions bloquent du travail déjà spécifié. Aucune n'est technique ;
aucune ne peut être prise par une passe de code. Tant que **0.3** n'est pas
rendu, le lot 1 n'a pas de critère d'arrêt — c'est pourquoi le lot 0 est
premier même s'il ne produit pas une ligne.

### 0.1 — P-01 · Qu'est-ce que le produit sandboxé ?

Le build App Store perd **Nettoyage, Apps et Intégrité** : cinq destinations
sur huit tombent. Trois issues exclusives, à trancher par écrit :

- **(a) Bac à sable élargi par portées choisies par l'utilisateur.** C'est la
  recommandation du programme : Nettoyage fonctionne sur les dossiers
  accordés. Apps et Intégrité ne peuvent pas suivre — ils lisent ce que
  macOS enregistre hors portée. Le build reste amputé et doit être nommé
  honnêtement pour ce qu'il est.
- **(b) Abandon formel du canal App Store.** Issue valable. Elle libère
  définitivement le lot 4 et retire une ambiguïté du site.
- **(c) Produit distinct.** Un autre nom, un autre périmètre annoncé. Le
  rapport est explicite : « ce n'est pas une variante, c'est un autre
  produit ».

Bloque **tout le lot 4**. Sans réponse, le lot 4 ne figure dans aucun jalon.

### 0.2 — M-05 · Le routage au survol

Seul le trackpad du mainteneur tranche. Aucune capture, aucun test ne
remplace la main sur le matériel. Forme : une session courte, un verdict
écrit, classé avec les décisions.

### 0.3 — M-06 · Le verdict sur la différence générationnelle

Le plus important des trois : il fixe la barre d'arrêt du lot 1.

Forme imposée, pour qu'il soit un backlog et pas une impression : ouvrir
**1.0.1** et **`develop/v2`** côte à côte, module par module, et écrire pour
chacun **oui / non** à la question exacte de `CLAUDE.md` — « différence
visible au premier coup d'œil, sans changelog ». Les dix lignes de ce tableau
sont le contenu réel du lot 1, et son critère d'arrêt est le même tableau
repassé tout en « oui ».

### 0.4 — Les deux éléments d'infrastructure en attente

- Créer `PORTFOLIO_SYNC_TOKEN`.
- Décider du sort du runner de signature : `SessionCreate` est à `false` dans
  son plist pour qu'il garde l'accès au trousseau. Le garder et le documenter
  comme tel, ou le remplacer — mais pas le laisser implicite.

### 0.5 — Hygiène de l'arbre git

Traité et exécuté en partie : voir la section 7, qui enregistre ce qui a été
supprimé, ce qui a été archivé par tag, et ce qui reste à décider.

---

## 2. Lot 1 — La preuve visuelle

**C'est le lot qui décide si la 2.0 existe.** La barre est une différence
visible sans changelog ; tout le reste peut être parfait sans l'atteindre.

### 1.1 — Un moment de signature par module

Explorer a le sien : la carte où l'aire d'un dossier est ses octets, une
vérité lue d'un coup d'œil. Trois modules n'ont rien d'équivalent et sont le
cœur du lot.

| Module | Ce qu'il doit gagner | Matière disponible |
|---|---|---|
| **Aperçu** | Une lecture immédiate de l'état du Mac — sans score, sans jauge, sans total inventé | `activity`, `SystemMetrics`, historique des analyses |
| **Protocole** | Une lecture à rebours de ce qui s'est réellement passé, refus compris | `safety_log` : `stage`, `result`, `risk`, `redacted_path` |
| **Intégrité** | Une lecture de ce que macOS a déjà enregistré, sans prétendre être un antivirus | `IntegrityCore` : provenance, niveau de signature, objets de connexion |

Règle : chacun gagne son moment **par ses vraies données**, pas par un
ornement. Un graphique décoratif qui n'ajoute pas une vérité lisible ne
ferme pas une ligne.

Ordre déduit : **Aperçu d'abord** — c'est la première chose qu'un utilisateur
de 1.0.1 ouvre, donc celle qui porte le verdict M-06 —, puis **Protocole**,
puis **Intégrité**.

### 1.2 — Matière et profondeur, seulement là où le système en fournit

Rails d'inspecteur, états d'analyse en cours. Interdits explicites, hérités
de la direction visuelle : **aucun flou fait main, aucune carte de verre.**

### 1.3 — Chorégraphie d'arrivée

Dans les bandes `MCMotion` existantes, pas de nouvelles durées inventées :
une analyse qui se termine, une carte qui se pose, une ligne qui atterrit.
« Réduire les animations » reste **absolu** — c'est une contrainte
d'accessibilité, testée, jamais une préférence.

### 1.4 — Relecture module par module

Contre `CORETEND_VNEXT_VISUAL_DIRECTION.md`, captures ouvertes, dans l'ordre
de la file.

### 1.5 — La méthode imposée, non contournable

Chaque affirmation visuelle exige une capture produite par
`Scripts/capture-module.sh`, qui écrit ce que l'application affiche et refuse
une incohérence. **Une galerie que l'outil n'a pas pu vérifier ne compte
pas.**

Corollaire connu et assumé : les captures d'application ne sont pas gardées
par la CI — elles exigent une vraie session macOS. C'est un choix, pas un
oubli, et il déplace la charge sur la relecture humaine. Donc chaque module
fermé porte une signature humaine datée.

### Critère d'arrêt du lot 1

Le tableau de **0.3** repassé, tout en « oui ». Rien d'autre ne ferme ce lot :
ni la file d'exécution, ni le nombre de tests, ni l'absence d'avertissement.

---

## 3. Lot 2 — La profondeur

### 2.1 — Résoudre ou abandonner `.icon` → `Assets.car`

`actool` ne produit silencieusement **aucun** `Assets.car` depuis un paquet
`.icon` écrit à la main. Le chemin est bloqué depuis des semaines et il est
devenu porteur : macOS 26 attend ce traitement d'icône.

Le rapport tranche la méthode, pas l'issue : **abandonner explicitement est
une issue valable ; ce qui ne l'est pas, c'est de le laisser bloqué sans
décision.** Donc : une journée sèche d'investigation, puis verdict écrit —
résolu, ou abandonné avec la conséquence nommée sur macOS 26.

### 2.2 — Variante de favicon sombre

### 2.3 — Relecture du logotype contre la grille d'icônes macOS 26

---

## 4. Lot 3 — Le fond

**Parallélisable avec les lots 1 et 2 : il ne touche pas les mêmes fichiers.**
C'est le seul lot qui peut avancer pendant que le lot 0 attend des décisions
humaines. À utiliser comme tampon — jamais comme substitut au lot 1.

| # | Travail | Pourquoi maintenant |
|---|---|---|
| 3.1 | **Préréglages de filtres par catégorie** | Les règles portent déjà `minimumAgeDays` et `minimumSizeBytes` : c'est exposer ce qui existe, pas inventer un mécanisme. Coût faible, valeur visible — candidat à remonter dans l'ordre |
| 3.2 | **Analyses planifiées — jamais de suppression planifiée** | Une analyse peut être sans surveillance ; un déplacement ne peut pas. C'est la ligne qui sépare CoreTend de sa catégorie, et elle se tient par un test, pas par une intention |
| 3.3 | **Couverture de SafetyCore** | 80,4 % de lignes, et les mutants ont montré que la couverture surestime ce qui est tenu : 17 tués sur 28. Cible : tuer les survivants nommés, pas monter le pourcentage |
| 3.4 | **Catégories Homebrew, Docker, npm** | Le public développeur est celui qui a le plus de cache et le moins d'outils honnêtes |
| 3.5 | **Installation de mise à jour dans l'app** | Aujourd'hui : vérifier, puis ouvrir le navigateur |
| 3.6 | **Répétition de release sur un tag jetable** | Seul trou avéré de l'outillage : `release-preflight.sh` garde chaque étape, rien ne répète le chemin entier |

---

## 5. Lot 4 — App Store

Verrouillé par **0.1 / P-01**. N'existe pas tant que la décision n'est pas
rendue.

- **4.1** Un projet Xcode **fin**, limité à la soumission, est autorisé — et
  seulement si ce canal expédie réellement. Le dépôt reste SwiftPM sans
  projet Xcode pour tout le reste.
- **4.2** Nommage honnête du build amputé. Cinq destinations sur huit
  manquent : le nom, la page produit et la fiche doivent le dire avant
  l'installation, pas après.

---

## 6. Lot 5 — La 2.0

- **5.1** Validation à la main, par le mainteneur.
- **5.2** Jusque-là, CoreTend 2.0 reste **PRE-ALPHA**. Aucun mot impliquant
  l'achèvement — « final », « release candidate », « prêt », « terminé » — ne
  peut être employé pour le produit. Cette règle vaut pour le dépôt, le site,
  les messages de commit et les notes de version.

---

## 7. L'arbre git — état, action prise, et ce qui reste

### Ce que le relevé réel a montré

Le rapport annonçait sept branches à « zéro commit devant `main` ». Le graphe
dit autre chose : les sept sont très en avance en nombre de commits, parce
que l'histoire a été réécrite lors du changement de nom et de la migration
d'espace de travail. Le comptage `ahead` n'était donc pas le bon critère.

Le bon critère est celui que le rapport énonce lui-même pour justifier la
suppression : **les commits restent-ils joignables par un tag ?** C'est sur
celui-là que l'action a été prise.

### Supprimées — tip contenu dans un tag existant

| Branche | Tip | Préservée par |
|---|---|---|
| `release/v0.9.1-rc.4` | `21a6add0` | `v0.9.1-rc.4`, `rc.5`, `rc.6` |
| `release/v0.9.1-rc.4-publish` | `f505c350` | `v0.9.1-rc.5`, `rc.6` |
| `release/v0.9.1-rc.5` | `05121aba` | `v0.9.1-rc.5`, `rc.6` |
| `release/v0.9.1-rc.5-publish` | `55a7576c` | `v0.9.1-rc.6` |
| `feat/coretend-gold-master` | `fb76c47d` | `v0.9.1-rc.4`, `rc.5`, `rc.6` |
| `rescue/coretend-final-product` | `0fb99dcb` | `v0.9.1-rc.4`, `rc.5`, `rc.6` |

### Archivée puis supprimée — aucun tag ne la contenait

`release/v1.0.0-prep` (`bcdabf36`) était la septième de la liste, mais son
tip n'était contenu dans **aucun** tag : la supprimer telle quelle aurait
rendu son histoire injoignable. Un tag d'archive
`archive/release-v1.0.0-prep` a été posé sur le tip **avant** suppression,
pour que la promesse du rapport — « les commits restent joignables par tag »
— soit vraie dans les sept cas.

### Restent, et appellent une décision

| Branche | Devant `main` | Décision attendue |
|---|---|---|
| `release/v1.1.0-beta.1` | 89 | Porter dans `develop/v2`, ou tuer. Taguée `v1.1.0-beta.1`, donc sûre à supprimer |
| `feat/community-contact-site-v1.1` | 78 | Porter la section communauté/contact du site, ou tuer |
| `feat/deep-scan-cleanup-v1.2` | 26 | Porter l'analyse profonde dans le lot 3, ou tuer |
| `feat/coretend-public-redesign` | 9 | Non taguée — archiver avant toute suppression |
| `ci/retry-browser-download` | 1 | Absorbée, non taguée |
| `docs/state-after-1.0.1` | 1 | Absorbée, non taguée |

Ces six-là n'ont pas été touchées. Les laisser diverger fait grossir la dette
de fusion à chaque commit de la 2.0 : c'est une décision à prendre, pas à
reporter indéfiniment.

### La règle qui vaut pour la suite

`main` est la ligne 1.x qui expédie, **pas une branche d'intégration**. Les
releases sont coupées depuis elle — la garde de preflight l'exige, pour que
la source publiée soit relisible. `develop/v2` est le chantier, et il ne
fusionne pas avant validation à la main.

Rappel du coût de l'oubli : la 1.0.2 a d'abord été coupée sur une branche
locale partie de `v1.0.1`, qui ne contenait donc pas les quatre correctifs
déjà dans `main` — rebasage avant publication.

---

## 8. Les règles transversales

Elles ne sont pas des recommandations : elles gouvernent chaque lot et aucune
n'est négociée par un calendrier.

### T.1 — Les cinq contraintes sont le produit

1. **Il ne supprime jamais.** Aucun chemin de code ne supprime : ni pour les
   caches, ni pour les doublons, ni sous invite administrateur, ni depuis une
   planification, ni depuis une ligne de commande.
2. **Il n'annonce jamais de total « libéré ».** Il n'est pas informé du
   vidage de la corbeille ; un test échoue si un tel total réapparaît.
3. **Rien ne quitte le Mac.** Aucun compte, aucune analyse d'usage, aucune
   télémétrie. Une seule requête réseau dans tout l'arbre source, lancée par
   l'utilisateur, et elle ne télécharge rien.
4. **Un refus est un enregistrement de première classe**, jamais une note en
   bas de page sur un échec.
5. **Chaque chemin destructif passe par `SafetyCore.PathValidator`** — jamais
   un appel `FileManager` brut sur un chemin fourni par l'utilisateur.

Chacune fait échouer la compilation quand elle cesse d'être vraie. Ce ne sont
pas des promesses de README.

### T.2 — Décidé ou dérivé, jamais les deux

Chaque artefact choisit son camp et reçoit la garde opposée : la revue
humaine pour un décidé, un `--check` qui échoue sur la dérive pour un dérivé.
Ils échouent à l'opposé — un document décidé cesse d'être ce qu'on veut, un
document dérivé cesse de décrire ce qui est.

### T.3 — Une garde n'est crue qu'après avoir été mise en échec délibérément

Sept gardes ne gardaient pas ; deux n'avaient jamais rien gardé depuis leur
écriture. Toute garde ajoutée par ce plan est cassée exprès avant d'être
créditée.

Corollaire aussi important : **une garde qui se déclenche sur du code correct
est pire qu'aucune garde**, parce qu'elle apprend à ignorer la sortie.

### T.4 — Lire la mutation correctement

« Tué » est fiable. « Survivant » est une piste — un mutant dont l'effet est
mesurable peut être rapporté comme survivant. Le pourcentage est un
**plancher**, pas une note.

### T.5 — L'ordre de sacrifice, arrêté d'avance

Si le temps manque, dans cet ordre : l'espagnol, les catégories de cache
développeur, la CLI enrichie, l'analyse rapide depuis la barre de menus.

**Jamais sacrifiés :** l'intégrité des données, la sécurité, l'accessibilité,
la langue honnête du produit, le comportement natif de macOS.

Cet ordre est fixé ici pour ne pas être rediscuté au moment où il servira,
c'est-à-dire au moment où le jugement est le moins bon.

### T.6 — Le piège nommé

La file d'exécution est à 87 % fermée. C'est précisément la situation où l'on
se croit proche du but.

> Une file vide est un manque de planification, jamais une preuve que le
> produit est fini.

Le nettoyage, le retrait de code mort, les corrections d'états vides et les
réparations de tests sont réels et utiles. Ils ne remplacent pas l'audit qui
rouvre la file, et ne la ferment pas à eux seuls.

---

## 9. Le chemin critique

```
0.3 (verdict côte à côte)
  → 1.1 Aperçu
  → 1.1 Protocole
  → 1.1 Intégrité
  → 1.5 captures vérifiées et signées
  → M-06 repassé, tout en « oui »
  → lot 5, validation à la main
```

Tout le reste est du tampon parallèle. Si une seule chose doit avancer, c'est
le tableau côte à côte de **0.3** : il coûte une session et il débloque le
seul lot qui décide si la 2.0 existe.

## 10. La définition de « fini »

Déjà écrite dans `CLAUDE.md`, et ce plan ne la modifie pas :

> Une différence visuelle générationnelle par rapport à la 1.0.1, visible au
> premier coup d'œil sans changelog, est la barre pour dire qu'une refonte de
> module est faite.

Et pour le produit entier : **CoreTend 2.0 reste PRE-ALPHA jusqu'à validation
à la main.**

---

Ce plan est à relire quand le lot 1 sera engagé : c'est là qu'il sera
confronté à ce que le produit montre réellement à l'écran.
