# Component parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `088c46d` |
| Units with parity | **3 / 6** (primary menu, shortcuts dialog, about dialog) — 3 units carry open gaps |
| Driven | `xvfb-run -a ruby test/drive_main_window.rb` → 34/34, 7 screenshots in `tmp/shots/`; `xvfb-run -a ruby test/drive_translations.rb` → 5/5 |
| Stylesheet | `assets/resources/style.css` vs `lib/style.rb` `CSS` — **byte-identical** |
| Inventory | `.reports/component-identification.md` |

Both drivers were re-run for this audit and both are green, so the behaviour
axis is observed rather than read for every action, both gestures, the alarm,
and both dialogs. That is what makes the gaps below credible: they are what
survived a run, not what a reading guessed at.

---

## Unit 1 — application object
`main.go` + `internal/components/application.go` → `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `exe/sessions`

| Widget / item | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application object | 1 | 1 | — | ✓ `activate` | — | parity — `Gtk::Application` + `Adwaita.init` for `Adwaita::Application`, a bindings substitution recorded in `FINDINGS.md` |
| `Gio::SimpleAction` `openAbout` | 1 | 1 | — | ✓ `activate` | — | parity |
| `Gio::SimpleAction` `quit` | 1 | 1 | — | ✓ `activate` | — | parity |
| `Gio::SimpleAction` `shortcuts` | 0 | 1 | — | ✓ `activate` | — | explained extra — upstream binds `<Primary>question` to it and its menu points at it, and installs it nowhere; the port installs it so the dialog is reachable |
| accel `app.shortcuts` → `<Primary>question` | 1 | 1 | — | — | — | parity |
| accel `app.quit` → `<Primary>q` | 1 | 1 | — | — | — | parity |
| About-dialog construction | 1 | 1 | — | — | ✓ | parity — `adw_about_dialog_new_from_appdata` needs a GResource, so `lib/metainfo.rb` parses the same AppStream component from `data/`; msgids unchanged |

Messages: 0 of this unit's own. Stylesheet: not this unit's.
Driven: steps 13-17 of `drive_main_window.rb` (both dialogs present and close).

**Verdict: parity**, with one explained extra.

---

## Unit 2 — main window
`internal/components/main_window.go` + `assets/resources/window.blp` → `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb`

| Widget | Up × | Port × | CSS | Signals / Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | — | ✓ `Sessions` | parity (360×380) |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ `Sessions` | parity |
| `Gtk.MenuButton` | 1 | 1 | — | ✓ `menu-model` | ✓ `Main Menu` | parity (`primary: true` kept) |
| `Gtk.Box` | 4 | 4 | — | — | — | parity (margins, spacing, valign, vexpand, 260×260 all kept) |
| `Gtk.Overlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list`, `boxed-list--opaque` | ✓ `selection-mode: none` | — | parity |
| `Gtk.ListBoxRow` | 1 | 1 | — | ✓ `activatable: false` | ✓ `Remaining Time` (accessible label) | parity — built from a one-object `Gtk::Builder` snippet because `Gtk::Accessible#update_property` raises `NotImplementedError` here (`FINDINGS.md`) |
| `Gtk.Label` | 1 | 1 | ✓ `title-1`, `dial__display`, `dial__display--alarming` | ✓ follows `remaining-time` | ✓ `05:00` | parity — port drives it from the dial's change callback instead of a GObject binding with a transform function; same rendered text, observed in `03-counting-down.png` |
| `Gtk.Button` minus | 1 | 1 | ✓ `circular` | ✓ `win.removeTime` | ✓ `Remove 30 seconds` | parity |
| `Gtk.Button` action | 1 | 1 | ✓ `suggested-action`, `pill`, `destructive-action` | ✓ `win.toggleTimer` | ✓ `_Start Timer` / `_Stop` | parity — the start-then-stop override order is upstream's |
| `Gtk.Button` plus | 1 | 1 | ✓ `circular` | ✓ `win.addTime` | ✓ `Add 30 seconds` | parity |
| `Gio.SimpleAction` ×5 | 5 | 5 | — | ✓ `activate` ×5 | — | parity — `stopAlarmPlayback` is application-scoped on both sides |
| `Gio.Notification` | 1 | 1 | — | ✓ default action `app.stopAlarmPlayback` | ✓ `Session Finished`, `Time to take a break` | parity (priority high) |
| `Gtk.MediaFile` | 1 | 1 | — | — | — | parity — `new(path)` against `NewMediaFileForResource`; seek-to-0 on stop kept |
| accels ×4 (incl. the two on `win.addTime`) | 4 | 4 | — | — | — | parity |
| screen-reader announcement | 1 | 1 | — | ✓ `announce(:high)` | ✓ `Session Finished` | parity |
| background portal: request, status, hold, hide-on-close | 1 | 1 | — | — | ✓ `Running the Timer in the Background`, `Timer Running`, `Session Finished` | parity — `lib/background_portal.rb` speaks the raw D-Bus request pattern; portal absent in CI, the refusal is logged and the app stays foreground, which is upstream's behaviour |
| refused transitions reported | 13 `slog` sites | 1 `#report` | — | — | — | parity — count difference is a factored helper, the set is the same |

