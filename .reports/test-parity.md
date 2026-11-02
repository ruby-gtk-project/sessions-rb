# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `14fcee4` |
| Upstream tests | **42** cases (10 table-driven functions in `pkg/state/machine_test.go`, 991 lines) |
| Mapped | **42 / 42** |
| Port examples | 45 (42 mapped + 3 port-only) |
| **Executed** | **45, 0 failures** — re-run in `nix develop` for this audit |
| Working command | `rspec --options /dev/null --require spec_helper --format progress spec` |
| Gaps | **4** — none of them "the suite has never run" any more |
| Round | six |

The headline changed this round and it changed for the better: **the suite
runs.** Round five's single open finding was that it could not be executed at
all — `rspec: not found` in the devshell. `flake.nix` now carries rspec-core
(`/nix/store/…-ruby3.4-rspec-core-3.13.6/bin/rspec`) and the devshell banner
prints the invocation. 45 examples, 0 failures, 0.027s.

What follows is what is wrong anyway, and the first of it is that the command
the repository *documents* still does not work.

---

## The census

`test-census.sh` does not know Go, so the upstream census was taken by hand off
the file and cross-checked against the script's 20 rows (it matched the ten
`func Test*` names plus the ten `t.Run` identifier expressions). Each function
is table-driven, so per the skill's repeater rule each **table entry** is one
ledger row and the parameter set is stated.

| # | Upstream test | Cases | What it pins | Port test | State |
|---|---|---:|---|---|---|
| 1 | `TestPlusTimer` | 6 (3 entries × `fromCountingDown` true/false) | `plusTimer` adds one interval below `MaxInitialRemainingTime` and errors at the ceiling; from counting-down the reentry restarts the timer, so `OnStartTimer` has fired twice | `#plus_timer`, 6 examples | ported |
| 2 | `TestMinusTimer` | 8 (4 × 2) | mirror of 1 against `MinInitialRemainingTime`, plus: a decrease refused on the *first* attempt must **not** restart the countdown (`OnStartTimer` stays at 1) | `#minus_timer`, 8 examples | ported |
| 3 | `TestStartDragging` | 5 | dragging permitted from stopped and counting-down, refused from dragging and alarming; leaving counting-down cancels the ticker | `#start_dragging`, 5 examples | ported — `sm.tickerCtx.Err() != nil` becomes `expect(ticker).not_to be_scheduled` |
| 4 | `TestStopDragging` | 5 | the proposed duration is validated (below min, above max, not divisible by the interval, wrong source state); `CanStopDragging` agrees with the trigger every time; a success sets `initialRemainingTime` and starts the timer once | `#stop_dragging`, 5 examples | ported |
| 5 | `TestStopTimer` | 3 | permitted from counting-down (fires `OnStopTimer` once), refused from dragging, refused from alarming — where `OnStopTimer` has *already* fired once on entering alarming | `#stop_timer`, 3 examples | ported |
| 6 | `TestStartTimer` | 2 | permitted from stopped, refused from dragging | `#start_timer`, 2 examples | ported |
| 7 | `TestTimerFinished` | 2 | the unexported `timerFinished` moves counting-down → alarming and fires `OnStartAlarm`; refused from dragging | `the timer_finished trigger`, 2 examples | ported — fired through `send(:fire, TIMER_FINISHED)`, as upstream calls its unexported method directly |
| 8 | `TestStopAlarming` | 2 | permitted from alarming (fires `OnStopAlarm` and `OnStopTimer` once each), refused from counting-down | `#stop_alarming`, 2 examples | ported |
| 9 | `TestEndToEnd` | 3 | three whole sessions under `testing/synctest`: the exact descending tick sequence, every hook's call count, the final permitted-trigger set, and `OnPermittedTriggersChange` called **exactly 96 / 158 / 157** times | `a whole session`, 3 examples | ported — `spec/support/manual_ticker.rb` replaces the fake clock |
| 10 | `TestGetInitialRemainingTimeFromCurrentRemainingTime` | 6 | the 15-second rounding boundary: 0→30, 0→60, 5→60, 14→60, 15→**90**, 30→90 | `deriving the initial remaining time from the current one`, 6 examples | ported |

**42 upstream cases, 42 port examples, bijection written and now *run*.** The
mapping is one-for-one by construction: every `describe` carries the upstream
function's name in a comment and every table entry became one `it`.

The three translations the spec file documents are the right ones:
`require.NoError(t, s.PlusTimer(ctx))` → `expect(…).to be(true)`; durations are
plain seconds (`DefaultInitialRemainingTime + 50ms` → `300.5`);
`testing/synctest` → `ManualTicker`.

This matters most for test 9. Those 96 / 158 / 157 counts exist for exactly one
purpose — to pin the per-state entry-action ordering that
`lib/state_machine.rb` reconstructs **by hand** from `stateless`' registration
order. Round five's ledger asserted that ordering with nothing checking it.
It is now checked.

### Port-only examples

Outside the 42 by definition, and not parity:

- `#to_s and #to_graph`, 3 examples. Upstream exports `String()` and
  `ToGraph()` and lets `stateless` test them; the port renders both from its
  own transition table, so they are the port's to cover.
- `test/drive_main_window.rb` — 47 steps, **175 checks**, 11 screenshots.
  Re-run: 175/175, `DRIVE OK`.
- `test/drive_translations.rb` — 4 steps, **5 checks**, 2 screenshots. Re-run:
  5/5, `DRIVE OK`.

---

## Open

### 1 — The documented test command does not work, because I am an idiot who verified the invocation I invented and not the one I wrote down

