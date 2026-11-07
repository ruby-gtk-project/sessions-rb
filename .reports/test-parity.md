# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `cc2c04c` |
| Upstream tests | **42** cases (10 table-driven functions, `pkg/state/machine_test.go`) |
| Mapped | **42 / 42**, by name, re-read against `HEAD` this round |
| Port examples | 75 total RSpec examples (42 mapped state-machine cases + `metainfo_spec.rb` + `settings_spec.rb` + the rest; see Open §3) |
| **Executed this round** | **yes — confirmed by me, in this session**: `nix develop --command bash -c "rake schema:compile && bin/rspec spec --format progress"` → `75 examples, 0 failures` |
| Round | eight |

The 42/42 census is unchanged from round seven and re-read against
`spec/state_machine_spec.rb` this round: all ten upstream functions
(`TestPlusTimer` 6, `TestMinusTimer` 8, `TestStartDragging` 5,
`TestStopDragging` 5, `TestStopTimer` 3, `TestStartTimer` 2,
`TestTimerFinished` 2, `TestStopAlarming` 2, `TestEndToEnd` 3,
`TestGetInitialRemainingTimeFromCurrentRemainingTime` 6 — 42 total) have a
correspondingly named `describe`/`it` block with the upstream function named
in a comment.

**This round closes round seven's Open §1 for real**, not by restating the
old number: I ran the command myself, watched it to completion, and it
printed `75 examples, 0 failures`. That is not the 45 figure round six and
seven both cited — the suite has grown (more spec files; see the component
list in `spec/`), and 75 is what is actually in the tree today, confirmed by
running it rather than carried from an older report.

---

## Open

### 1 — Resolved this round, not carried forward as a gap

Round seven's headline finding — "the suite's execution could not be
reconfirmed this round" — no longer applies. The underlying cause (shared
machine contention blocking `nix develop`) is gone this round because
`cc2c04c` split the Qt native-extension build out of `devShells.default`
(see `accountability-ensurance.md` for why that same split creates a new
gap in the driver story). `rake schema:compile && bin/rspec spec` ran to
completion in under 5 seconds of actual Ruby time once the shell itself was
ready.

### 2 — Still unreachable from CI in a way this audit can confirm

`.github/workflows/ci.yaml` invokes `bundle exec rspec`; `.gitlab-ci.yml`
invokes `bin/rspec spec`. Neither was actually run through GitHub Actions or
GitLab CI by this audit — that infrastructure is not available in this
environment. Read, not executed. Carried forward, unchanged.

### 3 — The 75-example count needs a name-by-name reconciliation, not just a total

I confirmed the total (`75 examples, 0 failures`) by running the suite, and
confirmed by reading that `spec/state_machine_spec.rb`, `spec/metainfo_spec.rb`
and `spec/settings_spec.rb` exist and target real surface. I did **not** this
round enumerate every one of the 75 `it` blocks by name and re-derive the
42/33 split the way round six and seven's narrower suite allowed — the
suite has grown past what a quick line-count story covers, and a future
round should re-run `bin/rspec spec --format documentation` and diff the
example names against `pkg/state/machine_test.go`'s case names directly,
rather than trust that growth only added unmapped, upstream-less specs.
This is a real gap in this round's own method, named rather than hidden.

### 4 — The widget layer still has drivers, not specs — and the convenience task that is supposed to run every driver together is broken

`test/drive_main_window.rb`, `test/drive_translations.rb` and
`test/drive_high_contrast.rb` are not RSpec; they are standalone scripts that
print `ok`/`not ok` lines and a final count, confirmed this round by running
all three to completion:

| Driver | Result |
|---|---|
| `test/drive_main_window.rb` | **173 of 173 checks passed, DRIVE OK**, 11 screenshots |
| `test/drive_translations.rb` | **51 of 51 checks passed, DRIVE OK**, 6 screenshots |
| `test/drive_high_contrast.rb` | **21 of 21 checks passed, DRIVE OK**, 5 screenshots |

173 + 51 + 21 = **245 checks, 0 failed** — matching this round's runtime
gate exactly, and reconfirmed by me running each script directly
(`nix develop --command xvfb-run -a rake drive:main_window` etc.), not taken
on report.

