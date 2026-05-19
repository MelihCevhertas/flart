# flart — Flutter/Dart Token Optimization Tool

**Belge sürümü:** 1.13
**Tarih:** 18 Mayıs 2026
**Hedef geliştirme ortamı:** Claude Code
**Tahmini geliştirme süresi:** 18–25 gün full-time / 5–7 hafta part-time
**License:** MIT (tek lisans, tüm paketler dahil)

## Değişiklik Geçmişi

**v1.13 (19 Mayıs 2026):** v0.1.0 promotion from `-rc1` after Wonderous agent-session validation. (a) **Ölçüm:** Fresh Claude Code session, Wonderous Flutter app, 30 dk task — 11 invocation × 4 command type, 82.6 KB raw → 1.4 KB filtered, **%98.3 reduction (~21,807 token tasarrufu)**. Agent 47 warning → 0 (91 fix in 54 files); hook engaged, CLAUDE.md routing worked end-to-end, tee mechanism agent tarafından failure path'inde kullanıldı. Per-command: `analyze` %98.5 (7×), `fix` %97.1 (2×), `build` %92.6 (1×), `test` %48.5 (1× — zero-test run, anti-bloat fallback'i tetiklemedi çünkü filtered hâlâ raw'dan küçük). Failure scenario'ları da kapsandı (NDK-missing build error, zero-test run). Plan F bandı (40-65% session-level token saving) açık ara aşıldı — RC pattern başarıyla v0.1.0'a promote kararıyla sonuçlandı. (b) **README + CHANGELOG güncellendi:** Headline measurement claim 91% (17 invocation per-invocation avg) yerine 98.3% (real agent-session) ile yeniden çerçevelendi; "Real-world measurement" section eklendi, "Typical savings" per-invocation tablosu korundu (farklı kategori — synthetic single-shot ölçümler). CHANGELOG `v0.1.0` tarihi `2026-05-19` olarak işaretlendi, Performance bölümü agent-session özetiyle güncellendi, Limitations Windows/Intel Mac v0.2.0 referansları sync'lendi. (c) **macos-13 + Windows v0.2.0 deferral teyit edildi:** Bu plan girdisi Plan v1.11 (Windows) + v1.12 (macos-13) kararlarını v0.1.0 final tag'iyle birlikte mühürler. v0.2.0 backlog Section 14.5'te durmaya devam ediyor; geliştirici ortamında yeni veri gelene kadar açık. (d) **Tag akışı:** `git push origin main` → `git tag v0.1.0` → `release.yml` otomatik tetikleme → 2 binary build (~5 dk) → draft release → kullanıcı "Set as the latest release" işaretler ve publish eder. RC pattern dokümante edildiği şekilde (Section 12.5) tamamlandı.

**v1.12 (19 Mayıs 2026):** macOS Intel x64 (`macos-13`) v0.2.0'a ertelendi. (a) **Sebep:** v0.1.0-rc1 tag'lendikten sonra `release.yml` matrix build'inde `macos-13` job'ı 52 dakika queue'da bekledi — GitHub Actions Intel Mac runner availability sürdürülemez. Apple Silicon + Linux runner'lar 5 dk'da pickup oluyor. (b) **Geliştirici test imkanı yok:** Mac arm64 host'tan macos-13 binary'sini lokal smoke etmek mümkün değil — Intel Mac kullanıcı pool'u Apple Silicon transition'la birlikte küçülüyor, ROI düşük. (c) **release.yml matrix sadeleştirildi:** `macos-13` entry'si tamamen kaldırıldı, kalan iki target `macos-latest` (arm64) + `ubuntu-latest` (x64). Build süresi tahmini 5 dk. (d) **README Limitations:** Intel Mac kullanıcıları için "build from source" 5-satırlık snippet eklendi (`git clone` → `dart pub get` → `dart compile exe` → `mv /usr/local/bin/`). Status banner "macOS + Linux" → "macOS (Apple Silicon) + Linux (x64)". (e) **Section 1.3 + 14.5 güncellendi:** Intel Mac Kapsam Dışı listesine; v0.2.0 backlog'a Windows ile birlikte. (f) **Tag re-create:** v0.1.0-rc1 tag'i silinip yeni commit (`Drop macos-13 from release matrix`) üzerine yeniden atılır; queued macos-13 run iptal edilir.

**v1.11 (19 Mayıs 2026):** Post-push CI cleanup + Windows desteğinin v0.2.0'a ertelenmesi. (a) **macOS CI test cleanup fix:** `packages/flart_cli/test/analyze_command_test.dart` son test'i (`DB filtered_bytes == captured stdout bytes`) sonrası `Directory.current` silinmiş `tmpDir`'de kalıyordu — macOS `getcwd()` katı, `PathNotFoundException` ile crash; Linux toleranslı, ubuntu-latest geçiyordu. `setUp`'ta `originalCwd` capture edilip `addTearDown` tek callback içinde **önce restore, sonra delete** sırasıyla yürütülecek şekilde refactor edildi. Grep ile workspace'te `Directory.current` mutate eden başka test olmadığı doğrulandı; `withTempCwd` helper abstraction'ı reddedildi (tek caller için premature). (b) **Windows desteği v0.2.0'a ertelendi (Section 1.3 + 14.5):** Launch hızı önceliği + Mac-only geliştirme ortamı gerekçesiyle v0.1.0'da Windows hedeflenmiyor. Gerçek kapsam: hook protocol (bash/PS veya direkt binary), path handling (XDG vs APPDATA), CI matrix (windows-latest), `install.ps1`, fixture line ending normalizasyonu. Tahmini iş 2 hafta full-time. README "Limitations" mevcut Windows notu yeterli. v0.1.0 sonrası gerçek kullanıcı verisi gelince yeniden değerlendirilecek.

**v1.10 (18 Mayıs 2026):** Faz 7 Çekap 3 (final smoke + handoff + RC pattern). (a) **Release Candidate pattern (Section 12.5 yeni):** v0.1.0 doğrudan tag'lenmiyor — önce `v0.1.0-rc1` tag'lenip release.yml ile binaries üretilir, gerçek agent-session ölçümü `-rc1` artefactları üzerinde yapılır, sonuç iyiyse `v0.1.0` tag'i atılır; kötüyse `-rc2`'ye iterate. Motivasyon: utanç verici release önleme. Bu pattern future minor/major release'ler için de geçerli. (b) **Baseline commit + version stamp doğrulaması:** Local `git init` + remote `MelihCevhertas/flart` + initial commit `599c666 — flart v0.1.0 (Faz 1-7 complete)` (170 files). Local rc1 binary build (`dart compile exe ... --define=FLART_VERSION=0.1.0-rc1 --define=GIT_SHA=599c666 --define=BUILD_DATE=2026-05-18`) → 7.0 MB, `flart 0.1.0-rc1 (commit 599c666, built 2026-05-18)` ✓. (c) **install.sh local smoke:** Dry-run 404 (release henüz yok — beklenen davranış, error mesajı actionable). OS/arch detect + URL composition + jq prereq path + macOS quarantine clear branch'leri kod-okuma + dummy çağrılarla doğrulandı. Gerçek install testi user tarafında rc1 release.yml çalıştıktan sonra Step 3'te yapılır. (d) **DEPLOYMENT.md (handoff doc):** Step 1-5 (push → tag rc1 → install.sh real test → Wonderous 30 dk agent-session measurement → promote v0.1.0 veya iterate rc2). README/CHANGELOG'a measurement satırını rc1 ölçümü tamamlandıktan sonra eklemek üzere placeholder. Rollback/iteration guide dahil. (e) **Faz 6 son madde + Faz 7 son madde — user manual milestone:** Section 9'da "Integration test: gerçek Claude Code session'da hook tetiklensin" maddesi unchecked kalır; "v0.1.0 tag" maddesi de unchecked kalır. İkisi de **user-side manual milestone** (Çekap 3 ana iş tamamlandıktan sonra). Plan değişikliği değil — `flart` codebase'i ve release pipeline'ı Çekap 3 ile shippable; agent ölçümü ve final tag user'a devredildi.

**v1.9 (18 Mayıs 2026):** Faz 7 Çekap 2 (install.sh + CI + version stamping). (a) **Build-time version metadata (Section 8.1 / version_command revize):** `flart version` artık `String.fromEnvironment` ile `FLART_VERSION` / `GIT_SHA` / `BUILD_DATE` okur. Dev build (`dart compile exe` flagsiz) → `flart 0.1.0-dev`. Release build (`--define=FLART_VERSION=0.1.0 --define=GIT_SHA=<sha> --define=BUILD_DATE=YYYY-MM-DD`) → `flart 0.1.0 (commit <sha>, built YYYY-MM-DD)`. Binary self-contained, runtime'da git çağrısı yok. (b) **install.sh (Plan Section 12.3 dolduruldu):** OS/arch detect (macOS arm64/x64, Linux x64), `FLART_VERSION` + `FLART_INSTALL_DIR` env override, idempotent overwrite, macOS quarantine attribute pro-aktif silinir, jq prereq warning OS-aware, PATH check shell-aware (zsh/bash/fish), "next steps" mesajı. (c) **CI workflows (.github/workflows/):** `test.yml` push/PR'da matrix `[macos-latest, ubuntu-latest]` × `setup-dart@v1 sdk: 3.11.5` + `tools/test_all.sh`. `release.yml` tag-triggered `v*` matrix build `[macos-arm64, macos-x64, linux-x64]`, version stamp inject, smoke `./binary version + help`, `softprops/action-gh-release@v2` ile draft release oluşturur. (d) **README polish:** 91% caveat ("Real-world session savings depend on command mix and hook adoption"), macOS quarantine workaround, "Verifying savings" section (Quick start sonrası), install.sh `FLART_VERSION`/`FLART_INSTALL_DIR` env override doc'u.

