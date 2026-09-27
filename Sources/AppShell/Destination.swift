public enum Destination: String, CaseIterable, Sendable, Identifiable {
    case overview, record, cleanup, explore, duplicates, applications, integrity, performance
    public var id: String { rawValue }
    public static func restored(from rawValue: String?) -> Destination {
        guard let rawValue, let destination = Destination(rawValue: rawValue) else { return .overview }
        return destination
    }
    public var route: DestinationRoute {
        switch self {
        case .overview: .overview
        case .record: .record
        case .cleanup: .cleanup
        case .explore: .explore
        case .duplicates: .duplicates
        case .applications: .applications
        case .integrity: .integrity
        case .performance: .performance
        }
    }
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

public enum DestinationRoute: String, CaseIterable, Hashable, Sendable {
    case overview, record, cleanup, explore, duplicates, applications, integrity, performance
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
        "scan.accessDenied": "Access to the selected folder is unavailable.", "scan.rootAccessDenied": "macOS denied access to the selected folder.",
        "scan.rootUnavailable": "The selected folder's availability could not be determined.", "scan.partial": "Some items could not be read.",
        "scan.rootMissing": "The selected folder no longer exists.", "scan.rootSymlink": "The selected folder is a symbolic link; choose its real folder.",
        "scan.rootExcluded": "This folder is excluded in Settings.", "scan.rootNotFolder": "The selected item is not a folder.",
        "scan.empty": "No files found in the selected folder.", "scan.unknownSize": "Unknown size",
        "preview.unavailable": "This file is no longer available inside the selected folder.",
        "scan.cancelled": "Scan cancelled.", "scan.cancel": "Cancel scan", "duplicates.choose": "Choose a folder to compare",
        "explore.search": "Search names and folders", "explore.sort": "Sort", "explore.largest": "Largest local size", "explore.oldest": "Oldest first", "explore.name": "Name",
        "explore.preview": "Preview",
        "explore.delete.select": "Select file",
        "explore.delete.review": "Review selected files",
        "spacelens.delete.title": "Move selected files to Trash?",
        "spacelens.delete.confirm": "Move files to Trash",
        "spacelens.delete.success.one": "file moved to Trash",
        "spacelens.delete.success.many": "files moved to Trash",
        "spacelens.delete.partial.one": "additional file could not be moved to Trash",
        "spacelens.delete.partial.many": "additional files could not be moved to Trash",
        "spacelens.delete.failed.one": "file could not be moved to Trash",
        "spacelens.delete.failed.many": "files could not be moved to Trash",
        "spacelens.delete.blocked": "History unavailable; move blocked.",
        "spacelens.delete.cancelled": "Move cancelled; cancellation recorded.",
        "spacelens.delete.cancelled.unrecorded": "Move cancelled; cancellation could not be recorded.",
        "duplicates.choose.hint": "CoreTend compares file contents and does not change them.",
        "duplicates.none": "No exact duplicates found", "duplicates.keep": "Suggested file to keep",
        "duplicates.noAction": "Nothing has been moved. Review remains in your control.",
        "settings.title": "Settings", "settings.language": "Language", "settings.system": "Follow system",
        "settings.menubar.title": "Show CoreTend in the menu bar",
        "settings.menubar.help": "Adds quick access to existing destinations and Settings. Disabled by default.",
        "settings.folderaccess.help": "CoreTend accesses only folders you choose in the macOS picker. If a folder becomes unavailable, check that it still exists, its volume is mounted, and your account can read it, then choose it again. App exclusions or macOS privacy protections can limit individual items.",
        "settings.fulldiskaccess.help": "CoreTend does not request Full Disk Access and cannot open Privacy settings on your behalf. A partial or denied scan does not mean an item is absent or safe.",
        "settings.signature.title": "This copy’s signature",
        "settings.signature.valid": "This app bundle passes system signature validation",
        "settings.signature.invalid": "This app bundle did not pass system signature validation",
        "settings.signature.unavailable": "Signature information unavailable",
        "settings.signature.limit": "This local check describes the installed bundle only. It does not establish publisher identity, malware status, or safety.",
        "command.palette.title": "Go to or open…", "command.palette.search": "Search destinations and actions",
        "command.palette.empty": "No matching destinations or actions",
        "metrics.refresh": "Refresh measurements", "metrics.unavailable": "System measurements unavailable",
        "metrics.freeSpace": "Volume free space", "metrics.available": "reported by macOS",
        "metrics.trashNote": "This value does not subtract items in Trash.", "metrics.volumeTotal": "Volume capacity",
        "metrics.measured": "Measured", "metrics.unknown": "Unknown",
        "metrics.scope": "Source: macOS system measurements at the time shown. These observations are not a system-health diagnosis and do not estimate recoverable space.",
        "metrics.source.volume": "Source: macOS filesystem attributes for `/`",
        "metrics.source.load": "Source: macOS 1-minute load average",
        "metrics.source.processors": "Source: ProcessInfo.activeProcessorCount",
        "metrics.source.memory": "Source: ProcessInfo.physicalMemory",
        "metrics.source.uptime": "Source: ProcessInfo.systemUptime",
        "metrics.source.thermal": "Source: ProcessInfo.thermalState",
        "metrics.processors": "Available processor cores", "metrics.memory": "Physical memory capacity",
        "metrics.uptime": "System uptime", "metrics.thermal": "Thermal state",
        "metrics.loadAverage": "1-minute system load", "metrics.history": "Local measurement history",
        "metrics.historyHelp": "Measured when this view refreshes. Points show 1-minute system load, not CPU percent. Stored locally for 30 days, up to 500 readings.",
        "metrics.historyEmpty": "No known load measurements yet", "metrics.historyError": "Local measurement history is unavailable.",
        "metrics.clear": "Clear performance history…", "metrics.clear.title": "Clear performance readings?",
        "metrics.clear.message": "This removes saved performance readings from CoreTend’s local database. A new reading appears when this view refreshes or reopens.",
        "metrics.clear.confirm": "Clear readings", "metrics.clear.done": "Saved performance readings cleared.",
        "thermal.nominal": "Nominal", "thermal.fair": "Fair", "thermal.serious": "Serious",
        "thermal.critical": "Critical", "thermal.unknown": "Unknown",
        "record.filter": "Filter", "record.all": "All events", "record.range": "Date range",
        "record.range.all": "All dates", "record.range.last7": "Last 7 days", "record.range.last30": "Last 30 days",
        "record.actions": "Record actions", "record.export.json": "Export JSON…",
        "record.export.csv": "Export CSV…", "record.clear": "Clear history…", "record.clear.title": "Clear local history?",
        "record.clear.message": "This permanently removes CoreTend activity records from this reconstruction’s local database.",
        "record.clear.confirm": "Clear history", "record.empty": "No recorded actions yet",
        "record.localNotice": "Activity is stored locally. Export files may contain private names and paths.",
        "record.error": "Local history is unavailable.", "common.cancel": "Cancel",
        "activity.proposed": "Proposed", "activity.approved": "Approved", "activity.refused": "Declined",
        "activity.cancelled": "Cancelled", "activity.movedToTrash": "Moved to Trash", "activity.failed": "Failed",
        "activity.reason.trashFailed": "Could not move to Trash.",
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
        "apps.limits": "Inventory reads top-level .app metadata only. You can review moving one chosen app bundle to Trash; associated data stay in place. Updates are not checked.",
        "apps.empty": "No app bundles found", "apps.failed": "App metadata could not be read.",
        "integrity.choose": "Choose an app to inspect", "integrity.choose.hint": "Checks the selected app’s code signature locally.",
        "integrity.limit": "Signature validation reports one native signal. It does not determine whether an app is malware or safe.",
        "integrity.progress": "Checking signature…", "integrity.valid": "Signature passes system validation",
        "integrity.invalid": "Signature did not pass validation", "integrity.unavailable": "Signature information unavailable",
        "integrity.identifier": "Bundle identifier", "integrity.team": "Signing team", "integrity.status": "System status code",
        "integrity.quarantine.present": "macOS quarantine marker present", "integrity.quarantine.absent": "No quarantine marker observed",
        "integrity.quarantine.unavailable": "Quarantine marker unavailable", "integrity.quarantine.limit": "Marker presence does not prove origin or safety; absence does not prove the app is safe.",
        "integrity.loginItems.choose": "Choose a LaunchAgents folder", "integrity.loginItems.choose.hint": "Reviews plist files in the folder you select; no standard folders are scanned automatically.",
        "integrity.loginItems.limit": "Lists configured candidates from direct-child plist files only. This does not show whether an item is enabled, loaded, active, trusted, or safe.",
        "integrity.loginItems.progress": "Reviewing configured candidates…", "integrity.loginItems.results": "Configured candidates",
        "integrity.loginItems.empty": "No configured candidates or review issues found.", "integrity.loginItems.unknownLabel": "Label unavailable",
        "integrity.loginItems.executable": "Configured executable", "integrity.loginItems.plist": "Property list",
        "integrity.loginItems.issue.directory": "The selected folder could not be read.",
        "integrity.loginItems.issue.unreadable": "This property list could not be read.",
        "integrity.loginItems.issue.malformed": "This file is not a readable property list dictionary.",
        "integrity.loginItems.issue.tooLarge": "This property list exceeds the 1 MiB review limit.",
        "integrity.loginItems.issue.limit": "The review stopped at 500 property list candidates.",
        "onboarding.title": "Welcome to CoreTend",
        "onboarding.scope": "Choose folders yourself. Scans stay local and read-only. Any move requires selection, review and confirmation to macOS Trash.",
        "onboarding.privacy": "CoreTend does not request Full Disk Access. You can begin without granting additional access.",
        "onboarding.start": "Get started"
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
        "scan.accessDenied": "L’accès au dossier sélectionné est indisponible.", "scan.rootAccessDenied": "macOS a refusé l’accès au dossier sélectionné.",
        "scan.rootUnavailable": "Impossible de déterminer la disponibilité du dossier choisi.", "scan.partial": "Certains éléments n’ont pas pu être lus.",
        "scan.rootMissing": "Le dossier choisi n’existe plus.", "scan.rootSymlink": "Le dossier choisi est un lien symbolique; choisissez le dossier réel.",
        "scan.rootExcluded": "Ce dossier est exclu dans les réglages.", "scan.rootNotFolder": "L’élément choisi n’est pas un dossier.",
        "scan.empty": "Aucun fichier dans le dossier sélectionné.", "scan.unknownSize": "Taille inconnue",
        "preview.unavailable": "Ce fichier n’est plus disponible dans le dossier sélectionné.",
        "scan.cancelled": "Analyse annulée.", "scan.cancel": "Annuler l’analyse", "duplicates.choose": "Choisir un dossier à comparer",
        "explore.search": "Rechercher noms et dossiers", "explore.sort": "Trier", "explore.largest": "Plus grande taille locale", "explore.oldest": "Plus ancien d’abord", "explore.name": "Nom",
        "explore.preview": "Aperçu",
        "explore.delete.select": "Sélectionner le fichier",
        "explore.delete.review": "Examiner les fichiers sélectionnés",
        "spacelens.delete.title": "Déplacer les fichiers sélectionnés vers la Corbeille ?",
        "spacelens.delete.confirm": "Déplacer les fichiers vers la Corbeille",
        "spacelens.delete.success.one": "fichier déplacé vers la Corbeille",
        "spacelens.delete.success.many": "fichiers déplacés vers la Corbeille",
        "spacelens.delete.partial.one": "fichier supplémentaire n’a pas pu être déplacé vers la Corbeille",
        "spacelens.delete.partial.many": "fichiers supplémentaires n’ont pas pu être déplacés vers la Corbeille",
        "spacelens.delete.failed.one": "fichier n’a pas pu être déplacé vers la Corbeille",
        "spacelens.delete.failed.many": "fichiers n’ont pas pu être déplacés vers la Corbeille",
        "spacelens.delete.blocked": "Historique indisponible ; déplacement bloqué.",
        "spacelens.delete.cancelled": "Déplacement annulé ; annulation enregistrée.",
        "spacelens.delete.cancelled.unrecorded": "Déplacement annulé ; annulation non enregistrée.",
        "duplicates.choose.hint": "CoreTend compare le contenu des fichiers sans les modifier.",
        "duplicates.none": "Aucun doublon exact trouvé", "duplicates.keep": "Fichier proposé à conserver",
        "duplicates.noAction": "Aucun fichier déplacé. Vous gardez le contrôle des actions.",
        "settings.title": "Réglages", "settings.language": "Langue", "settings.system": "Langue du système",
        "settings.menubar.title": "Afficher CoreTend dans la barre des menus",
        "settings.menubar.help": "Ajoute un accès rapide aux destinations existantes et aux réglages. Désactivé par défaut.",
        "settings.folderaccess.help": "CoreTend accède uniquement aux dossiers que vous choisissez dans le sélecteur macOS. Si un dossier devient indisponible, vérifiez qu’il existe encore, que le volume est monté et que votre compte peut le lire, puis choisissez-le à nouveau. Les exclusions de cette app ou les protections de confidentialité macOS peuvent limiter certains éléments.",
        "settings.fulldiskaccess.help": "CoreTend ne demande pas l’accès intégral au disque et ne peut pas ouvrir à votre place les réglages de confidentialité. Un scan partiel ou refusé ne signifie pas qu’un élément est absent ni qu’il est sûr.",
        "settings.signature.title": "Signature de cette copie",
        "settings.signature.valid": "Le bundle de cette app est validé par le système",
        "settings.signature.invalid": "Le bundle de cette app n’est pas validé par le système",
        "settings.signature.unavailable": "Informations de signature indisponibles",
        "settings.signature.limit": "Cette vérification locale concerne uniquement le bundle installé. Elle ne prouve ni l’identité de l’éditeur, ni la présence d’un logiciel malveillant, ni la sûreté.",
        "command.palette.title": "Accéder à…", "command.palette.search": "Rechercher une destination ou une action",
        "command.palette.empty": "Aucune destination ni action correspondante",
        "metrics.refresh": "Actualiser les mesures", "metrics.unavailable": "Mesures système indisponibles",
        "metrics.freeSpace": "Espace libre du volume", "metrics.available": "indiqué par macOS",
        "metrics.trashNote": "Cette valeur ne soustrait pas les éléments de la Corbeille.", "metrics.volumeTotal": "Capacité du volume",
        "metrics.measured": "Mesuré", "metrics.unknown": "Inconnu",
        "metrics.scope": "Source : mesures système macOS à l’heure indiquée. Ces observations ne constituent pas un diagnostic de santé du système et n’estiment pas l’espace récupérable.",
        "metrics.source.volume": "Source : attributs du système de fichiers macOS pour `/`",
        "metrics.source.load": "Source : charge système macOS sur 1 minute",
        "metrics.source.processors": "Source : ProcessInfo.activeProcessorCount",
        "metrics.source.memory": "Source : ProcessInfo.physicalMemory",
        "metrics.source.uptime": "Source : ProcessInfo.systemUptime",
        "metrics.source.thermal": "Source : ProcessInfo.thermalState",
        "metrics.processors": "Cœurs de processeur disponibles", "metrics.memory": "Mémoire physique installée",
        "metrics.uptime": "Temps de fonctionnement", "metrics.thermal": "État thermique",
        "metrics.loadAverage": "Charge système sur 1 minute", "metrics.history": "Historique local des mesures",
        "metrics.historyHelp": "Mesuré à chaque actualisation de cette vue. Les points indiquent la charge sur 1 minute, pas un pourcentage CPU. Conservation locale : 30 jours, 500 relevés au plus.",
        "metrics.historyEmpty": "Aucune mesure de charge connue", "metrics.historyError": "Historique local des mesures indisponible.",
        "metrics.clear": "Effacer les relevés Performance…", "metrics.clear.title": "Effacer les relevés Performance ?",
        "metrics.clear.message": "Les relevés enregistrés sont retirés de la base locale CoreTend. Un nouveau relevé apparaît quand cette vue est actualisée ou rouverte.",
        "metrics.clear.confirm": "Effacer les relevés", "metrics.clear.done": "Relevés Performance enregistrés effacés.",
        "thermal.nominal": "Normal", "thermal.fair": "Modéré", "thermal.serious": "Élevé",
        "thermal.critical": "Critique", "thermal.unknown": "Inconnu",
        "record.filter": "Filtrer", "record.all": "Tous les événements", "record.range": "Période",
        "record.range.all": "Toutes les dates", "record.range.last7": "7 derniers jours", "record.range.last30": "30 derniers jours",
        "record.actions": "Actions de l’historique", "record.export.json": "Exporter en JSON…",
        "record.export.csv": "Exporter en CSV…", "record.clear": "Effacer l’historique…", "record.clear.title": "Effacer l’historique local ?",
        "record.clear.message": "Cette action supprime définitivement les événements CoreTend de la base locale de cette reconstruction.",
        "record.clear.confirm": "Effacer l’historique", "record.empty": "Aucune action enregistrée",
        "record.localNotice": "L’activité reste locale. Les exports peuvent contenir des noms et chemins privés.",
        "record.error": "L’historique local est indisponible.", "common.cancel": "Annuler",
        "activity.proposed": "Proposé", "activity.approved": "Approuvé", "activity.refused": "Refusé",
        "activity.cancelled": "Annulé", "activity.movedToTrash": "Déplacé dans la Corbeille", "activity.failed": "Échec",
        "activity.reason.trashFailed": "Déplacement vers la Corbeille impossible.",
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
        "apps.limits": "L’inventaire lit les métadonnées des .app au premier niveau. Vous pouvez revoir le déplacement d’un bundle choisi vers la Corbeille; les données associées restent en place. Mises à jour non vérifiées.",
        "apps.empty": "Aucune app trouvée", "apps.failed": "Impossible de lire les métadonnées des apps.",
        "integrity.choose": "Choisir une app à examiner", "integrity.choose.hint": "Vérifie localement la signature de l’app sélectionnée.",
        "integrity.limit": "La validation de signature est un signal système. Elle ne détermine pas si une app est malveillante ou sûre.",
        "integrity.progress": "Vérification de la signature…", "integrity.valid": "La signature est validée par le système",
        "integrity.invalid": "La signature n’est pas validée", "integrity.unavailable": "Informations de signature indisponibles",
        "integrity.identifier": "Identifiant du bundle", "integrity.team": "Équipe de signature", "integrity.status": "Code d’état système",
        "integrity.quarantine.present": "Marqueur de quarantaine macOS présent", "integrity.quarantine.absent": "Aucun marqueur de quarantaine observé",
        "integrity.quarantine.unavailable": "Marqueur de quarantaine indisponible", "integrity.quarantine.limit": "Sa présence ne prouve ni l’origine ni la sûreté; son absence ne prouve pas que l’app est sûre.",
        "integrity.loginItems.choose": "Choisir un dossier LaunchAgents", "integrity.loginItems.choose.hint": "Examine les fichiers plist du dossier choisi; aucun dossier connu n’est analysé automatiquement.",
        "integrity.loginItems.limit": "Liste les candidats configurés des fichiers plist directement présents dans le dossier. Cela n’indique pas si un élément est activé, chargé, actif, fiable ou sûr.",
        "integrity.loginItems.progress": "Examen des candidats configurés…", "integrity.loginItems.results": "Candidats configurés",
        "integrity.loginItems.empty": "Aucun candidat configuré ni problème de lecture.", "integrity.loginItems.unknownLabel": "Libellé indisponible",
        "integrity.loginItems.executable": "Exécutable configuré", "integrity.loginItems.plist": "Liste de propriétés",
        "integrity.loginItems.issue.directory": "Impossible de lire le dossier choisi.",
        "integrity.loginItems.issue.unreadable": "Impossible de lire cette liste de propriétés.",
        "integrity.loginItems.issue.malformed": "Ce fichier ne contient pas de dictionnaire plist lisible.",
        "integrity.loginItems.issue.tooLarge": "Cette liste de propriétés dépasse la limite d’examen de 1 Mio.",
        "integrity.loginItems.issue.limit": "L’examen s’est arrêté à 500 fichiers plist candidats.",
        "onboarding.title": "Bienvenue dans CoreTend",
        "onboarding.scope": "Choisissez vous-même les dossiers. Les scans restent locaux et en lecture seule. Tout déplacement demande sélection, revue et confirmation vers la Corbeille macOS.",
        "onboarding.privacy": "CoreTend ne demande pas l’accès intégral au disque. Vous pouvez commencer sans autoriser d’accès supplémentaire.",
        "onboarding.start": "Commencer"
    ]
    public static func value(for key: String, french isFrench: Bool) -> String {
        (isFrench ? french : english)[key] ?? key
    }

    public static func scanResultAccessibilitySummary(name: String, source: String, state: String,
                                                       allocated: String, logical: String, modified: String,
                                                       french isFrench: Bool) -> String {
        if isFrench {
            return "\(name). Source : \(source). État : \(state). Allouée localement : \(allocated). Taille logique : \(logical). Modifié : \(modified). Candidat à examiner avant toute action."
        }
        return "\(name). Source: \(source). State: \(state). Allocated locally: \(allocated). Logical size: \(logical). Modified: \(modified). Candidate to review before action."
    }

    public static func activityDetail(_ detail: String, failureCode: String?, french isFrench: Bool) -> String {
        guard failureCode == "trash_failed" else { return detail }
        let marker = " | reason=trash_failed"
        let path = detail.hasSuffix(marker) ? String(detail.dropLast(marker.count)) : detail
        return "\(path) — \(value(for: "activity.reason.trashFailed", french: isFrench))"
    }

    public static func savedFileAvailability(isPresent: Bool, french isFrench: Bool) -> String {
        if isFrench {
            return isPresent ? "Présent (accès actuel non garanti)" : "Absent ou inaccessible"
        }
        return isPresent ? "Present (current access not verified)" : "Missing or inaccessible"
    }

    public static func scanRootFailure(reason: String, french isFrench: Bool) -> String {
        let key: String
        switch reason {
        case "permission_denied": key = "scan.rootAccessDenied"
        case "missing": key = "scan.rootMissing"
        case "root_symlink": key = "scan.rootSymlink"
        case "root_excluded": key = "scan.rootExcluded"
        case "root_not_directory": key = "scan.rootNotFolder"
        case "metadata_unavailable", "directory_read_failed": key = "scan.rootUnavailable"
        default: key = "scan.rootUnavailable"
        }
        return value(for: key, french: isFrench)
    }

    public static func scanPartialFailure(reasons: Set<String>, french isFrench: Bool) -> String {
        let denied = reasons.contains("permission_denied")
        let missing = reasons.contains("missing")
        let other = reasons.contains(where: { !["permission_denied", "missing"].contains($0) })
        if isFrench {
            if denied && other { return "macOS a refusé l’accès à certains éléments; les détails d’autres éléments n’ont pas pu être lus." }
            if denied { return "macOS a refusé l’accès à certains éléments du dossier choisi." }
            if missing && other { return "Certains éléments ont disparu pendant l’analyse; d’autres détails n’ont pas pu être lus." }
            if missing { return "Certains éléments ont disparu pendant l’analyse." }
            return "Les détails de certains éléments n’ont pas pu être lus."
        }
        if denied && other { return "macOS denied access to some items; details for other items could not be read." }
        if denied { return "macOS denied access to some items in the chosen folder." }
        if missing && other { return "Some items disappeared during the scan; details for others could not be read." }
        if missing { return "Some items disappeared during the scan." }
        return "Details for some items could not be read."
    }

    public static func scanProgress(completedFiles: Int, french isFrench: Bool) -> String {
        let count = max(0, completedFiles)
        if isFrench { return count == 1 ? "1 fichier examiné" : "\(count) fichiers examinés" }
        return "\(count) files examined"
    }

    public static func duplicateHashProgress(completed: Int, total: Int, french isFrench: Bool) -> String {
        let total = max(0, total)
        let done = min(max(0, completed), total)
        return isFrench ? "Hachage des candidats : \(done)/\(total)" : "Hashing candidates: \(done)/\(total)"
    }

    public static func similarImageProgress(completed: Int, total: Int, comparingPairs: Bool, french isFrench: Bool) -> String {
        let total = max(0, total)
        let done = min(max(0, completed), total)
        if comparingPairs {
            return isFrench ? "Comparaison des paires : \(done)/\(total)" : "Comparing pairs: \(done)/\(total)"
        }
        return isFrench ? "Analyse des images : \(done)/\(total)" : "Checking images: \(done)/\(total)"
    }
}