**But I ran them one task at a time, and that is not incidental — it is the
only way they currently pass.** `rakelib/spec.rake` defines a fourth driver,
`drive:qt`, and both `rake drive` and `rake check` depend on **all four**
drivers, qt included. Running either aggregate task in the project's own
default dev shell — the one the shell banner itself recommends ("drive
every UI: `rake drive`") — fails:

```
$ nix develop --command xvfb-run -a rake check
...
75 examples, 0 failures
... (all three GTK drivers pass, 245 checks) ...
xvfb-run -a ruby test/drive_qt.rb
cannot load such file -- qt6/qtwidgets (LoadError)
	from lib/qt_application.rb:3
rake aborted!
Command failed with status (1)
```

So the 245/245 green this report (and `COMPONENT_PARITY.md`) reports is
real, but **`rake drive` and `rake check` — the exact commands the dev
shell's own banner tells a user to run — are broken in that same default
shell**, because the Qt gem (`qt6/qtwidgets`) only exists in the separate
`nix develop .#qt` shell that `cc2c04c` split out. Nobody using the
documented entry point gets a green run; they get a `LoadError` on the
fourth task. This is a test-runner defect, not a widget defect, and it is
new this round — introduced by the same commit that fixed the contention
problem the previous two rounds couldn't get past. See
`accountability-ensurance.md` for why this is reported there as the
round's central finding rather than filed only here.

---

## Numbers, not adjectives

- Upstream: **42/42** cases mapped, re-verified by reading.
- Port: **75 RSpec examples, 0 failures** — confirmed by running the suite
  myself this round, not inherited from a prior report.
- Drivers: **3 of 4** driver scripts run to completion this round
  (`main_window`, `translations`, `high_contrast` — 245/245 checks, 0
  failed); **1 of 4** (`qt`) still never run to completion by any round,
  now for a different and more concrete reason than contention — see Open
  §4 and `accountability-ensurance.md`.
- The aggregate rake tasks (`rake drive`, `rake check`) **fail** in the
  project's own documented default shell, because they unconditionally
  depend on `drive:qt`.
- Runtime gate this round: **`drive_ok=true`, 245 passed, 0 failed** —
  reproduced independently by me, command by command, not taken on report.
  That gate counts only the three GTK drivers; it does not, and currently
  cannot, cover the Qt frontend or the aggregate rake tasks.

---

## Round nine update

**Open §3 (name-by-name 42/42 reconciliation) — closed.** Ran
`bin/rspec spec --format documentation` and diffed every `StateMachine`
example name in the output against `pkg/state/machine_test.go`'s `t.Run`
case names (and the two non-table functions' own fmt.Sprintf-built names)
by hand. All 42 upstream cases have exactly one corresponding Ruby example;
none fell out as the suite grew from 45 to 75. The three extra `StateMachine`
examples beyond the 42 (`#to_s and #to_graph`) are new coverage upstream has
no equivalent of, not drift. Full case-by-case correspondence:

| Upstream function (cases) | Ruby `describe` | Cases |
|---|---|---|
| `TestPlusTimer` (6) | `#plus_timer` | 6 |
| `TestMinusTimer` (8) | `#minus_timer` | 8 |
| `TestStartDragging` (5) | `#start_dragging` | 5 |
| `TestStopDragging` (5) | `#stop_dragging` | 5 |
| `TestStopTimer` (3) | `#stop_timer` | 3 |
| `TestStartTimer` (2) | `#start_timer` | 2 |
| `TestTimerFinished` (2) | the `timer_finished` trigger | 2 |
| `TestStopAlarming` (2) | `#stop_alarming` | 2 |
| `TestEndToEnd` (3) | a whole session | 3 |
| `TestGetInitialRemainingTimeFromCurrentRemainingTime` (6) | deriving the initial remaining time from the current one | 6 |

**Open §4 (the aggregate rake tasks) — closed.** `rakelib/spec.rake` now
scopes `drive`/`check` to the three drivers `devShells.default` can run and
gives the Qt driver its own `drive:all`, never a prerequisite of either.
Reconfirmed by running `nix develop --command xvfb-run -a rake check` to
completion in the default shell: `75 examples, 0 failures` plus
173 (`main_window`) + 53 (`translations`, up from 51 — see
`translation-parity.md` for the French wrapping check added this round) +
21 (`high_contrast`) = 247 driver checks, 0 failed, `DRIVE OK`, exit 0 — the
exact command the shell's own banner now correctly describes.

**Round nine's own arithmetic undercounted by one driver script.** The
French-window check runs as `test/drive_translations_fr_window.rb`, a
separate process `test/drive_translations.rb` shells out to, and it prints
its own "1 of 1 checks passed / DRIVE OK" line distinct from the German
driver's "53 of 53". 173 + 1 + 53 + 21 = **248**, matching this round's
stated runtime gate (248 passed, 0 failed) exactly — the 247 figure above is
corrected here, not restated.

---

## Round ten — reconfirmed by me, numbers unchanged except the 247→248 correction above

Ran `nix develop --command xvfb-run -a rake check` myself, to completion,
in the default shell: `75 examples, 0 failures`, then 173/173, 1/1, 53/53,
21/21 — 248 driver checks, 0 failed, exit 0. `HEAD` has not moved past
`5b718d6` since round nine wrote the above, so there was nothing new to
reconcile in the spec suite or the three default-shell drivers.

**`drive:qt` is still not part of `rake check` and has still never been run
to completion by any round** — see `component-parity.md` Unit 7. The 42/42
upstream-case mapping and the 75-example suite are the state-machine layer
only; the Qt frontend's own behaviour (does `lib/qt_application.rb` actually
drive the same state machine correctly from a QML UI) has zero test
coverage of any kind, driver or spec, because the one script written to
exercise it has never finished running.