**v1.8 (18 Mayıs 2026):** Faz 6 (Claude Code Integration) implementasyon notları + Faz 7 sıralama. (a) **Hook konumu XDG-compliant (Section 7.2 revize):** Plan v1.0'da bahsedilen non-XDG `~/.flart/hooks/rewrite.sh` yerine **`~/.config/flart/hooks/rewrite.sh`** kullanılır (XDG_CONFIG_HOME, fallback `$HOME/.config`). Savings DB (`~/.local/share/flart/savings.db`) ve tee dosyaları (`~/.local/share/flart/tee/`) XDG_DATA_HOME'da kalır. Test override mekanizması: `FLART_CONFIG_DIR` env var, `flart_hooks.resolveConfigHome(env)` helper'ı kullanılır. (b) **CLAUDE.md uninstall — empty-file deletion:** `flart init --uninstall` sonrasında CLAUDE.md sadece flart routing marker block'unu içeriyorsa (başka user content yoksa) dosya **silinir**. Mixed content varsa marker block çıkarılır, geri kalan korunur. User content invariant. (c) **`flart init --check` exit code protokolü:** En az 1 probe fail → exit 1 (CI'da useful), tüm probe'lar pass → exit 0. Plan Section 8.3 exit code aralığında 1-99 bandında (alt komut tarzı). (d) **Uninstall savings safety (Section 7.3 yeni):** `flart init --uninstall` **sadece integration teardown** yapar — `settings.json` flart entry'si + hook script dosyası + CLAUDE.md marker block silinir. **Savings DB asla dokunulmaz**; user `flart savings --reset` ile history'i ayrı silebilir. Smoke ve unit test'lerle doğrulandı. (e) **Faz 6 Çekap 3 (gerçek agent ölçümü) Faz 7 sonuna ertelendi:** Polish öncesi negative measurement çıkma riski yerine, polish tamamlandıktan sonra gerçek session ölçümü → README'ye launch verisi olarak girer. Çekap 3 = Faz 7 son adım, kullanıcı (Melih) yeni Claude Code session'da Wonderous'ta 30 dk task ile yürütür.

**v1.7 (18 Mayıs 2026):** Faz 5 (Savings Reporter) implementasyon notları. (a) **Aggregator katmanı (Section 6.1 ek):** `flart_savings` paketinde read-only SQL aggregator (`Aggregator(FlartDatabase)`); `summary`, `byModule`, `byCommand`, `byProject`, `top`, `details`, `dailyBuckets` query methods. Tüm `--since`/`--until`/`--project` filter'ları aggregator method param'ı; CLI sadece dispatch yapar. (b) **Token-first vurgu (Plan v1.7 A):** Default text reporter token block'unu byte block'undan önce gösterir. Disclaimer satırı dinamik (Config'den `chars_per_token` ve `estimated_deviation` okunur, v1.3'te belirlenen tek-kaynak). (c) **`--graph` ASCII bar chart (Section 6.3):** `DailyBucket` listesi + Unicode block chars `▁▂▃▄▅▆▇█`. Tek-row min implementasyon (v1.1+'da multi-row threshold chart). Boş data → "No data to graph.", all-zero → "No tokens saved in this window." (d) **`--reset` confirmation flow (Section 6.2):** Interactive `[y/N]` prompt + `--force` override (CI). Cancellation → "No changes made.", confirm → `DELETE FROM invocations` + delete count. Test'lerde `stdinOverride` ile mock'lanır. (e) **`parseSince` flexible (Section 6.2 ek):** Relative `7d`/`24h`/`2w`/`3m` + absolute ISO. Date-only ("2026-01-15") UTC midnight, datetime explicit Z/offset honored. Garbage → `FormatException` → CLI exit 100. (f) **CSV denormalised (Section 6.3 ek):** Single table, `dimension` kolonu module/command/project sınıflandırması yapar. Label'lar virgül/quote içerirse `"` quoting. (g) **JSON schema stabil (Section 6.3):** `report_generated_at`, `summary`, `by_module`, `by_project`, `top_commands` top-level keys; her grouped row aynı schema. Section 6.3 örnekleri gerçek implementation output'una göre güncellendi.

**v1.6 (18 Mayıs 2026):** Faz 4 implementasyon notları. (a) **FilterRunner anti-bloat boş-raw istisnası (Section 5.3 ek):** `rawCombined.trim().isEmpty` durumunda filter'ın friendly mesajı (`No issues.` vs.) korunur — uzun olsa bile. (b) **TeeManager entegrasyonu (Section 3.6 + 5.3):** `FilterRunner` `TeeManager` inject alır; failure'larda `<dataDir>/tee/{epoch}_{slug}.log` yazılır. `[full output: <path>]` hint **filteredOutput içinde** — DB filtered_bytes agent'ın stdout'ta gördüğüne eşit. Separator: `$rawStdout\n---STDERR---\n$rawStderr`. (c) **truncate_long_messages_at (Section 3.2 + 5.4.1 + 5.4.2):** `FilterUtils.truncateMessage(msg, maxLen)` helper'ı `analyze_filter` (her ERROR message) ve `test_filter` (errorMessage), ve `build_filter` (compile error message) tarafından uygulanır. maxLen≤0 → no-op. (d) **Doctor all-healthy davranışı (Section 5.4.7):** `[✓]` kategorilerin hepsi sağlıklıysa output `✓ All N categories healthy.` olarak collapse olur, [✗]/[!] yoksa sub-bullet basılmaz. (e) **pub_outdated --json default + --no-json fallback (Section 5.4.4):** Filter `--json` flag'ini her zaman injekte eder; user `--no-json` geçerse tabular text parser devreye girer. JSON formatı stabil; text mode defensive. (f) **Build filter 3-target single class (Section 5.4.3):** `BuildFilter({target})` tek class, apk/web/ipa dispatch. Success: `✓ Built <path>` + timing. Failure: stderr'den `file:line:col: Error:` blokları + `BUILD FAILED` summary (Gradle task fallback). Tee tam log için. (g) **Fix filter rule-summary collapse (Section 5.4, v1.0 launch quality fix):** İlk Faz 4 implementation per-file detay korumuştu, Wonderous'ta %6 tasarrufla outlier idi. Faz 5 öncesi rule-summary collapse'a refactor edildi: çıktı `{rule_name} [N fixes in M files]` formatında, fix sayısına göre desc sıralı. Per-file granularity kaybedilir; agent ihtiyaç duyarsa raw `dart fix --dry-run` çalıştırabilir. Wonderous'ta yeni ölçüm: 5772 → 189 byte (**%96.7**), Plan target bandının üstüne çıktı. Backlog #4 closed. (h) **Manual fixture liste (13):** `flutter build`, `flutter doctor`, `dart fix`, `flutter devices`, `dart compile`, `flutter pub outdated`, `flutter pub deps` çıktıları `tools/generate_fixtures.sh`'a entegre edilmedi (çok yavaş / host-state-bağımlı). Her manuel fixture dosyası başında `# MANUAL CAPTURE` header'ı + capture komutu + regenerate adımları. Auto vs manual fixture ayrımı `packages/flart_filters/test/fixtures/`'da fixture header'larından okunur. (i) **Generic wrappers `err`/`test-wrap`:** baseNativeCommand userArgs'ı verbatim native komut olarak kullanır (`flart err git status` → `git status`). FilterCommandBase `ArgParser.allowAnything()` ile her flag/pozisyonelu geçirir.

**v1.5 (17 Mayıs 2026):** Faz 3 implementasyon notları. (a) **FilterRunner anti-bloat (Section 5.3 ek):** Filter output'u ham (`rawStdout + rawStderr`) byte sayısından büyük veya eşitse, runner ham çıktıyı stdout'a yazar. Filter "compress edemediği" çağrılardan çekilir — agent en kötü ihtimalle wrap'siz komutun maliyetini öder. **Boş raw için istisna:** `rawCombined.trim()` boşsa filter'ın "No issues."/"ok" gibi friendly mesajı korunur (uzun olsa bile). Implementation `packages/flart_cli/lib/filter_runner.dart`. (b) **TestFilter Flutter/Dart auto-detect (Section 5.4.2 ek):** Yeni `TestFilter({bool isFlutterProject})` flag'i; CLI tarafında `ProjectContext.isFlutterPackage()` `pubspec.yaml`'ı parse edip `flutter:` / `flutter_test:` / environment `flutter:` constraint'ini arar. Flutter pubspec → `flutter test --reporter=json`, pure-Dart pubspec → `dart test --reporter=json`. JSON event format aynı, parser değişmez. (c) **pub_get/pub_upgrade filters (Section 5.4.4 doldurma):** Plan v1.3'te bahsedilen `pubspec.lock` parse uygulandı — `PubGetFilter(projectRoot:)` `packages:` map key sayısını okur, çıktı header'ına `(N deps, M changed)` ekler. `PubUpgradeFilter` upgrade/add/remove'leri ayrı kova'lara koyar, `> info` satırlarını drop eder. (d) **Nested `pub` command:** `flart pub get`, `flart pub upgrade` — args `CommandRunner` subcommand pattern'iyle. `outdated` ve `deps` Faz 4'te eklenecek.

**v1.4 (17 Mayıs 2026):** Faz 2 implementasyon notları. (a) **Stream-vs-exitCode senkronizasyonu (Section 4.3 ek):** Bash/dart benzeri runtime'lar bir child process (örn. `sleep`) fork ettiğinde, parent ölse bile child stdout/stderr fd'lerini miras almıştır ve pipe'lar child ölene kadar kapanmaz. Bu, `process.exitCode` resolve olmasına rağmen stream `onDone` callback'inin saniyelerce gecikmesine yol açar (Plan Section 4.3 v1.3 kodu bu durumu öngörmemişti). Doğrulanan davranış: `process.exitCode` await edilir → resolve olur → stream'lere 200ms grace tanınır (`Future.wait().timeout(200ms)`) → `TimeoutException`'da subscription'lar cancel edilir → o ana kadar buffer'a girmiş byte'lar final çıktı olur. Implementasyon `packages/flart_executor/lib/src/executor.dart`'ta. (b) **Executor savings semantics (Section 6 ek):** Executor için `raw_bytes` ve `filtered_bytes` eşittir (executor pre/post filter ayrımı yapmaz; sadece bounded capture yapar). Savings reporter ileride executor row'larını invocation-count ekseninde gösterir, byte-reduction-ratio ekseninde değil. Metadata: `{"runtime": "<runtime>", "timed_out": <bool>}`. (c) **CLI exec input mode mutual exclusivity:** `<code> positional`, `--file <path>`, `--stdin` üçü mutually exclusive; biri eksikse veya birden fazlası verildiyse usage error (exit 100). (d) **`sigkillGrace` parametrize edildi:** Executor `execute()` default 2s grace tutar (Plan 4.3'e sadık), test'ler kısa grace ile koşar (200ms) — toplam timeout budget'ı CI'da öngörülebilir kalır. (e) **Dart auto-wrap (Section 4.4 ek):** `flart exec dart` standalone mode'un `main()` boilerplate zorunluluğunu otomatik handle eder. Top-level `main(` regex'i eşleşmezse: import'lar (Dart'ta top-level zorunlu) wrap dışına çıkarılır, kalan body `void main() async { ... }` içine sarılır. Implementation `flart_executor/lib/src/dart_wrapper.dart`. Wrap ergonomi katmanı, **validation katmanı değil** — `validateDartImports` orijinal kod üzerinden çalışır, mod-A allowlist'i bypass yok. Block comment içinde fake `void main(` false-positive üretirse wrap atlanır, Dart compile error verir (silent korupsiyon yok).

**v1.3 (17 Mayıs 2026):** Üçüncü pass — Faz 1 öncesi tutarsızlık temizliği. (a) `FilterRunner` örnek kodunda `stdout`/`stderr` yerel değişken adları `rawStdout`/`rawStderr` olarak değiştirildi (dart:io shadowing kaldırıldı), filtered output koşulsuz print edilir. (b) `SandboxExecutor` örnek kodu yeniden yazıldı: `process.stdin.close()` eklendi (stdin bekleyen script'leri unblock eder), stdout/stderr stream'leri `listen` + `Completer` ile drain edilir (pipe tıkanma riski yok), `Future.wait` ile stream'ler ve `exitCode` paralel beklenir. (c) Token tahmini sapma payı tek kaynağa alındı: `token_estimation.estimated_deviation: 0.15` config alanı eklendi; raporlar magic number yerine bunu okur. Section 6.4 ve 13.2'deki çelişen rakamlar (%5-10 vs %5-15) %15 üzerinde standartlaştırıldı. (d) Alt komut exit code çakışma koruması: alt komut 100/101/124/127 döndürürse `metadata_json`'a `{"native_exit_code": <kod>}` not düşülür. (e) `pub_get_filter` dependency sayısı `pubspec.lock` parse edilerek elde edilir; Faz 4'te implement edilir.

**v1.3 Faz 1 implementasyon notları (sapma kayıtları):** (i) Adım 1.8 kabul kriteri "dosyalar syntax-valid, workspace member'ları olmadan `dart pub get` resolve atlanır; tam resolve testi Adım 2.8'de" olarak okunur. Pure pub workspaces boş `workspace:` listesini resolve etmez. (ii) Workspace dev-dep paylaşımında `lints/recommended`'in `depend_on_referenced_packages` lint'i false-positive verir; çözüm test dosyalarının başına `// ignore_for_file: depend_on_referenced_packages` comment'i. Üst-seviye `analysis_options.yaml` exclusion ileride değerlendirilebilir, şu an gereksiz. (iii) Faz 1 dahili TODO sırası **Storage → Estimator → Tracker** olarak uygulanır (Tracker, Estimator'a bağımlı; Plan TODO listesi v1.0'da bunu açıkça sıralamamıştı). TokenEstimator Section 9 Faz 1 listesinde Adım 5 altındaymış gibi görünse de pratik bağımlılık nedeniyle Adım 4'te yazılır. (iv) Tüm timestamp'ler **UTC** olarak saklanır: `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)` ile oku, `dateTime.toUtc().millisecondsSinceEpoch` ile yaz. DST veya TZ değişen kullanıcılarda data corruption önler — Section 3.3'e bağlayıcı. (v) `Config.fromMap` partial map'leri defaults ile auto-merge eder (idempotent — tam map ile çağrı no-op). Test ergonomisi ve kullanıcı config esnekliği için. (vi) Workspace-wide test çalıştırması için `tools/test_all.sh` script'i: her paketin kendi pubspec'inde `dart test` çağırır. `dart test packages/*/test` tek-paket fallback'i hızlı ama her paketin transitive resolve'unu garanti etmez; CI ve günlük kullanım `test_all.sh` üzerinden gider.

**v1.2 (16 Mayıs 2026):** İkinci pass tutarsızlık denetimi. `Process.run` + timeout sorunu düzeltildi (`Process.start` + manuel kill kullanılacak). TokenEstimator config injection netleştirildi. Workspace tooling kararı kesinleştirildi (pure pub workspaces, melos yok). `metadata_json` populate kaynağı tanımlandı. Exit code 1 vs alt komut exit code çelişkisi giderildi. Interaktif prompt yaklaşımı eklendi. `CommandFilter` paket konumu (flart_filters) netleştirildi. `cl100k_base` yanıltıcı not düzeltildi. Doctor `[!]` davranışı eklendi. `dart-file` typo'su giderildi. Fixture path tutarsızlığı düzeltildi.

**v1.1 (16 Mayıs 2026):** Tutarsızlıklar giderildi. Modül numaralandırması netleştirildi (0-1-2-3-4-5; "Modül 2" gelecek sürümlere ertelendi, kasıtlı boş). `dart analyze --format=machine` tek doğru kullanım olarak belirlendi. SQLite schema'da `command`/`subcommand` ayrımı netleştirildi. `CommandFilter` ile `FilterRunner` ayrı sorumluluklar olarak tanımlandı. `flart run` v1.0'dan çıkarıldı (v1.1'e ertelendi). `flart pub deps` ve `flart compile exe` faz planına eklendi. Logging detayları, license, test stratejisi eksikleri tamamlandı. Süre tahmini gerçekçileştirildi.

**v1.0 (16 Mayıs 2026):** İlk sürüm.

---

## 1. Vizyon ve Kapsam

### 1.1 Problem

Claude Code ile Flutter geliştirirken üç ana kaynaktan token yakılır:

1. **Bash tool çıktıları:** `flutter analyze`, `flutter test`, `flutter build`, `git status` gibi komutların ham çıktısı her turn'de context'te tekrar yer kaplar.
2. **Dosya keşfi:** Read/Grep/Glob tool'ları ile birden fazla dosya açılır, sonuç sayfalarca satır.
3. **Veri analizi:** "Kaç tane provider var?" gibi sorularda agent dosyaları okuyup el ile sayar; oysa bir script bunu 1 satırda yapardı.

### 1.2 Çözüm

İki paradigmayı birleştiren bir CLI aracı. Modüller şu numara şemasıyla anılır (sıralı 0-5 yerine fonksiyonel; **Modül 2 kasıtlı olarak boş** — gelecek sürümler için ayrılmıştır):

- **Modül 0 — flart_core:** Tüm modüllerin paylaştığı altyapı (config, storage, truncation, tokens, tee, logger).
- **Modül 1 — flart_filters (Reactive Filter):** Flutter/Dart komutlarının çıktısı pre-process'ten geçer; gürültü atılır, sadece kritik bilgi kalır.
- **Modül 2 — (Proactive Code Graph) — v1.0'da YOK:** Blast radius, dead code, PR impact. ROI düşük bulundu, gelecek sürümlere ertelendi.
- **Modül 3 — flart_executor (Sandbox Executor):** Agent ham veri yerine script yazıp sonucu alır. Veri context'e değil, sandbox'a gider; sadece hesaplanmış sonuç context'e gelir.
- **Modül 4 — flart_savings (Savings Reporter):** Her çağrı kaydedilir; aracın gerçek tasarrufu rakamla görülebilir.
- **Modül 5 — flart_hooks (Claude Code Integration):** PreToolUse hook + CLAUDE.md routing.
- **Modül 6 — flart_cli (CLI Entry Point):** Tüm modülleri birleştiren komut satırı arayüzü.

### 1.3 Kapsam Dışı

Bu sürümde **bilerek yapmadığımız** şeyler (gelecek versiyonlar için not):

- Modül 2 (proactive code graph / blast radius) — değerlendirildi, ROI düşük bulundu.
- LLM destekli özetleme — sadece deterministik kurallarla çalışır.
- Telemetry / network çağrısı — tüm veri lokal kalır.
- Multi-agent desteği (Cursor, Gemini CLI, Codex) — sadece Claude Code hedefli.
- Interaktif komutlar (`flutter run` hot reload modu) — filter etmesi karmaşık, v1.1'e ertelendi.
- Windows desteği — launch hızı + Mac-only geliştirme ortamı gerekçesiyle v0.2.0 yol haritasına ertelendi (bkz. Section 14.5). v0.1.0 macOS (Apple Silicon) ve Linux (x64) hedefler.
- macOS Intel x64 (`macos-13`) — Apple Silicon transition pool küçülüyor + GitHub Actions Intel Mac runner queue 50+ dakika, v0.2.0'a ertelendi (bkz. Section 14.5). Intel Mac kullanıcıları "build from source" yolunu izler (README Limitations).

### 1.4 İsim ve Marka

- İsim: **flart**
- pub.dev'de `flarts` (s ile, ölü 2019 charts paketi) var ama `flart` (s'siz) temiz.
- GitHub'da `flart` adında ciddi CLI tool yok.
- Komut: `flart`
- Config dosya prefix'i: `flart`

---

## 2. Üst Düzey Mimari

### 2.1 Tek Binary, Monorepo Geliştirme

**Production:** Tek `flart` binary'si (`dart compile exe`). Kullanıcı hiçbir dependency kurmaz.

**Geliştirme:** Dart 3.5+ **pub workspaces** (pure, melos yok). Workspace root `pubspec.yaml`'da `workspace:` section'ı paket yollarını listeler. Tek `dart pub get` tüm paketleri çözer, tek `dart test` tüm testleri çalıştırır. melos şu an için overkill (release management özelliği bizim ihtiyacımızdan büyük).

### 2.2 Paket Yapısı

Workspace root + 6 child paket = toplam 7 `pubspec.yaml` dosyası.

```
flart/
├── pubspec.yaml                    # Workspace root (no code, sadece workspace declaration)
├── packages/
│   ├── flart_cli/                  # Entry point, CLI parsing, command dispatch
│   ├── flart_core/                 # Config, SQLite storage, token estimation, truncation
│   ├── flart_executor/             # Sandbox executor (Modül 3)
│   ├── flart_filters/              # Komut filtreleri (Modül 1)
│   ├── flart_savings/              # Savings tracking + reporting (Modül 4)
│   └── flart_hooks/                # Claude Code hook installation (Modül 5)
├── tools/                          # Build scripts
├── test/                           # Integration tests (paket içi unit testler ayrı)
├── README.md
├── CHANGELOG.md
├── LICENSE
└── analysis_options.yaml
```

### 2.3 Veri Akışı

```
[Claude Code] → [bash tool] → [flart_hooks/rewrite.sh]
                                      ↓
                              [flart binary]
                                      ↓
                    ┌─────────────────┴──────────────────┐
                    ↓                                     ↓
              [flart_filters]                      [flart_executor]
                    ↓                                     ↓
              [Real command run]                    [Sandbox script]
                    ↓                                     ↓
              [Filter output]                      [Capture output]
                    ↓                                     ↓
                    └─────────────────┬──────────────────┘
                                      ↓
                             [flart_savings]
                                      ↓
                          [SQLite + tee dosyaları]
                                      ↓
                             [Claude'a dön]
```

---

## 3. Modül 0 — Çekirdek (flart_core)

Tüm modüllerin paylaştığı katman. **İlk yazılacak modül.**

### 3.1 Sorumluluklar

- Configuration loading (global + project, merge)
- SQLite veritabanı kurulumu ve migration
- Token estimation (byte → token tahmini)
- Byte-safe / UTF-8 safe string truncation
- Tee directory yönetimi (fail durumunda ham çıktı saklama)
- Logger (verbosity levels)

### 3.2 Konfigürasyon Dosyaları

**Global:** `~/.config/flart/config.yaml`

**Proje:** `<project_root>/.flart/config.yaml`

**Merge stratejisi:** Project override global. Liste field'larında concat (örn. `excluded_commands`), scalar field'larında replace.

**Örnek config:**

```yaml
# Token estimation
token_estimation:
  chars_per_token: 3.8         # English+code ortalaması; TR için 3.5 öneririz
  estimated_deviation: 0.15    # Tokenizer sapma payı (±%15); raporlarda gösterilir.
  # Not: Anthropic'in gerçek tokenizer'ı kapalı (BPE varyantı).
  # Yerel hesap her zaman tahmindir; raporlarda "estimated" belirtilir.

# Tee mechanism
tee:
  enabled: true
  mode: failures               # failures | always | never
  directory: null              # null → ~/.local/share/flart/tee
  max_files: 30
  max_file_size_mb: 5
  min_size_bytes: 500

# Filter behavior
filters:
  max_failures_shown: 15
  max_warnings_shown: 50
  truncate_long_messages_at: 300
  ultra_compact: false

# Executor behavior
executor:
  timeout_seconds: 60
  max_output_bytes: 65536
  head_ratio: 0.6              # head/tail split: 60% head, 40% tail
  allowed_runtimes:
    - dart
    - bash
    - python
    - javascript

# Savings tracking
savings:
  enabled: true
  database_path: null          # null → ~/.local/share/flart/savings.db
  retention_days: 365

# Logging
log:
  level: info                  # debug | info | warn | error
  file: null                   # null → stderr only
```

### 3.3 SQLite Schema

**Konum:** `~/.local/share/flart/savings.db`

**Tablo: invocations**

```sql
CREATE TABLE invocations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp       INTEGER NOT NULL,           -- Unix epoch seconds
  project_path    TEXT NOT NULL,              -- Project root (cwd-based)
  module          TEXT NOT NULL,              -- 'filter' | 'executor'
  command         TEXT NOT NULL,              -- flart subcommand only: 'analyze' | 'test' | 'exec' | 'build' ...
  args            TEXT,                       -- Full arg string: 'dart' | 'apk --release' | 'lib/'
  raw_bytes       INTEGER NOT NULL,           -- Ham çıktı byte sayısı
  filtered_bytes  INTEGER NOT NULL,           -- Filtre sonrası
  raw_chars       INTEGER NOT NULL,
  filtered_chars  INTEGER NOT NULL,
  est_raw_tokens  INTEGER NOT NULL,           -- chars / chars_per_token
  est_filt_tokens INTEGER NOT NULL,
  duration_ms     INTEGER NOT NULL,           -- Komut çalışma süresi
  exit_code       INTEGER NOT NULL,
  was_truncated   INTEGER NOT NULL DEFAULT 0,
  tee_path        TEXT,                       -- Eğer tee yazıldıysa
  metadata_json   TEXT                        -- Komut-spesifik ekstra bilgi
);

CREATE INDEX idx_invocations_timestamp ON invocations(timestamp DESC);
CREATE INDEX idx_invocations_project ON invocations(project_path, timestamp DESC);
CREATE INDEX idx_invocations_command ON invocations(command, timestamp DESC);
```

**Schema kararı:** `command` field'ı sadece `flart` subcommand'ını tutar (örn. `'analyze'`, `'exec'`, `'build'`). Tam komut satırı için `args` ile birleştirilir. Örnek satırlar:

| command | args | Tam komut |
|---------|------|-----------|
| `analyze` | `lib/` | `flart analyze lib/` |
| `exec` | `dart` | `flart exec dart` |
| `exec` | `bash` | `flart exec bash` |
| `build` | `apk --release` | `flart build apk --release` |
| `test` | `(null)` | `flart test` |

`--by-command` raporları `command` üzerinde GROUP BY yapar; executor için ayrıca `args`'tan runtime çıkarılır.

**`metadata_json` populate kaynağı:**

- Filter çağrılarında: `FilterResult.metadata` Map → `jsonEncode(...)` → DB
- Executor çağrılarında: `{"runtime": "<runtime>", "timed_out": <bool>}` JSON → DB
- Null veya `{}` kabul; query'lerde defensive parse.

Örnek metadata payloads:

```json
// flart analyze
{"errors": 3, "warnings_unique": 8, "warnings_total": 24, "infos_suppressed": 17}

// flart test
{"tests_total": 47, "passed": 45, "failed": 2, "skipped": 0, "duration_s": 4.2}

// flart exec dart
{"runtime": "dart", "timed_out": false}
```

**Tablo: schema_version**

```sql
CREATE TABLE schema_version (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);
```

Migration sistemi: `core/migrations/v1.dart`, `v2.dart` ... her biri SQL list'i export eder, `MigrationRunner` çalışmamış olanları sırayla uygular.

**SQLite Pragmas (Faz 1'de uygulanacak):**

```sql
PRAGMA journal_mode = WAL;          -- Concurrent read/write için
PRAGMA synchronous = NORMAL;         -- WAL ile güvenli, daha hızlı
PRAGMA busy_timeout = 5000;          -- 5s retry
PRAGMA foreign_keys = ON;
```

WAL mode iki `flart` process'inin aynı anda yazmaya çalışmasını handle eder. busy_timeout açıkça set edilir, default 0 (immediate fail) istenmez.

### 3.4 Token Estimation

**Strateji:** Byte ve karakter sayımı kesin; token sayısı tahmin.

```dart
class TokenEstimator {
  final double charsPerToken;

  /// Constructor — config'den `chars_per_token` değeri alınır,
  /// yoksa 3.8 default kullanılır. flart_cli composition root'unda inject edilir.
  const TokenEstimator({this.charsPerToken = 3.8});

  /// Config'den factory — `flart_core`'un Config sınıfından kurar.
  factory TokenEstimator.fromConfig(Config config) {
    return TokenEstimator(
      charsPerToken: config.tokenEstimation.charsPerToken,
    );
  }

  int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / charsPerToken).ceil();
  }

  /// Bilgilendirme amaçlı: gerçek token sayısı için Anthropic count_tokens
  /// API'sine bağlanılabilir (opsiyonel, ileride).
}
```

**Composition:** CLI entry point Config'i yükler, TokenEstimator'ı `fromConfig` ile kurar, FilterRunner ve SandboxExecutor'a inject eder.

**Not:** İlerde Anthropic `count_tokens` API integration eklenebilir. v1.0'da basit tahmin yeterli; raporlarda "estimated" kelimesi belirtilecek.

### 3.5 Byte-Safe Truncation

UTF-8 surrogate pair koruma, satır sınırında snap. Context-mode'un `truncate.ts`'inden ilham alacak.

```dart
class SafeTruncator {
  /// Head + tail strategy: ilk N% + son M%, ortayı işaretle.
  /// Satır sınırında snap eder, UTF-8 char boundary'sini bozmaz.
  static String headTail({
    required String input,
    required int maxBytes,
    double headRatio = 0.6,
    String marker = '\n... [{n} lines / {bytes} truncated — kept first {head} + last {tail}] ...\n',
  });

  static String byteSafePrefix(String input, int maxBytes);
}
```

### 3.6 Tee Mechanism

Fail durumunda ham çıktı `~/.local/share/flart/tee/` altında `{epoch}_{slug}.log` olarak saklanır. Filter veya executor output'unun sonuna hint eklenir:

```
FAILED: 2/15 tests
[full output: ~/.local/share/flart/tee/1747405200_flutter_test.log]
```

Rotation: son N dosya (config'den) tutulur, eski silinir.

### 3.7 Logger

Basit level-based logger, stderr'e yazar. `log.file` config set edilmişse ayrıca dosyaya append eder (stderr çıktısı yine devam eder).

**Format (stderr):**

```
[<HH:MM:SS>] <LEVEL> <message>
[17:42:18] INFO  Loaded config from /Users/x/.config/flart/config.yaml
[17:42:18] WARN  jq not found; hook installation may fail
[17:42:19] ERROR Database migration v2 failed: ...
```

**Format (dosya, varsa):**

```
2026-05-16T17:42:18+0300 INFO  Loaded config from ...
```

**Level filter:**
- `debug` (`-vvv`): her şey
- `info` (`-v`, default): debug hariç
- `warn` (`-q` veya `log.level: warn`): info + debug hariç
- `error`: sadece hatalar

**Logger API:**

```dart
class Logger {
  final LogLevel level;
  final IOSink? fileSink;        // null → sadece stderr

  void debug(String msg);
  void info(String msg);
  void warn(String msg);
  void error(String msg, [Object? error, StackTrace? stack]);
}
```

`log.file: null` → sadece stderr. `log.file: ~/.local/share/flart/flart.log` → hem stderr hem dosya.

---

## 4. Modül 3 — Sandbox Executor (flart_executor) — ÖNCELİK 1

### 4.1 Hedef

Agent'ın ham veri yerine **script çalıştırıp sonuç almasını** sağlamak. Tipik kullanım:

```
[Agent kararı] "kaç provider var? Read+Grep yapmak yerine script yazayım"
[Agent komutu] flart exec dart 'sayProviders()'
[flart] Script'i çalıştır → çıktıyı yakala → truncate et → savings'e kaydet → döndür
```

### 4.2 Desteklenen Runtime'lar

**v1.0'da:**

| Runtime | Kullanım | Komut |
|---------|----------|-------|
| `dart` | Hızlı analiz scripti, AST | `flart exec dart 'kod...'` veya `flart exec dart --file path.dart` |
| `bash` / `sh` | find/grep/awk/jq kombinasyonları | `flart exec bash 'find lib -name "*.dart" \| wc -l'` |
| `python` | Veri parse, JSON manipülasyonu | `flart exec python 'kod'` |
| `node` / `javascript` | JSON manipülasyonu, regex | `flart exec node 'kod'` |

**Runtime alias'ları:** `sh` → `bash`, `javascript` → `node`. Implementation `_resolveRuntime(String input) → String canonical` ile yapar; dört kanonik runtime: `dart`, `bash`, `python`, `node`.

**Tespit ve fallback:** Her runtime için PATH'te varlığını kontrol et. Eksikse anlamlı hata döndür:

```
flart exec python: 'python' not found in PATH.
Tried: python3, python. Install Python 3 or use bash/node.
```

`python` araması önce `python3`, sonra `python` denemeli (modern dağıtımlar `python` symlink'i kaldırdı).

### 4.3 Çalışma Modu

**Stratejisi:** Geçici dizinde script dosyası oluştur, runtime ile çalıştır, output'u capture et, temizle.

**Önemli:** `Process.run(...).timeout(...)` kullanma. Timeout olunca process kill edilmez, zombie kalır. Doğru yol: `Process.start` + manuel kill.

```dart
class SandboxExecutor {
  Future<ExecResult> execute({
    required String runtime,
    required String code,
    Map<String, String>? env,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 60),
    int maxOutputBytes = 65536,
  }) async {
    final tmpDir = await Directory.systemTemp.createTemp('flart_exec_');
    Process? process;
    Timer? timeoutTimer;
    var killed = false;

    try {
      final scriptFile = File('${tmpDir.path}/${_scriptName(runtime)}');
      await scriptFile.writeAsString(code);

      process = await Process.start(
        _runtimeCommand(runtime),
        [scriptFile.path],
        environment: env,
        workingDirectory: workingDirectory ?? Directory.current.path,
        runInShell: false,
      );

      // stdin'i hemen kapat — script stdin bekliyorsa deadlock olmasın.
      await process.stdin.close();

      // Manuel timeout: süre dolduğunda SIGTERM, 2s sonra SIGKILL.
      timeoutTimer = Timer(timeout, () {
        killed = true;
        process?.kill(ProcessSignal.sigterm);
        Future.delayed(const Duration(seconds: 2), () {
          process?.kill(ProcessSignal.sigkill);
        });
      });

      // stdout + stderr: byte sayacı tut, limite ulaşınca buffer'a yazmayı
      // bırak ama stream'i drain etmeye devam et — pipe dolarsa script
      // hang olur. Stream tamamlanması Completer ile sinyallenir.
      final stdoutBytes = <int>[];
      final stderrBytes = <int>[];
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      process.stdout.listen(
        (chunk) {
          final remaining = maxOutputBytes - stdoutBytes.length;
          if (remaining <= 0) return;
          stdoutBytes.addAll(chunk.length <= remaining
              ? chunk
              : chunk.sublist(0, remaining));
        },
        onDone: stdoutDone.complete,
        onError: stdoutDone.completeError,
      );
      process.stderr.listen(
        (chunk) {
          final remaining = maxOutputBytes - stderrBytes.length;
          if (remaining <= 0) return;
          stderrBytes.addAll(chunk.length <= remaining
              ? chunk
              : chunk.sublist(0, remaining));
        },
        onDone: stderrDone.complete,
        onError: stderrDone.completeError,
      );

      // stdout, stderr ve exitCode paralel beklenir; sıra deadlock'a yol açmaz.
      final results = await Future.wait<Object?>([
        stdoutDone.future,
        stderrDone.future,
        process.exitCode,
      ]);
      final exitCode = results[2] as int;

      return ExecResult(
        stdout: utf8.decode(stdoutBytes, allowMalformed: true),
        stderr: utf8.decode(stderrBytes, allowMalformed: true),
        exitCode: killed ? 124 : exitCode,  // 124 = POSIX timeout
        timedOut: killed,
      );
    } finally {
      timeoutTimer?.cancel();
      await tmpDir.delete(recursive: true);
    }
  }
}
```

**maxOutputBytes davranışı:** Byte sayacı limit'e ulaşınca buffer'a yazma durur; stream `listen` ile drain edilmeye devam eder ki pipe tıkanıp script hang olmasın. Bu intentional — kullanıcı `--max-output` ile büyütebilir.

### 4.4 Dart Sandbox — Özel Durum

Dart için iki mod:

**Mod A (v1.0 — standalone):** `dart` komutu ile tek dosya script çalıştır. Pubspec yok, dependency çözümlemesi yok.

**İzin verilen import'lar (mod A):**
- `dart:core`, `dart:io`, `dart:convert`, `dart:async`, `dart:math`, `dart:typed_data`, `dart:collection`
- Diğer `dart:` core kütüphaneler (`dart:isolate`, vs.) — runtime'da kullanılabilir, garanti yok

**Yasak (mod A):**
- `package:...` import'ları — pubspec olmadığı için resolve edilemez
- Project'in kendi dosyalarına relative import — script tmpdir'de, ona göre relative imkansız

**Import validation:** Script'i çalıştırmadan önce regex ile `^import\s+['"](package:|\.\./|\./)` aranır. Eşleşme bulunursa anlamlı hata döndürülür:

```
flart exec dart: package: and relative imports not supported in mod A.
Allowed: dart:core, dart:io, dart:convert, dart:async, dart:math, dart:typed_data.
Use bash/python for tasks that need project dependencies.
```

**Mod B (v1.1+, opsiyonel):** Project root'a sembolik link ile bağla; mevcut `pubspec.yaml`'ı kullan. **Risk:** dependency yükleme yavaş; ilk versiyonda atlanır.

**Auto-wrap (v1.4):**

`flart exec dart` Dart standalone mode'un `main()` boilerplate zorunluluğunu otomatik handle eder. Kullanıcı (veya CLAUDE.md routing'inden Claude) doğrudan top-level kod yazabilir:

```bash
flart exec dart 'print("hello")'                # auto-wrap → void main() async { print("hello") }
flart exec dart 'final n = 1+2; print(n);'      # aynı şekilde
flart exec dart 'void main() => print("hi");'   # explicit main varsa wrap atlanır
flart exec dart "import 'dart:io'; print(pid);" # import'lar wrap dışına çıkarılır
```

Wrap kuralı:
- Top-level `main(` regex'i (`^\s*(void\s+|Future(\s*<[^>]*>)?\s+)?main\s*\(`, multiLine) eşleşirse, kod olduğu gibi geçer.
- Eşleşmezse: `import` statement'ları (Dart'ta top-level zorunlu) ayrıştırılıp wrap dışına alınır, kalan body `void main() async { ... }` içine sarılır. `async` wrap'i body içinde `await` kullanımına izin verir.
- Block comment içinde fake `void main(` varsa false-positive olabilir (wrap atlanır), kullanıcı kendi main'ini açıkça yazmalıdır. **Silent korupsiyon yok** — Dart compile error verir.

Implementation: `flart_executor/lib/src/dart_wrapper.dart` → `wrapDartIfNeeded(String code)`. Validation (`validateDartImports`) **orijinal kod üzerinden** çalışır — wrap import eklemez, mod A allowlist'ini bypass etmez.

### 4.5 Output Capture ve Truncation

**Akış:**

1. Process'i başlat
2. stdout + stderr ayrı stream olarak topla
3. Toplam maxOutputBytes'a yaklaşıyorsa stream'i kapat (overflow protection)
4. Truncate stratejisi: `head_ratio` config'den, satır boundary'sinde snap
5. Truncate edildiyse hint ekle: `[{n} lines / {bytes} truncated — kept first {h}% + last {t}%]`

### 4.6 Güvenlik

**v1.0'da yapılacaklar:**

- Process timeout (default 60s)
- Output size limit (default 64KB)
- Geçici dosyalar otomatik temizlenir
- Çalışma dizini explicit

**v1.0'da YAPILMAYACAK:**

- Network sandbox (script network çağrısı yapabilir; izolasyon feature değil)
- Filesystem sandbox (project dışına yazabilir)
- CPU/memory limit (OS-level)

**Not:** Bu kullanıcı kendi makinesinde, kendi projesinde çalışan bir araç. Tam izolasyon hedefi yok — kötü niyetli script çalıştırma senaryosu kapsam dışı. Sen bu aracı kendi geliştirme akışında kullanacaksın.

### 4.7 CLI Arayüzü

```
flart exec [flags] <runtime> <code>
flart exec [flags] <runtime> --file <path>
flart exec [flags] <runtime> --stdin                 # stdin'den oku
```

**Flag'ler runtime ve code'dan önce gelmeli** (args paketi POSIX-style requires). Örnekler:

```bash
flart exec --timeout 30 dart 'print("hi")'
flart exec --max-output 32k bash 'find . -name "*.dart"'
flart exec --no-truncate dart --file analysis.dart
```

**Yanlış kullanım:**
```bash
flart exec dart --timeout 30 'print("hi")'   # ERROR: --timeout exec'in flag'i
```

`args` paketi alt komutlar için ayrı parser kullanır; `exec` komutu kendi flag'lerini deklare eder, sonra positional alır.

**Örnekler:**

```bash
flart exec dart "
import 'dart:io';
final providers = Directory('lib').listSync(recursive: true)
  .whereType<File>()
  .where((f) => f.path.endsWith('.dart'))
  .where((f) => f.readAsStringSync().contains('Provider<'))
  .length;
print('Total provider files: \$providers');
"

flart exec bash 'find lib -name "*.dart" ! -name "*.g.dart" ! -name "*.freezed.dart" | wc -l'

flart exec python "
import json, subprocess
result = subprocess.run(['flutter', 'pub', 'outdated', '--json'], capture_output=True, text=True)
data = json.loads(result.stdout)
outdated = [p for p in data['packages'] if p['current'] != p['latest']]
print(f'{len(outdated)} outdated packages')
"
```

### 4.8 Test Kapsamı

- `buildScriptFilename` — her runtime için doğru extension
- `headTailTruncate` — boundary cases (empty, exactly maxBytes, UTF-8 split)
- `timeoutEnforcement` — uzun süren script'in kesilmesi
- `outputCapture` — stdout + stderr birleşik mi ayrı mı
- Integration: gerçek runtime'larla küçük scriptler

---

## 5. Modül 1 — Reactive Filters (flart_filters) — ÖNCELİK 2

### 5.1 Hedef

Flutter/Dart geliştirme komutlarının çıktısını parse edip compact hale getirir. Her komut bir filter modülü.

### 5.2 Desteklenen Komutlar (Senin Workflow'una Göre)

| Komut | flart komutu | Tasarruf hedefi | Strateji |
|-------|--------------|----------------|----------|
| `flutter analyze` / `dart analyze` | `flart analyze` | %75-90 | `dart analyze --format=machine` parse, gruplayarak göster |
| `flutter test` | `flart test` | %85-95 | `flutter test --reporter=json` parse, sadece failure |
| `flutter build apk` | `flart build apk` | %80-90 | Gradle çıktısı parse, BUILD SUCCESS/FAILED + error blokları |
| `flutter build web` | `flart build web` | %75-85 | Build output filter, asset summary |
| `flutter build ipa` | `flart build ipa` | %75-85 | Xcode/Cocoapods output filter |
| `flutter pub get` | `flart pub get` | %85-95 | "Got dependencies" + conflict'ler |
| `flutter pub upgrade` | `flart pub upgrade` | %70-85 | Değişen versiyonlar listesi |
| `flutter pub outdated` | `flart pub outdated` | %60-75 | `--json` flag, tablo render |
| `flutter pub deps` | `flart pub deps` | %80-90 | Direct dependencies only (default), `--tree` flag ile ağaç |
| `dart format` | `flart format` | %85-95 | Sadece değişen dosyalar |
| `dart fix` | `flart fix` (default `--dry-run`) / `flart fix --apply` | %70-95 | Tek filter, `--apply` ile davranış değişir |
| `flutter gen-l10n` | `flart gen-l10n` | %80-90 | Generated file listesi + missing key uyarıları |
| `flutter clean` | `flart clean` | %95+ | "ok" |
| `flutter doctor` | `flart doctor` | %60-75 | Sadece [✗] olan kategoriler + özet |
| `flutter devices` | `flart devices` | %50-70 | Compact tablo |
| `dart compile exe` | `flart compile exe` | ≈%0 (anti-bloat passthrough) | Modern `dart compile` zaten tek satır (`Generated: <path>`); filter "✓ Compiled exe → path" wrap'ini önerir ama wrap raw'dan büyük → FilterRunner anti-bloat raw geçirir. Tracking + tee mekanizmaları çalışır, sadece compaction "no work to do" durumudur. |

**v1.0'da YOK (v1.1'e ertelendi):**

- `flutter run` — interaktif hot reload, filter etmesi karmaşık. Önce non-interactive moda nasıl bağlanacağımız çözülmeli.

**Generic wrapper:**

| Komut | Açıklama |
|-------|----------|
| `flart err <cmd>` | Çıktıdan sadece error satırlarını çek (RTK'nın yaklaşımı) |
| `flart test-wrap <cmd>` | Generic test runner — failure only |

### 5.3 Filter Mimari Pattern

İki ayrı sorumluluk:

**`CommandFilter`** — Pure transformation (testlenebilir, side-effect yok). Çıktıyı parse edip compact stringe çevirir. Process çalıştırma sorumluluğu **yok**.

**`FilterRunner`** — Orchestration. Filter'ı çağırır, native process'i çalıştırır, savings DB'ye yazar, tee yapar, exit code'u döndürür.

```dart
/// Pure transformation. Implementations override the methods below.
/// No I/O, no process spawning, no DB writes here.
abstract class CommandFilter {
  /// Filter'ın benzersiz adı (örn. 'analyze', 'test', 'build_apk')
  String get name;

  /// Hangi `flart` subcommand'ına bağlı (örn. 'analyze')
  String get flartCommand;

  /// Native komut + flag'ler (örn. ['dart', 'analyze', '--format=machine'])
  /// userArgs hariç; runner birleştirir.
  List<String> baseNativeCommand(List<String> userArgs);

  /// Native komutu çalıştırırken set edilecek env vars
  Map<String, String> environment(List<String> userArgs) => const {};

  /// Pure function: stdout + stderr + exit code → filtered output.
  /// Side-effect içermez, file system'e dokunmaz, process spawn etmez.
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  });
}

@immutable
class FilterResult {
  final String output;             // Compact, model'e gidecek string
  final bool wasTruncated;
  final Map<String, Object?> metadata;  // Komut-spesifik (test count, warning count)

  const FilterResult({
    required this.output,
    this.wasTruncated = false,
    this.metadata = const {},
  });
}
```

**`FilterRunner`** sorumluluğu (flart_filters paketinde değil, flart_cli içinde — çünkü tracking ve tee orchestration CLI concern'ü):

```dart
class FilterRunner {
  final CommandFilter filter;
  final InvocationTracker tracker;
  final TeeManager tee;
  final Logger log;

  FilterRunner({
    required this.filter,
    required this.tracker,
    required this.tee,
    required this.log,
  });

  Future<int> run(List<String> userArgs) async {
    final stopwatch = Stopwatch()..start();
    final nativeCmd = filter.baseNativeCommand(userArgs);
    final fullArgs = [...nativeCmd.skip(1), ...userArgs];

    final process = await Process.start(
      nativeCmd.first,
      fullArgs,
      environment: filter.environment(userArgs),
      runInShell: false,
    );

    // dart:io'nun global `stdout`/`stderr`'iyle çakışmayı önlemek için
    // raw* isimleri kullanılır.
    final rawStdoutFuture = process.stdout.transform(utf8.decoder).join();
    final rawStderrFuture = process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode;
    final rawStdout = await rawStdoutFuture;
    final rawStderr = await rawStderrFuture;
    stopwatch.stop();

    // Pure filter: text → text
    final result = filter.filter(
      stdout: rawStdout,
      stderr: rawStderr,
      exitCode: exitCode,
      userArgs: userArgs,
    );

    // Tee on failure (config'e göre)
    String? teePath;
    if (exitCode != 0 && tee.shouldTee(exitCode)) {
      teePath = await tee.write(filter.name, '$rawStdout\n$rawStderr');
    }

    // Track
    await tracker.record(
      module: 'filter',
      command: filter.flartCommand,
      args: userArgs.join(' '),
      rawText: '$rawStdout$rawStderr',
      filteredText: result.output,
      durationMs: stopwatch.elapsedMilliseconds,
      exitCode: exitCode,
      wasTruncated: result.wasTruncated,
      teePath: teePath,
      metadata: result.metadata,
    );

    // Filter output'u koşulsuz basılır — boş olup olmadığına filter karar verir.
    print(result.output);
    if (teePath != null) print('[full output: $teePath]');

    return exitCode;
  }
}
```

**Test edilebilirlik:** `CommandFilter` implementasyonları input string → output string, mock'suz unit test edilir. `FilterRunner` integration test'lerle test edilir (fake process veya gerçek `echo`/`true`/`false` ile).

### 5.4 Filter Implementasyon Notları (Komut Bazında)

#### 5.4.1 `flart analyze`

**Native call:** `dart analyze --format=machine`

**Not:** `dart analyze` JSON output desteklemez (eski `dart analyzer` deprecated). Sadece `--format=machine` ve default human-readable format vardır. Biz `machine` kullanırız çünkü parse edilebilir, deterministik.

**Format machine:** Her satır pipe-separated: `SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE`

**Filtreleme:**

- Generated dosyaları (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`) ayrı bucket
- Severity gruplaması: ERROR > WARNING > INFO
- Dosya başına gruplama
- Aynı rule code tekrar eden uyarıları say (`unused_local_variable: 12 occurrences`)

**Compact output örneği:**

```
ERRORS (3):
  lib/features/auth/auth_repository.dart:
    L42:8  invalid_assignment: cannot assign String to int
    L67:12 undefined_method: 'foo' not defined on User
  lib/features/projects/project_service.dart:
    L120:4 missing_required_argument: 'id'

WARNINGS (8 unique, 24 total):
  unused_local_variable [12]: in 5 files
  unnecessary_import [4]: in 3 files
  prefer_const_constructors [8]: in 4 files

INFO: 17 hints suppressed (use -v to show)
Generated files: 4 warnings suppressed (.g.dart, .freezed.dart)
```

#### 5.4.2 `flart test`

**Native call:** `flutter test --reporter=json`

**Format:** Her satır JSON event (`testStart`, `testDone`, `error`, `print`, `done`, `suite`).

**Filtreleme:**

- Tüm test ID'lerini topla, başarılı olanları sıkıştır (sadece toplam göster)
- `error` event'lerinde stack trace + error + expected/actual saklanır
- `print` event'lerini başarısız testlere bağla (test sırasında log basanlar)
- `done.success: true` durumunda sadece "X tests passed in Ys"

**Compact output örneği (fail case):**

```
FAILED 2/47 tests in 4.2s

✗ test/features/auth/login_test.dart
  - LoginNotifier: emits error on invalid credentials
    Expected: contains 'Invalid email'
    Actual:   'Network error'
    Stack:    package:myapp/login_notifier.dart:54:18

✗ test/widget/project_card_test.dart
  - ProjectCard: renders status badge
    Expected: 1 widget with text 'Active'
    Actual:   0 widgets matching
    Stack:    package:myapp/widgets/project_card.dart:88:12

Passed: 45  Failed: 2  Skipped: 0
```

#### 5.4.3 `flart build apk` / `flart build web`

**Strateji:** Gradle/build output çok gürültülü. State machine ile takip et:

- Pre-build: "Running Gradle task...", task list — atılır
- Compilation: hata satırlarını yakala (error: ile başlayan, file:line:col formatı)
- Asset processing: özet (`Built X assets`)
- Output: "✓ Built build/app/outputs/flutter-apk/app-release.apk (Y MB)"

**Compact output örneği (success):**

```
✓ Built build/app/outputs/flutter-apk/app-release.apk (24.3 MB)
  Compile: 47s | Assemble: 12s | Total: 59s
```

**Fail case:**

```
✗ Build failed (Gradle exit 1)

ERROR: lib/features/auth/auth_screen.dart:42:8
  The argument type 'String?' can't be assigned to the parameter type 'String'.

ERROR: lib/main.dart:18:14
  Undefined name 'AppRouter'.

[full Gradle output: ~/.local/share/flart/tee/...]
```

#### 5.4.4 `flart pub get`

**Native call:** `flutter pub get` (JSON output yok native olarak)

**Filtreleme:**

- "Resolving dependencies..." — at
- "Got dependencies!" → "ok"
- Conflict varsa: tam paragraf bırak (kritik bilgi)
- New/changed/removed: gruplayarak göster

**Dependency count source:** `flutter pub get` text output toplam dependency sayısı vermez. Sayı `pubspec.lock`'ı parse ederek elde edilir (`packages:` map'inin key sayısı). Filter `pubspec.lock` yoksa veya bozuksa sayı kısmını sessizce atlar (`ok (0 changed)` gibi). Faz 4'te implement edilir.

**Compact output:**

```
ok (47 deps, 0 changed)

# veya değişiklik varsa:
ok (47 deps)
  + riverpod_generator 2.4.0
  + freezed 2.5.7
  ~ supabase_flutter 2.5.0 → 2.6.1
  - http (removed)
```

#### 5.4.5 `flart format`

**Native:** `dart format <args>` standart çıktı: her satır `Formatted <file>` veya `Unchanged <file>`.

**Filtreleme:**

- Unchanged satırları at
- "Formatted X files (Y changed)" özet

#### 5.4.6 `flart gen-l10n`

**Native:** `flutter gen-l10n` — standart text output

**Filtreleme:**

- "Generated to: ..." → sadece path
- Untranslated message warning'lerini grupla (locale bazında count)

#### 5.4.7 `flart doctor`

**Native:** `flutter doctor`

**Filtreleme:**

- `[✓]` kategorileri özetle (tek satırlık özet)
- `[!]` (partial / warning) kategorileri orta detayda göster — alt bullet'ları kısalt
- `[✗]` (eksik / hata) kategorileri **tam göster** (kritik)

**Örnek:**

```
✓ Flutter (3.27.0, stable)
✓ Android toolchain (SDK 34)
! Cocoapods (1.13.0) — needs update
✗ Xcode — incomplete installation
  • Xcode 15.4 found but xcodebuild not in PATH
  • Run: sudo xcode-select --switch /Applications/Xcode.app
✓ Chrome
✓ Android Studio (2024.1)
✓ VS Code (1.95.0)
✓ Connected device (2)
✓ Network resources
```

**All-healthy davranışı (v1.6 ek):** Tüm kategoriler `[✓]` ise output şu şekilde collapse olur:

```
✓ All 9 categories healthy.
```

Bu Wonderous/CI-without-issues gibi gerçek dünyada beklenen tek-satırlık özet. Daha hassas filtreleme istenirse `flart doctor --verbose` ile alt-bullet'lar tutulabilir (v1.1).

### 5.5 Generic Wrappers

#### `flart err <command>`

Komutu olduğu gibi çalıştır, ama stdout/stderr'den sadece error pattern'lerini çek. Pattern'ler:

- `error:`, `ERROR:`, `Error:` ile başlayan satırlar
- `FAILED`, `FAIL`, `failed:` içeren satırlar
- File:line:col formatlı satırlar
- Stack trace satırları (önceki match'lerin altında)

#### `flart test-wrap <command>`

Test runner sonucu özetler. JSON output yoksa text parse. "X passed, Y failed" özeti.

---

## 6. Modül 4 — Savings Reporter (flart_savings)

### 6.1 Hedef

Aracın tasarrufunu rakamla ölçmek. Her invocation kaydedilir, raporlar üretilir.

### 6.2 CLI

```
flart savings                          # Toplam özet (proje + global)
flart savings --since 7d               # Son 7 gün
flart savings --since 2026-01-01       # Belirli tarihten
flart savings --project                # Sadece bu proje
flart savings --by-command             # Komut bazında breakdown
flart savings --by-module              # Modül bazında (filter / executor)
flart savings --top 10                 # En çok tasarruf ettiren ilk 10 invocation
flart savings --details --limit 20     # Son 20 invocation detay
flart savings --json                   # Machine-readable JSON çıktı
flart savings --csv                    # CSV export
flart savings --graph                  # ASCII grafik (son 30 gün, daily)
flart savings --reset                  # Veritabanını temizle (onay ister)
```

### 6.3 Rapor Örnekleri

#### Default (`flart savings`)

```
flart Savings Report
====================

All-time savings (since 2026-01-15):
  Invocations:        1,247
  Raw output:         48.3 MB
  Filtered output:     6.1 MB
  Saved:              42.2 MB  (87.4%)

  Estimated raw tokens:        12,711,000
  Estimated filtered tokens:    1,605,000
  Estimated tokens saved:      11,106,000  (87.4%)

By module:
  filter:    854 invocations  →  saved   8.2M tokens  (82%)
  executor:  393 invocations  →  saved   2.9M tokens  (96%)

By project:
  ~/dev/project-a             623 invocations  →  saved 6.1M tokens
  ~/dev/project-b             412 invocations  →  saved 3.8M tokens
  ~/dev/playground            212 invocations  →  saved 1.2M tokens

Top commands:
  flart analyze     →  saved  3.2M tokens  (89%)
  flart test        →  saved  2.8M tokens  (93%)
  flart exec dart   →  saved  1.9M tokens  (96%)
  flart build apk   →  saved  1.4M tokens  (87%)
  flart exec bash   →  saved  1.0M tokens  (95%)

Use `flart savings --details` for individual invocation breakdown.
```

#### `--by-command`

```
Command                    Calls    Raw tokens   Filtered    Saved    %
flart analyze                312    3,572,000     402,000   3,170,000  88.7
flart test                   218    3,012,000     201,000   2,811,000  93.3
flart exec dart              154    1,987,000      82,000   1,905,000  95.9
flart build apk               42    1,520,000     198,000   1,322,000  87.0
flart exec bash               89    1,098,000      52,000   1,046,000  95.3
flart pub get                132      488,000      19,000     469,000  96.1
flart gen-l10n                47      298,000      31,000     267,000  89.6
...
```

#### `--graph`

```
Tokens saved per day (last 30 days)

   2.5M ┤                                              ▆█
   2.0M ┤                                          ▆▆██▆█
   1.5M ┤                              ▆       ▆█████████
   1.0M ┤        ▆▆          ▆▆██   ███▆██  ▆██████████████
   0.5M ┤   ▆██████▆     ▆█████████████████████████████████
     0  ┼──┴──────────┴──────────────────────────────────────
        Apr 16              May 1              May 16

Peak: May 14  (2,847,000 tokens)
Avg:  892,000 tokens/day
```

#### `--json`

```json
{
  "report_generated_at": "2026-05-16T17:00:00Z",
  "since": "2026-01-15T09:23:11Z",
  "summary": {
    "invocations": 1247,
    "raw_bytes": 50638848,
    "filtered_bytes": 6395904,
    "bytes_saved": 44242944,
    "savings_ratio": 0.874,
    "est_raw_tokens": 12711000,
    "est_filtered_tokens": 1605000,
    "est_tokens_saved": 11106000
  },
  "by_module": [
    { "module": "filter", "invocations": 854, "tokens_saved": 8210000, "ratio": 0.82 },
    { "module": "executor", "invocations": 393, "tokens_saved": 2896000, "ratio": 0.96 }
  ],
  "by_project": [...],
  "top_commands": [...]
}
```

### 6.4 Sonuç Doğruluğu Disclaimer

Rapor footer'ında her zaman config'deki değerlerle render edilir:

```
Note: Token sayıları tahminidir (chars / {chars_per_token} formülü ile).
Gerçek Claude tokenizasyonu ile ±%{estimated_deviation*100} sapma olabilir.
Byte/karakter sayıları kesindir.
```

Default config (`chars_per_token: 3.8`, `estimated_deviation: 0.15`) ile:

```
Note: Token sayıları tahminidir (chars / 3.8 formülü ile).
Gerçek Claude tokenizasyonu ile ±%15 sapma olabilir.
Byte/karakter sayıları kesindir.
```

Formatter Config'i okur; magic number kodda tekrar etmez.

---

## 7. Modül 5 — Claude Code Integration (flart_hooks)

### 7.1 Hedef

Claude Code'un flart komutlarını otomatik kullanmasını sağlamak.

### 7.2 İki Mekanizma Bir Arada (Alternatif Değil)

Filter'lar için **hook**, executor için **routing instructions**. İkisi birlikte kurulur, biri diğerinin yerine geçmez.

**Mekanizma A — PreToolUse Hook (filter rewrite için):**

Bash tool çağrılarını intercept eder, `flutter analyze` → `flart analyze` çevirir.

```
~/.claude/settings.json:
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "~/.config/flart/hooks/rewrite.sh" }]
    }]
  }
}
```

`~/.config/flart/hooks/rewrite.sh`:

```bash
#!/usr/bin/env bash
# Thin delegating hook — tüm logic flart binary'sinde
set -e

