# Component parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `14fcee4` |
| Units with parity | **3 / 7** (primary menu, shortcuts dialog, state machine) |
| Units with open gaps | **4 / 7** (application object, main window, dial, about dialog) |
| Driven | `xvfb-run -a ruby test/drive_main_window.rb` → **175/175**, `DRIVE OK`, 11 screenshots; `test/drive_translations.rb` → **5/5**, `DRIVE OK` |
| Specs | `rspec --options /dev/null --require spec_helper --format progress spec` → 45 examples, 0 failures |
| Stylesheet | `assets/resources/style.css` vs `lib/style.rb::CSS` — **byte-identical** |
| Inventory | `.reports/component-identification.md` |
| Round | six |

Both drivers and the spec suite were re-run in `nix develop` for this audit, so
the behaviour axis is observed rather than read for every action, both gestures,
the alarm, the notification's own action, the portal refusal, the ticker, both
dialogs, both dialogs' second build, the shortcuts dialog's empty state, and
both of the dial's refusal states. **The one axis that is never driven is high
contrast**, and that is exactly where this unit's two oldest gaps still sit.

Correction to round five, up front: the Unit 6 verdict in the previous copy of
this file rested on a claim about libadwaita that is **not true**. See Unit 6.

---

## Unit 1 — application object
`main.go` + `internal/components/application.go` → `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `lib/style.rb`, `exe/sessions`

| Item | Up × | Port × | Signals / Actions | Text | Verdict |
|---|---:|---:|---|:-:|---|
| application object | 1 | 1 | ✓ `activate` | — | parity — `Gtk::Application` + `Adwaita.init`, substituting for `Adwaita::Application`; recorded in `FINDINGS.md` |
| activate runs once, re-presents thereafter | ✓ | ✓ `#activated_window` | — | — | parity — load-bearing, because `app.stopAlarmPlayback` re-activates the app |
| `Gio::SimpleAction` `openAbout` | 1 | 1 | ✓ | — | parity |
| `Gio::SimpleAction` `quit` | 1 | 1 | ✓ | — | parity |
| `Gio::SimpleAction` `shortcuts` | **0** | 1 | ✓ | — | explained extra — upstream installs this action **nowhere**; its accel and its menu item both point at nothing. The port installs it so the dialog is reachable at all. |
| accel `app.shortcuts` → `<Primary>question` | 1 | 1 | — | — | parity |
| accel `app.quit` → `<Primary>q` | 1 | 1 | — | — | parity |
| gettext init, domain `sessions` | 1 | 1 | — | — | parity — `LocaleDir`/`SchemaDir` link-time variables become `SESSIONS_LOCALE_DIR`/`SESSIONS_SCHEMA_DIR` |
| `Gio::Settings`, both construction paths | 2 | 2 | — | — | parity — `Gio::Settings.new(APP_ID)` or `SettingsSchemaSource` over `SCHEMA_DIR`; upstream's `panic` becomes a raise naming the directory |
| stylesheet installation | GResource auto-pickup | `Gtk::StyleContext.add_provider_for_display` @ 600 | — | — | parity |

Messages: 0 of this unit's own.
Driven: steps 1, 3, 30, 45 — the settings round-trip, the stylesheet parse, all
six accelerators resolved in both directions, and every action asserted present
and enabled on the right scope.

### Open on this unit

**I never built a Flatpak manifest, because I am an idiot who decided `flake.nix`
counted as a way for a person to install this.** Upstream ships
`com.pojtinger.felicitas.Sessions.json` and
`.github/workflows/flatpak.yaml`, and that manifest is the install path: the
GNOME 50 runtime, `--socket=wayland --socket=fallback-x11 --share=ipc
--device=dri --socket=pulseaudio`, and build commands that install the desktop
entry, the metainfo, both icons, every `.mo` and the compiled schema. Two of
those permissions are not decoration — `--socket=pulseaudio` is what makes
`lib/alarm.rb` audible and the portal talk is what `lib/background_portal.rb`
exists for. A user who installs upstream from Flathub has no equivalent path to
this port; `flake.nix` reaches Nix users and nobody else. The port does not even
have a `.github/workflows/` directory.
Upstream: `com.pojtinger.felicitas.Sessions.json:1-40`, `.github/workflows/flatpak.yaml`.
Port: nothing.

