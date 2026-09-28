# Performance baseline

## Synthetic release CLI scan — 2026-09-27

- Host: arm64, macOS 27.0, Apple Swift 6.4.
- Reproduce with `make benchmark-scan`. Build time and fixture creation are excluded from timings.
- Workload: 10,000 regular files in 100 directories; deterministic size pattern repeats 0, 4 KiB, 4 KiB, 64 KiB (184,320,000 logical bytes total). Fixture lives in a unique temporary directory and is removed after the run.
- Command per sample: `.build/release/CoreTendCLI scan --root <temporary-fixture> --rule scan.explore`. CLI formats all results to a temporary output file; script checks final result count and requires exit status 0. Five fresh processes run against same fixture; sample 1 is reported separately, samples 2–5 form warm median.
- Warm median: **0.913 s wall**, **0.979 s child CPU**, **74.18 MiB peak RSS**. Individual samples: 0.904/0.983/74.2, 0.926/0.980/74.2, 0.902/0.979/74.2, 0.925/0.976/74.2, 0.901/0.980/74.2 (wall/CPU/RSS).
- No budget is inferred from one host and synthetic workload. This measures release CLI startup + metadata traversal + text formatting, not app window readiness, native UI responsiveness, image hashing, or a representative user library. OS caches and host load were not controlled. Repeat on realistic fixtures and additional supported hosts before setting budgets.

## Packaged app fixture startup and residency sample — 2026-09-27

- Host: arm64, macOS 27.0, Apple Swift 6.4. Reproduce with `make app-runtime-smoke` or full `make qualify`; app is the actual unsigned Release package installed under fixture `HOME`, with fixture store and menu-bar mode enabled.
- Two fixture launches each reached first SQLite observation in **1.094 s**. This is store readiness, not main-window readiness.
- Each run collected 13 socket/isolation samples approximately 0.5 s apart after store creation. Run A: `ps` `%CPU` median **0.0**, maximum **55.2**; resident memory median **92.5 MiB**, maximum **95.4 MiB**. Run B: `%CPU` median **0.0**, maximum **69.1**; RSS median **96.3 MiB**, maximum **97.6 MiB**. `%CPU` is `ps` lifetime average at each observation, including startup, not instantaneous idle utilization. RSS is sampled, not peak resident memory.
- These measurements describe two synthetic launches on one host. They do not set budgets or claim UI responsiveness; user load and host load were not controlled.

## Remaining NFR-09 evidence

Native app startup-to-window, UI interaction latency, CPU/RSS during real scans, animation at rest, a representative corpus and additional hosts remain unmeasured. NFR-09 stays `PARTIEL`.

## P4 — lot 4.3, mesures locales — 28-09-2026

### Méthode et corpus

- Hôte unique : MacBook Air M1, arm64, macOS 27.0 (26A428), Swift 6.4.
  Source app/CLI `1c8b8c08`, scripts de mesure modifiés dans ce lot ; aucun code produit optimisé.
- Création de corpus, compilation et installation exclues. Série finale sans compilation
  concurrente de l’agent ; charge des autres applications et caches OS non contrôlés.
  Le premier processus n’est **pas** un essai à cache froid : les fichiers viennent d’être créés
  et leurs métadonnées sont inspectées avant la mesure.
- `uniform` : 10 000 fichiers, 100 dossiers, motif de tailles 0/4 KiB/4 KiB/64 KiB,
  184 320 000 octets logiques et alloués.
- `mixed` : 10 000 fichiers, 164 dossiers, quatre branches Projects/Logs/Documents/Médias,
  profondeur allant jusqu’à cinq dossiers ; noms Unicode et quatre fichiers sparse de 64 MiB.
  452 681 728 octets logiques, 184 246 272 alloués. Les autres fichiers gardent le motif uniforme.
- Ces corpus modélisent des formes de données usuelles ; ils restent synthétiques. Ils ne
  représentent pas à eux seuls une bibliothèque utilisateur, un fournisseur cloud ou des
  contenus d’images à hasher. Aucun accès au HOME/store/Corbeille réels.
- CLI : cinq processus par corpus, contrôle du code 0 et du compte final de 10 000 fichiers.
  Temps monotone inclut démarrage, parcours et formatage des résultats vers un fichier temporaire.
  CPU et RSS maximale fournis par `wait4` ; médiane chaude des processus 2–5.
- App : cinq profils HOME/store/TMPDIR distincts, copie du paquet Release unsigned P4.2,
  Vue d’ensemble FR/sombre, onboarding terminé, menu bar non activé. Sonde CGWindow existante :
  fenêtre normale de plus de 200 × 200 détectée, incluant lancement de la sonde et polling.
  Cela ne prouve pas que le contenu est rendu ou interactif. Dix relevés `ps` à 0,5 s après
  détection, par processus. RSS échantillonnée ; `%CPU` est une moyenne depuis le lancement,
  pas une consommation instantanée au repos. Tous les processus de mesure sont terminés.

### Résultats de la série finale

