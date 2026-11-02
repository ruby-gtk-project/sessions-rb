# Component identification — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` (Go + puregotk, blueprint UI in a GResource) |
| Port | `ruby` @ `088c46d` |
| Symbol table | `.claude/skills/component-identification/scripts/symbols.tsv` |
| Scans | `component-scan.sh` over both trees, then read file by file |

Step 1 of the skill first: upstream's declarative UI is
`assets/resources/window.blp` and `assets/resources/shortcuts-dialog.blp`.
`window.blp` has one `template $SessionsMainWindow` root plus a `menu
main_menu` block; `shortcuts-dialog.blp` has a top-level **named object**
(`Adw.ShortcutsDialog shortcuts_dialog`), not a template — matching `template`
alone finds half the app. The port has no `.blp`/`.ui` at all, as the house
style requires, so its side is scan-plus-reading throughout.

---

## Unit list

Six units, in the order a user meets them.

| # | Unit | Upstream files | Port file(s) |
|---|---|---|---|
| 1 | application object | `main.go`, `internal/components/application.go` | `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `exe/sessions` |
| 2 | main window | `internal/components/main_window.go` + `assets/resources/window.blp` | `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb` |
| 3 | primary menu | the `menu main_menu` block of `window.blp` | `lib/main_menu.rb` |
| 4 | dial | `internal/components/dial.go` | `lib/dial.rb` |
| 5 | shortcuts dialog | `assets/resources/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` |
| 6 | about dialog | `application.go:76-92` + `assets/resources/metainfo.xml.in` | `lib/about_dialog.rb`, `lib/metainfo.rb` |

Non-widget units that still carry behaviour: `pkg/state/machine.go` +
`constants.go` → `lib/state_machine.rb` + `lib/ticker.rb`;
`assets/resources/style.css` → `lib/style.rb`.

Upstream files that belong to **no** unit on the port side, because the port
has nothing opposite them: `qt/main.go`, `qt/main.qml`,
`com.pojtinger.felicitas.Sessions.json`, `.github/workflows/flatpak.yaml`,
`sessions.doap`, `LICENSE`, `assets/meta/screenshot-*.png`. They are carried
into `component-parity.md` as gaps, not dropped here.

---

## 1 — application object

| Widget | × | CSS | Signals | Actions | Notes |
|---|---:|---|---|---|---|
| `Adw.Application` subclass (`SessionsApplication`) | 1 | — | `activate` (vfunc override) | installs `app.openAbout`, `app.quit` | upstream registers the GType by hand in `init()` |
| `Gio.SimpleAction` | 2 | — | `activate` ×2 | `openAbout`, `quit` | |

Accelerators installed here: `app.shortcuts` → `<Primary>question`,
`app.quit` → `<Primary>q`.

**`app.shortcuts` has an accelerator and a menu item upstream and no install
site anywhere in the Go.** `git grep -n shortcut origin/main -- '*.go'` returns
two lines, both of them the accelerator and the resource path; no
`gio.NewSimpleAction("shortcuts", …)` exists. The dialog
`shortcuts-dialog.blp` describes is unreachable in upstream's own build.

Port side: `lib/application.rb` is a `Gtk::Application` (not Adwaita —
`Adwaita::Application` is unusable in these bindings) with three
`Gio::SimpleAction`s: `shortcuts`, `openAbout`, `quit`. The third action is an
addition, explained in the file's header comment.

Conditional: `activated_window` runs the whole install exactly once, which is
upstream's early-return-and-present on a second activation.

## 2 — main window

Union of `window.blp` and `main_window.go`, with the template root counted once
(`class SessionsMainWindow` in Go and `template $SessionsMainWindow` in the
blueprint are one window).

| Widget | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | — | 360×380, title `_("Sessions")` |
| `Adw.ToolbarView` | 1 | — | — | `toolbar_view` |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | title `_("Sessions")` |
| `Gtk.MenuButton` | 1 | — | `menu-model: main_menu` | `open-menu-symbolic`, `primary: true`, tooltip `_("Main Menu")` |
| `Gtk.Box` | 4 | — | — | outer vertical, dial pane, `dial_area` (260×260), button row |
| `Gtk.Overlay` | 1 | — | — | dial underneath, time card on top |
| `Gtk.ListBox` | 1 | `boxed-list`, `boxed-list--opaque` | `selection-mode: none` | |
| `Gtk.ListBoxRow` | 1 | — | `activatable: false` | carries `accessibility { label: _("Remaining Time") }` |
| `Gtk.Label` | 1 | `title-1`, `dial__display`, **`dial__display--alarming` (dynamic)** | — | `analog_time_label`; bound to the dial's `remaining-time` through a transform function |
| `Gtk.Button` | 3 | minus/plus `circular`; action button `suggested-action`, `pill`, **`destructive-action` (dynamic)** | `win.removeTime`, `win.toggleTimer`, `win.addTime` | tooltips `_("Remove 30 seconds")` / `_("Add 30 seconds")`; action button label flips `_("_Start Timer")` ↔ `_("_Stop")` and its icon `media-playback-start-symbolic` ↔ `media-playback-stop-symbolic` |
| `Gio.SimpleAction` | 5 | — | `activate` ×5 | `toggleTimer`, `addTime`, `removeTime`, `closeWindow` on the window; `stopAlarmPlayback` on the **application** |
| `Gio.Notification` | 1 | — | default action `app.stopAlarmPlayback` | `_("Session Finished")` / `_("Time to take a break")`, high priority |
| `Gtk.MediaFile` | 1 | — | — | `alarm-clock-elapsed.oga` |

Accelerators installed here: `win.closeWindow` → `<Primary>w`,
`win.toggleTimer` → `<Primary>space`, `win.addTime` → `<Primary>plus` **and**
`<Primary>equal`, `win.removeTime` → `<Primary>minus`.

Dynamic CSS, listed with every value it can take rather than as "dynamic":
`destructive-action` and `suggested-action` are added and removed on the action
button by `OnPermittedTriggersChange`; `dial__display--alarming` is added to
the label on `OnStartAlarm` and removed on `OnStopAlarm`.

Repeaters: none. Conditional: the background-portal request only when not
already held; the whole alarm block only in the alarming state.

Non-widget behaviour that belongs to this unit and that no scan row shows:
seven state-machine hooks, the `org.freedesktop.portal.Background`
`RequestBackground` + `SetStatus` pair, `app.hold`/`app.release`,
`set_hide_on_close`, `Gtk::Label#announce(…, :high)`, and the thirteen
`log.Error` sites on refused transitions.

