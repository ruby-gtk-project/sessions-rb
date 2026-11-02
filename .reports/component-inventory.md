# sessions — upstream component inventory

Upstream is **Go** (puregotk bindings over GTK4/libadwaita) on `origin/main`, with
its widget trees in blueprint (`.blp`) files compiled into a GResource. 62 files
total; only five contribute user-facing components:

- `assets/resources/window.blp` — the whole main window tree plus the primary menu
- `assets/resources/shortcuts-dialog.blp` — the shortcuts dialog
- `internal/components/application.go` — the `SessionsApplication` subclass, app actions, About dialog
- `internal/components/main_window.go` — the `SessionsMainWindow` template class, window actions, alarm, portal
- `internal/components/dial.go` — the `SessionsDial` custom widget (GSK snapshot, drag/click gestures, two properties, two signals)

plus `pkg/state/machine.go` + `pkg/state/constants.go` (the four-state timer state
machine that drives every one of those), `assets/resources/index.gschema.xml`
(one GSettings key), `assets/resources/style.css` (three classes) and 27 `po/`
catalogues.

The app is one window: a circular dial you drag to set a duration, a time label
overlaid on it, and minus / start-stop / plus buttons underneath.

## What the `ruby` branch has today

Three `.rb` files — a skeleton, no app:

| File | What it is |
|---|---|
| `lib/sessions.rb` | one `require_relative` |
| `lib/sessions/application.rb` | `Gtk::Application` + `Adwaita::ApplicationWindow` + `Adwaita::ToolbarView` + `Adwaita::HeaderBar` + `Adwaita::StatusPage` saying "The Ruby port has not been written yet." |
| `lib/sessions/rb/version.rb` | `VERSION = '0.1.0'` |

`exe/sessions` (`Sessions::Application.new.build.run`) is the entry point and is
the one piece of `main.go` that already exists.

Every component below is therefore **missing**. The port follows the pilot's flat
layout (`gnome-contacts-rb/lib/contact_sheet.rb`), so the real app lands in
`lib/*.rb` and the existing `lib/sessions/application.rb` skeleton is superseded
by `lib/application.rb`.

---

## assets/resources/window.blp + internal/components/main_window.go — the only window

`template $SessionsMainWindow : Adw.ApplicationWindow`, 360×380, title "Sessions".
→ `lib/main_window.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `win.closeWindow`, `win.toggleTimer`, `win.addTime`, `win.removeTime` installed here | `hide-on-close` toggled true while the timer runs (background hold) |
| `Adw.ToolbarView` | 1 | — | — | `toolbar_view` |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` | 1 | — | — | title "Sessions" |
| `Gtk.MenuButton` | 1 | — | `menu-model: main_menu` | `open-menu-symbolic`, tooltip "Main Menu", `primary: true` (so F10 opens it) |
| `Gtk.Box` | 4 | — | — | vertical root; centred dial box (spacing 12, margins 12); horizontal button row (spacing 12, margins 12, halign center); `dial_area` 260×260 |
| `Gtk.Overlay` | 1 | — | — | dial underneath, the time listbox on top |
| `Gtk.ListBox` | 1 | `boxed-list`, `boxed-list--opaque` | `selection-mode: none`, halign/valign center | exists purely to give the label a card |
| `Gtk.ListBoxRow` | 1 | — | `activatable: false` | `timer_row`, accessibility label "Remaining Time" |
| `Gtk.Label` | 1 | `title-1`, `dial__display`, + `dial__display--alarming` (added while alarming) | — | `analog_time_label`, default "05:00", margins 12; bound to the dial's `remaining-time` property through a transform that formats `%02d:%02d`; `Announce("Session Finished", high)` on alarm |
| `Gtk.Button` | 1 | `circular` | `action-name: win.removeTime` | `minus_button`, `list-remove-symbolic`, tooltip "Remove 30 seconds" |
| `Gtk.Button` | 1 | `suggested-action` + `pill`, swapped to `destructive-action` + `pill` | `action-name: win.toggleTimer` | `action_button`; label and icon switch between `_Start Timer`/`media-playback-start-symbolic` and `_Stop`/`media-playback-stop-symbolic` as the permitted triggers change; `use-underline` |
| `Gtk.Button` | 1 | `circular` | `action-name: win.addTime` | `plus_button`, `list-add-symbolic`, tooltip "Add 30 seconds" |
| `Gtk.MediaFile` | 1 | — | — | not a widget; `alarm-clock-elapsed.oga` from the GResource, seek(0)+play on alarm |

