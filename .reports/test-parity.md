# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `088c46d` |
| Upstream tests | **42** (10 table-driven functions in `pkg/state/machine_test.go`, 991 lines) |
| Mapped | 42 |
| Gaps | **1** — and it is the one that matters: the suite cannot be run |
| Test command | `rspec spec/state_machine_spec.rb` — **exits `rspec: not found`** |

---

## The census

`test-census.sh` does not know Go, so the upstream census was taken by hand off
the file and cross-checked against the script's 20 rows (it matched the ten
`func Test*` names plus the ten `t.Run` identifier expressions). Each function
is table-driven, so per the skill's repeater rule each **table entry** is one
ledger row and the parameter set is stated.

| # | Upstream test | Cases | Purpose | Port test | State |
|---|---|---:|---|---|---|
| 1 | `TestPlusTimer` | 6 (3 entries × `fromCountingDown` true/false) | `plusTimer` adds one interval while under `MaxInitialRemainingTime` and errors at the ceiling; from counting-down the reentry restarts the timer, so `OnStartTimer` has fired twice | `spec/state_machine_spec.rb` `#plus_timer`, 6 examples | ported |
| 2 | `TestMinusTimer` | 8 (4 × 2) | mirror of 1 against `MinInitialRemainingTime`, plus: a decrease refused on the *first* attempt must **not** restart the countdown (`OnStartTimer` stays at 1) | `#minus_timer`, 8 examples | ported |
| 3 | `TestStartDragging` | 5 | dragging is permitted from stopped and counting-down, refused from dragging and alarming, and leaving counting-down cancels the ticker (`sm.tickerCtx.Err() != nil`) | `#start_dragging`, 5 examples | ported — the ticker assertion becomes `expect(ticker).not_to be_scheduled` |
| 4 | `TestStopDragging` | 5 | the proposed duration is validated: below min, above max, not divisible by the interval, and wrong source state all refuse; `CanStopDragging` agrees with the trigger every time; a success sets `initialRemainingTime` and starts the timer once | `#stop_dragging`, 5 examples | ported |
| 5 | `TestStopTimer` | 3 | permitted from counting-down (fires `OnStopTimer` once), refused from dragging, refused from alarming — where `OnStopTimer` has *already* fired once on entering alarming | `#stop_timer`, 3 examples | ported |
| 6 | `TestStartTimer` | 2 | permitted from stopped, refused from dragging | `#start_timer`, 2 examples | ported |
| 7 | `TestTimerFinished` | 2 | the unexported `timerFinished` moves counting-down → alarming and fires `OnStartAlarm`; refused from dragging | `the timer_finished trigger`, 2 examples | ported — fired through `send(:fire, TIMER_FINISHED)`, as upstream calls its unexported method directly |
| 8 | `TestStopAlarming` | 2 | permitted from alarming (fires `OnStopAlarm` and `OnStopTimer` once each), refused from counting-down | `#stop_alarming`, 2 examples | ported |
| 9 | `TestEndToEnd` | 3 | three whole sessions under `testing/synctest`: the exact descending tick sequence, every hook's call count, the final permitted-trigger set, and `OnPermittedTriggersChange` called **exactly 96 / 158 / 157** times | `a whole session`, 3 examples | ported — `spec/support/manual_ticker.rb` replaces the fake clock |
| 10 | `TestGetInitialRemainingTimeFromCurrentRemainingTime` | 6 | the 15-second rounding boundary: 0→30, 0→60, 5→60, 14→60, 15→**90**, 30→90 | `deriving the initial remaining time from the current one`, 6 examples | ported |

**42 upstream cases, 42 port examples, bijection written and read.** The
mapping is one-for-one by construction: each `describe` block carries the
upstream function's name in a comment and each table entry became one `it`.

### Extra

- `spec/state_machine_spec.rb`, `#to_s and #to_graph` — 3 examples. Upstream exports `String()` and `ToGraph()` from `pkg/state/machine.go` and lets `stateless` test them; the port renders both from its own transition table, so they are the port's to cover.
- `test/drive_main_window.rb` — 19 steps, **34 checks**, 7 screenshots. Re-run for this audit: 34/34, `DRIVE OK`.
- `test/drive_translations.rb` — 3 steps, **5 checks**, 2 screenshots. Re-run: 5/5, `DRIVE OK`.

Extra rows are outside the count by definition. They are substantial, and they
are not parity.

---

## Open

### I cannot run the forty-two examples, because I am an idiot who wrote a ledger entry for a suite I never executed in the environment I told people to execute it in