if ! command -v flart &>/dev/null; then exit 0; fi
if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

REWRITTEN=$(flart rewrite "$CMD" 2>/dev/null)
EXIT_CODE=$?

case $EXIT_CODE in
  0)  # Rewrite var
    [ "$CMD" = "$REWRITTEN" ] && exit 0
    jq -c --arg cmd "$REWRITTEN" \
      '.tool_input.command = $cmd | {
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "allow",
          "permissionDecisionReason": "flart auto-rewrite",
          "updatedInput": .tool_input
        }
      }' <<<"$INPUT"
    ;;
  *) exit 0 ;;  # Passthrough
esac
```

**Mekanizma B — CLAUDE.md Routing Instructions (executor için):**

Hook bash komutlarını rewrite eder ama agent **executor paradigmasını kendi seçmelidir** ("kaç provider var?" sorusuna Read+Grep yerine `flart exec dart ...` yazsın). Bu için proje root'una `CLAUDE.md` routing block ekleriz (init sırasında):

```markdown
## flart routing

For Flutter/Dart development tasks in this project, prefer flart commands when available:

| Instead of                   | Use                          |
|------------------------------|------------------------------|
| flutter analyze              | flart analyze                |
| dart analyze                 | flart analyze                |
| flutter test                 | flart test                   |
| flutter build apk            | flart build apk              |
| flutter pub get              | flart pub get                |
| dart format                  | flart format                 |
| dart fix                     | flart fix                    |
| dart fix --apply             | flart fix --apply            |

