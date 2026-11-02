# sessions — upstream component inventory

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` (2026-07-17), Go + puregotk over GTK4/libadwaita |
| Port | `ruby`, 19 files / 2329 lines under `lib/` |
| Identified with | `.claude/skills/component-identification`, `scripts/component-scan.sh` on both sides, then every file read |

Upstream keeps its widget trees in blueprint (`.blp`) compiled into a GResource
and subclasses GObject by hand in Go. The scan finds components in exactly six
upstream files:

```
assets/resources/window.blp              the main window tree + the primary menu
assets/resources/shortcuts-dialog.blp    the shortcuts dialog
internal/components/application.go       SessionsApplication: app actions, About dialog
internal/components/main_window.go       SessionsMainWindow: window actions, alarm, portal
internal/components/dial.go              SessionsDial: GSK snapshot, gestures, 2 props, 2 signals
main.go                                  i18n, GResource registration, GSettings, run
```

The scan totals, as a map of how much app there is — not an inventory to act on:

| | widgets | distinct CSS | distinct signals | actions | controllers |
|---|---:|---:|---:|---:|---:|
| upstream (6 files) | 35 rows | 9 | 6 | 13 | 2 |
| `ruby` (`lib/`) | 14 rows | 8 | 7 | 13 | 2 |

The widget-row gap is not a parity gap: upstream's rows include its
`gobject.TypeRegisterStaticSimple` plumbing (`Adw.ApplicationGLibType`,
`Gtk.WidgetGLibType`, `Gtk.NewMediaFileForResource`, `Gio.SettingsFull`) which
the Ruby bindings do not need. The one real CSS difference is that
`dial__display--alarming` is applied through `Style::ALARMING_CLASS` in the port,
so the scan's literal-string matcher does not see it at the `add_css_class` site.

**The app is one window**: a circular dial you drag or click to set a duration, a
time label overlaid on it in a boxed-list card, and minus / start-stop / plus
buttons underneath. One primary menu, two dialogs, one GSettings key, one
stylesheet, one sound.

---

## Component list

Every row here was read on both sides. `kind` is the component's role, not its
GTK type.

| Upstream | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `window.blp` + `internal/components/main_window.go` | `lib/main_window.rb` | window | yes |
| `internal/components/dial.go` | `lib/dial.rb` | custom widget | yes |
| `window.blp` `menu main_menu` | `lib/main_menu.rb` | menu | yes |
| `assets/resources/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | dialog | yes |
| `internal/components/application.go` | `lib/application.rb` | application | yes |
| `application.go` activate + `metainfo.xml.in` | `lib/about_dialog.rb` | dialog | yes |
| `metainfo.xml.in` (parsed for the About fields) | `lib/metainfo.rb` | data | yes |
| `main_window.go` alarm hooks + `alarm-clock-elapsed.oga` | `lib/alarm.rb` | notification + sound | yes |
| `main_window.go` portal calls (`rymdport/portal/background`) | `lib/background_portal.rb` | portal client | yes |
| `pkg/state/machine.go` + `pkg/state/constants.go` | `lib/state_machine.rb` | state machine | yes |
| `pkg/state/machine.go` ticker goroutine | `lib/ticker.rb` | timer | yes |
| `assets/resources/index.gschema.xml` + `main.go:43-58` | `lib/settings.rb` | settings | yes |
| `assets/resources/style.css` | `lib/style.rb` | stylesheet | yes |
| `assets/resources/index.go` | `lib/resources.rb` | constants | yes |
| `main.go:19-35` (gettext init) | `lib/translations.rb` | i18n | yes |
| `main.go` `main()` | `exe/sessions` + `lib/sessions.rb` | entry point | yes |
| `po/*.po`, `po/sessions.pot` | `po/` (26 catalogues, 33 messages) | catalogues | yes |
| `assets/meta/*.desktop.in`, `metainfo.xml.in`, `icon*.svg`, `index.gschema.xml` | `data/` (not `lib/`) | packaging data | yes |
| `qt/main.go` + `qt/main.qml` (Kirigami frontend) | — | second frontend | **no** |
| `com.pojtinger.felicitas.Sessions.json`, `.github/workflows/flatpak.yaml` | — | Flatpak manifest | **no** |

