<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# GitHub Repository Setup

Perform only after explicit authorization:

```sh
git push -u origin feat/coretend-rebrand-workspace
gh pr create --base main --head feat/coretend-rebrand-workspace \
  --title "Complete CoreTend public product presentation" \
  --body-file Documentation/PULL_REQUEST_BODY.md
gh repo edit ahmetbsbnr/coretend \
  --description "Local, transparent and reversible care for macOS." \
  --homepage "https://coretend.ahmetbsbnr.com" \
  --add-topic macos --add-topic swift --add-topic apple-silicon \
  --add-topic disk-usage --add-topic privacy --add-topic open-source
```

Upload `Resources/Brand/Generated/OpenGraph-1200x630.png` as the repository
social preview through Settings → General → Social preview. Confirm the README,
website, security policy, issue templates, PR template, release and topics
render correctly. Do not edit the existing v0.9.0 prerelease as part of this
repository-presentation step.
