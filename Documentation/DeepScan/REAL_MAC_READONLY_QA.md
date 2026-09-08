# CoreTend Deep Scan — READ-ONLY QA report
Generated: 2026-09-08T20:34:43Z

## Scan
- roots: /Users/ahmetbasbunar/.claude, /Users/ahmetbasbunar/.codex, /Users/ahmetbasbunar/.cache, /Users/ahmetbasbunar/Library/Caches, /Users/ahmetbasbunar/Developer, /Users/ahmetbasbunar/Downloads, /Users/ahmetbasbunar/Library/LaunchAgents
- nodes observed: 126396
- wall time: 3.0s
- cancelled: false   timed out: false
- roots we could not read: /Users/ahmetbasbunar/Library/Caches/CloudKit, /Users/ahmetbasbunar/Library/Caches/FamilyCircle, /Users/ahmetbasbunar/Library/Caches/com.apple.HomeKit, /Users/ahmetbasbunar/Library/Caches/com.apple.Safari, /Users/ahmetbasbunar/Library/Caches/com.apple.Safari.SafeBrowsing, /Users/ahmetbasbunar/Library/Caches/com.apple.ap.adprivacyd, /Users/ahmetbasbunar/Library/Caches/com.apple.containermanagerd, /Users/ahmetbasbunar/Library/Caches/com.apple.homed, /Users/ahmetbasbunar/Library/Caches/familycircled
- permission-denied nodes: 9   partial nodes: 1

## Installed apps & git repos
- installed apps discovered: 79
- git repositories discovered: 8
  - [YELLOW] /Users/ahmetbasbunar/.claude/plugins/marketplaces/context-mode — branch main, dirty=false, stashes=0, unpushed=0
  - [YELLOW] /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio — branch main, dirty=false, stashes=0, unpushed=0
  - [RED] /Users/ahmetbasbunar/Developer/Website/products/coretend/app — branch feat/deep-scan-cleanup-v1.2, dirty=true, stashes=0, unpushed=9
  - [YELLOW] /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/checkouts/swift-syntax — branch detached, dirty=false, stashes=0, unpushed=0
  - [YELLOW] /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/checkouts/swift-testing — branch detached, dirty=false, stashes=0, unpushed=0
  - [YELLOW] /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/checkouts/swift-syntax — branch detached, dirty=false, stashes=0, unpushed=0
  - [YELLOW] /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/checkouts/swift-testing — branch detached, dirty=false, stashes=0, unpushed=0
  - [RED] /Users/ahmetbasbunar/Library/Caches/mise/python/pyenv — branch detached, dirty=false, stashes=0, unpushed=0

## Candidates by category
### appsAndLeftovers — 7 candidates, ~11.1 MB reviewable, 0 protected
- 10.6 MB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.adobe.lightroomCC
    owner: com.adobe.lightroomCC  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “com.adobe.lightroomCC”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “com.adobe.lightroomCC”
    · No installed app or helper claims this identifier
    · Last changed about 4 days ago
- 131 KB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.google.GoogleUpdater
    owner: com.google.GoogleUpdater  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “com.google.GoogleUpdater”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “com.google.GoogleUpdater”
    · No installed app or helper claims this identifier
    · Last changed about 1 days ago
- 82 KB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.openai.sky.CUAService
    owner: com.openai.sky.CUAService  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “com.openai.sky.CUAService”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “com.openai.sky.CUAService”
    · No installed app or helper claims this identifier
    · Last changed about 35 days ago
- 60 KB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.electron.ollama
    owner: com.electron.ollama  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “com.electron.ollama”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “com.electron.ollama”
    · No installed app or helper claims this identifier
    · Last changed about 36 days ago
- 27 KB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/dev.sigstore.sigstore-rust
    owner: dev.sigstore.sigstore-rust  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “dev.sigstore.sigstore-rust”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “dev.sigstore.sigstore-rust”
    · No installed app or helper claims this identifier
    · Last changed about 9 days ago
- 1 KB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.vercel.cli
    owner: com.vercel.cli  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “com.vercel.cli”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “com.vercel.cli”
    · No installed app or helper claims this identifier
    · Last changed about 1 days ago
