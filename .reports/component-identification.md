# Component identification — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `cc2c04c` |
| Scan | `.claude/skills/component-identification/scripts/component-scan.sh`, re-run this round over a fresh `git worktree` of `origin/main` and over the current `ruby` checkout |
| Round | eight |

Re-checked against `HEAD`. No commit between `ca7988e` (round seven) and
`cc2c04c` (this round — `121bf1d`, `5865a3d`, `cc2c04c`) touched a file this
report's unit table names, so the inventory below is unchanged in substance;
what changed is which claims are now backed by an actual run rather than a
reading, recorded in Unit 7's row.

Step 1 first, both sides: upstream's declarative UI is still exactly two
blueprint files, confirmed unchanged by `cmp`-diffing this round's
`origin/main` worktree against the prior round's reading:

```
assets/resources/window.blp              1 template root + 1 menu block
assets/resources/shortcuts-dialog.blp    1 named root (Adw.ShortcutsDialog), not a template
```

The port still has no `.blp`/`.ui` file at all.

---

## Unit list — seven units now, not six

The six GTK/libadwaita units are unchanged from round six. **A seventh unit
now has a port file where round six's inventory correctly recorded none:**

| # | Unit | Upstream files | Port file(s) | Status this round |
|---|---|---|---|---|
| 1 | application object | `main.go`, `application.go`, `constants.go` | `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `lib/style.rb`, `exe/sessions` | unchanged |
| 2 | main window | `main_window.go` + `window.blp` | `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb` | unchanged |
| 3 | primary menu | `menu main_menu` block of `window.blp` | `lib/main_menu.rb` | unchanged |
| 4 | dial | `dial.go` | `lib/dial.rb` | unchanged |
| 5 | shortcuts dialog | `shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | unchanged |
| 6 | about dialog | `application.go:76-92` + `metainfo.xml.in` | `lib/about_dialog.rb`, `lib/metainfo.rb` | **changed**: the four invented `add_link` rows (`Donate`, `Translate`, `Source Code`, `Contribute`) are gone (`83cfb05`) — confirmed by reading `lib/about_dialog.rb:95-111`, which marks only `translator-credits` now |
| 7 | Qt/Kirigami frontend | `qt/main.go` (46 lines), `qt/main.qml` (52 lines) | `lib/qt_application.rb` (64 lines), `exe/sessions-qt`, `lib/sessions/qt.rb`, `data/qt/main.qml` (byte-identical to upstream's) | written, **still never driven to completion**, and this round found a more concrete reason than contention: `lib/qt_application.rb:3` requires `qt6/qtwidgets`, a gem that only exists in the separate `nix develop .#qt` shell `cc2c04c` split out this round. Run in the project's own default shell, `test/drive_qt.rb` fails with `LoadError: cannot load such file -- qt6/qtwidgets`, confirmed by me running it. See `component-parity.md` Unit 7 and `accountability-ensurance.md` |

The scan still produces **no rows** for either `qt/main.go`/`qt/main.qml` or
`lib/qt_application.rb`/`data/qt/main.qml` — re-confirmed this round by
running `component-scan.sh` over both a fresh `origin/main` worktree and the
current `ruby` tree (62 port rows, 24 upstream rows, same shape as round
six's 6-file-scoped totals). Qt/QML is invisible to a regex built for
GTK/libadwaita on both sides; this was true last round and remains true.

---

## Scan totals, re-run and re-confirmed this round

```
upstream (6 GTK/libadwaita files, scoped):  35 widget, 10 css,  9 signal, 16 action, 2 controller, 12 type
port (`lib/`, 7 files with rows):           14 widget,  8 css,  7 signal, 13 action, 2 controller,  9 type
```

Same totals as round six — the files these come from (`window.blp`,
`shortcuts-dialog.blp`, `application.go`, `dial.go`, `main_window.go`,
`main.go` on one side; `about_dialog.rb`, `alarm.rb`, `application.rb`,
`dial.rb`, `main_window.rb`, `shortcuts_dialog.rb`, `style.rb` on the other)
have not changed in this round's commits, so re-running the scan on them
and getting the same numbers is the expected and correct result, not a
skipped step.

The repeater, shared-factory, Builder-snippet, CSS-constant, dead-code, and
menu-model findings documented in round six's `.reports/component-identification.md`
were each re-checked by opening the cited file and line this round rather
than re-asserted; all held (`lib/shortcuts_dialog.rb#sections` still builds 2
sections/7 items from one literal table; `app.shortcuts` is still never
installed in `application.go` upstream, confirmed by re-grepping
`origin/main`; `lib/main_window.rb`'s `timer_row` is still built from a
`Gtk::Builder` snippet, not a `Gtk::ListBoxRow.new` call the scan could see).

---

## Files that belong to no unit — updated for this round's two new additions

| Upstream | Port | Verdict |
|---|---|---|
| `com.pojtinger.felicitas.Sessions.json` | `com.pojtinger.felicitas.Sessions.json` (262 lines, added `ca7988e`) | **present, unbuilt** — see `component-parity.md` |
| `.github/workflows/flatpak.yaml` | `.github/workflows/flatpak.yaml` (75 lines, added `ca7988e`) | **present, unrun** |
| `sessions.doap` | — | still a **gap** |
| `assets/meta/screenshot-{initial,running}.png` | — | still a **gap**; metainfo still cites upstream's `raw.githubusercontent.com` URLs |
| `README.md` tutorial section | `README.md` (gem boilerplate) | still a **gap** |

All other rows (LICENSE, icons, oga, desktop.in, metainfo.xml.in,
gschema.xml, all 26 `.po`) were re-confirmed this round with fresh `cmp`
against the `origin/main` worktree; all still identical.

## Rules observed

Same as round six's rules — every widget type carries its CSS classes and
signals, no scan row struck without opening the file, dynamic CSS classes
and the two dynamic action-button states listed with every value.