For data/analysis questions ("how many providers", "count files matching X",
"summarize structure"), use the executor instead of multiple Read/Grep calls:

  flart exec dart '...'    # Dart için (top-level kod yeterli — auto-wrap)
  flart exec bash '...'    # find/grep/awk kombinasyonları
  flart exec python '...'  # JSON/CSV manipülasyonu

The executor runs the script in a sandbox and returns only the result,
which keeps tool output out of your context window.
```

### 7.3 `flart init` Komutu

Tek komut ile her şeyi kurar:

```bash
flart init                          # Hem global hook hem proje config (interactive)
flart init --global                  # Sadece global hook
flart init --project                 # Sadece proje config + CLAUDE.md routing
flart init --yes                     # Tüm prompt'ları onayla (CI için)
flart init --uninstall               # Geri al
flart init --show                    # Mevcut kurulumu göster
flart init --check                   # Doctor: jq var mı, hook ok mı, vs.
```

`flart init --project` yaparken:

1. `<project>/.flart/config.yaml` oluştur (default content)
2. `<project>/CLAUDE.md` varsa, routing block'unu append et (eklenmediyse)
3. `<project>/.flart/.gitignore` oluştur (savings DB git'e gitmesin)

**İlk çalıştırmada interaktif prompt** (`--yes` flag'i yoksa):

```dart
// stdin.readLineSync() ile basit y/N prompt
stdout.write('flart will install a Claude Code hook that auto-allows '
             'rewritten commands (bypasses permission prompts for filter targets).\n'
             'Continue? [y/N] ');
