# Porting — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `d5182c8` (GTK4 + Libadwaita through ruby-gnome) |
| Parity reports | `.reports/component-parity.md`, `.reports/test-parity.md`, `.reports/translation-parity.md`, `.reports/accountability-ensurance.md`, `.reports/component-identification.md`, `.reports/drive-verification.md` |
| Root ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Last accountability round | round ten, `.reports/accountability-ensurance.md` — **clean=false** |

This file is the resume point. It records what exists, what does not, and what
the last audit found wrong; it grants no permission to skip anything listed
under **Open gaps** or **Not started**. This update re-ran the spec suite and
all three GTK drivers against `HEAD` itself (see **Runtime**) rather than
restating a prior round's numbers.

---

## Upstream

Sessions is a single-window GNOME pomodoro timer: a draggable circular dial
sets a 30s-to-1h duration, a time label overlays it, and minus / start-stop /
plus buttons run the countdown, which ends in a blinking label, a notification
and an alarm sound. It is implemented in Go (puregotk bindings over GTK4 and
libadwaita), with its widget trees written in blueprint (`.blp`) files compiled
into a GResource. It also ships a second, independent Qt/QML frontend
(`qt/main.go`, `qt/main.qml`) over the same state machine. This is a Ruby port
(GTK4 + Libadwaita via ruby-gnome, `gtk4`/`adwaita` gems) of both frontends.

The spec lives on the `origin/main` ref of this repo. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check it out, never merge it.

Upstream's component-identification scan (`.claude/skills/component-identification/scripts/component-scan.sh`,
re-run this round's predecessor against both trees) finds **7 units**: the
application object, the main window, the primary menu, the dial, the
shortcuts dialog, the about dialog, and the Qt/Kirigami frontend.

---

## Done

Components with a Ruby counterpart that a driver or spec has actually
exercised, confirmed again this round against `HEAD` (`d5182c8`) — see
**Runtime** for the exact commands and their output. One upstream source
file, one `lib/*.rb`.

| Port | Upstream |
|---|---|
| `lib/application.rb` | `internal/components/application.go`, `main.go` |
| `lib/translations.rb` | `main.go` (i18n init) |
| `lib/settings.rb` | `main.go` (settings) + `assets/resources/index.gschema.xml` |
| `lib/resources.rb` | `assets/resources/index.go` |
| `lib/main_window.rb` | `internal/components/main_window.go` + `assets/resources/window.blp` |
| `lib/main_menu.rb` | the `menu main_menu` block of `window.blp` |
| `lib/alarm.rb` | the `Gtk.MediaFile` / notification half of `main_window.go` |
| `lib/background_portal.rb` | the portal calls in `main_window.go` (see **Blockers**) |
| `lib/dial.rb` | `internal/components/dial.go` |
| `lib/shortcuts_dialog.rb` | `assets/resources/shortcuts-dialog.blp` |
| `lib/about_dialog.rb` | `internal/components/application.go:76-92` |
| `lib/metainfo.rb` | `assets/resources/metainfo.xml.in` |
| `lib/state_machine.rb` | `pkg/state/machine.go`, `pkg/state/constants.go` |
| `lib/ticker.rb` | `pkg/state/machine.go`'s inline `time.Ticker`, extracted into a collaborator |
| `lib/style.rb` | `assets/resources/style.css` (heredoc is byte-identical) |
| `spec/state_machine_spec.rb`, `spec/support/manual_ticker.rb` | `pkg/state/machine_test.go` |
| `spec/metainfo_spec.rb`, `spec/settings_spec.rb` | nothing upstream to compare against directly |
| `data/*` (oga, 3 SVGs, desktop.in, metainfo.xml.in, gschema.xml) | `assets/` equivalents, byte-identical |
| `po/*.po` (26 catalogues) | `po/*.po`, byte-identical |

Six of the seven identified units (application object, main window, primary
menu, dial, shortcuts dialog, about dialog) are confirmed running this round
by the GTK drivers below. The **Qt/Kirigami frontend is not in this table**:
`lib/qt_application.rb`, `exe/sessions-qt`, `lib/sessions/qt.rb` and
`data/qt/main.qml` exist as files, but nothing has run `test/drive_qt.rb` to
completion in this environment — see **Open gaps**.

---

## Runtime

Run this round, in order, against `HEAD` (`d5182c8`):

```
nix develop --command bash -c "bin/rspec spec --options /dev/null --require spec_helper --format progress"
nix develop --command xvfb-run -a rake drive
```

