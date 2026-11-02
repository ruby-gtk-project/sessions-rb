# Test parity — sessions

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `4f87634` |
| Upstream tests | **10** test functions / **42** generated cases |
| Ported | **0** |
| Gaps | **10** (42 cases) |
| Test command | `bundle exec rspec` (via `rake spec`) — **cannot run, see below** |

## Census

`.claude/skills/test-parity/scripts/test-census.sh` returns **0 rows for
upstream**. That is a scanner defect, not an empty suite: the script's `find`
takes `*.vala *.c *.py *.js *.ts *.rs *.rb *.cpp` and upstream is Go. Censused
by hand from `pkg/state/machine_test.go` (991 lines, `testify/require`,
`testing/synctest`).

Cross-check against the build file: `go.mod` declares
`github.com/stretchr/testify` and `github.com/qmuntal/stateless`; `grep -rl
'func Test' --include='*.go'` returns exactly one file, so the census is
complete at one file.

Every test is table-driven. Per the skill's repeater rule each table gets one
ledger row with the parameter set in the Purpose cell, and the generated case
count is stated beside it — both numbers are reported because the count is the
check and 10 reads very differently from 42.

| # | Upstream test | Cases | Purpose | Port test | State |
|---|---|---:|---|---|---|
| 1 | `pkg/state/machine_test.go#TestPlusTimer` | 6 | `+30s` from `stopped` and from `countingDown`. Parameter set: `{30s,1 press}`, `{1h−30s,1 press}`, `{1h−30s,2 presses, the 2nd must fail}` × `{fromCountingDown: true,false}`. Pins that the guard refuses the press that would exceed 1h, that the duration lands exactly on the sum, and that pressing `+` while counting down restarts the timer (`OnStartTimer` fires a second time) | — | **gap** |
| 2 | `pkg/state/machine_test.go#TestMinusTimer` | 8 | `−30s` from both states. Parameter set: `{1h,1}`, `{60s,1}`, `{60s,2, the 2nd fails}`, `{30s,1, the 1st fails}` × `{fromCountingDown: true,false}`. Adds the case row 1 has no equivalent of: when the *first* `−` press is refused while counting down, the timer is **not** restarted (`OnStartTimer` stays at 1, not 2) | — | **gap** |
| 3 | `pkg/state/machine_test.go#TestStartDragging` | 5 | Where a drag may begin: from `stopped` yes; from `dragging` no; from `countingDown` yes; from `alarming` no. Fifth case pins that beginning a drag while counting down **cancels the running ticker** (`tickerCtx.Err() != nil`) | — | **gap** |
| 4 | `pkg/state/machine_test.go#TestStopDragging` | 5 | The guard on the dragged value: 5min accepted; below 30s refused; above 1h refused; a value not divisible by 30s refused; and `stopDragging` refused outright from `stopped` (you cannot stop a drag you never started). The accepted case also pins that the countdown starts immediately — `OnStartTimer` called once | — | **gap** |
| 5 | `pkg/state/machine_test.go#TestStopTimer` | 3 | `stopTimer` from `countingDown` yes; from `dragging` no; from `alarming` no | — | **gap** |
| 6 | `pkg/state/machine_test.go#TestStartTimer` | 2 | `startTimer` from `stopped` yes; from `dragging` no | — | **gap** |
| 7 | `pkg/state/machine_test.go#TestTimerFinished` | 2 | the private `timerFinished` from `countingDown` yes; from `dragging` no | — | **gap** |
| 8 | `pkg/state/machine_test.go#TestStopAlarming` | 2 | `stopAlarming` from `alarming` yes; from `countingDown` no | — | **gap** |
| 9 | `pkg/state/machine_test.go#TestEndToEnd` | 3 | Three whole sessions under `testing/synctest` fake time: set 90s and let it finish and dismiss it; set 150s and let it finish and dismiss it; set 150s and let it finish and **leave the alarm ringing**. Each asserts the exact sequence of `OnCurrentRemainingTimeTick` arguments from `initial−1s` down to `0`, that no tick arrives after the timer stops (the scenario deliberately sleeps one interval longer than the timer runs), the hook call counts (`OnStartTimer` 1, `OnStopTimer` 1, `OnStartAlarm` 1, `OnStopAlarm` 1 or 0), the exact permitted-trigger set at rest, and `OnPermittedTriggersChange` call counts of 96 / 158 / 157 | — | **gap** |
| 10 | `pkg/state/machine_test.go#TestGetInitialRemainingTimeFromCurrentRemainingTime` | 6 | The rounding rule behind `±30s while counting down`. Parameter set: `(0s,+1)→30s`, `(0s,+2)→60s`, `(5s,+2)→60s`, `(14s,+2)→60s`, `(15s,+2)→90s`, `(30s,+2)→90s`. Pins half-up at exactly 15s — the boundary that decides whether pressing `+` at 15 seconds left gives you a minute or ninety seconds | — | **gap** |

