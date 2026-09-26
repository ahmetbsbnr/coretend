# Contribuer à CoreTend

Le code en reconstruction vit sur `next`; `main` représente la version publique stable. Ouvrir une issue pour un changement de produit important, puis une branche courte issue de la branche visée. Une pull request doit expliquer comportement, risques, documentation et preuve de vérification.

## Travail local

Requis : macOS 14+ et Swift 6. Depuis la racine :

```sh
make qualify
```

Utiliser uniquement des dossiers temporaires synthétiques pour les tests de fichiers. Aucun test ne doit viser le store CoreTend réel, la Corbeille réelle ou un dossier personnel implicite. Les opérations de déplacement passent par `SafetyCore` et exigent sélection, revue et confirmation.

Mettre à jour `Documentation/Traceability.csv` et `Documentation/Progress.md` lorsque l’état d’une capacité change. Signaler clairement ce qui a été compilé, testé ou laissé non vérifié. Ajouter toute nouvelle dépendance, image ou police seulement avec provenance et licence documentées.

Pour une faille, suivre `SECURITY.md` plutôt qu’une issue publique.
