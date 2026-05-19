/// CLAUDE.md routing block — injected by `flart init --project`. Plan
/// Section 7.2 Mechanism B. Surrounded by HTML-comment markers so
/// subsequent `flart init` runs replace the block in-place rather than
/// appending duplicates.
const String claudeMdMarkerStart = '<!-- flart-routing-start -->';
const String claudeMdMarkerEnd = '<!-- flart-routing-end -->';

const String claudeMdBlock = '''$claudeMdMarkerStart
## flart routing

For Flutter/Dart development tasks in this project, prefer flart commands when available:

| Instead of                   | Use                          |
|------------------------------|------------------------------|
| flutter analyze              | flart analyze                |
| dart analyze                 | flart analyze                |
| flutter test                 | flart test                   |
| flutter build apk            | flart build apk              |
| flutter build web            | flart build web              |
| flutter build ipa            | flart build ipa              |
| flutter pub get              | flart pub get                |
| flutter pub upgrade          | flart pub upgrade            |
| flutter pub outdated         | flart pub outdated           |
| flutter pub deps             | flart pub deps               |
| flutter clean                | flart clean                  |
| flutter doctor               | flart doctor                 |
| flutter devices              | flart devices                |
| flutter gen-l10n             | flart gen-l10n               |
| dart format                  | flart format                 |
| dart fix                     | flart fix                    |
| dart fix --apply             | flart fix --apply            |
| dart compile <target>        | flart compile <target>       |

For data/analysis questions ("how many providers", "count files matching X",
"summarize structure"), use the executor instead of multiple Read/Grep calls:

  flart exec dart '...'    # top-level code OK — auto-wrap
  flart exec bash '...'    # find/grep/awk combinations
  flart exec python '...'  # JSON/CSV manipulation

The executor runs the script in a sandbox and returns only the result,
which keeps tool output out of your context window.

Sub-agents (Task tool): when you spawn one, the PreToolUse/Task hook
prepends a short flart usage reminder to its prompt automatically, so
the same routing applies inside the sub-agent without any extra setup.

Raw shell commands (grep, find, python, awk, custom binaries) — their
output is auto-filtered by flart's PostToolUse/Bash hook on Claude Code
v2.1.121+. Decision tree: ≤30 lines passthrough; 31-200 lines → head 20
+ tail 5 + tee path; >200 lines → head 15 + tail 5 + error grep + tee
path; exit ≠ 0 → framed Command failed + stderr + stdout tail + tee
path. The full raw output is always written to
~/.local/share/flart/tee/<epoch>_<slug>_bash.log.

To bypass the filter when you genuinely need the full output:
  - prefix the command with FLART_FULL_OUTPUT=1, or
  - cat/head/tail/grep the tee log directly (auto-passthrough).
$claudeMdMarkerEnd''';
