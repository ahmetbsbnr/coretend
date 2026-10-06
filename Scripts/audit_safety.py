#!/usr/bin/env python3
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
errors=[]
scan_core_mutation_patterns = (
 r'\.(?:createDirectory|createFile|copyItem|moveItem|removeItem|replaceItemAt|setAttributes|setUbiquitous|createSymbolicLink|linkItem|trashItem)\s*\(',
 r'\b(?:unlink|unlinkat|rename|renameat|renamex_np|renameatx_np|mkdir|mkdirat|rmdir|chmod|fchmod|fchmodat|chflags|fchflags|chflagsat|truncate|ftruncate|symlink|link|linkat|write|pwrite|fwrite|setxattr|fsetxattr|removexattr|fremovexattr|copyfile|fcopyfile|clonefile|remove|mkfifo|mknod|setattrlist|fsetattrlist|setattrlistat|utimes|futimes|utimensat|futimens|posix_fallocate)\s*\(',
 r'\.write\s*\(', r'\.(?:setResourceValue|setResourceValues)\s*\(',
 r'FileHandle\.(?:write|truncate)\s*\('
)

def scan_core_mutation_findings(text):
 findings = [pattern for pattern in scan_core_mutation_patterns if re.search(pattern,text)]
 direct_open_count = len(re.findall(r'\b(?:open|openat|fopen|freopen)\s*\(',text))
 allowlisted_read_open_count = len(re.findall(
  r'\bopen\s*\(\s*url\.path\s*,\s*O_RDONLY\s*\|\s*O_NOFOLLOW\s*\|\s*O_CLOEXEC\s*\)',text))
 if direct_open_count != allowlisted_read_open_count:
  findings.append('unapproved direct file descriptor open API')
 return findings

for unsafe_scan_sample in ('open(path, O_WRONLY | O_CREAT)', 'fopen(path, "w")',
                           'open(path, flags)', 'fopen(path, mode)', 'openat(dirfd, path, O_RDONLY)',
                           'open(pathFor(url), flags)', 'fopen(pathFor(url), mode)',
                           'copyfile(source, destination, 0)', 'renamex_np(old, new, flags)'):
 if not scan_core_mutation_findings(unsafe_scan_sample):
  errors.append(f'ScanCore mutation audit misses known write API: {unsafe_scan_sample}')
if scan_core_mutation_findings('open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)'):
 errors.append('ScanCore mutation audit rejects its allowlisted read-only hashing open')
for file in (root/'Sources').rglob('*.swift'):
 text=file.read_text()
 # The import reader owns one freshly created private snapshot directory. Only its
 # exact defer cleanup is exempt; arbitrary removals elsewhere remain forbidden.
 if file.relative_to(root).as_posix() == 'Sources/Persistence/LegacyPreferencesImport.swift':
  creation = r'''let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-snapshot-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])'''
  cleanup = 'defer { try? FileManager.default.removeItem(at: root) }'
  if text.count(creation) != 1 or text.count(cleanup) != 1 or creation + '\n        ' + cleanup not in text:
   errors.append('legacy snapshot cleanup must follow exclusive private-directory creation')
  else:
   text = text.replace(cleanup, '', 1)
 # The app's fixture Trash is an isolated test-mode adapter. Keep its two mutation
 # sites allowlisted only while the selector and every move validate the fixture profile.
 if file.relative_to(root).as_posix() == 'Sources/CoreTendApp/AppTrashClient.swift':
  adapter_contract = (
   'CORETEND_TEST_TRASH_DIR' in text
   and text.count('TestStoreOverride.trashDirectory(') == 2
   and 'return UnavailableTrashClient()' in text
   and 'current.path == directory.path' in text
   and 'directory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)' in text
  )
  mutations = ('try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)',
               'try FileManager.default.moveItem(at: url, to: destination)')
  if not adapter_contract or any(text.count(site) != 1 for site in mutations):
   errors.append('fixture Trash adapter no longer satisfies its validated test-only contract')
  else:
   for site in mutations: text = text.replace(site, '', 1)
 for pattern in (r'FileManager\.(?:default\.)?removeItem', r'\bunlink\s*\(', r'FileManager\.(?:default\.)?moveItem', r'\.removeItem\s*\('):
  if re.search(pattern,text): errors.append(f'production mutation API in {file.relative_to(root)}: {pattern}')
trash=[f for f in (root/'Sources').rglob('*.swift') if 'trashItem(' in f.read_text()]
if len(trash)!=1 or trash[0].relative_to(root).as_posix()!='Sources/SafetyCore/SafetyCore.swift':
 errors.append('production Trash API must exist only in SafetyCore')
for file in (root/'Tests').rglob('*.swift'):
 text=file.read_text()
 if re.search(r'/(?:Users|Volumes)/|~\/\.Trash|homeDirectoryForCurrentUser',text):
  errors.append(f'personal-store path reference in test: {file.relative_to(root)}')
for file in (root/'Sources').rglob('*.swift'):
 if 'homeDirectoryForCurrentUser' in file.read_text(): errors.append(f'implicit HOME lookup in runtime: {file.relative_to(root)}')
network_patterns = (
 r'^\s*import\s+(?:Network|MetricKit)\b',
 r'\b(?:URLSession|URLRequest|URLProtocol|NWConnection|NWListener|WebSocketTask|MQTTClient)\b',
 r'\b(?:TelemetryDeck|PostHog|Mixpanel|Amplitude)\b',
 r'\b(?:connect|getaddrinfo|socket)\s*\(',
 r'\bProcess\s*\(',
)
for file in (root/'Sources').rglob('*.swift'):
 text=file.read_text()
 for pattern in network_patterns:
  if re.search(pattern,text,re.MULTILINE):
   errors.append(f'network client or telemetry API in runtime: {file.relative_to(root)}: {pattern}')
manifest=(root/'Package.swift').read_text()
if re.search(r'\.package\s*\(\s*url\s*:',manifest):
 errors.append('external SwiftPM package dependency present; review privacy and network surface')
scan_core_target=re.search(r'\.target\(name:\s*"ScanCore",\s*dependencies:\s*\[([^\]]*)\]\)',manifest)
if not scan_core_target:
 errors.append('ScanCore target declaration could not be checked for write-capable dependencies')
elif re.search(r'\bSafetyCore\b|\bPersistence\b',scan_core_target.group(1)):
 errors.append('ScanCore must not depend on SafetyCore or Persistence')
scan_core_sources=list((root/'Sources/ScanCore').rglob('*.swift'))
for file in scan_core_sources:
 text=file.read_text()
 if re.search(r'^\s*import\s+(?:SafetyCore|Persistence)\b',text,re.MULTILINE):
  errors.append(f'read-only ScanCore imports write-capable module: {file.relative_to(root)}')
 for pattern in scan_core_mutation_findings(text):
  errors.append(f'filesystem mutation API in ScanCore: {file.relative_to(root)}: {pattern}')
if errors: print('\n'.join(errors)); raise SystemExit(1)
print('Safety audit passed: app Trash boundary intact; no arbitrary runtime permanent-removal API (private import snapshot cleanup only); local uninstall remains explicit and separate; no personal test paths, network client, or known telemetry SDK/import.')