- 8 bytes  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/org.webkit.Playwright
    owner: org.webkit.Playwright  subcategory: orphanedContainer  default-selected: false
    why: Appears to belong to “org.webkit.Playwright”, which is not installed.
    if removed: If you reinstall that app it will recreate this folder.
    · No installed app declares the bundle ID “org.webkit.Playwright”
    · No installed app or helper claims this identifier
    · Last changed about 35 days ago

### aiAndLLM — 99 candidates, ~5.43 GB reviewable, 90 protected
- 3.55 GB  [highRisk/weak]  /Users/ahmetbasbunar/.cache/lm-studio/models
    owner: LM Studio  subcategory: modelWeights  default-selected: false
    why: LM Studio — model weights.
    if removed: You would re-download these model weights (can be many GB).
    · Inside LM Studio's data folder
- 1.16 GB  [review/weak]  /Users/ahmetbasbunar/.cache/lm-studio/extensions
    owner: LM Studio  subcategory: extensionsPlugins  default-selected: false
    why: LM Studio — extensions / plugins.
    if removed: You would reinstall the extensions.
    · Inside LM Studio's data folder
- 319.3 MB  [review/weak]  /Users/ahmetbasbunar/.codex/plugins
    owner: Codex  subcategory: extensionsPlugins  default-selected: false
    why: Codex — extensions / plugins.
    if removed: You would reinstall the extensions.
    · Inside Codex's data folder
- 313.3 MB  [protected/unknown]  /Users/ahmetbasbunar/.claude/projects
    owner: Claude Code  subcategory: projectState  default-selected: false
    why: Claude Code — per-project state.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code per-project state — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code per-project state — protected user state
- 225.5 MB  [safe/weak]  /Users/ahmetbasbunar/.cache/lm-studio/.internal
    owner: LM Studio  subcategory: runtimeCache  default-selected: false
    why: LM Studio — runtime cache.
    if removed: LM Studio recreates this automatically.
    · Inside LM Studio's data folder
- 172.5 MB  [protected/unknown]  /Users/ahmetbasbunar/.codex/sessions
    owner: Codex  subcategory: conversationHistory  default-selected: false
    why: Codex — conversation history.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex conversation history — protected user state
    · Inside Codex's data folder
    · This is Codex conversation history — protected user state
- 65.1 MB  [safe/weak]  /Users/ahmetbasbunar/.cache/lm-studio/bin
    owner: LM Studio  subcategory: runtimeCache  default-selected: false
    why: LM Studio — runtime cache.
    if removed: LM Studio recreates this automatically.
    · Inside LM Studio's data folder
- 24.9 MB  [review/weak]  /Users/ahmetbasbunar/.claude/plugins
    owner: Claude Code  subcategory: extensionsPlugins  default-selected: false
    why: Claude Code — extensions / plugins.
    if removed: You would reinstall the extensions.
    · Inside Claude Code's data folder
- 17.7 MB  [protected/unknown]  /Users/ahmetbasbunar/.claude/file-history
    owner: Claude Code  subcategory: projectState  default-selected: false
    why: Claude Code — per-project state.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code per-project state — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code per-project state — protected user state
- 9.9 MB  [protected/unknown]  /Users/ahmetbasbunar/.codex/thread_history_1.sqlite
    owner: Codex  subcategory: conversationHistory  default-selected: false
    why: Codex — conversation history.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex conversation history — protected user state
    · Inside Codex's data folder
    · This is Codex conversation history — protected user state
- 2.5 MB  [protected/unknown]  /Users/ahmetbasbunar/.codex/state_5.sqlite
    owner: Codex  subcategory: projectState  default-selected: false
    why: Codex — per-project state.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex per-project state — protected user state
    · Inside Codex's data folder
    · This is Codex per-project state — protected user state
- 967 KB  [safe/weak]  /Users/ahmetbasbunar/.cache/lm-studio/server-logs
    owner: LM Studio  subcategory: runtimeCache  default-selected: false
    why: LM Studio — runtime cache.
    if removed: LM Studio recreates this automatically.
    · Inside LM Studio's data folder
- 598 KB  [protected/unknown]  /Users/ahmetbasbunar/.claude/backups
    owner: Claude Code  subcategory: unknownData  default-selected: false
    why: Claude Code — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code data of an unknown kind — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code data of an unknown kind — protected user state