final answer = stdin.readLineSync()?.trim().toLowerCase();
if (answer != 'y' && answer != 'yes') {
  print('Cancelled. No changes made.');
  exit(0);
}
```

CI ortamında veya non-tty stdin durumunda `--yes` flag'i zorunludur; aksi halde komut hata ile çıkar.

### 7.4 `flart rewrite <cmd>` Komutu

Hook tarafından çağrılır. Komutun flart karşılığı varsa onu döndürür, yoksa hata kodu döner.

```dart
String? rewriteCommand(String input) {
  // Tokenize, parse leading command
  // Match table: flutter analyze → flart analyze, vb.
  // Return rewritten or null (passthrough)
}
```

**Önemli:** Komut başında `cd ...` veya `cd ... && ...` varsa korunur, sadece son komut rewrite edilir. Pipe (`|`), redirect (`>`), background (`&`) durumlarında **rewrite yapılmaz** (output yönü değişmiş, filter işe yaramaz).

---

## 8. Modül 6 — CLI Entry Point (flart_cli)

### 8.1 Komut Şeması

```
flart <command> [args...]

Komutlar:
  exec <runtime> <code|--file path>    Sandbox executor
  analyze [path]                       Flutter/Dart analyze (filtered)
  test [path]                          Flutter test (filtered)
  build <target> [args...]             Flutter build (filtered) — apk | web | ipa
  pub <subcommand> [args...]           Flutter pub (filtered) — get | upgrade | outdated | deps
  format [paths...]                    Dart format (filtered)
  fix [--apply]                        Dart fix (filtered) — default --dry-run
  gen-l10n                             Flutter gen-l10n (filtered)
  clean                                Flutter clean
  doctor                               Flutter doctor (filtered)
  devices                              Flutter devices (filtered)
  compile <target> [args...]           Dart compile (filtered) — exe | aot-snapshot | js
  err <command>                        Generic error filter
  test-wrap <command>                  Generic test wrapper
  rewrite <command>                    Hook için: komut rewrite et
  savings [flags...]                   Tasarruf raporu
  init [flags...]                      Kurulum/teşhis
  config <subcommand>                  Config görüntüle/değiştir — show | path | edit
  version                              flart sürümü
  help [command]                       Yardım