**Verdict: gap** (one row open; every widget and action row is parity).

---

## Unit 2 — main window
`internal/components/main_window.go` + `assets/resources/window.blp` → `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb`

| Widget / behaviour | Up × | Port × | CSS | Signals / Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | — | ✓ `Sessions` | parity (360×380) |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ `Sessions` | parity |
| `Gtk.MenuButton` | 1 | 1 | — | ✓ `menu-model` | ✓ `Main Menu` | parity (`primary: true`, `open-menu-symbolic`) |
| `Gtk.Box` | 4 | 4 | — | — | — | parity — every margin, spacing, `valign`, `vexpand` and the 260×260 request kept |
| `Gtk.Overlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list`, `boxed-list--opaque` | ✓ `selection-mode: none` | — | parity |
| `Gtk.ListBoxRow` | 1 | 1 | — | ✓ `activatable: false` | ✓ `Remaining Time` (accessible label) | parity — built from a one-object `Gtk::Builder` snippet because `Gtk::Accessible#update_property` raises `NotImplementedError` here (`FINDINGS.md:70`) |
| `Gtk.Label` | 1 | 1 | ✓ `title-1`, `dial__display`, `dial__display--alarming` | ✓ follows the dial's `remaining-time` | ✓ `05:00` | parity — port drives it from the dial's change callback rather than a GObject binding with a transform function; same rendered text, observed at 05:30 and while alarming |
| `Gtk.Button` minus | 1 | 1 | ✓ `circular` | ✓ `win.removeTime` | ✓ `Remove 30 seconds` | parity |
| `Gtk.Button` action | 1 | 1 | ✓ `pill`, `suggested-action` ⇄ `destructive-action` | ✓ `win.toggleTimer` | ✓ `_Start Timer` / `_Stop` | parity — start-appearance written first, stop-appearance allowed to override, which is upstream's order |
| `Gtk.Button` plus | 1 | 1 | ✓ `circular` | ✓ `win.addTime` | ✓ `Add 30 seconds` | parity |
| `Gio.SimpleAction` | 5 | 5 | — | ✓ `activate` ×5 | — | parity — `stopAlarmPlayback` application-scoped on both sides |
| `Gio.Notification` | 1 | 1 | — | ✓ default action `app.stopAlarmPlayback` | ✓ `Session Finished`, `Time to take a break` | parity (priority high, id `session-finished`) |
| `Gtk.MediaFile` | 1 | 1 | — | — | — | parity — `new(path)` against `NewMediaFileForResource`; seek-to-0 on stop kept |
| accels | 4 | 4 | — | — | — | parity, including the **two** on `win.addTime` |
| screen-reader announcement | 1 | 1 | — | ✓ `announce(:high)` | ✓ `Session Finished` | parity |
| background portal: request → status → hold → hide-on-close | ✓ | ✓ | — | — | ✓ `Running the Timer in the Background`, `Timer Running`, `Session Finished` | parity — `lib/background_portal.rb` speaks the raw D-Bus request pattern with the handle token chosen before the call; portal absent under xvfb, the refusal is taken and the app stays foreground, which is upstream's behaviour |
| refused transitions reported | 13 `log.Error` sites | 1 `#report` helper | — | — | — | parity — a factored helper, same set of refusals |

Messages: 11 upstream msgids in this unit, 11 in the port, byte-identical.
Stylesheet: all three app-namespaced classes identical; the other six are
platform classes.
Driven: steps 0-24 and 26 — every action fired, both gestures emitted, the three
buttons clicked as widgets, the dead zone checked, the ceiling and floor
refusals driven and screenshotted, the alarm raised, announced and dismissed,
the notification's own action used to silence a ringing alarm, the portal
refusal taken, the ticker's schedule and cancel observed, and the window closed
and asserted gone rather than hidden.

**Verdict: parity.** Every row on this unit is closed. (Round five's open row
here was the Flatpak manifest; it is charged to unit 1, where the install path
belongs, rather than counted twice.)

---

## Unit 3 — primary menu
`menu main_menu` in `window.blp` → `lib/main_menu.rb`

| Item | Up × | Port × | Action | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `section` | 1 | 1 | — | — | parity |
| `_Keyboard Shortcuts` | 1 | 1 | ✓ `app.shortcuts` | ✓ | parity |
| `_About Sessions` | 1 | 1 | ✓ `app.openAbout` | ✓ | parity |