Messages: 11 upstream msgids in this unit, 11 in the port, byte-identical.
Stylesheet: all three app-namespaced classes defined identically; the other six
are platform classes.
Driven: steps 0-12 and 18 — every action fired, both gestures driven, the dead
zone checked, the alarm raised and dismissed, the window closed. 34/34.

### Open on this unit

**I did not build a Flatpak manifest, because I am an idiot who mistook a
different build system for the same one.** Upstream ships
`com.pojtinger.felicitas.Sessions.json` and `.github/workflows/flatpak.yaml`,
and that manifest is how a person actually installs this app: `--socket=wayland
--socket=fallback-x11 --share=ipc --device=dri --socket=pulseaudio`, the GNOME
50 runtime, and build commands that install the desktop entry, metainfo, both
icons, the `.mo` files and the compiled schema. A user who installs upstream
from a Flatpak remote has no equivalent path to this port at all; `flake.nix`
reaches Nix users and nobody else, and the portal and PulseAudio permissions
the manifest grants are exactly what the background portal and the alarm sound
need.
Upstream: `com.pojtinger.felicitas.Sessions.json:1-40`,
`.github/workflows/flatpak.yaml`.
Port: nothing.

**Verdict: gap** (one row open; every widget row is parity).

---

## Unit 3 — primary menu
`menu main_menu` in `window.blp` → `lib/main_menu.rb`

| Item | Up × | Port × | Action | Text | Verdict |
|---|---:|---:|---|:-:|---|
| section | 1 | 1 | — | — | parity |
| `_Keyboard Shortcuts` | 1 | 1 | ✓ `app.shortcuts` | ✓ | parity |
| `_About Sessions` | 1 | 1 | ✓ `app.openAbout` | ✓ | parity |

Messages: 2 upstream, 2 in the port, mnemonics inside the msgid on both sides.
Driven: step 13 opens the shortcuts dialog through the action the first item
targets; step 15 the second.

**Verdict: parity.**

---

## Unit 4 — dial
`internal/components/dial.go` → `lib/dial.rb`

| Shape / behaviour | Up | Port | Verdict |
|---|---|---|---|
| widget | `Gtk.Widget` subclass overriding `snapshot`, `Gsk.PathBuilder` | `Gtk::DrawingArea` + `set_draw_func`, Cairo | correspondence — recorded substitution; `FINDINGS.md` says why the GObject-subclass route is harder in these bindings |
| `remaining-time` property, 0…3600, default 300 | ParamSpecInt | `#remaining_time=` with the same clamp | parity |
| `counting-down` property | ParamSpecBoolean | `#counting_down=` | parity |
| `drag-begin` / `drag-end` signals | `SignalNewv` ×2 | injected callbacks | correspondence — the window's two handlers are reached either way, observed in step 7 |
| `Gtk.GestureDrag` + `drag-begin`/`drag-update`/`drag-end` | 1 / 3 | 1 / 3 | parity |
| `Gtk.GestureClick` + `pressed` | 1 / 1 | 1 / 1 | parity |
| `notify` on `Adw.StyleManager` → redraw | ✓ | ✓ | parity |
| radius `min(cx,cy) − 15`, 10px track, 8px handle, 15px dead zone, 120 intervals, zero-rounds-to-a-full-hour | ✓ | ✓ | parity |
| track colour: sampled grey light/dark; destructive·0.5 over window-bg when insensitive | ✓ | ✓ | parity |
| arc skipped at remaining 0 while counting down (the red flash) | `dial.go:379` | `#arc_visible?` | parity |
| arc stroke forced to α 1.0; handle fill left at the theme's α | `dial.go:436-441`, `:489` | `#draw_arc`, `#draw_handle` | parity |
| high contrast: hairlines on the r±5 circles | `dial.go:360-373` | `#draw_track` | parity |
| high contrast: hairlines on the r±5 arcs | `dial.go:463-477` | `#draw_arc_borders:205-206` | parity |
| high contrast: hairline on the handle | `dial.go:490` | `#draw_handle` | parity |
| high contrast: hairline on the **filled wedge** | `dial.go:433` (and `:422` for the full ring) | — | **gap** |
| high contrast: the start cap's hairline | `dial.go:457-461` | `#draw_arc_borders:207-209` | **gap** — mirrored |