Nothing in `lib/` is an extra: every port file traces to an upstream file.
`lib/sessions/application.rb`, `lib/sessions/rb.rb` and `lib/sessions/rb/version.rb`
are gem plumbing (the gem is published as `sessions-rb`, so `require
"sessions/rb"` has to resolve) and carry no components.

---

## assets/resources/window.blp + internal/components/main_window.go — the only window

`template $SessionsMainWindow : Adw.ApplicationWindow`, 360×380, title "Sessions".
→ `lib/main_window.rb` (**exists**)

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | installs `win.closeWindow`, `win.toggleTimer`, `win.addTime`, `win.removeTime` | `hide-on-close` flipped true while the timer runs (background hold) |
| `Adw.ToolbarView` | 1 | — | — | `toolbar_view` |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` | 1 | — | — | title "Sessions" |
| `Gtk.MenuButton` | 1 | — | `menu-model: main_menu` | `open-menu-symbolic`, tooltip "Main Menu", `primary: true` so F10 opens it |
| `Gtk.Box` | 4 | — | — | vertical root; centred dial box (spacing 12, margins 12); horizontal button row (spacing 12, margins 12, halign center); `dial_area` 260×260 |
| `Gtk.Overlay` | 1 | — | — | dial underneath, the time card on top |
| `Gtk.ListBox` | 1 | `boxed-list`, `boxed-list--opaque` | `selection-mode: none` | exists purely to give the label a card; halign/valign center |
| `Gtk.ListBoxRow` | 1 | — | `activatable: false` | `timer_row`, accessibility label "Remaining Time" |
| `Gtk.Label` | 1 | `title-1`, `dial__display`, + `dial__display--alarming` while alarming | — | `analog_time_label`, default "05:00", margins 12; bound to the dial's `remaining-time` through a transform formatting `%02d:%02d`; `Announce("Session Finished", high)` on alarm |
| `Gtk.Button` | 1 | `circular` | `win.removeTime` | `minus_button`, `list-remove-symbolic`, tooltip "Remove 30 seconds", valign center |
| `Gtk.Button` | 1 | `suggested-action`+`pill`, swapped to `destructive-action`+`pill` | `win.toggleTimer` | `action_button`; label/icon switch between `_Start Timer`/`media-playback-start-symbolic` and `_Stop`/`media-playback-stop-symbolic` as the permitted triggers change; `use-underline` |
| `Gtk.Button` | 1 | `circular` | `win.addTime` | `plus_button`, `list-add-symbolic`, tooltip "Add 30 seconds", valign center |
| `Gtk.MediaFile` | 1 | — | — | not a widget; `alarm-clock-elapsed.oga` from the GResource, `seek(0)` + `play` on alarm |

Repeaters: none. Conditional: `dial__display--alarming` only in the alarming
state; the three buttons' sensitivity is driven entirely by the state machine's
permitted-trigger set, never set directly.

**Window actions** — all `gio.SimpleAction`, read off the source because the
names never appear as grepppable literals beside their accelerators:

| Action | Accelerator | Effect |
|---|---|---|
| `win.toggleTimer` | `<Primary>space` | stop timer / stop alarming / start timer, in that precedence |
| `win.addTime` | `<Primary>plus`, `<Primary>equal` | `PlusTimer` (+30s) |
| `win.removeTime` | `<Primary>minus` | `MinusTimer` (−30s) |
| `win.closeWindow` | `<Primary>w` | `window.Close()` |
| `app.stopAlarmPlayback` | — | installed on the *application*, not the window, so the notification can activate it with no window focused |

Port: `lib/main_window.rb` installs the same five (`ACCELERATORS` at
`lib/main_window.rb:135`, `stop_alarm_playback_action` on the app at `:134`), and
builds the accessible row from a one-object `Gtk::Builder` snippet
(`TIMER_ROW_UI`) because `update_property` raises `NotImplementedError` in these
bindings.

## assets/resources/window.blp — `menu main_menu`

→ `lib/main_menu.rb` (**exists**; a `Gio::Menu` — blueprint menus are all
lowercase keywords and produce no scan rows at all)

| Item | Action |
|---|---|
| `_Keyboard Shortcuts` | `app.shortcuts` |
| `_About Sessions` | `app.openAbout` |

One section, two items.

**Upstream bug worth knowing:** `app.shortcuts` gets an accelerator
(`<Primary>question`, `application.go:111`) and a menu item, but no
`SimpleAction` named `shortcuts` is ever installed and
`ResourceShortcutsDialogUIPath` is never loaded — the menu item and
`shortcuts-dialog.blp` are dead on `origin/main`. The port installs the action
and presents the dialog (`lib/application.rb:66`, `:81`), which is a deliberate
divergence in the user's favour.

## internal/components/dial.go — the draggable circular dial

→ `lib/dial.rb` (**exists**)

`SessionsDial`, a direct `Gtk.Widget` subclass that draws itself with GSK paths.

| Facet | Detail |
|---|---|
| Properties | `remaining-time` (int, 0…3600, default 300), `counting-down` (bool, default false); both `QueueDraw` on set |
| Signals | `drag-begin`, `drag-end`, defined on the class with `SignalNewv` and emitted from the gesture handlers |
| Controllers | `Gtk.GestureDrag` (`drag-begin`, `drag-update`, `drag-end`) and `Gtk.GestureClick` (`pressed`) — both map a position to a time |
| Hit-testing | `positionToRemainingTime`: ignores anything within 15px of the centre; `atan2`-derived angle → one of 120 intervals × 30s |
| Drawing | 10px track circle (manually sampled `#343437` dark / `#D8D8D8` light; replaced by `destructive_color` blended at 0.5 over `window_bg_color` when insensitive); filled progress wedge (`error_color` @ 0.3 counting down, grey @ 0.2 idle); 10px round-capped progress arc (`error_color` counting down, `accent_bg_color` idle); 8px handle circle; in high-contrast mode an extra `window_fg_color` @ 0.5 border stroke on every shape plus inner/outer arcs at ±5px |
| Redraw triggers | `AdwStyleManager::notify` → `QueueDraw`, so light/dark and high-contrast switches repaint |
| Edge case | the arc is skipped when `counting-down && remaining == 0`, to avoid a red flash before the insensitive colour lands |