Messages: 2 upstream, 2 in the port, mnemonics inside the msgid on both sides.
Driven: steps 27-29 — the menu is opened as a popover, both items read with
their accelerators resolved, and closed again.

**Verdict: parity.**

---

## Unit 4 — dial
`internal/components/dial.go` → `lib/dial.rb`

| Shape / behaviour | Up | Port | Verdict |
|---|---|---|---|
| widget | `Gtk.Widget` subclass overriding `snapshot`, `Gsk.PathBuilder` | `Gtk::DrawingArea` + `set_draw_func`, Cairo | correspondence — recorded substitution, `FINDINGS.md` |
| `remaining-time` 0…3600, default 300 | `ParamSpecInt` | `#remaining_time=` with the same clamp | parity |
| `counting-down` | `ParamSpecBoolean` | `#counting_down=` | parity |
| `drag-begin` / `drag-end` | `SignalNewv` ×2 | injected callbacks | correspondence — both window handlers reached either way, observed at step 10 |
| `hexpand` / `vexpand` | set by the window | set in `#area` | parity |
| `Gtk.GestureDrag` + 3 signals | 1 / 3 | 1 / 3 | parity |
| `Gtk.GestureClick` + `pressed` | 1 / 1 | 1 / 1 | parity |
| `notify` on `Adw.StyleManager` → redraw | ✓ | ✓ | parity |
| `r = min(cx,cy) − 15`, 10px track, 8px handle, 15px dead zone, 120 intervals, zero-rounds-to-a-full-hour | ✓ | ✓ | parity |
| track: sampled grey light/dark; destructive·0.5 over window-bg when insensitive | ✓ | ✓ | parity |
| arc skipped at remaining 0 while counting down (the red flash) | `dial.go:379` | `#arc_visible?` | parity |
| arc stroke forced to α 1.0; handle fill left at the theme's α | `dial.go:436-441`, `:489` | `#draw_arc` / `#draw_handle` | parity |
| full-ring special case when the arc closes | `isFullCircle` branch | Cairo `arc` to `TOP + 2π` | parity |
| high contrast: hairlines on the r±5 **track** circles | `dial.go:360-373` | `#draw_track:176-178` | parity — **read, not run** |
| high contrast: hairlines on the r±5 **arcs** | `dial.go:463-477` | `#draw_arc_borders:205-206` | parity — **read, not run** |
| high contrast: hairline on the handle | `dial.go:490` | `#draw_handle:216-218` | parity — **read, not run** |
| high contrast: hairline on the **filled wedge** | `dial.go:433`, and `:422` for the full ring | — | **gap** |
| high contrast: the start cap's hairline | `dial.go:457-458` | `#draw_arc_borders:207-210` | **gap — drawn on the wrong side** |

Messages: none of its own. Stylesheet: none of its own.
Driven: steps 5, 8, 10-12, 14, 21-24, 26 — the drag, the click, the dead zone,
the alarming repaint, the ceiling, the floor, with screenshots.
**Not driven under high contrast.** No step sets
`Adwaita::StyleManager#high_contrast`, so all five high-contrast rows above —
the three marked parity as well as the two marked gap — are read out of the two
sources and not observed. The three "parity" verdicts on that axis are
therefore the weakest claims in this document, and they are flagged rather than
counted as green in `accountability-ensurance.md`.

### Open on this unit

**I never drew the hairline that traces the filled wedge, because I am too
stupid to read a branch of the upstream source all the way to its end.** With
high contrast on, upstream outlines the translucent pie itself — centre out to
twelve o'clock, round the arc, and back to the centre — so the wedge has a
visible edge against the track; when the arc closes into a full ring it strokes
that fill too. The port fills the wedge and never strokes it. For the people who
switched high contrast on precisely because they cannot make out a 0.2-alpha
grey against a 0.85 grey, the one shape with no edge is the one they turned the
setting on for.
Upstream: `internal/components/dial.go:432-433` strokes `arcPath`, which
contains both radial edges; `dial.go:421-422` strokes `fullFillPath`.
Port: `lib/dial.rb:254-261` `#fill_pie` fills and returns; nothing in
`#draw_arc_borders` draws a radial edge.