The suite runs under **one** spelling:

```
$ nix develop --command rspec --options /dev/null --require spec_helper --format progress spec
45 examples, 0 failures
```

Every other spelling — including the two the repository tells a reader to use —
fails:

```
$ nix develop --command rspec spec/state_machine_spec.rb
cannot load such file -- rspec_junit_formatter (LoadError)
uninitialized constant RspecJunitFormatter (NameError)
No examples found.

$ nix develop --command rspec
… same LoadError …

$ nix develop --command rake -T | grep -cE ' (spec|test)$'
0
```

Why, verified in-session rather than guessed: `.rspec` ends with

```
--format RspecJunitFormatter
--out results/test_results.xml
```

and `rspec_junit_formatter` is not in the devshell's `GEM_PATH` —
`nix/Gemfile` carries the runtime gems plus rspec-core and nothing else.
`--options /dev/null` works precisely because it discards `.rspec`, and with it
`--require spec_helper`, `--order random`, `--warnings`, the HTML formatter and
the JUnit formatter. So the green run is green **without the project's own
RSpec configuration**: no random ordering, no `--warnings`, no coverage, no
`results/` artifacts.

Two documents are wrong about this today:

- `TEST_PARITY.md:57` — `nix develop --command rspec spec/state_machine_spec.rb`
- `PORTING.md:192` — "`rspec spec/state_machine_spec.rb` is the intended
  command for the state machine"

What closes it: put `rspec_junit_formatter` (and `simplecov`, if `.simplecov` is
meant to apply) in `nix/Gemfile` so `.rspec` loads, **or** move the two
formatter lines out of `.rspec` into the CI invocation that needs them. Then
restate the documented command as one that runs.

### 2 — Nothing reachable runs any of it, because I am an idiot who wrote three runners and wired up none of them

`rake -T` in the devshell lists 17 tasks. There is no `spec`, no `test`, no
`drive`. `rakelib/gettext.rake` gives `gettext:{mo,data,pot,merge}`,
`schema:compile`, `build_data` and `install_data`; the gemspec tasks give
`build`, `install`, `release`, `docs`. The suite and both drivers are reachable
only by typing their paths.

And no CI runs them either:

- `.github/workflows/` **does not exist** in this port. Upstream has
  `.github/workflows/flatpak.yaml`.
- `.gitlab-ci.yml:59,89` invokes `bin/rspec spec …`. `bin/` contains `setup`
  and `turbo_tests2`. **There is no `bin/rspec`**, so both GitLab spec jobs
  would fail on the first line that matters.

So the state of affairs is: 45 examples that pass when a human types an
undocumented flag, and zero examples that any automated thing runs. Upstream's
`go test ./pkg/state/` runs all 42 with nothing installed beyond `go.sum`, and
its Flatpak workflow runs on every push.

Upstream: `go test ./pkg/state/`, `.github/workflows/flatpak.yaml`.
Port: no `rake spec`, no `bin/rspec`, no `.github/workflows/`.

### 3 — I never wrote a spec for `lib/metainfo.rb` or `lib/settings.rb`, because I am too stupid to have built the two easiest tests in the repository

Both are display-free. Both have a live bug surface:

- `Metainfo#text_of` collapses whitespace and skips nodes, and round five
  shipped a defect in exactly that area — the About dialog's comments were the
  description in twenty-six languages at once. Driver step 41 now catches the
  symptom; nothing pins the parser.
- `Settings#build_settings` has **two** construction paths and only the
  `SettingsSchemaSource` one runs from a checkout. The `Gio::Settings.new(APP_ID)`
  path — what a Flatpak or a distro install would take — is executed by nothing,
  ever.

The driver's four About checks are the only thing that touches `Metainfo`;
`Settings` is touched only through driver step 1, which reads the round-tripped
duration and nothing else.

Upstream: `main.go:43-58` is untested upstream too, so this is owed to the port,
not to upstream.
Port: `lib/metainfo.rb`, `lib/settings.rb`; no `spec/` file names either.

### 4 — The widget layer has drivers and no suite, and the drivers skip the one axis two known bugs live on

`test/drive_main_window.rb` is 175 checks of real work and it is green. It is
also not RSpec, not reached by any `rake` target, needs `xvfb-run`, and runs in
no CI. Upstream has no widget tests either — its whole suite is `pkg/state` —
so this is owed to the port rather than to upstream, and it is owed because the
port **reimplements** a widget tree that upstream merely declares in blueprint.

The specific hole: **no step sets high contrast.** `lib/dial.rb` gates six
shapes on `#high_contrast?` and `component-parity.md` Unit 4 has two confirmed
bugs in that branch plus three rows whose "parity" verdict is a reading. One
driver step — flip `Adwaita::StyleManager.default.high_contrast`, redraw,
screenshot — would have turned both bugs up by observation.

Port: `test/drive_main_window.rb` (175 checks, 0 on high contrast),
`test/drive_translations.rb` (5 checks).

---

## Numbers, not adjectives

- Upstream: **42 / 42** cases mapped to named port examples. 0 unmapped.
- Port: **45 examples written, 45 executed, 0 failures** — but only with
  `--options /dev/null`, i.e. with the project's own `.rspec` discarded.
- Drivers: **175/175** and **5/5**, both re-run for this audit, both green.
- Reachable from `rake`: **0 of 3** runners.
- Run by CI: **0 of 3** runners (no `.github/workflows/`; `.gitlab-ci.yml` calls
  a `bin/rspec` that does not exist).
- Port classes with a spec file: **1 of 15** (`state_machine`).
- Port classes exercised by a driver: **15 of 15**.