Repeaters: none. Conditional: `dial__display--alarming` only in the alarming
state; the sensitivity of the three buttons is driven entirely by the state
machine's permitted-trigger set.

**Window actions** (all `gio.SimpleAction`, names read off the source — the
inventory's least greppable axis):

| Action | Accelerator | Effect |
|---|---|---|
| `win.toggleTimer` | `<Primary>space` | stop timer / stop alarming / start timer, in that precedence |
| `win.addTime` | `<Primary>plus`, `<Primary>equal` | `PlusTimer` (+30s) |
| `win.removeTime` | `<Primary>minus` | `MinusTimer` (−30s) |
| `win.closeWindow` | `<Primary>w` | `window.Close()` |
| `app.stopAlarmPlayback` | — | installed on the *application*, not the window, so the notification can activate it with no window focused |

## assets/resources/window.blp — `menu main_menu`

→ `lib/main_menu.rb` (built as a `Gio::Menu`; blueprint menus produce no widget rows)

| Item | Action |
|---|---|
| `_Keyboard Shortcuts` | `app.shortcuts` |
| `_About Sessions` | `app.openAbout` |

One section, two items. **Upstream bug worth knowing:** `app.shortcuts` is given
an accelerator (`<Primary>question`) and a menu item, but no `SimpleAction` named
`shortcuts` is ever installed and `ResourceShortcutsDialogUIPath` is never loaded
— the menu item and `shortcuts-dialog.blp` are dead on `origin/main`. The port
should install the action and present the dialog.

## internal/components/dial.go — the draggable circular dial

→ `lib/dial.rb`

`SessionsDial`, a direct `Gtk.Widget` subclass that draws itself with GSK paths.

| Facet | Detail |
|---|---|
| Properties | `remaining-time` (int, 0…3600, default 300), `counting-down` (bool, default false); both `QueueDraw` on set |
| Signals | `drag-begin`, `drag-end` (defined on the class, emitted from the gesture) |
| Controllers | `Gtk.GestureDrag` (`drag-begin`, `drag-update`, `drag-end`) and `Gtk.GestureClick` (`pressed`) — both map a position to a time |
| Hit-testing | `positionToRemainingTime`: ignores anything within 15px of the centre; `atan2`-derived angle → one of 120 intervals × 30s |
| Drawing | 10px track circle (manually sampled `#343437` dark / `#D8D8D8` light; replaced by `destructive_color` blended 0.5 over `window_bg_color` when insensitive); filled progress wedge (`error_color` @ 0.3 alpha counting down, grey @ 0.2 idle); 10px round-capped progress arc (`error_color` counting down, `accent_bg_color` idle); 8px handle circle; in high-contrast mode an extra `window_fg_color` @ 0.5 border stroke on every shape plus inner/outer arcs at ±5px |
| Redraw triggers | `AdwStyleManager::notify` → `QueueDraw`, so light/dark and high-contrast switches repaint |
| Edge case | the arc is skipped when `counting-down && remaining == 0`, to avoid a red flash before the insensitive colour lands |

## assets/resources/shortcuts-dialog.blp — keyboard shortcuts

→ `lib/shortcuts_dialog.rb`

`Adw.ShortcutsDialog` with two `Adw.ShortcutsSection`s and seven
`Adw.ShortcutsItem`s. Items that name an `action-name` take their accelerator
from the app's accel map.

| Section | Items |
|---|---|
| General | Open menu (`F10`), Show keyboard shortcuts (`app.shortcuts`), Close window (`win.closeWindow`), Quit (`app.quit`) |
| Timer | Start or stop timer (`win.toggleTimer`), Add 30 seconds (`win.addTime`), Remove 30 seconds (`win.removeTime`) |

## internal/components/application.go — the application

→ `lib/application.rb`

Not a widget class, but it owns the actions, the accelerators, the About dialog
and the single-window `activate` behaviour (re-`present` an existing window
rather than building a second one).

| Action | Accelerator | Effect |
|---|---|---|
| `app.openAbout` | — | presents the About dialog over the window |
| `app.quit` | `<Primary>q` | `Application.Quit()` |
| `app.shortcuts` | `<Primary>question` | accelerator set, action never installed (see above) |

## About dialog — application.go + assets/resources/metainfo.xml.in

→ `lib/about_dialog.rb`

`adw.NewAboutDialogFromAppdata(metainfo.xml, "0.1.20")`, then developers
(Felicitas Pojtinger, Guido Günther), artists (Felicitas Pojtinger, Mirabelle
Salles), copyright (`© 2026 …`) and `translator-credits`. The Ruby bindings have
no appdata constructor worth relying on, so the port fills
`Adwaita::AboutDialog` fields from the same metainfo values by hand: name,
summary, description, license AGPL-3.0-or-later, and the bugtracker / homepage /
donation / help / translate / contribute URLs.

## pkg/state/machine.go + pkg/state/constants.go — the timer state machine

→ `lib/state_machine.rb`

Four states — `stopped`, `dragging`, `countingDown`, `alarming` — and the whole
app's behaviour. Not user-facing itself, but every enabled/disabled button, every
label and every colour above is a function of its permitted-trigger set, so the
port cannot be built around anything else.

| Facet | Detail |
|---|---|
| Triggers | `plusTimer`, `minusTimer`, `startDragging`, `stopDragging` (private, parameterised by the new duration), `startTimer`, `stopTimer`, `timerFinished` (private), `stopAlarming` |
| Guards | ±30s must keep the duration within 30s…1h; `stopDragging` additionally requires the new duration to be a whole multiple of 30s |
| Hooks | `OnStartTimer`, `OnStopTimer`, `OnInitialRemainingTimeChange`, `OnCurrentRemainingTimeTick`, `OnStartAlarm`, `OnStopAlarm`, `OnPermittedTriggersChange` |
| Constants | default 5min, adjustment interval 30s, min 30s, max 1h, tick 1s |
| Quirks | ±30s while counting down re-enters `countingDown`, stopping and restarting the ticker from the rounded current value; `stopped` runs `OnStopTimer` only when entered via `stopTimer`, so the alarm path does not double-stop |
| Ticker | a Go goroutine on a 1s ticker marshalling back through `glib.IdleAdd`; in Ruby this becomes `GLib::Timeout.add(1000)` on the main loop and the whole idle-marshalling layer disappears |

`pkg/state/machine_test.go` is the upstream test suite for it and is the natural
first target for the port's specs.

## assets/resources/index.gschema.xml — settings

→ `lib/settings.rb`

One key: `last-position` (int64, default 300) — the last manually set duration,
restored at startup and written on every `OnInitialRemainingTimeChange`.
Following the pilot (`gnome-contacts-rb/lib/settings.rb`), this is backed by a
small JSON file under `XDG_CONFIG_HOME` rather than a GSettings schema that
would have to be compiled and installed before the app could run from a
checkout.

## assets/resources/style.css — the stylesheet

→ `lib/style.rb` (a `Gtk::CssProvider` loaded from a heredoc)

| Class | What it does |
|---|---|
| `boxed-list--opaque` | overrides the boxed-list background to `var(--headerbar-bg-color)`, which is otherwise slightly transparent |
| `dial__display` | `font-feature-settings: "tnum"` so the digits do not jitter |
| `dial__display--alarming` | 1s infinite opacity blink, wrapped in `@media (prefers-reduced-motion: no-preference)` |

## Alarm — notification and sound (main_window.go)

→ `lib/alarm.rb`

On entering `alarming`: dial set to 0 and made insensitive, blink class added, a
high-priority `Gio::Notification` titled "Session Finished" / "Time to take a
break" with default action `app.stopAlarmPlayback`, `alarm-clock-elapsed.oga`
seeked and played, and a high-priority accessibility announcement. On stopping:
all of it undone and the notification withdrawn.

## Background portal (main_window.go)

→ `lib/background_portal.rb`

While counting down or alarming, upstream calls the XDG background portal
(`github.com/rymdport/portal/background`) to request permission to run in the
background with reason "Running the Timer in the Background", sets the
background-apps status to "Timer Running" / "Session Finished", then
`app.Hold()` + `hide-on-close = true`. Cleared and `app.Release()`d on stop.

## assets/resources/index.go — app constants

→ `lib/resources.rb`

App ID, version `0.1.20`, developers, artists, copyright, resource paths and the
`last-position` key name. Partially present: `lib/sessions/rb/version.rb` holds a
`VERSION` only, and the app ID is inline in the skeleton as
`org.rubygtkproject.Sessions`.

## po/ — 27 translation catalogues

→ `po/` (kept as catalogues; see the `translation-parity` skill)

`sessions.pot` has 30 messages across bn, ca, cs, de, en_GB, en_US, es, et, fi,
fr, fr_CA, hi, hr, hu, ia, oc, pl, pt, pt_BR, ru, sv, tr, uk, vi, zh_Hans,
zh_Hant. Every user-visible string listed above is translated, including the
desktop keywords and the GSettings summary/description.

## main.go — entry point

→ `exe/sessions` + `lib/sessions.rb` (**present**)

i18n init, GResource registration, settings construction, `Application.Run`.
The Ruby entry point `Sessions::Application.new.build.run` already exists; the
GResource half has no equivalent (resources are loaded from the filesystem).

## Packaging and metadata (not `lib/`)

`assets/meta/com.pojtinger.felicitas.Sessions.desktop.in`,
`assets/resources/metainfo.xml.in`, `icon.svg` / `icon-alt.svg` /
`icon-symbolic.svg`, `assets/resources/index.gresource.xml`,
`com.pojtinger.felicitas.Sessions.json` (Flatpak) and
`.github/workflows/flatpak.yaml`. These become `data/` files if the port is ever
packaged; none of them is a `lib/*.rb`.

## Out of scope

`qt/main.go` + `qt/main.qml` are a separate Qt/QML frontend in the same repo,
not part of the GTK application. `go.mod`, `go.sum`, `modules.txt`,
`go.mod.json`, `sessions.doap`, `LICENSE`, `README.md` carry no components.

---

## Blockers and divergences

1. **The dial cannot be a GSK-snapshot `Gtk::Widget` subclass.** Upstream
   overrides the `snapshot` vfunc and draws with `Gsk::PathBuilder`,
   `Gsk::Stroke`, `AppendFill`/`AppendStroke` and `Graphene::Point`. The Ruby
   bindings expose no usable vfunc override for `snapshot` and no `Gsk` path
   API; the house pattern for custom drawing is `Gtk::DrawingArea` with
   `set_draw_func` and Cairo (`references/declarative-patterns.md`). The dial is
   ported as a `Gtk::DrawingArea` drawn with Cairo arcs — visually equivalent,
   including the high-contrast borders, but not the same mechanism.
2. **The dial's custom GObject properties and `drag-begin`/`drag-end` signals
   go away.** `remaining-time` is bound to the label's `label` property through
   a `BindPropertyFull` transform upstream. In Ruby the dial exposes plain
   accessors and a callback, and the window formats the label itself.
3. **GSettings needs a compiled, installed schema.** Backed by a JSON file under
   `XDG_CONFIG_HOME` instead, exactly as the pilot port does; the key name,
   type and default are preserved.
4. **GResource is not used.** `window.ui`, `shortcuts-dialog.ui`, `metainfo.xml`,
   `style.css` and the alarm sound are compiled into a GResource upstream (and
   the two `.ui` files are generated from blueprint). The port builds widgets in
   Ruby and loads the sound and CSS from the filesystem.
5. **The XDG background portal has no Ruby binding here.** Upstream uses a Go
   portal library over D-Bus. Without it the port can still `app.hold`-equivalent
   and set `hide-on-close`, but cannot request background permission or set the
   background-apps status message; those two strings ("Running the Timer in the
   Background", "Timer Running") have no port-side home unless a D-Bus call is
   written by hand.
6. **`Gtk::Accessible#announce` is not exposed by the Ruby bindings** (nor is the
   `accessibility { label: ... }` blueprint block, which becomes
   `update_property`/`accessible_role` calls). The alarm's screen-reader
   announcement is likely to be lost; the "Remaining Time" row label can be set
   via `Gtk::Accessible` property updates.
7. **`Adwaita::Application` and `Adwaita::ApplicationWindow` are partly broken**
   in the Ruby bindings — the app object must be `Gtk::Application`
   (`references/adwaita-quirks.md`), which is what the skeleton already does.
8. **`adw_about_dialog_new_from_appdata` has no Ruby equivalent**; the About
   dialog's fields are filled from the metainfo values by hand.
9. **`NewAboutDialogFromAppdata` reads release notes from `metainfo.xml`** —
   the port's About dialog will have no "What's New" section unless the releases
   are transcribed.
10. **27 `po/` catalogues.** The port has no gettext wiring at all today; strings
    are inline English. Reaching translation parity is a separate unit (see the
    `translation-parity` skill), not something the component port delivers.
