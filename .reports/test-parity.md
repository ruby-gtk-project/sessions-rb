# Test parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `ca7988e` |
| Upstream tests | **42** cases (10 table-driven functions, `pkg/state/machine_test.go`) |
| Mapped | **42 / 42**, by name, carried forward from `TEST_PARITY.md` and re-read against `HEAD` |
| Port examples | 45 (42 mapped + 3 port-only: `#to_s`/`#to_graph`) |
| **Executed this round** | **not reconfirmed — see Open §1** |
| Round | seven |

The 42/42 census itself is unchanged from round six's `TEST_PARITY.md` and
`.reports/test-parity.md`, and I re-read `spec/state_machine_spec.rb` against
it rather than take the count on faith: all ten upstream functions
(`TestPlusTimer` 6 cases, `TestMinusTimer` 8, `TestStartDragging` 5,
`TestStopDragging` 5, `TestStopTimer` 3, `TestStartTimer` 2,
`TestTimerFinished` 2, `TestStopAlarming` 2, `TestEndToEnd` 3,
`TestGetInitialRemainingTimeFromCurrentRemainingTime` 6) have a
correspondingly named `describe`/`it` block with the upstream function
named in a comment, 42 total. `spec/metainfo_spec.rb` and
`spec/settings_spec.rb` remain present with no upstream counterpart to map
to (`main.go:43-58` is untested upstream too).

**This matters specifically for `TestEndToEnd`'s 96/158/157
`OnPermittedTriggersChange` call counts**: those numbers pin the per-state
entry-action ordering `lib/state_machine.rb` reconstructs by hand from
`stateless`'s registration order, and they are the one place a static census
cannot tell you whether the port actually gets the ordering right —
only running the suite can.

---

## Open

### 1 — The suite's execution could not be reconfirmed this round, and the runtime gate says it did not run: `drive_ok=false`, 0 passed, 0 failed

I ran, in this session, in the project's own dev shell, exactly the command
`.reports/test-parity.md` (round six) and `TEST_PARITY.md` document as
working:

```
nix develop --command bash -c "rake schema:compile && bin/rspec spec --options /dev/null --require spec_helper --format progress"
```

**It produced zero lines of output after 4+ minutes of wall time**, and
`ps` shows the `nix develop` process blocked reading from the nix-daemon's
unix socket the entire time, not running Ruby — the dev shell itself never
finished evaluating, let alone got to `rspec`. In parallel I ran
`test/drive_main_window.rb` the same way; same result, 7+ minutes, zero
output. The host's load average held between 5.4 and 17.6 throughout — this
is a shared machine with many other agents' `nix develop` invocations
competing for the same nix-daemon, not a defect in this port's command.

This reproduces the round's own runtime gate (`drive_ok=false`, 0 checks
passed, 0 failed, across 8 components) rather than contradicting it. **The
last time anyone actually observed 45/45 examples pass was commit `bf51215`
or earlier** — two commits before `HEAD`, and neither of the two commits
since (`0f80f06` the Qt port, `ca7988e` the Flatpak manifest) touched
`spec/` or `lib/state_machine.rb`, so there is no code reason to expect the
suite's *content* has changed. But "nothing changed that I can see" is a
different claim from "it still passes", and this round could not make the
second claim. Per the skill's own rule, a suite not executed this round is
unverified, not passing.

### 2 — Still unreachable from `rake`/CI, confirmed unchanged by reading

`rakelib/spec.rake` defines `spec`, `drive`, `drive:main_window`,
`drive:translations`, `drive:high_contrast`, `drive:qt`, and `check`
(`spec` + `drive`) — this is real and is an improvement over the "0 of 3
runners reachable" finding from two rounds ago; I read the file rather than
trust the claim. What is still true: **no CI runs any of it.**
`.github/workflows/` now exists (added this round) but holds only
`ci.yaml` and `flatpak.yaml`; reading `ci.yaml`, it does invoke
`bundle exec rspec` — so CI-reachability may actually be closed, but I could
not confirm this by running it (GitHub Actions is not available to run
locally, and this falls outside the skill's own in-repo checks). `.gitlab-ci.yml`
still invokes `bin/rspec spec`, which exists now (`bin/rspec` was added in
round six).

### 3 — `lib/metainfo.rb` and `lib/settings.rb` specs exist (closing a round-five gap), re-confirmed by reading rather than running

`spec/metainfo_spec.rb` (162 lines) and `spec/settings_spec.rb` (146 lines)
are both present and, by reading, both exercise real surface: the metainfo
spec reads `#untranslated` and the `xml:lang`-rejection fix directly, the
settings spec covers both of `Settings#build_settings`'s construction paths.
Whether they currently pass is covered by Open §1 — unconfirmed this round.

### 4 — The widget layer still has drivers, not specs, and still no high-contrast step is independently confirmed present

`test/drive_main_window.rb` is 725 lines (up from round six's shorter
version — grew with the merge/interrupted-run commits). By reading it,
it does **not** contain a step that toggles
`Adwaita::StyleManager.default.high_contrast=` — that assertion lives
entirely in the separate `test/drive_high_contrast.rb` (225 lines, a fifth
driver not wired into `DRIVERS` under the same name convention but present
as `rake drive:high_contrast`). So the original finding ("no step sets high
contrast") is resolved by a separate driver existing, which I confirmed by
reading `rakelib/spec.rake`'s `DRIVERS` hash (it lists `high_contrast:
"test/drive_high_contrast.rb"`), not by running it — Open §1 applies here
too.

---

## Numbers, not adjectives

- Upstream: **42/42** cases mapped, unchanged, re-verified by reading.
- Port: **45 examples exist** (confirmed by reading the spec files and
  counting `it` blocks); **0 confirmed executed this round**.
- Drivers: **4 driver scripts exist** (`main_window`, `translations`,
  `high_contrast`, `qt`) reachable via `rake drive`; **0 confirmed executed
  this round.**
- Runtime gate this round: **`drive_ok=false`, 0 passed, 0 failed, 8
  components** — reproduced independently rather than taken on report.