Port divergence: `lib/dial.rb` is a `Gtk::DrawingArea` with a `set_draw_func`
drawing the same shapes in Cairo, because there is no vfunc override for
`snapshot` in these bindings (`FINDINGS.md`). The two custom properties are plain
accessors and the two signals are callbacks; the label formatting that upstream
does with `BindPropertyFull` is done in `lib/main_window.rb`.

## assets/resources/shortcuts-dialog.blp — keyboard shortcuts

→ `lib/shortcuts_dialog.rb` (**exists**)

A top-level named object, not a `template`: `Adw.ShortcutsDialog shortcuts_dialog`
with two `Adw.ShortcutsSection`s and seven `Adw.ShortcutsItem`s. Items naming an
`action-name` take their accelerator from the app's accel map; only "Open menu"
spells a literal, because no action in this app is bound to F10.

| Section | Items |
|---|---|
| General | Open menu (`F10`), Show keyboard shortcuts (`app.shortcuts`), Close window (`win.closeWindow`), Quit (`app.quit`) |
| Timer | Start or stop timer (`win.toggleTimer`), Add 30 seconds (`win.addTime`), Remove 30 seconds (`win.removeTime`) |

Neither side sets the dialog title, so libadwaita supplies its own translated
heading. Binding quirk recorded in the port: `Adwaita::ShortcutsItem.new` takes
positional `(title, accelerator)` and the action name is assigned afterwards.

## internal/components/application.go — the application

→ `lib/application.rb` (**exists**)

Not a widget class, but it owns the app actions, the accelerators, the About
dialog and the single-window `activate` behaviour (re-`present` an existing
window rather than building a second one).

| Action | Accelerator | Effect |
|---|---|---|
| `app.openAbout` | — | presents the About dialog over the window |
| `app.quit` | `<Primary>q` | `Application.Quit()` |
| `app.shortcuts` | `<Primary>question` | accelerator set, action never installed upstream (see above); installed in the port |

