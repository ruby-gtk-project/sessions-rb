# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` |
| Upstream suite | `pkg/state/machine_test.go`, 991 lines, 10 functions, 42 generated cases |
| Port suite | `spec/`, 75 examples, 0 failures (`rake spec`) |
| Drivers | `test/drive_main_window.rb`, 173 checks, 11 screenshots; `test/drive_translations.rb`, 5 checks, 2 screenshots; `test/drive_high_contrast.rb`, 21 checks, 5 screenshots (`rake drive`) |
| CI | `.github/workflows/ci.yaml` — three jobs: the suite, the three drivers, the catalogues |

The previous revision of this table said "45 examples, 0 failures" and the
previous revision of `PORTING.md` called that a false green and said zero
examples had ever run. Both were wrong. 45 examples did run, under one
invocation — `rspec --options /dev/null --require spec_helper --format progress
spec` — and under no documented one, because `.rspec` ended in `--format
RspecJunitFormatter` and that gem is not in the dev shell's `GEM_PATH`. The two
formatter lines are out of `.rspec` now, `bin/rspec` and `bin/rake` exist for
the `.gitlab-ci.yml` jobs that call them, and `rake spec` compiles the schema
and runs the suite.

---

## The ten upstream functions, one for one

Every one of upstream's table-driven test functions has a `describe` block in
`spec/state_machine_spec.rb` with one parameterised example per table entry.

| Upstream | Port | Cases | Covers |
|---|---|---|---|
| `TestPlusTimer` | `#plus_timer` | 3 × from-counting-down = 6 | the max guard, reentry restarting the countdown |
| `TestMinusTimer` | `#minus_timer` | 4 × from-counting-down = 8 | the min guard, and that a refused first decrease does *not* restart the timer |
| `TestStartDragging` | `#start_dragging` | 5 | every refused source state, and that the ticker is cancelled on the way out of counting-down |
| `TestStopDragging` | `#stop_dragging` | 5 | below min, above max, not divisible by the interval, wrong source state, and `can_stop_dragging?` agreeing with the trigger each time |
| `TestStopTimer` | `#stop_timer` | 3 | including that entering `alarming` has already fired `on_stop_timer` once |
| `TestStartTimer` | `#start_timer` | 2 | |
| `TestTimerFinished` | the `timer_finished` trigger | 2 | fired through `send`, as upstream calls its unexported `timerFinished` |
| `TestStopAlarming` | `#stop_alarming` | 2 | |
| `TestEndToEnd` | a whole session | 3 | the exact tick sequence, every hook count, the final permitted set, and the exact number of permitted-trigger announcements |
| `TestGetInitialRemainingTimeFromCurrentRemainingTime` | deriving the initial time | 6 | the 15-second rounding boundary |

Three more examples cover `#to_s` and `#to_graph`, which upstream inherits from
`stateless` and does not test itself.

### What the end-to-end rows actually pin

The three scenarios assert `on_permitted_triggers_change` was called exactly
96, 158 and 157 times. That number is the whole point of the row: it is one
announcement per transition plus one per tick plus one for the explicit flush,
and it comes out right only if the port's per-state entry actions run in the
order `stateless` gives upstream's registration order. `lib/state_machine.rb`
had a comment asserting that ordering and nothing checking it. It is now
checked, and it was correct.

### The clock

Upstream wraps each end-to-end scenario in `testing/synctest`, so
`time.Sleep(90 * time.Second)` returns at once and the ticker fires ninety
times. Ruby has no equivalent, so the seam is explicit: `lib/ticker.rb` is a
collaborator the state machine schedules through, and
`spec/support/manual_ticker.rb` is the same contract with the clock taken out.
`StateMachine#start_ticker` called `GLib::Timeout.add` directly before this
round and the end-to-end rows could not have been written at all.

### Running it

```sh
nix develop --command rake spec                           # the whole suite, 75 examples
nix develop --command rspec spec/state_machine_spec.rb    # just this file
```

No display needed: `lib/state_machine.rb` and `lib/ticker.rb` pull in `glib2`
only, and `lib/sessions/rb.rb` — which `spec/spec_helper.rb` requires —
deliberately does not load the app, because `require "gtk4"` calls `gtk_init`
and aborts without a display (`FINDINGS.md`).

---

## Open

### The widget layer has drivers, not a spec suite

`test/drive_main_window.rb` fires every action and both dial gestures and
asserts 173 things about the result; `test/drive_high_contrast.rb` adds 21 under
high contrast, four of which read the dial's pixels back. Neither is an RSpec
suite: they are reached by `rake drive` rather than `rake spec`, they need
`xvfb-run`, and a widget assertion written as a check gets none of RSpec's
matchers or its `--only-failures`.

This is a gap against what this port needs rather than against upstream, whose
whole suite is `pkg/state` — and recording that does not make it smaller,
because the port reimplements by hand a widget tree upstream declares in
blueprint. The drivers' existence is not coverage: it is 194 checks a human has
to read the output of.
Upstream: none.
Port: `test/drive_main_window.rb`, `test/drive_high_contrast.rb`.

### Closed: `lib/metainfo.rb` and `lib/settings.rb` now have specs

`spec/metainfo_spec.rb` pins `#summary`, `#description_paragraphs`,
`#description_bullets`, `#releases`, `#notes_for` and the private `#text_of`
against a fixture shaped like the merged metainfo — wrapped paragraphs,
`xml:lang` siblings inside one `<ul>`, inline markup, a release with no
description. Writing it found the one thing I would have guessed wrong: `msgfmt
--xml` tags each `<li>` rather than adding a translated `<ul>`, which is why
the port's filter has to be on the item.

`spec/settings_spec.rb` exercises both of upstream's construction paths against
`GSETTINGS_BACKEND=memory`: the `SettingsSchemaSource` one every checkout takes,
and the plain `Gio::Settings.new(APP_ID)` one a Flatpak or distro install takes,
which nothing had ever executed. It also pins two things reading had got wrong —
the schema's path has a trailing slash where `Resources::APP_PATH` does not, and
a directory with no `gschemas.compiled` raises `GLib::FileError` from GLib
before the port's own "could not find schema" message can fire.
Upstream: `main.go:43-58` is untested upstream too.
Port: `spec/metainfo_spec.rb`, `spec/settings_spec.rb`.

### Closed: there is now something that runs the runners

`rake -T` listed seventeen tasks and none was `spec`, `test` or `drive`;
`.github/workflows/` did not exist; and `.gitlab-ci.yml:59` and `:89` called
`bin/rspec spec` into a `bin/` that held only `setup` and `turbo_tests2`. So
the suite ran when a human typed an undocumented flag, and nothing automated
ran it at all, against upstream's workflow on every push.

`rakelib/spec.rake` defines `spec`, `test`, `drive`, `drive:main_window`,
`drive:translations`, `drive:high_contrast` and `check`; `bin/rspec` and
`bin/rake` are the binstubs the GitLab jobs call; `.github/workflows/ci.yaml`
runs the suite, all three drivers and the catalogues on every push, uploading
`tmp/shots/` so the screenshots can be looked at.
Upstream: `.github/workflows`, `go test ./pkg/state/`.
Port: `rakelib/spec.rake`, `bin/rspec`, `bin/rake`, `.github/workflows/ci.yaml`.
