public enum Destination: String, CaseIterable, Sendable, Identifiable {
    case overview, record, cleanup, explore, duplicates, applications, integrity, performance
    public var id: String { rawValue }
    public var titleKey: String { "\(rawValue).title" }
    public var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .record: "clock.arrow.circlepath"
        case .cleanup: "sparkles"
        case .explore: "externaldrive"
        case .duplicates: "doc.on.doc"
        case .applications: "app.dashed"
        case .integrity: "checkmark.shield"
        case .performance: "gauge.with.dots.needle.67percent"
        }
    }
}

public enum ProductCopy {
    public static let english: [String: String] = [
        "overview.title": "Overview", "record.title": "Record", "cleanup.title": "Cleanup",
        "explore.title": "Explore", "duplicates.title": "Duplicates", "applications.title": "Applications",
        "integrity.title": "Integrity", "performance.title": "Performance",
        "safety.notice": "Scans only read files. Any removal requires review, confirmation, and moves to Trash.",
        "overview.summary": "Understand what is happening on this Mac.",
        "empty.title": "No results yet", "empty.body": "Start a scan to see measured results here.",
        "scan.choose": "Choose a folder to inspect", "scan.choose.hint": "CoreTend reads this folder without changing its files.",
        "scan.progress": "Reading selected folder…", "scan.failed": "The folder could not be read.",
        "scan.accessDenied": "Access to the selected folder is unavailable.", "scan.partial": "Some items could not be read.",
        "scan.empty": "No files found in the selected folder.", "scan.unknownSize": "Unknown size",
        "scan.cancelled": "Scan cancelled.", "duplicates.choose": "Choose a folder to compare",
        "explore.search": "Search names and folders", "explore.sort": "Sort", "explore.largest": "Largest local size", "explore.oldest": "Oldest first", "explore.name": "Name",
        "duplicates.choose.hint": "CoreTend compares file contents and does not change them.",
        "duplicates.none": "No exact duplicates found", "duplicates.keep": "Suggested file to keep",
        "duplicates.noAction": "Nothing has been moved. Review remains in your control.",
        "settings.title": "Settings", "settings.language": "Language", "settings.system": "Follow system",
        "metrics.refresh": "Refresh measurements", "metrics.unavailable": "System measurements unavailable",
        "metrics.freeSpace": "Volume free space", "metrics.available": "reported by macOS",
        "metrics.trashNote": "This value does not subtract items in Trash.", "metrics.volumeTotal": "Volume capacity",
        "metrics.measured": "Measured", "metrics.unknown": "Unknown",
        "metrics.processors": "Available processor cores", "metrics.memory": "Physical memory capacity",
        "metrics.uptime": "System uptime", "metrics.thermal": "Thermal state",
        "metrics.loadAverage": "1-minute system load", "metrics.history": "Local measurement history",
        "metrics.historyHelp": "Measured when this view refreshes. Points show 1-minute system load, not CPU percent. Stored locally for 30 days, up to 500 readings.",
        "metrics.historyEmpty": "No known load measurements yet", "metrics.historyError": "Local measurement history is unavailable.",
        "thermal.nominal": "Nominal", "thermal.fair": "Fair", "thermal.serious": "Serious",
        "thermal.critical": "Critical", "thermal.unknown": "Unknown",
        "record.filter": "Filter", "record.all": "All events", "record.actions": "Record actions", "record.export.json": "Export JSON…",
        "record.export.csv": "Export CSV…", "record.clear": "Clear history…", "record.clear.title": "Clear local history?",
        "record.clear.message": "This permanently removes CoreTend activity records from this reconstruction’s local database.",
        "record.clear.confirm": "Clear history", "record.empty": "No recorded actions yet",
        "record.localNotice": "Activity is stored locally. Export files may contain private names and paths.",
        "record.error": "Local history is unavailable.", "common.cancel": "Cancel",
        "activity.proposed": "Proposed", "activity.approved": "Approved", "activity.refused": "Declined",
        "activity.cancelled": "Cancelled", "activity.movedToTrash": "Moved to Trash", "activity.failed": "Failed",
        "activity.migrationImported": "Legacy preferences imported",
        "cleanup.intro": "Choose one known location to inspect. No rule is selected until you choose it.",
        "cleanup.caches": "User caches", "cleanup.caches.help": "Files under ~/Library/Caches.",
        "cleanup.logs": "User logs", "cleanup.logs.help": "Files under ~/Library/Logs.",
        "cleanup.crashes": "Crash reports", "cleanup.crashes.help": "Only .crash reports under DiagnosticReports.",
        "cleanup.derived": "Xcode DerivedData", "cleanup.derived.help": "Files under Xcode/DerivedData.",
        "cleanup.downloads": "Incomplete downloads", "cleanup.downloads.help": "Only files ending in .download.",
        "cleanup.deviceSupport": "Xcode Device Support", "cleanup.deviceSupport.help": "Files under iOS DeviceSupport.",
        "cleanup.iosBackups": "iOS backups", "cleanup.iosBackups.help": "Files under MobileSync/Backup.",
        "cleanup.risk.low": "Low risk", "cleanup.risk.medium": "Medium risk", "cleanup.risk.high": "High risk",
        "cleanup.choose": "Select the rule’s folder", "cleanup.choose.hint": "Choose the exact folder shown above.",
        "cleanup.rootMismatch": "Select the exact folder shown for this rule.",
        "cleanup.scan": "Inspect selected rule", "cleanup.scan.hint": "Reads the listed folder. No files are changed.",
        "cleanup.noAction": "Select candidates to review. Nothing moves without your confirmation.",
        "cleanup.partial": "Some items could not be read.", "cleanup.none": "No matching files found.",
        "apps.choose": "Choose an Applications folder", "apps.choose.hint": "Reads app bundle metadata in the selected folder only.",
        "apps.limits": "This inventory reads top-level .app metadata only. It does not uninstall apps or check for updates.",
        "apps.empty": "No app bundles found", "apps.failed": "App metadata could not be read.",
        "integrity.choose": "Choose an app to inspect", "integrity.choose.hint": "Checks the selected app’s code signature locally.",
        "integrity.limit": "Signature validation reports one native signal. It does not determine whether an app is malware or safe.",
        "integrity.progress": "Checking signature…", "integrity.valid": "Signature passes system validation",
        "integrity.invalid": "Signature did not pass validation", "integrity.unavailable": "Signature information unavailable",
        "integrity.identifier": "Bundle identifier", "integrity.team": "Signing team", "integrity.status": "System status code",
        "integrity.quarantine.present": "macOS quarantine marker present", "integrity.quarantine.absent": "No quarantine marker observed",
        "integrity.quarantine.unavailable": "Quarantine marker unavailable", "integrity.quarantine.limit": "Marker presence does not prove origin or safety; absence does not prove the app is safe.",
        "onboarding.title": "Welcome to CoreTend"
    ]
    public static let french: [String: String] = [
        "overview.title": "Vue d’ensemble", "record.title": "Historique", "cleanup.title": "Nettoyage",
        "explore.title": "Explorer", "duplicates.title": "Doublons", "applications.title": "Applications",
        "integrity.title": "Intégrité", "performance.title": "Performances",
        "safety.notice": "Les analyses lisent les fichiers sans les modifier. Tout retrait demande une revue et une confirmation, puis passe par la Corbeille.",
        "overview.summary": "Comprendre l’état de ce Mac.",
        "empty.title": "Aucun résultat", "empty.body": "Lancez une analyse pour afficher les mesures ici.",
        "scan.choose": "Choisir un dossier à examiner", "scan.choose.hint": "CoreTend lit ce dossier sans modifier ses fichiers.",
        "scan.progress": "Lecture du dossier sélectionné…", "scan.failed": "Impossible de lire ce dossier.",
        "scan.accessDenied": "L’accès au dossier sélectionné est indisponible.", "scan.partial": "Certains éléments n’ont pas pu être lus.",
        "scan.empty": "Aucun fichier dans le dossier sélectionné.", "scan.unknownSize": "Taille inconnue",
        "scan.cancelled": "Analyse annulée.", "duplicates.choose": "Choisir un dossier à comparer",
        "explore.search": "Rechercher noms et dossiers", "explore.sort": "Trier", "explore.largest": "Plus grande taille locale", "explore.oldest": "Plus ancien d’abord", "explore.name": "Nom",
        "duplicates.choose.hint": "CoreTend compare le contenu des fichiers sans les modifier.",
        "duplicates.none": "Aucun doublon exact trouvé", "duplicates.keep": "Fichier proposé à conserver",
        "duplicates.noAction": "Aucun fichier déplacé. Vous gardez le contrôle des actions.",
        "settings.title": "Réglages", "settings.language": "Langue", "settings.system": "Langue du système",
        "metrics.refresh": "Actualiser les mesures", "metrics.unavailable": "Mesures système indisponibles",
        "metrics.freeSpace": "Espace libre du volume", "metrics.available": "indiqué par macOS",
        "metrics.trashNote": "Cette valeur ne soustrait pas les éléments de la Corbeille.", "metrics.volumeTotal": "Capacité du volume",
        "metrics.measured": "Mesuré", "metrics.unknown": "Inconnu",
        "metrics.processors": "Cœurs de processeur disponibles", "metrics.memory": "Mémoire physique installée",
        "metrics.uptime": "Temps de fonctionnement", "metrics.thermal": "État thermique",
        "metrics.loadAverage": "Charge système sur 1 minute", "metrics.history": "Historique local des mesures",
        "metrics.historyHelp": "Mesuré à chaque actualisation de cette vue. Les points indiquent la charge sur 1 minute, pas un pourcentage CPU. Conservation locale : 30 jours, 500 relevés au plus.",
        "metrics.historyEmpty": "Aucune mesure de charge connue", "metrics.historyError": "Historique local des mesures indisponible.",
        "thermal.nominal": "Normal", "thermal.fair": "Modéré", "thermal.serious": "Élevé",
        "thermal.critical": "Critique", "thermal.unknown": "Inconnu",
        "record.filter": "Filtrer", "record.all": "Tous les événements", "record.actions": "Actions de l’historique", "record.export.json": "Exporter en JSON…",
        "record.export.csv": "Exporter en CSV…", "record.clear": "Effacer l’historique…", "record.clear.title": "Effacer l’historique local ?",
        "record.clear.message": "Cette action supprime définitivement les événements CoreTend de la base locale de cette reconstruction.",
        "record.clear.confirm": "Effacer l’historique", "record.empty": "Aucune action enregistrée",
        "record.localNotice": "L’activité reste locale. Les exports peuvent contenir des noms et chemins privés.",
        "record.error": "L’historique local est indisponible.", "common.cancel": "Annuler",
        "activity.proposed": "Proposé", "activity.approved": "Approuvé", "activity.refused": "Refusé",
        "activity.cancelled": "Annulé", "activity.movedToTrash": "Déplacé dans la Corbeille", "activity.failed": "Échec",
        "activity.migrationImported": "Préférences héritées importées",
        "cleanup.intro": "Choisissez un emplacement connu à examiner. Aucune règle n’est sélectionnée par défaut.",
        "cleanup.caches": "Caches utilisateur", "cleanup.caches.help": "Fichiers sous ~/Library/Caches.",
        "cleanup.logs": "Journaux utilisateur", "cleanup.logs.help": "Fichiers sous ~/Library/Logs.",
        "cleanup.crashes": "Rapports de crash", "cleanup.crashes.help": "Uniquement les rapports .crash de DiagnosticReports.",
        "cleanup.derived": "Données dérivées Xcode", "cleanup.derived.help": "Fichiers sous Xcode/DerivedData.",
        "cleanup.downloads": "Téléchargements incomplets", "cleanup.downloads.help": "Uniquement les fichiers finissant par .download.",
        "cleanup.deviceSupport": "Support d’appareils Xcode", "cleanup.deviceSupport.help": "Fichiers sous iOS DeviceSupport.",
        "cleanup.iosBackups": "Sauvegardes iOS", "cleanup.iosBackups.help": "Fichiers sous MobileSync/Backup.",
        "cleanup.risk.low": "Risque faible", "cleanup.risk.medium": "Risque moyen", "cleanup.risk.high": "Risque élevé",
        "cleanup.choose": "Choisir le dossier de cette règle", "cleanup.choose.hint": "Choisissez exactement le dossier indiqué ci-dessus.",
        "cleanup.rootMismatch": "Choisissez exactement le dossier indiqué pour cette règle.",
        "cleanup.scan": "Examiner cette règle", "cleanup.scan.hint": "Lit le dossier indiqué sans modifier ses fichiers.",
        "cleanup.noAction": "Sélectionnez des éléments à examiner. Aucun déplacement sans confirmation.",
        "cleanup.partial": "Certains éléments n’ont pas pu être lus.", "cleanup.none": "Aucun fichier correspondant.",
        "apps.choose": "Choisir un dossier d’applications", "apps.choose.hint": "Lit uniquement les métadonnées des apps de ce dossier.",
        "apps.limits": "Cet inventaire lit les métadonnées des apps .app au premier niveau. Il ne désinstalle pas et ne vérifie pas les mises à jour.",
        "apps.empty": "Aucune app trouvée", "apps.failed": "Impossible de lire les métadonnées des apps.",
        "integrity.choose": "Choisir une app à examiner", "integrity.choose.hint": "Vérifie localement la signature de l’app sélectionnée.",
        "integrity.limit": "La validation de signature est un signal système. Elle ne détermine pas si une app est malveillante ou sûre.",
        "integrity.progress": "Vérification de la signature…", "integrity.valid": "La signature est validée par le système",
        "integrity.invalid": "La signature n’est pas validée", "integrity.unavailable": "Informations de signature indisponibles",
        "integrity.identifier": "Identifiant du bundle", "integrity.team": "Équipe de signature", "integrity.status": "Code d’état système",
        "integrity.quarantine.present": "Marqueur de quarantaine macOS présent", "integrity.quarantine.absent": "Aucun marqueur de quarantaine observé",
        "integrity.quarantine.unavailable": "Marqueur de quarantaine indisponible", "integrity.quarantine.limit": "Sa présence ne prouve ni l’origine ni la sûreté; son absence ne prouve pas que l’app est sûre.",
        "onboarding.title": "Bienvenue dans CoreTend"
    ]
    public static func value(for key: String, french isFrench: Bool) -> String {
        (isFrench ? french : english)[key] ?? key
    }
}