Global flags:
  -v, --verbose                        Verbosity (-v, -vv, -vvv)
  -q, --quiet                          Hata dışında sessiz
  --no-savings                         Bu çağrıyı savings'e kaydetme (env: FLART_NO_SAVINGS=1)
  --no-tee                             Tee yazma
  --config <path>                      Custom config dosyası
  --json                               JSON çıktı (destekleyen komutlar)
```

**v1.0'da olmayan komutlar (v1.1+):**
- `flart run` — interaktif `flutter run` filter'ı, karmaşık state machine gerekiyor

### 8.2 Argument Parsing

`package:args` kullan. Her komut için ayrı `Command` subclass'ı.

### 8.3 Exit Codes

**Genel kural:** Alt komutun (filter veya executor target) exit code'unu olduğu gibi koru. flart kendi ayrı exit kategorileri için 100+ aralık kullanır.

| Code | Anlam | Kim üretir |
|------|-------|-----------|
| 0   | Başarılı | Alt komut |
| 1-99 | Alt komut hatası (passthrough) | Alt komut (örn. `flutter analyze` exit 3 → flart exit 3) |
| 100 | flart kendisi hata verdi (parse error, config bozuk) | flart |
| 101 | flart config yok / yanlış | flart |
| 124 | Sub-process timeout (POSIX convention) | flart (timeout kill sonrası) |
| 127 | Runtime not found | flart (örn. `flart exec ruby` ama ruby yok) |
| 130 | SIGINT (Ctrl-C) | OS |

Yani `flutter test` exit 1 verirse → `flart test` de exit 1 verir. Aynı behavior. Sadece flart-spesifik hatalar 100+ alır, agent karışıklık yaşamaz.

**Çakışma koruması:** Alt komut `100`, `101`, `124` veya `127` döndürürse (flart-internal kodlarla çakışan değerler) bu kod passthrough edilir **ve** `metadata_json`'a `{"native_exit_code": <kod>}` not düşülür. Pratik olarak `flutter`/`dart` 0/1/2/3 döndürür; bu mekanizma debug için, agent'ın gördüğü exit code değişmez.

---

## 9. Geliştirme Fazları (Sıralı Plan)

**Toplam süre:** 18–25 gün full-time / 5–7 hafta part-time. Aşağıdaki gün tahminleri full-time. Süreler test fixture toplama, edge case bulma, gerçek Flutter projesi ile manuel doğrulama dahil.

### Faz 1 — Altyapı (Gün 1-3)

- [x] Repo init, MIT license, README iskelet
- [x] Workspace pubspec.yaml + 6 paket için pubspec.yaml'lar (toplam 7 pubspec)
- [x] `analysis_options.yaml` (lints/recommended + strict-casts)
- [x] `flart_core` paketi:
  - [x] Config loader (YAML, global + project merge)
  - [x] SQLite kurulum + migration sistemi (WAL pragmas dahil)
  - [x] TokenEstimator
  - [x] SafeTruncator
  - [x] TeeManager
  - [x] Logger
- [x] Unit tests `flart_core` için (in-memory SQLite kullan)
- [x] `flart_cli` iskeleti — `flart version`, `flart help` çalışsın
- [x] Faz sonu: `dart compile exe` → `flart version` çıktı verir → checkbox işaretle

**Çıktı:** `dart compile exe` ile çalışan minimal `flart` binary. `flart version` çıktısı verir.

### Faz 2 — Executor (Gün 4-7)

- [x] `flart_executor` paketi:
  - [x] `SandboxExecutor` sınıfı
  - [x] Runtime detection (`which dart`, `which bash`, vs.)
  - [x] Dart import validation (mod A, regex check)
  - [x] Timeout enforcement
  - [x] Output capture + truncation (head/tail strategy)
  - [x] Stdin support
  - [x] File mode (`--file path`)
- [x] Savings tracking integration — her exec → SQLite kayıt
- [x] CLI: `flart exec <runtime> ...` komutu
- [x] Tests:
  - [x] dart script çalıştırma (basit + uzun output)
  - [x] dart import validation (package:, relative reject)
  - [x] bash script çalıştırma
  - [x] python script çalıştırma
  - [x] node script çalıştırma
  - [x] timeout enforcement (1s script, 100ms timeout → kill)
  - [x] output truncation (>64KB → head+tail)
  - [x] runtime missing handling (`flart exec ruby` → actionable error)
- [x] Faz sonu: `dart compile exe` → `flart exec dart 'print("hello")'` → SQLite kayıt düşer → checkbox işaretle

**Çıktı:** `flart exec` 4 runtime ile çalışır, SQLite'a kayıt düşer.

### Faz 3 — Filters Kısım 1 (Gün 8-11)

Öncelikli filter'lar (en sık kullanılanlar). Her filter için: önce fixture topla (gerçek komut çıktısı), sonra test yaz, sonra implement.

- [ ] `flart_filters` paketi:
  - [x] Base `CommandFilter` abstract class + `FilterResult` immutable class
  - [x] `analyze_filter.dart` — `dart analyze --format=machine` parse
  - [x] `test_filter.dart` — `flutter test --reporter=json` parse
  - [x] `pub_get_filter.dart` / `pub_upgrade_filter.dart`
  - [x] `format_filter.dart`
  - [x] `clean_filter.dart`
- [x] `flart_cli` paketi:
  - [x] `FilterRunner` class (orchestration: Process.start + filter.filter() + tracking + tee)
  - [x] Command sınıfları (analyze_command.dart, test_command.dart, vs.) — `package:args`
- [x] Tests:
  - [x] Her filter için fixture-based unit test (filter input → output)
  - [x] Edge case'ler: empty output, sadece error, sadece success, malformed input
  - [x] FilterRunner integration test (fake process veya `echo`/`true`/`false` ile)
- [x] Faz sonu: gerçek bir Flutter projesinde her komut çalıştır, çıktı doğru mu kontrol et → `dart compile exe` → checkbox işaretle

### Faz 4 — Filters Kısım 2 (Gün 12-15)

- [x] **Tee entegrasyonu (FilterRunner) — Faz 4 başında zorunlu** (v1.6 a/b)
- [x] **`FilterUtils.truncateMessage` + analyze/test/build entegrasyonu** (v1.6 c)
- [x] `build_filter.dart` (apk + web + ipa, tek filter)
- [x] `pub_outdated_filter.dart`
- [x] `pub_deps_filter.dart`
- [x] `fix_filter.dart` (default --dry-run, --apply farklı davranış)
- [x] `gen_l10n_filter.dart`
- [x] `doctor_filter.dart`
- [x] `devices_filter.dart`
- [x] `compile_filter.dart`
- [x] Generic wrapper'lar: `err_filter.dart`, `test_wrap_filter.dart`

Tests:
- [x] Her filter için fixture-based unit test
- [x] Faz sonu: `dart compile exe` → gerçek projede tüm komutları test et → checkbox işaretle

### Faz 5 — Savings Reporter (Gün 16-17)

- [x] `flart savings` komutu (default report)
- [x] `--since`, `--project`, `--by-command`, `--by-module`
- [x] `--top`, `--details`
- [x] `--json`, `--csv`
- [x] `--graph` (ASCII)
- [x] `--reset` (onay ile) + `--force`
- [x] Tests:
  - [x] Aggregator: zaman aralığı, project filter, command grouping
  - [x] Formatters: text, JSON, CSV, graph
  - [x] Faz sonu: SQLite'a test verileri ekle, raporları kontrol et

### Faz 6 — Claude Code Integration (Gün 18-20)

- [x] `flart rewrite` komutu (pipe/redirect/background detection dahil)
- [x] `flart_hooks` paketi
  - [x] `rewrite.sh` template
  - [x] CLAUDE.md routing block template
- [x] `flart init` komutu:
  - [x] `--global`, `--project`, `--show`, `--check`, `--uninstall` (`--yes` ek)
  - [x] İlk çalıştırmada onay prompt'u ("hook permission flow'unu bypass edecek, devam? [y/N]")
  - [x] PATH check (flart binary erişilebilir mi?)
  - [x] jq presence check (actionable hata)
  - [x] settings.json edit (idempotent — birden fazla kez çağrılabilir, atomic write)
  - [x] CLAUDE.md append (var olan content'i koru, marker ile)
- [x] Tests:
  - [x] `flart rewrite "flutter analyze"` → "flart analyze"
  - [x] `flart rewrite "cd /tmp && flutter test"` → "cd /tmp && flart test"
  - [x] `flart rewrite "flutter analyze | tee out.txt"` → passthrough
  - [x] `flart rewrite "git status"` → passthrough (kapsam dışı)
- [ ] Integration test: gerçek Claude Code session'da hook tetiklensin **— Faz 7 user-side manual milestone'una ertelendi (Plan v1.8 e + v1.10 a/e); DEPLOYMENT.md Step 4'te yürütülür**

### Faz 7 — Polish & Release (Gün 21-25)

- [x] README — kurulum, hızlı başlangıç, tüm komutların listesi, gerçek tasarruf rakamları (Çekap 1 — 91% caveat + macOS quarantine workaround + Verifying savings; Çekap 2'de install.sh env override doc'u eklendi)
- [x] CHANGELOG.md ilk entry (Çekap 1 — v0.1.0 per-package Added sections, 109 satır)
- [x] CI: GitHub Actions
  - [x] Test workflow (macOS + Linux) — `.github/workflows/test.yml`, matrix `[macos-latest, ubuntu-latest]` × Dart 3.11.5 + `tools/test_all.sh` (Çekap 2)
  - [x] Release workflow (`dart compile exe` + GitHub release) — `.github/workflows/release.yml`, tag-triggered `v*` matrix `[macos-arm64, macos-x64, linux-x64]`, version stamp inject, draft release (Çekap 2)
- [x] `flart --version` çıktısı düzgün (semver + git sha) — `String.fromEnvironment` ile build-time stamp; local rc1 doğrulama `flart 0.1.0-rc1 (commit 599c666, built 2026-05-18)` (Çekap 2+3)
- [x] Doctor mode (`flart init --check`) tüm checks yeşil — exit 0 (Çekap 3 final smoke)
- [x] `install.sh` script (Section 12.3 dolduruldu) — OS/arch detect, env override, macOS quarantine, jq prereq, PATH check; dry-run smoke (Çekap 2+3)
- [x] Baseline commit + local rc1 binary build (`599c666`, 7.0 MB, smoke `version + help` ✓) (Çekap 3)
- [x] DEPLOYMENT.md handoff doc (Step 1-5: push → tag rc1 → install.sh real test → Wonderous agent-session measurement → promote v0.1.0 veya rc2) (Çekap 3)
- [ ] **User-side manual milestone (post-Çekap 3, DEPLOYMENT.md):** Gerçek Claude Code session'da hook tetiklensin — Wonderous 30 dk task, `flart savings` rakamları Plan F bandında (40-65% session)
- [ ] **User-side manual milestone (post-Çekap 3, DEPLOYMENT.md):** v0.1.0 tag (rc1 ölçümü iyiyse promote, kötüyse rc2 iterate)

---

## 10. Dependency Listesi

### `flart_core` dependencies

```yaml
dependencies:
  yaml: ^3.1.2                # Config parsing
  sqlite3: ^2.4.0             # SQLite native bundled
  path: ^1.9.0                # Cross-platform path
  meta: ^1.15.0
