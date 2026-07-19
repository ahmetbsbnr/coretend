# PRIVILEGED HELPER
Non implémenté. Bloqué par: absence d'identité de signature Developer ID
(SMAppService pour daemons exige une signature stable). Toutes les
fonctionnalités actuelles fonctionnent sans privilèges. Si implémenté plus
tard: XPC à méthodes typées uniquement (jamais runCommand/deleteArbitraryPath),
re-validation indépendante côté helper, pas d'accès réseau.
