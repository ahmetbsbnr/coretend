# Repository social preview

`social-preview.png` (1280×640) is the image GitHub shows when the repo is
linked on social media / chat. GitHub does **not** read it from the repo — a
human uploads it once in **Settings → General → Social preview**.

It is a straight copy of `Resources/Brand/Generated/SocialPreview-1280x640.png`,
produced by `socialPreview()` in
`Resources/Brand/Sources/generate-brand-assets.swift` (checked by
`Scripts/check-brand-assets.sh`). Every element clears GitHub's recommended
40 pt safe border with room to spare, so Slack / Discord / X re-crops do not
clip the mark or the wordmark. Regenerate and re-copy whenever the brand marks
change:

```sh
swift Resources/Brand/Sources/generate-brand-assets.swift
cp Resources/Brand/Generated/SocialPreview-1280x640.png .github/social-preview.png
```
