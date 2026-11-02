# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` |
| Upstream suite | `pkg/state/machine_test.go`, 991 lines, 10 functions, 42 generated cases |
| Port suite | `spec/state_machine_spec.rb`, 45 examples, 0 failures |
| Drivers | `test/drive_main_window.rb`, 19 steps, 34 checks, 7 screenshots; `test/drive_translations.rb`, 5 checks, 2 screenshots |

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
nix develop --command rspec spec/state_machine_spec.rb
```

No display needed: `lib/state_machine.rb` and `lib/ticker.rb` pull in `glib2`
only, and `lib/sessions/rb.rb` — which `spec/spec_helper.rb` requires —
deliberately does not load the app, because `require "gtk4"` calls `gtk_init`
and aborts without a display (`FINDINGS.md`).

---

## Open

### The widget layer has a driver, not a spec suite

`test/drive_main_window.rb` fires every action and both dial gestures and
asserts 34 things about the result, which is the first time anything in this
port was observed rather than read. It is not an RSpec suite and it is not run
by `rake spec`; it needs `xvfb-run` and it takes about ten seconds.

Upstream has no widget tests either — its whole suite is `pkg/state` — so this
is not a parity gap against upstream. It is a gap against what this port needs,
because the port reimplements a widget tree upstream declares in blueprint, and
I am recording it rather than letting the driver's existence stand in for
coverage.
Upstream: none.
Port: `test/drive_main_window.rb`.

### `lib/metainfo.rb` and `lib/settings.rb` have no specs

Both are display-free and both parse or persist something, which is exactly the
shape the `ruby-gtk-testing` skill says to pin with plain checks first. The
About dialog's four checks in the driver are the only thing exercising
`Metainfo` today, and nothing at all exercises `Settings`' two construction
paths — in particular the `SettingsSchemaSource` fallback, which is the one
that runs from a checkout.
Upstream: `main.go:43-58` is untested upstream too.
Port: `lib/metainfo.rb`, `lib/settings.rb`; no `spec/`.