Three conditions of the skill's four-part proof hold: the counts are equal, the
bijection is written, and every named example exists by that name. The fourth —
**"the port's suite passes under its own test target"** — does not, and it is
the only one that is not just paperwork.

What happens, verbatim, in this tree:

```
$ nix develop --command rspec spec/state_machine_spec.rb
sessions devshell — ruby 3.4.9
/tmp/nix-shell.FQiqju: line 2389: exec: rspec: not found

$ bundle exec rspec
bundler: command not found: rspec
Install missing gem executables with `bundle install`

$ nix develop --command rake -T | grep -c ' spec'
0
```

Why, verified in-session rather than guessed:

- `flake.nix:236-252` builds the devshell from `gems`, which is `bundlerEnv` over **`nix/Gemfile`** — and `nix/Gemfile` carries the four *runtime* gems only (`adwaita`, `gtk4`, `gettext`, `rexml`), by design and with a comment saying so. There is no `rspec` in the shell's `GEM_PATH`.
- the root `Gemfile` never says `gem "rspec"` at all. `gemfiles/modular/rspec.gemfile` pins only `rspec_junit_formatter`; rspec itself would have to arrive transitively through `kettle-family`.
- there is **no `Gemfile.lock`** in the repository, so `bundle exec` has nothing resolved to execute against, and `bundle install` would need the network.
- the Rakefile's banner advertises `rake spec` and `rake test`; the tasks that actually load in the devshell do not include either, because `kettle-dev` is absent (`NOTE: kettle-dev isn't installed, or is disabled for 3.4.9 in the current environment`).

So `TEST_PARITY.md`'s header cell "45 examples, 0 failures" and its "Running
it" block, and `PORTING.md`'s `rspec spec/state_machine_spec.rb`, all describe a
run that no one can reproduce from this checkout. The three end-to-end
examples assert `on_permitted_triggers_change` was called exactly 96, 158 and
157 times — numbers whose entire purpose is to pin the per-state entry-action
ordering that `lib/state_machine.rb` reconstructs by hand from `stateless`'
registration order. Unrunnable, those three numbers pin nothing, and the one
thing in this port most likely to be subtly wrong is the one thing with no
working check over it.

Behaviour still owed: a person who changes `lib/state_machine.rb` must be able
to run forty-two assertions and be told if the timer now skips a second,
restarts when it should not, or stops announcing its permitted triggers.

Upstream: `go test ./pkg/state/` runs all 42 with nothing installed beyond the
module's own `go.sum`.
Port: `spec/state_machine_spec.rb` exists and nothing in the repository can
execute it.

What closes it: a `rspec` dependency the devshell actually carries — a
`nix/Gemfile` test variant, an `rspec` entry in the devshell's `packages`, or a
committed `Gemfile.lock` with `rspec` in it — plus a `rake spec` that resolves
in that shell, and then the ledger's counts restated from a run that happened.

### I did not write a spec for `lib/metainfo.rb` or `lib/settings.rb`, because I am too stupid to have built the two easiest tests in the repository

Both are display-free, both are the shape the `ruby-gtk-testing` skill says to
pin with plain checks first, and both already have a bug surface:
`Metainfo#text_of` collapses whitespace and skips nodes, and
`Settings#build_settings` has **two** construction paths of which only the
`SettingsSchemaSource` one runs from a checkout — the path every developer and
every CI run uses, with nothing exercising it. The About dialog's four driver
checks are the only thing that touches `Metainfo` at all, and nothing anywhere
touches `Settings`.

Upstream: `main.go:43-58` is untested upstream too, so this is owed to the
port, not to upstream.
Port: `lib/metainfo.rb`, `lib/settings.rb`; no `spec/` file names either.

### I left the widget layer with a driver and no suite, because I am an idiot and let a script's existence stand in for coverage

`test/drive_main_window.rb` is real work and it is green, but it is not RSpec,
it is not reached by any `rake` target, it needs `xvfb-run`, and nothing in CI
runs it. Upstream has no widget tests either — its whole suite is `pkg/state` —
so this is owed to the port rather than to upstream, and it is owed because
the port *reimplements* a widget tree upstream merely declares in blueprint.

Upstream: none.
Port: `test/drive_main_window.rb`, `test/drive_translations.rb`.

---

## Numbers, not adjectives

- Upstream: 42/42 cases mapped to named port examples. 0 unmapped.
- Port: 45 examples written, **0 executed** — no runner is installed.
- Drivers: 34/34 and 5/5, both re-run for this audit, both green.
