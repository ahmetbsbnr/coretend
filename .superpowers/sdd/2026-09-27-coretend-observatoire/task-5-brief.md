### Task 5: Redesign Applications and Integrity views

**Base:** `6d744ea fix(app): constrain cleanup to expected folder`

**Files:** `Sources/CoreTendApp/ApplicationsView.swift`, `Sources/CoreTendApp/IntegrityView.swift`.

**Required outcome:** Apply Observatoire semantic surfaces, typography, spacing, status hierarchy and restrained motion. Applications inventory should be searchable/scannable with stable app identity, version and metadata, with its inspection limits beside the data. Integrity should separate signature, quarantine and configured login item evidence into independent sections. Empty, unavailable, malformed and partial states must match existing result state and provide precise next step where possible.

**Preserve:** Existing initializers, chosen-folder scope, metadata inspection, signature/quarantine/login item APIs, single bundle review, local event behavior, revalidation, confirmation and macOS Trash action. Never combine signals into safe/malicious verdict, assert app-data attribution/uninstall safety, expand filesystem scope, or add persistence. No automated tests.

**Acceptance:** Evidence remains labeled by source and limitation; distinct signals stay separate; app bundle action remains isolated and explicitly confirmed; no fake data or blanket status labels. `swift build --product CoreTendApp` only; do not run tests.