| Mesure | Uniforme | Varié |
|---|---:|---:|
| Médiane chaude wall | 0,873 s | 1,069 s |
| Médiane chaude CPU enfant | 0,941 s | 1,147 s |
| Médiane chaude RSS maximale | 74,08 MiB | 81,45 MiB |
| Première exécution wall | 0,869 s | 1,094 s |

App : détection de fenêtre en **0,458 / 0,407 / 0,480 / 0,469 / 0,475 s**, médiane
**0,469 s**. Sur 50 relevés : RSS médiane **96,73 MiB**, maximum échantillonné **98,63 MiB** ;
`ps` CPU médiane **0,35 %**, maximum **50,4 %**, incluant le démarrage. Aucun budget de CPU
instantanée ou de fluidité ne peut être déduit de cette moyenne.

Données brutes conservées dans `P4-43-uniform-2026-09-28.json`,
`P4-43-mixed-2026-09-28.json` et `P4-43-app-2026-09-28.json` (ce dossier).
Deux séries exploratoires de démarrage ayant pu chevaucher la qualification ont été écartées
pour cette table ; seuls les cinq lancements finaux sont conservés.

### Essais Explorer et limites

Un essai AX en fixture a ouvert le sélecteur et choisi le corpus mixed. La progression
native a été lue de 520 à **9 875 fichiers**, ce dernier relevé vers **21,089 s** après la
validation du sélecteur. RSS échantillonnée maximale avant ce relevé : environ **185,9 MiB**.
La requête suivante a échoué (`System Events`, `-10000`) : **fin du scan non observée**.
Le polling AX perturbe le travail mesuré ; ce délai ne constitue pas un temps moteur comparable
au CLI. Un second essai de lecture ciblée est resté sur l’état initial : sélection du corpus
non confirmée, pas de mesure de scan retenue. Les processus ont été terminés.

Journaux locaux : `/tmp/coretend-p4-43-ui-scan.log`, `/tmp/coretend-p4-43-ui-targeted.log`.
Il faut reprendre la mesure du scan natif avec une sonde fiable et observer la fin, la latence
clavier/annulation et le rendu des résultats. Ces essais ne prouvent ni un blocage produit ni
une fin réussie. Aucun déplacement ni confirmation destructive n’a été exercé.

### Budgets locaux proposés — soumis à la recette

Pour cet hôte et ces corpus seulement, proposer un **seuil d’alerte de non-régression** à deux
fois la référence finale, arrondi vers le haut. La marge est volontairement conservatrice :
peu de processus, charge non contrôlée, pas de campagne multi-hôtes. Une alerte déclenche une
nouvelle mesure puis une investigation, pas une déclaration automatique de défaut produit.

| Mesure comparable | Référence retenue | Seuil proposé |
|---|---:|---:|
| Wall CLI, médiane chaude (chacun des deux corpus) | maximum 1,069 s | 2,2 s |
| CPU CLI, médiane chaude (chacun des deux corpus) | maximum 1,147 s | 2,3 s |
| RSS CLI maximale, médiane chaude | maximum 81,45 MiB | 165 MiB |
| Détection fenêtre app, médiane des cinq lancements | 0,469 s | 1,0 s |
| RSS app, maximum de 50 relevés avec même protocole | 98,63 MiB | 200 MiB |

Aucun seuil proposé pour hashing, fluidité, scan natif complet, CPU instantanée au repos,
cache froid ou autre matériel. Ces budgets ne sont pas activés en CI et ne changent aucune
promesse publique. Après acceptation, les répéter avec le même protocole avant comparaison.

### Reproduction

```sh
export PATH=/opt/homebrew/bin:$PATH
swift build -c release --product CoreTendCLI
make package-local verify-package
python3 Scripts/benchmark_scan.py --profile uniform --json Artifacts/Performance/P4-43-uniform.json
python3 Scripts/benchmark_scan.py --profile mixed --json Artifacts/Performance/P4-43-mixed.json
python3 Scripts/benchmark_app_fixture.py
```

Lancer les benchmarks séquentiellement, après les builds ; aucune compilation concurrente.
Le profil uniforme reste le défaut de `make benchmark-scan`. Les scripts nettoient leurs
fixtures, n’utilisent pas de données personnelles et n’envoient aucune touche destructive.

**Recette :** accepter/corriger le corpus, les mesures, les cinq seuils proposés et les
réserves. NFR-09 reste PARTIEL : corpus réel représentatif, latence UI, fin de scan natif,
CPU instantanée/animations au repos et autres hôtes non qualifiés. G4 non passée.


### Vérification finale du lot

`make qualify` : PASS, code 0 (`/tmp/coretend-p4-43-final-qualify.log`).
`make traceability` et `git diff --check` : PASS. Les deux profils CLI et le runner app
ont été exécutés ; la mesure UI Explorer reste un essai non qualifié. La feuille de rendu
DesignSystem est ignorée par la suite standard ; aucune preuve visuelle nouvelle n’en est déduite.