| Command | Result |
|---|---|
| `bin/rspec spec` | **75 examples, 0 failures** |
| `rake drive` → `test/drive_main_window.rb` | 173 of 173 checks passed, `DRIVE OK`, 11 screenshots |
| `rake drive` → `test/drive_translations.rb` (German pass) | 53 of 53 checks passed, `DRIVE OK`, 6 screenshots |
| `rake drive` → `test/drive_translations.rb` (nested French sub-process) | 1 of 1 checks passed, `DRIVE OK` |
| `rake drive` → `test/drive_high_contrast.rb` | 21 of 21 checks passed, `DRIVE OK`, 5 screenshots |

173 + 53 + 1 + 21 = **248 driver checks, 0 failed**, all exiting 0 and
printing `DRIVE OK`. Combined with the spec run: **248 driver checks passed /
0 failed, plus 75 spec examples passed / 0 failed.** `drive_ok=true`.

This exercises 6 of the 7 identified units (everything except the Qt
frontend). `test/drive_qt.rb` was **not** run this round: it needs the
separate `nix develop .#qt` shell (the default shell no longer carries the Qt
native-extension build), and that shell was not invoked in this pass — see
**Open gaps**. No claim is made here about the Qt frontend's runtime state.

`rake schema:compile`, `gettext:mo` and `gettext:data` are invoked as
prerequisites by `rake drive` itself and completed without error as part of
the run above.

---

## Not started

Upstream components with no Ruby counterpart at all:

| Upstream | Port |
|---|---|
| `sessions.doap` | nothing |
| `assets/meta/screenshot-initial.png`, `screenshot-running.png` | nothing; the port's metainfo cites upstream's `raw.githubusercontent.com` URLs |
| `README.md` tutorial section | nothing; `README.md` here is gem boilerplate |

Nothing here has an owner. A row closes when the behaviour is in the port.

---

## Open gaps

The last accountability audit, round ten (`.reports/accountability-ensurance.md`),
reported **clean=false**. Its verdict: the six GTK/libadwaita units are
reconfirmed running (248/248 driver checks, 75/75 spec examples — matching
this round's own re-run above); the Qt/Kirigami frontend and the Flatpak
packaging unit remain written but never observed to work, which is why
`clean` is false. Four standing gaps are carried, independent of this
round's own re-verification:

| # | Gap | Reports |
|---|---|---|
| 1 | Qt/QML frontend (`lib/qt_application.rb`, `exe/sessions-qt`, `data/qt/main.qml`) is written but `test/drive_qt.rb` has never been run to completion in this environment — it needs `nix develop .#qt`, which this round did not invoke | `.reports/component-parity.md`, `.reports/component-identification.md`, `.reports/accountability-ensurance.md` |
| 2 | Flatpak manifest (`com.pojtinger.felicitas.Sessions.json`) is written but never run through `flatpak-builder` — this environment has no `flatpak`/`flatpak-builder` binary at all | `.reports/component-parity.md`, `COMPONENT_PARITY.md` |
| 3 | DOAP record and both screenshots (`sessions.doap`, `assets/meta/screenshot-{initial,running}.png`) absent; the metainfo cites upstream's `raw.githubusercontent.com` images | `.reports/component-identification.md` |
| 4 | Widget layer is covered by drivers (248 checks a human has to read the output of), not an automated spec suite | `.reports/test-parity.md`, `TEST_PARITY.md` |

---

## Blockers

- **Qt/QML Kirigami frontend** (`qt/main.go`, `qt/main.qml`) — upstream's own
  version is a non-functional layout skeleton (no bindings, no `onClicked`,
  the state-machine hooks are all `nil`), so porting its behaviour has low
  value even once the toolkit exists; the Ruby side also needs a second
  toolkit binding (`qt6/qtwidgets` via a Qt gem) that only lives in the
  separate `nix develop .#qt` shell, not the default one, and that shell's
  driver has never been run to completion in this environment (see **Open
  gaps**, #1).
- **No Flatpak build** — a manifest (`com.pojtinger.felicitas.Sessions.json`)
  exists in the tree, but producing a working Flatpak needs building Ruby
  and the `ruby-gnome` C extensions from pinned sources, since there is no
  Ruby SDK extension equivalent to `org.freedesktop.Sdk.Extension.golang`,
  and this environment has no `flatpak-builder` to even attempt it.

---

## Verification performed for this update

```
git status --porcelain            # empty before and after this commit
bin/rspec spec                    # 75 examples, 0 failures
rake drive                        # 173/173 + 53/53 + 1/1 + 21/21 = 248 checks, 0 failed, DRIVE OK
```

`test/drive_qt.rb` was not run this round (needs `nix develop .#qt`); no
claim is made about the Qt frontend's current runtime behaviour beyond what
`.reports/component-parity.md` already records.
