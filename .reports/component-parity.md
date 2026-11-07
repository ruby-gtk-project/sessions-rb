# Component parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `cc2c04c` |
| Units with a port counterpart | **7 / 7** |
| Units with a counterpart *and reconfirmed running this round, by me* | **6 / 7** — the six GTK/libadwaita units; the Qt unit is still unobserved (see Unit 7) |
| Round | eight |

Round seven's headline finding was that nothing could be re-run because the
shared machine's `nix develop` never finished evaluating (contention on the
nix-daemon). **That is fixed this round** (`cc2c04c` split the Qt native
build out of `devShells.default`), and this report is built on actually
running the drivers myself, in this session, rather than reading commit
messages that claim they were run.

---

## §0 — The runtime gate, verified by me before writing a single row below

```
nix develop --command xvfb-run -a rake drive:main_window      → 173 of 173 checks passed, DRIVE OK
nix develop --command xvfb-run -a rake drive:translations     → 51 of 51 checks passed, DRIVE OK
nix develop --command xvfb-run -a rake drive:high_contrast    → 21 of 21 checks passed, DRIVE OK
nix develop --command bash -c "rake schema:compile && bin/rspec spec"  → 75 examples, 0 failures
```

173 + 51 + 21 = **245 checks, 0 failed** — matching this round's runtime
gate exactly, reproduced command by command, not taken on report.

**One thing the gate's "16 components" framing hides**: all 245 checks come
from exactly three driver scripts, covering the six GTK/libadwaita units
below. The seventh unit (Qt/Kirigami) and the Flatpak packaging unit
contribute **zero** checks to that count, because neither has ever run to
completion. A gate that reports "16 components, drive_ok=true" without
saying two of the port's seven+ units are outside what it measures is
narrower than it reads — see Unit 7 and Unit 8.

---

## Units 1–6: GTK/libadwaita frontend — reconfirmed by actually running the drivers, not by reading

| Unit | Upstream | Port | Observed by, this round |
|---|---|---|---|
| Application object | `main.go`, `application.go` | `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `lib/style.rb` | `drive:main_window` steps on `app.openAbout`, `app.stopAlarmPlayback` actions — all present, enabled |
| Main window | `main_window.go` + `window.blp` | `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb` | `drive:main_window`, 173/173 — window, header bar, menu button, dial, time card, three buttons, `win.toggleTimer`/`addTime`/`removeTime`/`closeWindow` |
| Primary menu | `menu main_menu` block of `window.blp` | `lib/main_menu.rb` | `drive:main_window` (menu button + its actions) |
| Dial, including both high-contrast fixes | `dial.go` | `lib/dial.rb` | `drive:main_window` + `drive:high_contrast`, 21/21 — idle/counting-down/full-ring/alarming/quarter-ring renders, wedge outline, start-cap geometry |
| Shortcuts dialog | `shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | `drive:main_window` (dialog opens, 2 sections / 7 items) |
| About dialog | `application.go:76-92` + `metainfo.xml.in` | `lib/about_dialog.rb`, `lib/metainfo.rb` | `drive:main_window` (dialog opens, no invented link rows) + `drive:translations` (9 German metainfo elements merge correctly) |

**Status: counterpart present, behaviour observed this round by me, not
carried forward from an older commit's claim.** This closes the exact gap
`accountability-ensurance.md`'s round-seven report (the previous
`.reports/accountability-ensurance.md`) flagged: a status that was true once
being presented as current without having been re-run. It has now actually
been re-run.

---

## Unit 7 — the Qt/Kirigami frontend: still never driven, and now for a sharper, more damning reason than "the machine was busy"

| Facet | Upstream | Port |
|---|---|---|
| Entry point | `qt/main.go`, 46 lines | `lib/qt_application.rb` (64 lines), `exe/sessions-qt` |
| UI | `qt/main.qml`, 52 lines | `data/qt/main.qml` — byte-identical to upstream's |
| Rake task | — | `rake drive:qt` → `test/drive_qt.rb` |

Round seven's story was infrastructure contention: other agents' `nix
develop` invocations on a shared machine kept the Qt native-extension build
from finishing in the time any round had. `cc2c04c` fixed exactly that, by
moving the Qt gems (`ruby-qt6-rice`, `ruby-qt6-qtwidgets`, etc.) out of
`devShells.default` into their own `devShells.qt`.

**That fix created a new, sharper failure, and I reproduced it myself:**

```
$ nix develop --command xvfb-run -a rake drive:qt
cannot load such file -- qt6/qtwidgets (LoadError)
	from lib/qt_application.rb:3
	from lib/sessions/qt.rb:3
	from test/drive_qt.rb:46
```

The Qt gem simply is not installed in the shell the project's own dev-shell
banner tells a user to enter (`nix develop`, no flag). It exists only in
`nix develop .#qt`, which neither `rake drive:qt` nor `rake drive` nor
`rake check` ever enters — they all run under whatever shell invoked
`rake`. **So the Qt unit is not merely unobserved; the one command written
to observe it (`rake drive:qt`) is wired to fail in the project's documented
default environment, unconditionally, every time, with no dependency on
machine load at all.** This is worse than round seven's finding, not
better, even though the contention problem that produced round seven's
version of it is gone. I started a `nix develop .#qt` shell to see whether
the driver passes there; it was still compiling `ruby-qt6-qtwidgets`'s C++
extension after several minutes (confirmed via `ps`: `cc1plus` running,
96% CPU) when this report was written, reproducing — now for the *correct*
shell — the same "never finished in the time a round has" story round
seven told about the wrong shell. **Owner: unassigned. Status: written,
never driven to completion by any round, against either shell.**

---

## Unit 8 — the Flatpak manifest and workflow: unchanged, still unbuilt

| Facet | Port |
|---|---|
| Manifest | `com.pojtinger.felicitas.Sessions.json`, 262 lines |
| CI workflow | `.github/workflows/flatpak.yaml`, 75 lines |
| Actually built | **no** — reconfirmed this round: `which flatpak flatpak-builder` returns nothing in this environment |

No code in this unit changed since round seven, and the blocker (no
`flatpak-builder` binary at all) is an environment fact, re-checked and
still true. **Owner: unassigned. Status: written, unbuilt, carried forward
unchanged.**

---

## Verdict

**7 of 7 upstream units have a port file.** This round, for the first time
across eight rounds, **6 of those 7 were reconfirmed running by someone who
actually watched the drivers execute, inside this session** — 245/245
checks, 75/75 spec examples, 0 failures, 0 skips. That is real progress and
should be read as real: the previous rounds' inability to re-run anything
was an infrastructure problem, and it is fixed.

**The 7th unit (Qt) is not just unverified — the automated path to verifying
it is broken in the project's own default shell**, a regression introduced
by the very commit that fixed the six-unit contention problem. The runtime
gate's "16 components, drive_ok=true, 245 passed" is accurate for what it
measures, but it does not cover this unit or the Flatpak packaging unit; a
reader who takes the gate as describing the whole port, rather than six of
eight recorded units, is misled by omission. See `accountability-ensurance.md`.