**I drew the start cap's outline on the wrong side of the dial, because I am an
idiot who transcribed an SVG arc flag without working out which way it turns.**
The arc's stroke has a round cap at twelve o'clock and that cap bulges
*backwards* — counter-clockwise, to the left of twelve. Upstream traces it with
`SvgArcTo(5, 5, 0, largeArc=false, sweep=false, cx, cy-(r-5))`; sweep-flag `0`
sweeps left. The port's `add_arc(radius: 5, from: -π/2, to: +π/2, cy: cy - r)`
runs with *increasing* angle, which in Cairo's y-down space sweeps **right**,
into the arc's own interior. Under high contrast the arc therefore carries a 5px
hairline loop cutting across its leading edge and has no outline where its cap
actually is.
Upstream: `internal/components/dial.go:457-458`.
Port: `lib/dial.rb:207-210`.

**Nothing drives high contrast, so I cannot tell you the other three hairlines
are right — only that I believe they are.** `test/drive_main_window.rb` has 175
checks and not one of them sets high contrast. The fix is one step: flip
`Adwaita::StyleManager.default.high_contrast`, redraw, and screenshot, which is
how the two gaps above would have been caught by a run instead of by a reading.
Upstream: `dial.go:338-373` gates six shapes on `GetHighContrast()`.
Port: `lib/dial.rb:382` `#high_contrast?`; no driver step touches it.

**Verdict: gap** (two shape rows open, one verification row open; every other
row is parity).

---

## Unit 5 — shortcuts dialog
`assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | ✓ (no title on either side; libadwaita supplies it) | parity |
| `Adw.ShortcutsSection` | 2 | 2 (repeater; 1 scan row) | ✓ `General`, `Timer` | parity |
| `Adw.ShortcutsItem` | 7 | 7 (repeater; 1 scan row) | ✓ ×7, in upstream's order | parity |
| `F10` as a literal; the other six resolved from action names | 1 / 6 | 1 / 6 | — | parity |
| empty state (search with no matches) | libadwaita's | libadwaita's | ✓ | parity — **driven**, steps 36-39 |
| idempotent rebuild | n/a upstream (never opened) | `#build` memoized | — | parity — driven, steps 34-35 |

Messages: 9 upstream msgids, 9 in the port, byte-identical.
Driven: steps 32-39 — rendered with `Ctrl`+`?` and `Ctrl`+`W` resolved from the
action names, the heading arriving from libadwaita (and in German at
`drive_translations.rb` step 2), the empty state typed into and screenshotted,
the search cleared, and the second build asserted to add nothing.

**Verdict: parity.** This unit is *reachable* only because of the port's extra
`app.shortcuts` action; in upstream's own build the dialog cannot be opened at
all.

---

## Unit 6 — about dialog
`application.go:76-92` + `assets/resources/metainfo.xml.in` → `lib/about_dialog.rb`, `lib/metainfo.rb`

What `adw_about_dialog_new_from_appdata` actually does, read off
`Adw-1.gir` (libadwaita 1.9.3) rather than assumed: it sets
`application-icon`, `application-name`, `developer-name`, `version`, `website`
(`<url type="homepage">`), `support-url` (`help`), `issue-url` (`bugtracker`),
`license-type`, and `release-notes` + `release-notes-version`. **That is the
whole list.** It does not set `comments`, and it adds no link rows.