`newTestingStateMachine` (line 15) is a harness, not a case, and is not
counted.

## Behaviour still owed

| # | Behaviour a Ruby test must pin |
|---|---|
| 1 | Pressing `+` cannot take the timer past an hour, and pressing it mid-countdown keeps the timer running from the new, rounded duration |
| 2 | Pressing `−` cannot take the timer below thirty seconds, and a refused `−` mid-countdown does **not** restart the countdown |
| 3 | The dial can be dragged while stopped and while counting down, not while already dragging and not while the alarm rings; starting a drag mid-countdown stops the countdown |
| 4 | Releasing the dial on a duration that is out of range, or not a whole half-minute, does nothing — and releasing it on a valid one starts the timer at once |
| 5 | Stop only works on a running timer |
| 6 | Start only works on a stopped timer |
| 7 | A timer that reaches zero rings the alarm, and only a running timer can reach zero |
| 8 | The alarm can be dismissed while it rings and not before |
| 9 | A whole session counts down second by second to zero, rings, stops ticking, is dismissed, and leaves the three buttons in exactly the state they started in — and a session left ringing leaves `Stop` as the only thing the user can do |
| 10 | With fifteen seconds left, pressing `+` twice gives ninety seconds, not sixty |

## The port's suite

The port has **no tests at all**. `spec/` contains `spec_helper.rb` and
`README.md` and nothing else; `test-census.sh` returns 0 rows for the port, and
that zero is correct.

There is no `## Extra` section because there is nothing extra. The port has
written no checks of its own either.

Two further findings about the harness, both of which mean this zero cannot be
turned into a one without work:

1. **The suite cannot load.** `spec/spec_helper.rb:26` is
   `require "sessions/rb"`. `lib/sessions/rb.rb` does not exist — only
   `lib/sessions/rb/version.rb`. The first spec anybody writes fails with
   `LoadError` before its first assertion.
2. **The suite cannot be run here at all.** `require 'gtk4'` raises `LoadError`
   in this environment, bare and under `bundle exec`. So "the port's suite
   passes under its own test target" is **not** a check that passed; it is a
   check that did not run. Rows 1–8 and 10 test `lib/state_machine.rb`, which
   requires only `glib2` and could be specced without a display — row 9 needs
   either a main loop or an injectable clock, and `StateMachine#start_ticker`
   calls `GLib::Timeout.add` directly (`lib/state_machine.rb:261`) with no seam,
   so porting row 9 will require changing the port, not only adding a spec.

## Parity

**0 / 10** test functions, **0 / 42** cases, 10 gaps. The suite is empty and
would not load if it were not.

The thing this costs is specific. `lib/state_machine.rb` is a from-scratch
reimplementation of a library state machine — `github.com/qmuntal/stateless`'s
`Configure`/`PermitReentry`/`OnEntryFrom`/`OnExitWith`/`OnTransitioned` DSL
rewritten as one hand-rolled transition table, 289 lines, with entry-action
ordering that depends on upstream's *registration order* to be correct. That is
exactly the kind of code upstream wrote 991 lines of tests for, and the port
reproduces it with none. Every behaviour in `component-parity.md` — every
button's sensitivity, every label swap, every colour on the dial — is a function
of this one untested file.