- 510 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/history.jsonl
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 386 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/skills
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 248 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/models_cache.json
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 214 KB  [protected/unknown]  /Users/ahmetbasbunar/.claude/history.jsonl
    owner: Claude Code  subcategory: unknownData  default-selected: false
    why: Claude Code — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code data of an unknown kind — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code data of an unknown kind — protected user state
- 201 KB  [protected/unknown]  /Users/ahmetbasbunar/.claude/jobs
    owner: Claude Code  subcategory: unknownData  default-selected: false
    why: Claude Code — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code data of an unknown kind — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code data of an unknown kind — protected user state
- 103 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/thread_history_1.sqlite-wal
    owner: Codex  subcategory: conversationHistory  default-selected: false
    why: Codex — conversation history.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex conversation history — protected user state
    · Inside Codex's data folder
    · This is Codex conversation history — protected user state
- 98 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/sqlite
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 82 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/queue_1.sqlite-wal
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 66 KB  [protected/unknown]  /Users/ahmetbasbunar/.claude/paste-cache
    owner: Claude Code  subcategory: unknownData  default-selected: false
    why: Claude Code — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Claude Code data of an unknown kind — protected user state
    · Inside Claude Code's data folder
    · This is Claude Code data of an unknown kind — protected user state
- 51 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/rules
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 44 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/hooks
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state
- 41 KB  [protected/unknown]  /Users/ahmetbasbunar/.codex/queue_1.sqlite
    owner: Codex  subcategory: unknownData  default-selected: false
    why: Codex — data of an unknown kind.
    if removed: This cannot be recovered. CoreTend will not remove it.
    PROTECTED: This is Codex data of an unknown kind — protected user state
    · Inside Codex's data folder
    · This is Codex data of an unknown kind — protected user state

### developer — 34 candidates, ~2.39 GB reviewable, 0 protected
- 1.58 GB  [review/confirmed]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build
    owner: —  subcategory: .build  default-selected: false
    why: SwiftPM build; rebuildable from the project.
    if removed: Recreated by the next build (can take minutes).
    · SwiftPM build directory named .build
    · A project manifest sits next to it, so it can be rebuilt