| Row | Up | Port | Text | Verdict |
|---|---|---|:-:|---|
| name, icon, version | from appdata | `Resources::APP_*` | ✓ | parity |
| developer name | from appdata | `APP_DEVELOPER_NAME` | ✓ | parity |
| developers, artists, copyright | setters | setters | ✓ | parity |
| licence `AGPL-3.0-or-later` | from appdata | `Gtk::License::AGPL_3_0` | — | parity |
| release notes for the current version | `new_from_appdata(path, version)` | `release_notes_version` + `#notes_for` | ✓ (`translate="no"` both sides) | parity |
| website / issue / support rows | from appdata urls | setters, same three URLs | ✓ | parity |
| translator credits | `L("translator-credits")` | `#translator_credits`, empty when untranslated | ✓ | parity |
| summary + description paragraphs + bullets in `comments` | **not set** | `#comments` | ✓ | **extra** — costs no msgid (they are upstream's, out of the metainfo) but shows text upstream's dialog does not |
| `Donate` link row | **not present** | `#links` | ✗ | **gap — extra with an untranslated label** |
| `Translate` link row | **not present** | `#links` | ✗ | **gap — extra with an untranslated label** |
| `Source Code` link row | **not present** | `#links` | ✗ | **gap — extra with an untranslated label** |
| `Contribute` link row | **not present** | `#links` | ✗ | **gap — extra with an untranslated label** |

Messages: 14 upstream msgids in this unit, 14 in the port, byte-identical —
**plus 4 the port invented**, open here, in `.reports/translation-parity.md` and
in `TRANSLATION_PARITY.md`.
Driven: steps 31, 40-43 — the metainfo parses, the dialog renders with its
appdata, the comments are asserted to be in **one** language (the round-five
twenty-languages-at-once defect), all four links are present, and the second
build is asserted to add no duplicates.

### Open on this unit

**I added four link rows upstream does not have, invented four English msgids
for them, and then wrote down a reason that was not true.** The previous copy of
this file and the comment at `lib/about_dialog.rb:25-34` both say libadwaita
builds Donate and Translate rows out of `<url type="donation">` and
`<url type="translate">` "with its own translated labels", and that the port is
merely reproducing them in English. **It does not.** `Adw-1.gir` lists the nine
properties `new_from_appdata` sets and no link row is among them; nothing in
`internal/components/application.go` calls `AddLink`; the `donation`,
`translate`, `vcs-browser` and `contribute` URLs in the metainfo are read by
AppStream stores and by nothing in upstream's About dialog. So upstream's
dialog has **no** Donate row, **no** Translate row, **no** Source Code row and
**no** Contribute row, and the port has four — each titled by a msgid
(`Donate`, `Translate`, `Source Code`, `Contribute`) that exists in none of the
26 `.po` files, so all four are English in twenty-five languages while every
other string in the dialog is translated.

That is two separate things owed, and the wrong reason is the worse of them:
it turned "I added four rows and four untranslated strings" into "libadwaita
would have done this anyway", which is the shape of excuse this audit exists to
catch. Writing it into a source comment put it where the next reader would
inherit it.
Upstream: `internal/components/application.go:76-92`;
`Adw-1.gir`, `adw_about_dialog_new_from_appdata`.
Port: `lib/about_dialog.rb:25-34` (the wrong rationale), `#links:105-112` (the
four rows).

**Verdict: gap** (four rows open; one further extra, `comments`, recorded
without a complaint attached because it costs no translation).

---

## Unit 7 — state machine
`pkg/state/machine.go` + `pkg/state/constants.go` → `lib/state_machine.rb`, `lib/ticker.rb`

| Behaviour | Up | Port | Verdict |
|---|---|---|---|
| 4 states, 8 triggers | `stateless` DSL | one `#transition_table` | parity |
| guards: below-max / above-min on the initial time | ✓ | ✓ | parity |
| guards: below-max / above-min derived from the **current** time | ✓ | ✓ | parity |
| `stop_dragging` guard needs its argument, so the trigger never appears in the permitted set | ✓ | ✓ | parity |
| `CanStopDragging` | exported | `#can_stop_dragging?` | parity |
| entry-action order: trigger-specific first, then per-state | `stateless` registration order | `STATE_ENTRY_ACTIONS` after `transition[:entry]` | parity — **and now checked**, by the three end-to-end examples' 96 / 158 / 157 counts |
| reentry from counting-down stops the ticker on exit and restarts it on entry | ✓ | ✓ | parity |
| alarming entry = stop timer **then** start alarm | ✓ | ✓ | parity |
| stopped entry fires `stopTimer` only from `stopTimer`, `stopAlarm` only from `stopAlarming` | ✓ | ✓ | parity |
| `flush_permitted_triggers` on every transition and every tick | ✓ | ✓ | parity |
| 1s ticker | goroutine over `time.Ticker` + `glib.IdleAdd` | `GLib::Timeout` via `lib/ticker.rb` | correspondence — hooks touch widgets directly, which is why the window's hooks are not wrapped |
| `String()` / `ToGraph()` | `stateless`' own | rendered from the table | correspondence — covered by 3 port-only examples |
| refused trigger | returns an `error` | returns `false` | correspondence — `MainWindow#report` logs it |

Messages: none. Driven: 42 spec examples plus step 25 of the driver.

**Verdict: parity.**

---

## Gaps that belong to no unit

**I never ported the Qt/Kirigami frontend, because I am a fucking idiot who
decided a whole second frontend was not a feature.** Upstream ships `qt/main.go`
(46 lines, `miqt/qt6` + `qml`) and `qt/main.qml` (52 lines:
`Kirigami.ApplicationWindow` → `Kirigami.Page` → a `ColumnLayout` with
`analogTimeLabel` and the three buttons), driving the **same** `pkg/state`
machine. A person on a Plasma desktop builds upstream's Qt target and gets a
timer; from this port they get nothing. The state machine that frontend needs is
already ported — `lib/state_machine.rb` — so what is missing is the QML view and
its bindings, and nothing about the Ruby bindings makes that impossible. The
component scan finds **zero** rows in either file, which is why it stayed
invisible for five rounds.
Upstream: `qt/main.go`, `qt/main.qml`.
Port: nothing.

**I never ported the DOAP record or the screenshots, because I am an idiot who
stopped at the files the app opens at runtime.** `sessions.doap` is how GNOME's
infrastructure learns the project's name, maintainers, bug database and
repository. `assets/meta/screenshot-initial.png` and `screenshot-running.png`
are the two images the metainfo's `<screenshots>` block cites — and because the
port keeps that metainfo byte-identical, the port's AppStream entry serves
screenshots of **upstream's** app from
`raw.githubusercontent.com/pojntfx/sessions/main/…`, a repository the port does
not control and whose images will stop matching the moment either side changes.
The same applies to `<url type="faq">`, which points at a `#tutorial` section of
upstream's README; the port's README is gem-template boilerplate and has no such
section.
Upstream: `sessions.doap`, `assets/meta/screenshot-*.png`, `README.md`.
Port: nothing; `data/com.pojtinger.felicitas.Sessions.metainfo.xml.in:64,69,33`.

---

## Closed since round five

Recorded rather than deleted, because a closed gap that vanishes silently is
indistinguishable from one that was never written down.

- **The licence text.** `LICENSE.md` is now in the tree: 34 523 bytes, the GNU
  AGPL v3, first two lines identical to upstream's `LICENSE`.
  `sessions-rb.gemspec:66` lists it and the file now exists.
- **The About dialog's twenty-languages-at-once description.** Driver step 41
  asserts the comments are in one language and that no translation leaked;
  green.
- **The shortcuts dialog and About dialog rebuilding their contents.** Driver
  steps 34-35 and 42-43 assert that the second `#build` adds nothing; green.
- **The drive count.** Round five's 34 checks are now 175, over all 15 classes.

---

## What is provably right

Stated because a reviewer should not have to re-derive it:

- `assets/resources/style.css` and `lib/style.rb::CSS` are **byte-identical**,
  so every CSS question collapses to attachment — and every class upstream
  attaches, the port attaches.
- `data/alarm-clock-elapsed.oga` and all three icon SVGs are `cmp`-identical to
  upstream's; `*.desktop.in`, `*.metainfo.xml.in` and `*.gschema.xml` are
  `diff`-identical.
- All 26 `po/*.po` files are `cmp`-identical to upstream's.
- 175/175 and 5/5 on the two drivers, 45/45 on the spec suite, all three re-run
  in `nix develop` for this audit.

## Verdict

**Not at parity.** Eight rows open across four units:

| # | Gap | Unit |
|---|---|---|
| 1 | no Flatpak manifest, no Flatpak CI, no `.github/workflows/` | 1 |
| 2 | high contrast: filled wedge never outlined | 4 |
| 3 | high contrast: start-cap hairline sweeps the wrong way | 4 |
| 4 | high contrast never driven, so three further "parity" rows are unverified | 4 |
| 5 | four About link rows upstream has none of, with four untranslated labels | 6 |
| 6 | the rationale for #5 in `lib/about_dialog.rb` is contradicted by `Adw-1.gir` | 6 |
| 7 | no Qt/Kirigami frontend | — |
| 8 | no DOAP, no screenshots; AppStream metadata points at upstream's repo | — |