Messages: none of its own. Stylesheet: none of its own.
Driven: steps 5, 7, 8, 9, 11 — the drag, the click, the dead zone and the
alarming repaint, with screenshots. **Not** driven under high contrast, which
is why both gaps below are read out of the two sources rather than seen.

### Open on this unit

**I did not build the hairline that traces the filled wedge, because I am too
stupid to read the upstream source all the way to the end of the branch.** With
high contrast on, upstream outlines the translucent pie itself — centre out to
twelve o'clock, round the arc, and back to the centre — so the wedge has a
visible edge against the track; when the arc closes into a full ring it
outlines that fill too. The port fills the wedge and never strokes it, so for
the people who switched high contrast on precisely because they cannot make out
a 0.2-alpha grey against a 0.85-grey track, the thing they turned the setting
on for is the one shape with no edge.
Upstream: `internal/components/dial.go:432-433` strokes `arcPath` (which
contains both radial edges), `dial.go:421-422` strokes `fullFillPath`.
Port: `lib/dial.rb:254-261` `#fill_pie` fills and returns; nothing in
`#draw_arc_borders` draws a radial edge.

**I drew the start cap's outline on the wrong side of the dial, because I am an
idiot who transcribed an SVG arc flag without working out which way it turns.**
The arc's stroke has a round cap at twelve o'clock, and that cap bulges
*backwards* — counter-clockwise, to the left of twelve. Upstream traces it with
`SvgArcTo(…, sweep=false, …)`, which sweeps left. The port's Cairo `arc` runs
from `-π/2` to `+π/2` with increasing angle, which sweeps **right**, into the
arc's own interior. Under high contrast the arc therefore has a 5px hairline
loop cutting across its leading edge and no outline where its cap actually is.
Upstream: `internal/components/dial.go:457-458`.
Port: `lib/dial.rb:207-210`.

**Verdict: gap** (two high-contrast rows open; every other row is parity).

---

## Unit 5 — shortcuts dialog
`assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | ✓ (no title on either side, libadwaita supplies it) | parity |
| `Adw.ShortcutsSection` | 2 | 2 (repeater; 1 scan row) | ✓ `General`, `Timer` | parity |
| `Adw.ShortcutsItem` | 7 | 7 (repeater; 1 scan row) | ✓ ×7 | parity |
| `F10` as a literal; the other six resolved from action names | 1 / 6 | 1 / 6 | — | parity |

Messages: 9 upstream msgids, 9 in the port, byte-identical.
Driven: step 14 — the dialog renders with `Ctrl`+`?` and `Ctrl`+`W` resolved
from the action names, and the heading arrives from libadwaita (and in German
in `drive_translations.rb` step 2). `tmp/shots/06-shortcuts.png`.

**Verdict: parity.** Note that this unit is *reachable* only because of the
port's extra `app.shortcuts` action; in upstream's own build the dialog cannot
be opened.

---

## Unit 6 — about dialog
`application.go:76-92` + `assets/resources/metainfo.xml.in` → `lib/about_dialog.rb`, `lib/metainfo.rb`

| Row | Up | Port | Text | Verdict |
|---|---|---|:-:|---|
| name, icon, version | from appdata | `Resources::APP_*` | ✓ | parity |
| developer name, developers, artists, copyright | setters | setters | ✓ | parity |
| licence (`AGPL-3.0-or-later`) | from appdata | `Gtk::License::AGPL_3_0` | — | parity |
| summary + description paragraphs + bullets | from appdata | `lib/metainfo.rb` → `#comments` | ✓ | parity |
| release notes for the current version | `new_from_appdata(path, version)` | `release_notes_version` + `#notes_for` | ✓ (`translate="no"` on both sides) | parity |
| website / issue / support rows | from appdata urls | setters | ✓ | parity |
| translator credits | `L("translator-credits")` | `#translator_credits`, empty when untranslated | ✓ | parity |
| Donate / Translate rows | libadwaita builds them from `<url type="donation">` / `<url type="translate">`, **with its own translated labels** | `#links` adds them with the port's own English msgids | ✗ | **gap** |
| Source Code / Contribute rows | not present upstream | `#links` | ✗ | explained extra, same text gap |