```

### `flart_executor` dependencies

```yaml
dependencies:
  flart_core:
    path: ../flart_core
  # dart:io built-in — Process.start / Process.run yeterli. Ek paket gereksiz.
```

### `flart_filters` dependencies

```yaml
dependencies:
  flart_core:
    path: ../flart_core
  # JSON parsing built-in
```

### `flart_savings` dependencies

```yaml
dependencies:
  flart_core:
    path: ../flart_core
  intl: ^0.20.0                # Tarih/sayı formatlama
```

### `flart_cli` dependencies

```yaml
dependencies:
  flart_core:
    path: ../flart_core
  flart_executor:
    path: ../flart_executor
  flart_filters:
    path: ../flart_filters
  flart_savings:
    path: ../flart_savings
  flart_hooks:
    path: ../flart_hooks
  args: ^2.5.0                 # CLI argument parsing
```

### Dev dependencies (all packages)

```yaml
dev_dependencies:
  test: ^1.25.0
  lints: ^5.0.0
```

---

## 11. Test Stratejisi

### 11.1 Test Kategorileri

**Unit tests (paket içi):**
- `packages/flart_core/test/` — config, truncation, token estimation, migrations
- `packages/flart_executor/test/` — runtime detection, timeout, output capture
- `packages/flart_filters/test/` — her filter için fixture-based test
- `packages/flart_savings/test/` — query'ler, aggregation
- `packages/flart_hooks/test/` — rewrite logic

**Integration tests (`test/integration/` workspace root altında):**
- Gerçek `dart`, `flutter`, `bash` ile end-to-end
- Test repo'su (mini Flutter projesi) ile

**Fixture data (filter'a özgü, paket içinde):**
- `packages/flart_filters/test/fixtures/analyze_*.txt` — gerçek `dart analyze` çıktıları
- `packages/flart_filters/test/fixtures/test_*.json` — gerçek `flutter test --reporter=json`
- `packages/flart_filters/test/fixtures/build_apk_*.txt` — gerçek build outputs
- vs.

**Workspace-wide çalıştırma:** `dart test` workspace root'tan otomatik member toplamaz. İki yol:
- `tools/test_all.sh` — her paketin dizinine cd edip `dart test` çağırır. Her paketin transitive resolve'unu garanti eden tek yol. **CI ve günlük kullanım için tercih.**
- `dart test packages/<pkg>/test` — tek paketi hızlı çalıştırmak için. Hızlı ama paket-spesifik resolve garanti yok.

### 11.2 Filter Test Pattern

```dart
void main() {
  group('AnalyzeFilter', () {
    test('groups warnings by rule', () {
      final fixture = File(
        'test/fixtures/analyze_with_warnings.txt'
      ).readAsStringSync();
      final filter = AnalyzeFilter();
      final result = filter.filter(
        stdout: fixture, stderr: '', exitCode: 0, userArgs: [],
      );
      expect(result.output, contains('WARNINGS'));
      expect(result.output, contains('unused_local_variable [12]'));
      expect(result.metadata['warnings_total'], 24);
      expect(result.metadata['warnings_unique'], 8);
    });

    test('preserves errors in full detail', () { /* ... */ });
    test('handles empty output', () { /* ... */ });
    test('handles malformed lines gracefully', () { /* ... */ });
  });
}
```

**Metadata key conventions:** snake_case, primitif tipler (int/double/bool/String) veya bunların List'leri. JSON-roundtrip-safe olmalı (Section 3.3 `metadata_json` ile uyumlu).

### 11.3 Coverage Hedefi

Paket bazında alt sınırlar:

- `flart_core`: %90+
- `flart_filters`: %85+ (her filter için happy path + 2-3 edge case)
- `flart_executor`: %80+
- `flart_savings`: %85+
- `flart_hooks`: %75+
- `flart_cli`: %60+ (entry point; daha çok integration test)

**Toplam (weighted average):** %80+. Section 18'deki başarı kriteri bu rakamı referans alır.

### 11.4 Test Database Stratejisi

Hiçbir test çalıştırması kullanıcının gerçek `~/.local/share/flart/savings.db` dosyasına yazmaz.

- **Unit testler:** SQLite in-memory mode (`sqlite3.openInMemory()`). Test sonu otomatik temizlenir.
- **Integration testler:** Test başında `Directory.systemTemp.createTempSync('flart_test_db_')` ile geçici dizin oluştur, env var `FLART_DATA_DIR` ile flart'a yaz, test sonu sil.
- **Manuel testler / development:** `FLART_NO_SAVINGS=1` env var ile savings tracking kapatılır.

`flart_core/lib/src/storage/database.dart` constructor'ı opsiyonel `path` alır; null veya `:memory:` ise in-memory açar.

---

## 12. Yayın Hazırlığı

### 12.1 Sürüm v0.1.0 (MVP) Tanımı

Bu sürümde olması gerekenler:

- [x] `flart_core` çalışıyor (config, SQLite, truncation, tee, logger)
- [x] `flart exec` 4 runtime ile çalışıyor (dart, bash, python, node)
- [x] Filtreler — en az 13 komut için:
  - [x] `analyze`, `test`, `clean`, `format`, `fix`, `gen-l10n`, `doctor`, `devices`, `compile`
  - [x] `pub get`, `pub upgrade`, `pub outdated`, `pub deps`
  - [x] `build apk`, `build web`, `build ipa`
  - [x] Generic: `err`, `test-wrap`
- [x] `flart savings` raporu çıkıyor (text + JSON + CSV + graph)
- [x] `flart init` Claude Code hook'unu kuruyor (idempotent, onay prompt'u dahil)
- [x] CLAUDE.md routing block ekleniyor
- [x] Tüm unit testler geçiyor (paket bazında min coverage hedefi tutuyor)
- [x] Bir gerçek Flutter projesinde 1 saat boyunca hatasız çalıştırıldı

### 12.2 Binary Distribution

```bash
# Build
dart compile exe packages/flart_cli/bin/flart.dart -o flart

# Release (GitHub):
flart-macos-arm64
flart-macos-x64
flart-linux-x64
flart-windows-x64.exe
```

### 12.3 Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/flart/main/install.sh | sh
```

veya manuel:

```bash
# Download → chmod +x → mv to ~/.local/bin/flart
flart init
```

### 12.4 README İçeriği

- Tek paragraflık tanıtım
- Kurulum (3 yol: install.sh, manual, build from source)
- Hızlı başlangıç (`flart init`, `flart analyze`, `flart savings`)
- Tüm komutlar tablosu
- Konfigürasyon örneği
- Tipik tasarruf rakamları (kendi ölçümlerin)
- Limitasyonlar bölümü (dürüst: ne yapamaz)

### 12.5 Release Candidate Pattern (Plan v1.10)

v0.1.0 ve sonraki tüm minor/major release'ler bu sıralamayla çıkar — tag doğrudan production'a atılmaz, önce RC artefactları üzerinde son doğrulama yapılır:

1. **`vX.Y.Z-rcN` tag'le.** `release.yml` matrix build çalıştırır, draft release oluşturur (3 binary attached).
2. **install.sh ile gerçek release'i test et.** `FLART_VERSION=vX.Y.Z-rcN` env ile fresh shell'de install + smoke.
3. **Agent-session measurement.** Fresh Claude Code session, mid-size Flutter projesi (Wonderous), 30 dk task. `flart savings` rakamları Plan F bandında olmalı.
4. **Karar:**
   - Rakamlar iyi → README/CHANGELOG'a measurement satırı, polish commit, `vX.Y.Z` tag'le. `release.yml` ikinci kez koşar, draft → publish.
   - Bug bulundu → patch + `vX.Y.Z-rc(N+1)` tag, baştan.
5. **Rollback:** Sadece **draft** release'ler için `git tag -d` + `git push origin :refs/tags/...` + UI'dan draft sil. **Published release'lere asla rollback yok** — `vX.Y.(Z+1)` patch release ile düzelt (artefactlar cache'lenmiş olabilir).

**Motivasyon:** Faz 6'nın son adımı (gerçek agent ölçümü) Plan v1.8'de Faz 7 sonuna ertelenmişti. Plan v1.10'da bu adım RC pattern'inin doğal bir parçası haline geldi — ölçüm `-rc1` üzerinde yapılır, `v0.1.0` final tag'i ancak ölçüm Plan F bandında olduğunda atılır. v0.1.0 utanç verici çıkmaz.

**Future tag'ler için kısa form:** Section 9'da phase checklist'in son iki maddesi her release'de tekrar eder — "user-side manual milestone: agent-session measurement on rcN" + "user-side manual milestone: promote to final tag".

---

## 13. Riskler ve Bilinen Sorunlar

### 13.1 Dart Sandbox Hızı

`dart` runtime ile script çalıştırmak ilk başlatmada **300-700ms overhead** alabilir (JIT). Çözümler:

- v1.0: Olduğu gibi bırak; çoğu kullanım kabul edilebilir
- v1.1: `dart compile jit-snapshot` ile snapshot cache
- v1.2: Long-running dart process (daemon) — ama compleksiteyi artırır

### 13.2 Token Estimation Doğruluğu

`chars / 3.8` formülü Anthropic'in gerçek tokenizer'ından ±%5-15 sapabilir. Mitigasyon:

- Raporlarda "estimated" ibaresi
- Byte/char rakamları (kesin) ön planda
- v1.1: opsiyonel Anthropic count_tokens API entegrasyonu

### 13.3 Hook Auto-Allow Davranışı

flart hook'u `permissionDecision: "allow"` ile rewrite ettiği komutları otomatik onaylar. Bu Claude Code'un permission flow'unu bypass eder. Kullanıcı bunu bilmeli (init message'da uyarı).

### 13.4 Pipe / Redirect Komutları

`flutter analyze | tee output.txt` gibi pipe'lı komutlar rewrite edilmez. Bu doğru davranış (output yönü değişmiş) ama Claude Code session'larında bazen yakalanmayabilir. v1.0'da: passthrough; v1.1'de daha akıllı detection.

### 13.5 Flutter Version Compatibility

Output formatları Flutter sürümleri arasında değişebilir.

**Hedef sürüm:** Flutter 3.27.x (Stable, Q1 2026). Tüm test fixture'lar bu sürümle oluşturulur.

**Stratejisi:**

- Fixture'ların başlık yorum satırında Flutter sürümü belirtilir (`# Captured from flutter 3.27.0`).
- Filter'lar **defensive parsing** yapar: bilmedikleri satırları görmezden gelir, crash etmez.
- CI matrix'inde **iki sürüm test edilir**: hedef minimum (3.27.0) + güncel stable.
- Output format breaking change tespit edilirse: yeni fixture, filter regex güncelleme, CHANGELOG.md'ye not.