- 433.5 MB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 261.1 MB  [safe/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/.next
    owner: —  subcategory: .next  default-selected: false
    why: Next.js build output; rebuildable from the project.
    if removed: Recreated by the next build.
    · Next.js build output directory named .next
    · A project manifest sits next to it, so it can be rebuilt
- 25.6 MB  [highRisk/weak]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Recovery cost is unknown — review before removing.
    · npm dependencies directory named node_modules
- 5 MB  [highRisk/weak]  /Users/ahmetbasbunar/Library/Caches/com.apple.python/Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build
    owner: —  subcategory: .build  default-selected: false
    why: SwiftPM build; rebuildable from the project.
    if removed: Recovery cost is unknown — review before removing.
    · SwiftPM build directory named .build
- 3.9 MB  [highRisk/weak]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/Website/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Recovery cost is unknown — review before removing.
    · npm dependencies directory named node_modules
- 3.2 MB  [highRisk/confirmed]  /Users/ahmetbasbunar/.cache/lm-studio/extensions/plugins/lmstudio/js-code-sandbox/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 3.2 MB  [highRisk/confirmed]  /Users/ahmetbasbunar/.cache/lm-studio/extensions/plugins/lmstudio/rag-v1/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 3 MB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/@axe-core/playwright/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 725 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/@typescript-eslint/typescript-estree/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 333 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/eslint-import-resolver-node/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 280 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/eslint-plugin-react/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 156 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/playwright/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 145 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/tinyglobby/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 109 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/@next/eslint-plugin-next/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 106 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/eslint/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 101 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/sharp/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 101 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/is-bun-module/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 78 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/tsconfig-paths/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 63 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/@typescript-eslint/eslint-plugin/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 63 KB  [highRisk/weak]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/vendor/ahmet-design-system/dist
    owner: —  subcategory: dist  default-selected: false
    why: bundler output; rebuildable from the project.
    if removed: Recovery cost is unknown — review before removing.
    · bundler output directory named dist
- 55 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/rimraf/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 53 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/eslint-plugin-import/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 53 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/eslint-module-utils/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt
- 32 KB  [highRisk/confirmed]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio/node_modules/@typescript-eslint/visitor-keys/node_modules
    owner: —  subcategory: node_modules  default-selected: false
    why: npm dependencies; rebuildable from the project.
    if removed: Reinstalling dependencies re-downloads this.
    · npm dependencies directory named node_modules
    · A project manifest sits next to it, so it can be rebuilt

### gitProjects — 8 candidates, ~Zero KB reviewable, 8 protected
- 1.75 GB  [protected/weak]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app
    owner: git@github.com:ahmetbsbnr/coretend-local-archive.git  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Git repository has uncommitted or unpushed work
    · uncommitted changes, 2 untracked files, 9 unpushed commit(s), remote not verified
- 712.5 MB  [protected/unknown]  /Users/ahmetbasbunar/Developer/Website/ahmetbsbnr-portfolio
    owner: git@github.com:ahmetbsbnr/ahmetbsbnrportfolio.git  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 18.6 MB  [protected/unknown]  /Users/ahmetbasbunar/.claude/plugins/marketplaces/context-mode
    owner: git@github.com:mksglu/context-mode.git  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 9.2 MB  [protected/unknown]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/checkouts/swift-syntax
    owner: /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/repositories/swift-syntax-e1f983d3  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 9.2 MB  [protected/unknown]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/checkouts/swift-syntax
    owner: /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/repositories/swift-syntax-e1f983d3  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 1.7 MB  [protected/unknown]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/checkouts/swift-testing
    owner: /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/index-build/repositories/swift-testing-f02b8e0f  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 1.7 MB  [protected/unknown]  /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/checkouts/swift-testing
    owner: /Users/ahmetbasbunar/Developer/Website/products/coretend/app/.build/repositories/swift-testing-f02b8e0f  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Not enough evidence to identify this data
    · remote not verified
- 367 KB  [protected/weak]  /Users/ahmetbasbunar/Library/Caches/mise/python/pyenv
    owner: —  subcategory: repository  default-selected: false
    why: Repository has local-only work — keep it.
    if removed: Local commits, stashes or edits would be lost.
    PROTECTED: Git repository has uncommitted or unpushed work
    · no remote

### systemAndSettings — 9 candidates, ~37 KB reviewable, 0 protected
- 1 KB  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/ai.openclaw.gateway.plist
    owner: ai.openclaw.gateway  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “ai.openclaw.gateway” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 978 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.ntfstool.ntfstool-bright-sdk.plist
    owner: com.ntfstool.ntfstool-bright-sdk  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.ntfstool.ntfstool-bright-sdk” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 973 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.crous.metz.bot.plist
    owner: com.crous.metz.bot  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.crous.metz.bot” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 880 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.google.GoogleUpdater.wake.plist
    owner: com.google.GoogleUpdater.wake  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.google.GoogleUpdater.wake” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 732 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/homebrew.mxcl.mysql.plist
    owner: homebrew.mxcl.mysql  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “homebrew.mxcl.mysql” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 686 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.adobe.GC.Invoker-1.0.plist
    owner: com.adobe.GC.Invoker-1.0  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.adobe.GC.Invoker-1.0” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 638 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.adobe.ccxprocess.plist
    owner: com.adobe.ccxprocess  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.adobe.ccxprocess” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 181 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.google.keystone.agent.plist
    owner: com.google.keystone.agent  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.google.keystone.agent” has no matching installed app
    · Lives in ~/Library/LaunchAgents
- 181 bytes  [review/probable]  /Users/ahmetbasbunar/Library/LaunchAgents/com.google.keystone.xpcservice.plist
    owner: com.google.keystone.xpcservice  subcategory: orphanedLaunchAgent  default-selected: false
    why: A login/background job for an app that is not installed.
    if removed: The background job stops being scheduled at next login.
    · Launch agent “com.google.keystone.xpcservice” has no matching installed app
    · Lives in ~/Library/LaunchAgents

## Safety self-check
- protected candidate default-selected: false  (must be false)
- unknown-confidence default-selected: false  (must be false)
- ~/.claude memory/projects/history default-selected: false  (must be false)
- total default-selected: 0 of 157
## Preselection decision inputs
- total candidates: 157
- risk==SAFE && confidence>=STRONG: 1
  by category: developer=1
- would meet DefaultSelectionPolicy.meetsBar: 1
- in executable SAFE subset (manually selectable for execution): 1
  developer-storage:.next .next