Port divergence: the application object is a `Gtk::Application` with
`Adwaita.init` called first, because `Adwaita::Application` is broken in these
bindings; the *window* is a real `Adwaita::ApplicationWindow`.

## About dialog — application.go + assets/resources/metainfo.xml.in

→ `lib/about_dialog.rb` + `lib/metainfo.rb` (**exists**)

`adw.NewAboutDialogFromAppdata(metainfo.xml, "0.1.20")`, then developers
(Felicitas Pojtinger, Guido Günther), artists (Felicitas Pojtinger, Mirabelle
Salles), copyright (`© 2026 …`) and `translator-credits`.

`adw_about_dialog_new_from_appdata` takes a *resource* path and the port ships no
GResource, so `lib/metainfo.rb` parses
`data/com.pojtinger.felicitas.Sessions.metainfo.xml.in` for the name, summary,
description paragraphs and bullets, the twenty-one `<release>` entries behind
"What's New", the AGPL-3.0-or-later licence and the bugtracker / homepage /
donation / help / translate / contribute URLs. Still missing: the *translated*
titles of the Donate and Translate rows, which libadwaita supplies from its own
catalogue only through the appdata constructor.

## pkg/state/machine.go + pkg/state/constants.go — the timer state machine

→ `lib/state_machine.rb` + `lib/ticker.rb` (**exists**)

Four states — `stopped`, `dragging`, `countingDown`, `alarming`. Not user-facing
itself, but every enabled button, every label and every colour above is a
function of its permitted-trigger set.

| Facet | Detail |
|---|---|
| Triggers | `plusTimer`, `minusTimer`, `startDragging`, `stopDragging` (private, parameterised by the new duration), `startTimer`, `stopTimer`, `timerFinished` (private), `stopAlarming` |
| Guards | ±30s must keep the duration within 30s…1h; `stopDragging` additionally requires a whole multiple of 30s |
| Hooks | `OnStartTimer`, `OnStopTimer`, `OnInitialRemainingTimeChange`, `OnCurrentRemainingTimeTick`, `OnStartAlarm`, `OnStopAlarm`, `OnPermittedTriggersChange` |
| Constants | default 5min, adjustment interval 30s, min 30s, max 1h, tick 1s |
| Quirks | ±30s while counting down re-enters `countingDown`, stopping and restarting the ticker from the rounded current value; `stopped` runs `OnStopTimer` only when entered via `stopTimer`, so the alarm path does not double-stop |
| Ticker | upstream is a goroutine on a 1s `time.Ticker` marshalling back through `glib.IdleAdd`; the port is `GLib::Timeout.add(1000)` in `lib/ticker.rb` and the idle-marshalling layer disappears |

`pkg/state/machine_test.go` is upstream's suite for it; `spec/state_machine_spec.rb`
is the port's.

## assets/resources/index.gschema.xml — settings

→ `lib/settings.rb` (**exists**)

One key: `last-position` (int64, default 300) — the duration last chosen,
restored at startup and written on every `OnInitialRemainingTimeChange`.
`main.go:43-58` has the uninstalled-schema fallback
(`NewSettingsSchemaSourceFromDirectory`) and the port reproduces it, with
`rake schema:compile` for a checkout.

## assets/resources/style.css — the stylesheet

→ `lib/style.rb` (**exists**; a `Gtk::CssProvider` loaded at application priority)

| Class | What it does |
|---|---|
| `boxed-list--opaque` | overrides the boxed-list background to `var(--headerbar-bg-color)`, which is otherwise slightly transparent |
| `dial__display` | `font-feature-settings: "tnum"` so the digits do not jitter |
| `dial__display--alarming` | 1s infinite opacity blink, wrapped in `@media (prefers-reduced-motion: no-preference)` |

Upstream ships it inside the GResource, where libadwaita picks it up
automatically.

## Alarm — notification and sound (main_window.go)

→ `lib/alarm.rb` (**exists**)