## 3 — primary menu

A blueprint `menu` block is all lowercase keywords, so it produces no scan
rows. Counted by hand: one `section`, two `item`s, no `custom:` slots.

| Item | Action |
|---|---|
| `_("_Keyboard Shortcuts")` | `app.shortcuts` |
| `_("_About Sessions")` | `app.openAbout` |

## 4 — dial

| Widget / controller | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` subclass (`SessionsDial`) | 1 | — | emits `drag-begin`, `drag-end`; listens `notify` on `Adw.StyleManager` | overrides `snapshot`; properties `remaining-time` (int 0…3600, default 300) and `counting-down` (bool, default false) |
| `Gtk.GestureDrag` | 1 | — | `drag-begin`, `drag-update`, `drag-end` | |
| `Gtk.GestureClick` | 1 | — | `pressed` | |

`Gsk.PathBuilder` ×10 and `Gsk.Stroke` ×3 are `type` rows, not widgets: they
are the drawing plumbing, compared as plumbing in `component-parity.md`.

Geometry and colour, read out of `snapshot` (dial.go:296-492): radius
`min(cx,cy) − 15`; 10px track; 8px handle; 15px dead zone at the centre; 120
intervals per ring; track is a sampled grey (`#343437` dark / `#D8D8D8` light)
or, when insensitive, `destructive_color` composited over `window_bg_color` at
0.5·alpha; arc stroke is `error_color` while counting down and
`accent_bg_color` otherwise; fill is `error_color` at α 0.3 or a flat
`(0.6,0.6,0.6,0.2)`; handle is filled with the looked-up colour **without**
forcing alpha. Under high contrast every shape gets a 1px
`window_fg_color` α 0.5 hairline: circles at r±5, the pie path itself, the
full-ring fill path, the start cap, arcs at r±5, and the handle.

Port side: `Gtk::DrawingArea` + `set_draw_func` with Cairo, the two properties
as plain accessors, the two signals as injected callbacks. Same two gestures,
same five signal names.

## 5 — shortcuts dialog

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.ShortcutsDialog` | 1 | — | top-level named object; **no title set**, so libadwaita supplies its own |
| `Adw.ShortcutsSection` | 2 | — | `_("General")`, `_("Timer")` |
| `Adw.ShortcutsItem` | 7 | — | see below |

| Item | Resolves via |
|---|---|
| `_("Open menu")` | literal accelerator `F10` |
| `_("Show keyboard shortcuts")` | `app.shortcuts` |
| `_("Close window")` | `win.closeWindow` |
| `_("Quit")` | `app.quit` |
| `_("Start or stop timer")` | `win.toggleTimer` |
| `_("Add 30 seconds")` | `win.addTime` |
| `_("Remove 30 seconds")` | `win.removeTime` |

Port side: `lib/shortcuts_dialog.rb` builds the same 2 sections and 7 items
**in a loop**, so the scan reports `Adw.ShortcutsSection 1` and
`Adw.ShortcutsItem 1`. Recorded as a repeater: one component, 2 and 7 at
runtime, driven by the `#sections` table. Counting the scan row here would
report a gap of 1 and 6 against a correct port.

## 6 — about dialog

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | built by `adw_about_dialog_new_from_appdata(metainfo resource, version)`, then `SetDevelopers` / `SetArtists` / `SetCopyright` / `SetTranslatorCredits(L("translator-credits"))` |

Everything else in the dialog — name, summary, description, release notes,
licence, and the bugtracker / homepage / donation / help / contact / faq /
vcs-browser / translate / contribute rows — comes from
`assets/resources/metainfo.xml.in` and is therefore part of this unit even
though no Go line names it. The rows libadwaita builds from
`<url type="donation">` and `<url type="translate">` carry **libadwaita's own
translated labels**; that is the fact the text axis turns on in
`component-parity.md`.

---

## Whole-app totals

| Axis | Upstream distinct | Port distinct |
|---|---:|---:|
| Widget types | 11 (window unit) + 1 dial + 3 dialog/shortcuts + 1 about | same set, with `Gtk.DrawingArea` substituted for the `Gtk.Widget` subclass |
| CSS classes | 9 | 9 |
| Signals | 10 | 10 |
| Actions | 7 (`toggleTimer`, `addTime`, `removeTime`, `closeWindow`, `stopAlarmPlayback`, `openAbout`, `quit`) | 8 — the seven plus `shortcuts`, which upstream declares and never installs |

A total is a map, not a verdict. The verdict is per unit, in
`component-parity.md`.
