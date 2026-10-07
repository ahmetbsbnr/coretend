# CoreTend 2.2 — à faire après la sortie

**Règle du mainteneur (07-10-2026) :** la 2.2.0 publiée reste en place. Aucune mise à jour publique
avant la prochaine version prévue, **sauf correctif de sécurité**. Les points ci-dessous
attendent cette version.

## Tests réels non passés (Mac Apple silicon, macOS 27, 2.2.0 installée)

- [ ] **Widget absent de la galerie** (« Modifier les widgets », recherche « core ») alors que
  `pluginkit` l'enregistre (`com.ahmetbsbnr.coretend.widget`). Aucun journal système ne le mentionne :
  le service des widgets ne semble pas le charger. Pistes, par ordre :
  1. comparer avec un widget minimal créé par Xcode (Info.plist, clés `DT*` et
     `CFBundleSupportedPlatforms`, options de lien) et reproduire ses différences dans
     `Scripts/package_local.sh` ;
  2. vérifier que l'exécutable démarre comme une extension (`@main WidgetBundle` sans
     `-e _NSExtensionMain` ni `-application-extension`) ;
  3. vérifier la signature sandbox de l'appex et l'accès au groupe d'apps.
- [ ] **Extension Finder** : pas encore activée par le mainteneur (Réglages Système › Général ›
  Ouverture et extensions › Extensions › Finder), donc le menu « Analyser avec CoreTend » n'est pas
  testé. Le lien `coretend://scan` qu'elle envoie, lui, est testé.
- [ ] **Raccourcis et Siri** : les actions ne sont pas vérifiées dans l'app Raccourcis (recherche
  « CoreTend » dans la bibliothèque d'actions), ni par Siri en français.
- [ ] **Interrupteur d'un service système** : aller-retour désactiver/réactiver non fait. La liste
  des 9 services tiers est juste.
- [ ] **Mac Intel** : aucun essai sur un vrai Mac Intel.
- [ ] **npm** : `coretend@2.2.0` non publié (session npm expirée). Après `npm login` :
  `npx -y npm@12 stage publish --access public` dans `npm/`, puis approbation avec la passkey.

## Corrigé sur `next`, non publié

- [x] Accessibilité : les interrupteurs de Réglages › Système portent le nom du service
  (`01c8d611`).

## Tests réels passés

- Helper système : accord, lecture des caches (caches Apple écartés), Corbeille puis Annuler sur
  un cache de test (SHA-256 identique), liste des services.
- Liens `coretend://open/<espace>` et `coretend://scan`, à froid et à chaud ; dossier ouvert avec
  l'app (même chemin que le dépôt sur le Dock).
- Total de Nettoyer transmis au widget par le groupe d'apps (6,84 Go).
- Build universelle signée, notarisée, agrafée ; Gatekeeper « Notarized Developer ID ».

## Question ouverte

- [ ] L'Historique est vide (0 événement, 512 le matin) : effacé par le mainteneur, ou autre
  cause ? Le code ne vide l'historique que par « Effacer l'historique… » avec confirmation.