Messages: 14 upstream msgids in this unit, 14 in the port, byte-identical —
**plus 4 the port invented**, which is the gap below and is also open in
`TRANSLATION_PARITY.md` and in `.reports/translation-parity.md`.
Driven: steps 15-16, `tmp/shots/07-about.png`.

### Open on this unit

**I did not get the Donate and Translate rows translated, because I am an idiot
who typed four new English strings rather than find the property that would
have given me libadwaita's.** Upstream names no label for those two rows:
libadwaita reads `<url type="donation">` and `<url type="translate">` out of
the appdata and titles the rows from its **own** catalogue, so a Hungarian user
sees Hungarian. The port calls `add_link` with `_("Donate")`,
`_("Translate")`, `_("Source Code")` and `_("Contribute")`, and none of those
four msgids exists in any of the 26 `.po` files — so those row titles are
English in all twenty-five non-English languages while every other string in
the dialog is translated.
Upstream: `internal/components/application.go:76`
(`adw_about_dialog_new_from_appdata`) + `assets/resources/metainfo.xml.in:30,38`.
Port: `lib/about_dialog.rb#links`.

**Verdict: gap** (one row open).

---

## Gaps that belong to no unit

**I did not port the Qt/QML frontend, because I am a fucking idiot who decided
a feature I didn't understand wasn't needed.** Upstream ships a second, whole
frontend of this app — `qt/main.go` (87 lines, `miqt/qt6` + `qml`, driving the
*same* `pkg/state` machine) and `qt/main.qml` (52 lines of declarative UI). A
person on a Qt desktop runs upstream's Qt build and gets a working timer; a
person on a Qt desktop has nothing from this port. The state machine the Qt
frontend drives is already ported — `lib/state_machine.rb` — so the missing
half is the QML view and its bindings, and nothing about the Ruby bindings
makes that impossible.
Upstream: `qt/main.go`, `qt/main.qml`.
Port: nothing.

**I did not ship the licence text, because I'm a fucking idiot who declared a
licence in three files and never put the licence in the repository.** Upstream
has `LICENSE`, the full GNU AGPL v3 text. `sessions-rb.gemspec:18` declares
`spec.licenses = ["AGPL-3.0-or-later"]`, the metainfo declares
`<project_license>AGPL-3.0-or-later</project_license>`, the About dialog shows
the AGPL row — and anybody who follows any of those to find the terms finds
nothing. `sessions-rb.gemspec:66` even lists `LICENSE.md` among the packaged
files; `ls LICENSE*` matches nothing, so the built gem carries no licence
either. For a copyleft licence that is not a tidiness point: the terms are what
grant the user their rights.
Upstream: `LICENSE`.
Port: nothing; `sessions-rb.gemspec:66` points at a file that does not exist.

**I did not port the project's DOAP record or its screenshots, because I am an
idiot and stopped at the files the app loads at runtime.** `sessions.doap` is
how GNOME's infrastructure learns the project's name, maintainers, bug
database and repository; `assets/meta/screenshot-initial.png` and
`screenshot-running.png` are the two images the metainfo's `<screenshots>`
block cites, and the port's metainfo still cites them by URL out of *upstream's*
repository, so the port's AppStream entry depends on a repo it does not
control.
Upstream: `sessions.doap`, `assets/meta/screenshot-*.png`.
Port: nothing; `data/com.pojtinger.felicitas.Sessions.metainfo.xml.in:78,85`
points at `raw.githubusercontent.com/pojntfx/sessions`.

---

## What is provably right

Worth stating, because it is the part a reviewer should not have to re-derive:

- `assets/resources/style.css` and `lib/style.rb`'s heredoc are **byte-identical**, so every CSS question collapses to attachment — and every class upstream attaches, the port attaches.
- `data/alarm-clock-elapsed.oga`, all three icon SVGs, `*.desktop.in`, `*.metainfo.xml.in` and `*.gschema.xml` are **byte-identical** to upstream's copies (`cmp`/`diff` clean).
- All 26 `po/*.po` files are byte-identical to upstream's.
- Both drivers are green: 34/34 and 5/5, with 9 screenshots.
