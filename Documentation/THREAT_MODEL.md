# THREAT MODEL (résumé)
Actifs: données utilisateur (perte = pire scénario), intégrité système.
Menaces couvertes:
- symlink swap entre scan et suppression → re-validation à l'exécution (testé)
- traversée `..` / chemins relatifs / racines protégées → PathValidator (testé)
- suppression hors périmètre → allowlists par opération, ApprovedFileOperation only
- suppression d'un groupe entier de doublons → garantie survivant (code)
- exécution de commandes arbitraires → aucun shell et aucun `Process(` dans les sources produit
- zip bombs → non applicable (pas d'extraction d'archives implémentée)
Non couvert (documenté): helper privilégié absent, pas d'Endpoint Security,
Integrity informatif uniquement, signature Developer ID et notarisation futures.
