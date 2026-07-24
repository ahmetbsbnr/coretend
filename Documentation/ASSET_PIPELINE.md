# ASSET PIPELINE

## Source de vérité
`Resources/Brand/Sources/generate-brand-assets.swift` — CoreGraphics pur,
partage la géométrie `MCBloomGeometry` (copie synchronisée; test
BloomGeometryTests garde les invariants côté app).

## Régénération
```sh
swift Resources/Brand/Sources/generate-brand-assets.swift
iconutil -c icns Resources/Brand/Generated/AppIcon.iconset -o Resources/Brand/Generated/AppIcon.icns
```

## Sorties (`Resources/Brand/Generated/`)
- `AppIcon.iconset/` — 16→512 @1x/@2x (traits épaissis < 64 px).
- `AppIcon.icns` — référencé par Info.plist (CFBundleIconFile).
- `MenuBarTemplate.png` / `@2x` — template monochrome 18/36 px.
- `AppIcon-1024.png` — export marketing.

## Intégration bundle
`Scripts/package-local.sh` copie icns + templates dans
`CoreTend.app/Contents/Resources/`. L'app ne lit jamais le dépôt:
`Bundle.main.path(forResource:)` uniquement. Tests BrandResourceTests vérifient
la présence des fichiers générés et la déclaration plist.

## Règles pour tout nouvel asset
1. Source vectorielle ou générateur versionné dans `Resources/Brand/Sources/`.
2. Export optimisé, sans métadonnées, variantes clair/sombre si nécessaire.
3. Vérification à 16 px avant intégration.
4. Copie bundle via package-local.sh + test de présence.
5. Pas de grande image raster; PDF/PNG optimisé seulement si indispensable.