On entering `alarming`: dial set to 0 and made insensitive, blink class added, a
high-priority `Gio::Notification` titled "Session Finished" / "Time to take a
break" with default action `app.stopAlarmPlayback`, `alarm-clock-elapsed.oga`
seeked and played, and a high-priority accessibility announcement. On stopping:
all of it undone and the notification withdrawn.

## Background portal (main_window.go)

→ `lib/background_portal.rb` (**exists**)

While counting down or alarming, upstream calls the XDG background portal
through `github.com/rymdport/portal/background` to request permission to keep
running with reason "Running the Timer in the Background", sets the
background-apps status to "Timer Running" / "Session Finished", then `app.Hold()`
+ `hide-on-close = true`. Cleared and `app.Release()`d on stop. The port makes
the same two D-Bus calls by hand.

## assets/resources/index.go — app constants

→ `lib/resources.rb` (**exists**)

App ID `com.pojtinger.felicitas.Sessions`, version `0.1.20`, developers, artists,
copyright, resource paths and the `last-position` key name.

## po/ — translation catalogues

→ `po/` (**exists**: 26 `.po` files, `sessions.pot` with 33 messages)

bn, ca, cs, de, en_GB, en_US, es, et, fi, fr, fr_CA, hi, hr, hu, ia, oc, pl, pt,
pt_BR, ru, sv, tr, uk, vi, zh_Hans, zh_Hant. Every user-visible string above is
translated, including the desktop keywords and the GSettings summary and
description. Detail in `TRANSLATION_PARITY.md`.

## main.go — entry point

→ `exe/sessions` + `lib/sessions.rb` (**exists**)

i18n init, GResource registration, settings construction, `Application.Run`. The
GResource half has no equivalent — the port reads its data from `data/`.

## Packaging and metadata (not `lib/`)

`assets/meta/com.pojtinger.felicitas.Sessions.desktop.in`,
`assets/resources/metainfo.xml.in`, `icon.svg` / `icon-alt.svg` /
`icon-symbolic.svg` and `index.gschema.xml` are all present under `data/` and
installed by `rake install_data` and flake.nix's `installPhase`.

`go.mod`, `go.sum`, `modules.txt`, `go.mod.json`, `sessions.doap`, `LICENSE` and
`README.md` carry no components.

---

## Blockers

Two components upstream ships and the port does not. Both are open rows in
`COMPONENT_PARITY.md`; neither is out of scope, because upstream set the scope by
shipping them.

1. **The Qt/QML frontend is not ported.** `qt/main.go` (46 lines) and
   `qt/main.qml` (52 lines), both counted with `wc -l` against `origin/main`
   this round, are a Kirigami *skeleton* of this same app:
   `Kirigami.ApplicationWindow` 360×360, a `ColumnLayout` with a static
   `analogTimeLabel` reading "05:00" and `minusButton` / `actionButton` /
   `plusButton`. Read, it does nothing: no QML binding touches the label, no
   button declares `onClicked`, nothing is exposed to QML from Go, and
   `qt/main.go` builds `state.NewStateMachine` with all seven hooks returning
   `nil`. It is a layout sketch, not a second working frontend, so the gap it
   leaves is four untranslated controls that respond to nothing. Porting it means
   a second toolkit and a binding set (qml-ruby or ruby-qml) that is not in this
   flake. Unassigned, and the lowest-value row in this file.

2. **No Flatpak manifest.** Upstream's `com.pojtinger.felicitas.Sessions.json`
   builds Go with `org.freedesktop.Sdk.Extension.golang`; there is no equivalent
   Ruby SDK extension, so a Ruby manifest has to build Ruby and the ruby-gnome C
   extensions from pinned sources inside the manifest. Not written. The *install*
   half of the gap is closed (`rake install_data`, `flake.nix`).

Binding limitations that shape *how* a component was ported, rather than whether
it was, live in `FINDINGS.md`: no `snapshot` vfunc override (hence the
`Gtk::DrawingArea` dial), `update_property` raising `NotImplementedError` (hence
the `Gtk::Builder` snippet for the accessible row), `Adwaita::Application` being
broken (hence `Gtk::Application` + `Adwaita.init`), and
`adw_about_dialog_new_from_appdata` needing a resource path (hence
`lib/metainfo.rb`).
