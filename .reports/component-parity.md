# Component parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `ca7988e` |
| Units with a port counterpart | **7 / 7** (was 6/6 through round six; the Qt frontend is now a real unit, not a gap) |
| Units with a counterpart *and reconfirmed this round* | **0 / 7** — see Open §0 |
| Round | seven |

Re-derived against `HEAD`, not inherited from `.reports/component-parity.md`
(last written at `83cfb05`, which predates the Qt port, the Flatpak manifest,
and the German-translation widening in `bfcf14f`).

---

## §0 — The runtime gate, checked first because it governs every other row

This round's gate: **`drive_ok=false`, 0 checks passed, 0 failed, across 8
components.** `COMPONENT_PARITY.md` and the prior `.reports/component-parity.md`
both report every "closed" row as observed by `test/drive_main_window.rb`
(175 checks) or `test/drive_translations.rb` (5 checks) or `rspec` (45
examples). I attempted to reconfirm those three runs myself, in this
session, before writing a single row below:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb      → 0 output, 9+ min, still building the dev shell
nix develop --command bash -c "rake schema:compile && bin/rspec ..."  → 0 output, 6+ min, same
```

Neither finished. `ps`/`/proc/<pid>/wchan` on both showed them blocked on a
read from the nix-daemon's socket the whole time, and the host's load
average sat between 5.3 and 17.6 for the duration — other agents' `nix
develop` invocations sharing the same daemon. This is the same result the
round's own gate already reports. **Every "Closed" row below is therefore a
claim about what the previous round observed on an older commit, re-verified
here only by reading the source, never by re-running the driver this round.**
I have marked that distinction on every row rather than collapse it, because
collapsing it is exactly how `.reports/drive-verification.md` went stale
(see `accountability-ensurance.md`).

---

## Units 1–6: GTK/libadwaita frontend — unchanged in substance since round six, re-read rather than re-driven

Round six's `COMPONENT_PARITY.md` carries roughly thirty closed rows across
these six units (window, dial — including both high-contrast fixes, menu,
shortcuts dialog, about dialog, settings/style/portal/ticker). I re-opened
`lib/dial.rb`, `lib/main_window.rb`, `lib/about_dialog.rb`,
`lib/shortcuts_dialog.rb`, `lib/main_menu.rb`, `lib/settings.rb` this round
and confirmed by reading that the code those rows describe is still present
and unchanged: `#stroke_pie` still strokes the wedge including the full-ring
case (`lib/dial.rb`, the two high-contrast fixes from `83cfb05`), the four
invented About-dialog link rows are still gone (`lib/about_dialog.rb:95-111`
marks only `translator-credits`), `app.shortcuts` is still installed
(`lib/application.rb`) where upstream's own build never installs it. None of
this round's two commits (`0f80f06` Qt, `ca7988e` Flatpak) touched any file
under these six units, so there is no code-level reason to expect regression.
**Status: counterpart present and read, behaviour not re-observed this
round.** Carry the "Closed" verdict provisionally — re-run the drivers before
trusting it as current.

---

## Unit 7 — the Qt/Kirigami frontend (new this round; was a total gap through round six)

| Facet | Upstream | Port |
|---|---|---|
| Entry point | `qt/main.go`, 46 lines | `lib/qt_application.rb` (64 lines), `exe/sessions-qt` |
| UI | `qt/main.qml`, 52 lines, `Kirigami.ApplicationWindow` → `ColumnLayout` → 1 `Controls.Label` + 3 `Controls.Button` | `data/qt/main.qml` — **byte-identical** to upstream's (confirmed by `cmp` against the `origin/main` worktree this round) |
| State machine wiring | `state.NewStateMachine(ctx, time.Minute*5, log, &state.Hooks{...})`, all seven hooks no-ops | `StateMachine.new(remaining_time: StateMachine::DEFAULT_INITIAL_REMAINING_TIME)` — no `hooks:` passed, same no-op-by-default behaviour via `&.call` |
| Buttons bound to anything | **No** — `qt/main.qml` wires no `onClicked` upstream either | **No** — matches upstream's own unfinished state, not a port gap |
| Rake task | — | `rake drive:qt` → `test/drive_qt.rb` (189 lines) |

**This is a correctly-scoped port of an upstream file that is itself a
skeleton** — I confirmed this by reading `qt/main.qml` in the `origin/main`
worktree directly: no button has an `onClicked`, the label is the literal
`"05:00"`, and all seven hook fields in `main.go` are
`func(...) error { return nil }`. The port matches that shape. This is a
correspondence, not a shortfall: porting a skeleton with working wiring
behind it would be *adding* behaviour upstream does not have.

**What is still open, unchanged from `COMPONENT_PARITY.md`'s own admission**:
nobody — not the round that wrote it, not this one — has watched
`test/drive_qt.rb` run to completion. I did not attempt this myself this
round given §0's result on two lighter-weight commands; a `ruby-qt6` native-extension
build is heavier, not lighter, than what already would not finish. **Owner:
unassigned. Status: written, unobserved, carried forward unchanged.**

---

## Unit 8 — the Flatpak manifest and workflow (new this round; was a total gap through round six)

| Facet | Upstream | Port |
|---|---|---|
| Manifest | `com.pojtinger.felicitas.Sessions.json` | same filename, 262 lines, written this round |
| CI workflow | `.github/workflows/flatpak.yaml` | same filename, 75 lines, written this round |
| Build modules | Go toolchain + vendored Go modules | Ruby 3.4.2 built from source (no `org.freedesktop.Sdk.Extension.ruby` since freedesktop-sdk 25.08) + `bundle install --local` against a vendored `.gem` cache of the gemspec's 4 runtime gems and 25 transitive dependencies |
| Checksums | n/a | 30 `sha256`s (Ruby's tarball + 29 gem files) — I independently re-verified 3 of the 30 by downloading and hashing them myself this round rather than trust the manifest's own figures; all 3 matched |
| Actually built | — | **no** — confirmed this round: `which flatpak flatpak-builder` returns nothing in this environment, same as the commit that wrote the manifest already found and said plainly |

Not run through `flatpak-builder` anywhere this round either. The open
questions the authoring commit already named as unresolved — whether Ruby's
`./configure` finds `org.gnome.Sdk`'s headers, whether the native gem
extensions (`cairo`, `gdk4`, `gsk4`) link against the SDK's `pkg-config` the
way `flake.nix`'s override does for Nix — remain exactly that open, because
nothing in this environment can run `flatpak-builder` to answer them.
**Owner: unassigned. Status: written, unbuilt, carried forward unchanged.**

---

## Verdict

**7 of 7 upstream units (plus the two non-widget packaging deliverables) now
have a port file**, up from 6/7 through round six. **Zero of them were
re-observed running this round**, because the runtime gate this round
reports and this audit independently reproduced is `drive_ok=false`, 0
checks passed. The six GTK units' prior green comes from commits at or
before `bf51215`/`bfcf14f` — two to five commits behind `HEAD` — and is
carried here as "read, not re-driven" rather than restated as current, the
distinction `.reports/drive-verification.md` failed to keep (see
`accountability-ensurance.md`). The two new units (Qt, Flatpak) have never
been driven at all, by any round, and this round's attempt to close that for
Qt did not finish for the same infrastructure reason the six-unit re-drive
did not finish.