**Minimum desteklenen Dart SDK:** 3.5.0 (workspace pubspec'lerde belirtilir).

### 13.6 Project Path Detection

`project_path` iki yerde kullanılır:
1. SQLite `invocations.project_path` kolonu — savings raporlarında grouping
2. Project-level config dosyası arama (`<project_root>/.flart/config.yaml`)

İkisi de aynı algoritmayla bulunur:

1. `cwd`'den yukarı doğru `pubspec.yaml` ara (maksimum 10 seviye)
2. Bulunmazsa `cwd`'yi kullan (project_path = cwd, project config yok)
3. Symlink'leri resolve et (`File.resolveSymbolicLinksSync` ile)

Bulunan path `ProjectContext.root` olarak tek seferlik hesaplanır, tüm modüllere bu instance inject edilir. Yukarıdan aşağı tutarlılık.

`flart_core/lib/src/project_context.dart`:

```dart
class ProjectContext {
  final String root;
  final bool hasFlutterProject;  // pubspec.yaml bulundu mu?

  static ProjectContext detect() { /* yukarıdaki algoritma */ }
}
```

### 13.7 Concurrent Invocations

Aynı anda iki `flart` process'i SQLite'a yazabilir. Section 3.3'teki PRAGMA'lar (WAL mode + busy_timeout=5000) Faz 1'de uygulanır, problem öncesinde halledilir. Sorun çıkarsa retry-with-backoff eklenecek.

---

## 14. Açık Kararlar (Geliştirme Sırasında Verilecek)

Bu maddeler tasarım sırasında ortaya çıkacak, **şimdi karar vermeye gerek yok:**

- `flart_filters` paketi içinde her filter ayrı dosya mı, yoksa kategoriler halinde mi? (Önerim: ayrı dosya, `analyze_filter.dart`, `test_filter.dart`, vs.)
- Color output kütüphanesi? (Önerim: ANSI escape sequence'ları kendi yaz; `chalkdart` veya `ansicolor` dahil etmek overkill)
- Version bumping — manuel mi, otomatik mi? (Önerim: manuel)

---

## 14.5 Backlog Tracker (Faz 4 sonu)

Faz 3 audit'inden ve Faz 4 implementasyonundan kalan iyileştirme adayları. v1.0 zorunlu olmayanlar; v1.1+ aday listesi.

**Tamamlandı:**
- ~~Tee entegrasyonu (Faz 4 hazırlık #6)~~ — v1.6 b
- ~~`truncate_long_messages_at` (analyze/test/build, audit #1/#4/#5)~~ — v1.6 c
- ~~`pubspec.lock` dep-count parse (Plan v1.3 → impl v1.5)~~
- ~~Fix filter cross-file rule collapse~~ — v1.6 g (Wonderous %6 → %96.7)

**v1.0 kapsamında kalan iyileştirme adayları (Faz 5 öncesi/sırasında):**

| # | Madde | Etki | Tahmini iş |
|---|---|---|---|
| 1 | analyze: same-rule-in-same-file collapse (L1 L42 L67 yerine `[3 occurrences in this file]`) | %2-5 ek tasarruf error-heavy senaryolarda | 1-2 saat |
| 2 | analyze: `max_warnings_shown` config'i uygula (rule sayısı capping) | Çok-rule projelerde stabilite | 30 dk |
| 3 | test: `max_failures_shown` config'i uygula (büyük test suite'lerinde fail detail capping) | Truncate başka yerlerde, burada count cap | 30 dk |
| 4 | pub_deps: `--tree` yerine compact ASCII (transitive sayısı + collapse) | Şu an tree pass-through; daha akıllı kısaltma mümkün | 1-2 saat |
| 5 | Build filter: Multi-target apk (universal vs split-per-abi) gruplama | Production build'lar için anlamlı | 1 saat |

**v1.1'e ertelendi:**

- `ultra_compact` config flag (analyze + test için ekstra agresif mod)
- Doctor `--verbose` (collapse'ten kaçınma)
- Pure-Dart fallback diğer komutlar için (build/clean Flutter-only kalıyor; gerek yok)
- Fix filter `-v` ile per-file detail expand (şu an raw `dart fix --dry-run` öneriliyor)
- iOS ipa build fixture (Mac dev env'i lab'a entegre edilirse)

**v0.2.0'a ertelendi (Plan v1.11+):**

- **Windows desteği** (Plan v1.11) — hook protocol (bash/PS veya direkt binary çağrısı, mevcut `rewrite.sh` Windows'ta çalışmaz), path handling (`XDG_CONFIG_HOME`/`XDG_DATA_HOME` yerine `%APPDATA%`/`%LOCALAPPDATA%`), CI matrix'e `windows-latest` eklenmesi (test fixture line ending normalizasyonu dahil), `install.ps1` (PowerShell muadili), `release.yml` Windows binary build (mevcut `flart-windows-x64.exe` placeholder Section 12.2'de duruyor ama henüz pipeline'a bağlı değil). Tahmini iş 2 hafta full-time. v0.1.0 launch sonrası gerçek kullanıcı talebi geldiğinde önceliklendirilecek.
- **macOS Intel x64 (`macos-13`)** (Plan v1.12) — runner availability sorunu (GitHub Actions Intel Mac queue 50+ dk, sürdürülemez) + geliştirici lokal test imkanı yok (Mac arm64 host). Windows ile birlikte v0.2.0'da ele alınacak: dedicated self-hosted Intel runner veya GitHub Actions Intel runner SLA iyileşene kadar. Intel Mac kullanıcıları v0.1.0'da "build from source" yolunu izler (README Limitations).

---

## 15. Gelecek Sürümler (v1.0 Sonrası)

**v1.1:**
- Anthropic `count_tokens` API entegrasyonu (opsiyonel)
- Long-running executor daemon (dart JIT snapshot cache)
- Cursor + Codex hook desteği
- Daha gelişmiş Riverpod/Bloc filter'lar

**v1.2:**
- Modül 2 (lite version): basit symbol indexing, `flart find consumers <ProviderName>`
- Pipe-aware rewrite

**v2.0:**
- Çoklu agent (Cursor, Gemini, Codex, Hermes)
- MCP server modu

---

## 16. Geliştirme Süreci Notları (Claude Code İçin)

Claude Code ile bu projeyi geliştirirken:

1. Faz sırasını bozma — altyapı bitmeden Modül 3'e geçme. Çünkü Modül 3 storage ve config'i kullanıyor.
2. Her faz sonunda `dart compile exe` çalıştır; build kırıldıysa devam etme. Faz sonu checkbox'ı bu doğrulamadan sonra işaretle.
3. Her filter'ı yazarken önce **fixture** oluştur (gerçek bir komut çıktısı kaydet), sonra test yaz, sonra implement et (TDD).
4. SQLite schema'yı v0'da donduralım; v1.0'a kadar değişmesin (migration olur ama eklemeli; mevcut kolon kaldırma/yeniden adlandırma yok).
5. CLI flag isimleri RTK / context-mode ile uyumlu olsun (kullanıcı kas hafızası). Örnek: `--since 7d`, `--json`, `--graph`.
6. Hata mesajları **actionable** olsun: `"jq not found in PATH"` değil, `"jq required for hook installation. Install: brew install jq (macOS) or apt install jq (Linux)"`.
7. `flart` binary'sini Claude Code session'ı içinde kullanırken — yani agent kendi yazdığı kodu test ederken — savings DB'sine kayıt **düşmesin**. Üç yol var:
   - `--no-savings` flag: tek seferlik
   - `FLART_NO_SAVINGS=1` env var: session boyunca
   - `FLART_DATA_DIR=/tmp/flart-dev` env var: gerçek DB'yi etkilemeden ayrı dizinde test
8. Test çalıştırırken **gerçek `~/.local/share/flart/` dosyalarına dokunma**. Test config'de `FLART_DATA_DIR` set edilmiş geçici dizin kullan veya in-memory SQLite aç.
9. Plan değişirse bu döküman güncellenir; `Değişiklik Geçmişi` bölümüne entry eklenir, sürüm artırılır.

---

## 17. Dosya Yapısı (Final)

```
flart/
├── .github/
│   └── workflows/
│       ├── test.yml
│       └── release.yml
├── packages/
│   ├── flart_cli/
│   │   ├── bin/
│   │   │   └── flart.dart                     # Entry point
│   │   ├── lib/
│   │   │   ├── commands/
│   │   │   │   ├── analyze_command.dart
│   │   │   │   ├── test_command.dart
│   │   │   │   ├── build_command.dart
│   │   │   │   ├── pub_command.dart
│   │   │   │   ├── format_command.dart
│   │   │   │   ├── fix_command.dart
│   │   │   │   ├── clean_command.dart
│   │   │   │   ├── doctor_command.dart
│   │   │   │   ├── devices_command.dart
│   │   │   │   ├── gen_l10n_command.dart
│   │   │   │   ├── exec_command.dart
│   │   │   │   ├── err_command.dart
│   │   │   │   ├── test_wrap_command.dart
│   │   │   │   ├── rewrite_command.dart
│   │   │   │   ├── savings_command.dart
│   │   │   │   ├── init_command.dart
│   │   │   │   ├── config_command.dart
│   │   │   │   └── version_command.dart
│   │   │   └── runner.dart
│   │   └── pubspec.yaml
│   ├── flart_core/
│   │   ├── lib/
│   │   │   ├── flart_core.dart                # Public API
│   │   │   └── src/
│   │   │       ├── config/
│   │   │       │   ├── config.dart
│   │   │       │   ├── loader.dart
│   │   │       │   └── defaults.dart
│   │   │       ├── storage/
│   │   │       │   ├── database.dart
│   │   │       │   ├── migrations/
│   │   │       │   │   ├── v1.dart
│   │   │       │   │   └── runner.dart
│   │   │       │   └── invocation_repo.dart
│   │   │       ├── tokens/
│   │   │       │   └── estimator.dart
│   │   │       ├── truncate/
│   │   │       │   └── safe_truncator.dart
│   │   │       ├── tee/
│   │   │       │   └── tee_manager.dart
│   │   │       ├── log/
│   │   │       │   └── logger.dart
│   │   │       └── tracking/
│   │   │           └── invocation_tracker.dart
│   │   ├── test/
│   │   │   ├── config_test.dart
│   │   │   ├── truncate_test.dart
│   │   │   ├── token_estimator_test.dart
│   │   │   ├── tee_test.dart
│   │   │   └── migrations_test.dart
│   │   └── pubspec.yaml
│   ├── flart_executor/
│   │   ├── lib/
│   │   │   ├── flart_executor.dart
│   │   │   └── src/
│   │   │       ├── executor.dart
│   │   │       ├── runtime.dart
│   │   │       └── exec_result.dart
│   │   ├── test/
│   │   │   └── executor_test.dart
│   │   └── pubspec.yaml
│   ├── flart_filters/
│   │   ├── lib/
│   │   │   ├── flart_filters.dart
│   │   │   └── src/
│   │   │       ├── filter.dart                # Base abstract class
│   │   │       ├── filter_result.dart
│   │   │       ├── analyze_filter.dart
│   │   │       ├── test_filter.dart
│   │   │       ├── build_filter.dart
│   │   │       ├── pub_get_filter.dart
│   │   │       ├── pub_upgrade_filter.dart
│   │   │       ├── pub_outdated_filter.dart
│   │   │       ├── pub_deps_filter.dart
│   │   │       ├── format_filter.dart
│   │   │       ├── fix_filter.dart
│   │   │       ├── gen_l10n_filter.dart
│   │   │       ├── clean_filter.dart
│   │   │       ├── doctor_filter.dart
│   │   │       ├── devices_filter.dart
│   │   │       ├── compile_filter.dart
│   │   │       ├── err_filter.dart
│   │   │       └── test_wrap_filter.dart
│   │   ├── test/
│   │   │   ├── fixtures/
│   │   │   │   ├── analyze_clean.txt
│   │   │   │   ├── analyze_with_errors.txt
│   │   │   │   ├── analyze_with_warnings.txt
│   │   │   │   ├── test_pass.json
│   │   │   │   ├── test_fail.json
│   │   │   │   ├── build_apk_success.txt
│   │   │   │   ├── build_apk_fail.txt
│   │   │   │   ├── pub_get_clean.txt
│   │   │   │   ├── pub_get_conflict.txt
│   │   │   │   ├── pub_outdated.json
│   │   │   │   ├── doctor_ok.txt
│   │   │   │   ├── doctor_warnings.txt
│   │   │   │   └── ... (her filter için 2-4 fixture)
│   │   │   ├── analyze_filter_test.dart
│   │   │   ├── test_filter_test.dart
│   │   │   └── ... (her filter için test)
│   │   └── pubspec.yaml
│   ├── flart_savings/
│   │   ├── lib/
│   │   │   ├── flart_savings.dart
│   │   │   └── src/
│   │   │       ├── reporter.dart
│   │   │       ├── aggregator.dart
│   │   │       ├── formatters/
│   │   │       │   ├── text_formatter.dart
│   │   │       │   ├── json_formatter.dart
│   │   │       │   ├── csv_formatter.dart
│   │   │       │   └── graph_formatter.dart
│   │   │       └── query.dart
│   │   ├── test/
│   │   │   ├── aggregator_test.dart
│   │   │   └── formatters_test.dart
│   │   └── pubspec.yaml
│   └── flart_hooks/
│       ├── lib/
│       │   ├── flart_hooks.dart
│       │   └── src/
│       │       ├── installer.dart
│       │       ├── rewriter.dart
│       │       └── templates/
│       │           ├── rewrite_sh.dart       # Template string
│       │           └── claude_md_block.dart
│       ├── test/
│       │   └── rewriter_test.dart
│       └── pubspec.yaml
├── test/
│   └── integration/
│       ├── exec_integration_test.dart
│       ├── filter_integration_test.dart
│       └── full_flow_test.dart
├── tools/
│   ├── build_release.sh
│   └── generate_fixtures.sh
├── docs/
│   ├── architecture.md
│   ├── commands.md
│   └── configuration.md
├── analysis_options.yaml
├── pubspec.yaml                                 # Workspace root
├── README.md
├── CHANGELOG.md
├── LICENSE                                      # MIT
└── flart_PLAN.md                               # Bu döküman
```

---

## 18. Başarı Kriterleri

v0.1.0 başarılı sayılır eğer:

1. `flart init` tek komutla kurulum yapar
2. `flart analyze` gerçek bir Flutter projesinde çalışır ve ham `flutter analyze`'a göre ≥%70 daha az çıktı verir
3. `flart test` gerçek test suite'inde çalışır, sadece failure'ları gösterir
4. `flart exec dart '...'` çalışır, çıktı 65KB altında kalır
5. `flart savings` raporu doğru sayıları gösterir
6. Bir gerçek Claude Code session'ında (orta boyutta bir Flutter projesinde) 1 saat boyunca hatasız çalışır
7. `flart` binary boyutu < 30MB
8. Unit test coverage weighted average %80+ (paket bazında alt sınırlar Section 11.3'te)
9. CI tüm platform'larda (macOS, Linux) yeşil

---

**Plan sonu.**

Bu dökümanı Claude Code session'ında kullan: faz sırasını takip et, her bölüm referans olarak kalsın. Değişiklik gerekirse bu dosyayı güncelle, tarihi ve sürümü artır.
