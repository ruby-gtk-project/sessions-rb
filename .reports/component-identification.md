# Component identification — sessions

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` (62 files, Go + puregotk + blueprint) |
| Port | `ruby` @ `4f87634` |
| Scanned | 2026-11-02 |
| Scan tool | `.claude/skills/component-identification/scripts/component-scan.sh` |

This supersedes `.reports/component-inventory.md`, which was written against the
three-file skeleton and describes a port that no longer exists. Everything it
listed as "missing" has since been built; what follows is the inventory of both
sides as they stand, so `component-parity.md` can be joined against it.

## Step 1 — declarative files

Upstream has two: `assets/resources/window.blp` (the whole window tree plus the
primary menu) and `assets/resources/shortcuts-dialog.blp`. Both are compiled by
`blueprint-compiler` into `window.ui` / `shortcuts-dialog.ui` and bundled into
`index.gresource`. Two template roots:

```
template $SessionsMainWindow: Adw.ApplicationWindow   -> lib/main_window.rb
Adw.ShortcutsDialog shortcuts_dialog                  -> lib/shortcuts_dialog.rb
```

The port has none, by design of the house style — every widget is a memoized
method. Verified: `find . -name '*.ui' -o -name '*.blp'` is empty on `ruby`.

## Step 2 — the scan

```
component-scan.sh <upstream>  ->  24 rows
component-scan.sh <port>      ->  55 rows   (.claude/skills/ excluded)
```

### Upstream

| File | Kind | Value | × |
|---|---|---|---:|
| `assets/resources/window.blp` | widget | `Adw.ApplicationWindow` | 1 |
| | widget | `Adw.ToolbarView` | 1 |
| | widget | `Adw.HeaderBar` | 1 |
| | widget | `Adw.WindowTitle` | 1 |
| | widget | `Gtk.MenuButton` | 1 |
| | widget | `Gtk.Box` | 4 |
| | widget | `Gtk.Overlay` | 1 |
| | widget | `Gtk.ListBox` | 1 |
| | widget | `Gtk.ListBoxRow` | 1 |
| | widget | `Gtk.Label` | 1 |
| | widget | `Gtk.Button` | 3 |
| | css | `boxed-list`, `boxed-list--opaque`, `circular` ×2, `dial__display`, `pill`, `suggested-action`, `title-1` | |
| | action | `app.shortcuts` | 1 |
| `assets/resources/shortcuts-dialog.blp` | widget | `Adw.ShortcutsDialog` | 1 |
| | type | `Adw.ShortcutsSection` | 2 |
| | type | `Adw.ShortcutsItem` | 7 |
| | action | `app.shortcuts`, `app.quit` | |

The scan reads blueprint only. Everything behavioural in this app is in the Go
sources, which `component-scan.sh` does not scan at all (no `.go` in its
`find`), so the rest of this inventory is read by hand from
`internal/components/*.go`. **Scanner defect, reported below.**

### Upstream, read by hand

`internal/components/main_window.go`:

| Facet | Detail |
|---|---|
| Actions installed on the window | `toggleTimer`, `addTime`, `removeTime`, `closeWindow` (`gio.NewSimpleAction`) |
| Action installed on the *application* | `stopAlarmPlayback` — so the notification can activate it with no window focused |
| Accelerators | `win.closeWindow`=`<Primary>w`; `win.toggleTimer`=`<Primary>space`; `win.addTime`=`<Primary>plus`,`<Primary>equal`; `win.removeTime`=`<Primary>minus` |
| Non-widget objects | `gtk.MediaFile` for `alarm-clock-elapsed.oga`; `gio.Notification`; `gobject.Binding` (`remaining-time` → label `label`, with a `%02d:%02d` transform, `SYNC_CREATE`) |
| Runtime CSS | `dial__display--alarming` added/removed on the label; `destructive-action`/`suggested-action` swapped on `action_button` |
| Runtime label/icon | `action_button` switches `_Start Timer`/`media-playback-start-symbolic` ↔ `_Stop`/`media-playback-stop-symbolic` |
| Accessibility | `window.label.Announce("Session Finished", HIGH)`; `timer_row` carries `accessibility { label: _("Remaining Time") }` from the blueprint |
| Portal | `background.RequestBackground` + `background.SetStatus`, then `app.Hold()` + `SetHideOnClose(true)` |
| State hooks | 7: `OnStartTimer`, `OnStopTimer`, `OnInitialRemainingTimeChange`, `OnCurrentRemainingTimeTick`, `OnStartAlarm`, `OnStopAlarm`, `OnPermittedTriggersChange` |

`internal/components/application.go`:

| Facet | Detail |
|---|---|
| Actions | `app.openAbout`, `app.quit` |
| Accelerators | `app.shortcuts`=`<Primary>question`, `app.quit`=`<Primary>q` |
| About dialog | `adw.NewAboutDialogFromAppdata(metainfo.xml, "0.1.20")` + `SetDevelopers`, `SetArtists`, `SetCopyright`, `SetTranslatorCredits(L("translator-credits"))` |
| `activate` | re-`Present()`s the existing window instead of building a second one |

**Upstream defect worth carrying:** `app.shortcuts` has an accelerator and a
menu item, but no `SimpleAction` named `shortcuts` is ever installed and
`ResourceShortcutsDialogUIPath` is never loaded. On `origin/main` the shortcuts
dialog is unreachable. The port installs the action — a correspondence that
improves on upstream, recorded so nobody reads it as an extra.

`internal/components/dial.go` — `SessionsDial`, a direct `Gtk.Widget` subclass:

| Facet | Detail |
|---|---|
| Properties | `remaining-time` (int, 0…3600, default 300), `counting-down` (bool, default false); both `QueueDraw` on set |
| Signals defined | `drag-begin`, `drag-end` |
| Controllers | `Gtk.GestureDrag` (`drag-begin`, `drag-update`, `drag-end`), `Gtk.GestureClick` (`pressed`) |
| Signals consumed | `AdwStyleManager::notify` → `QueueDraw` |
| Hit test | 15px dead zone at the centre; `atan2` angle → one of 120 intervals × 30s; interval 0 means a full hour |
| Drawing | 10px track circle (sampled `#343437` dark / `#D8D8D8` light; `destructive_color` @ 0.5 over `window_bg_color` when insensitive), filled wedge (`error_color` @ 0.3 counting down, grey @ 0.2 idle), 10px round-capped arc, 8px handle; high contrast adds a `window_fg_color` @ 0.5 hairline on every shape plus ±5px arcs and a start cap |
| Edge case | the arc is skipped when `counting-down && remaining == 0` |

`pkg/state/machine.go` + `constants.go` — four states (`stopped`, `dragging`,
`countingDown`, `alarming`), eight triggers (two of them private:
`stopDragging`, `timerFinished`), guards on ±30s and on the dragged value's
divisibility, a 1s ticker, and `DefaultInitialRemainingTime` 5min /
`RemainingTimerAdjustmentInterval` 30s / `MinInitialRemainingTime` 30s /
`MaxInitialRemainingTime` 1h.

Non-code component sources: `assets/resources/index.gschema.xml` (one key,
`last-position`, int64, default 300), `assets/resources/style.css` (three
classes), `assets/meta/*.desktop.in`, `assets/resources/metainfo.xml.in`
(9 `<url>` kinds, 21 `<release>` entries, branding colours), `po/` (26 `.po`).

### Port

| File | Kind | Value | × |
|---|---|---|---:|
| `lib/main_window.rb` | widget | `Adw.ApplicationWindow`, `Adw.ToolbarView`, `Adw.HeaderBar`, `Adw.WindowTitle`, `Gtk.MenuButton`, `Gtk.Overlay`, `Gtk.ListBox`, `Gtk.ListBoxRow`, `Gtk.Label` | 1 each |
| | widget | `Gtk.Box` | 4 |
| | widget | `Gtk.Button` | 3 |
| | css | `boxed-list`, `boxed-list--opaque`, `circular` ×2, `dial__display`, `pill`, `suggested-action`, `destructive-action`, `title-1` | |
| | action | `toggleTimer`, `addTime`, `removeTime`, `closeWindow`, `stopAlarmPlayback` | 1 each |
| `lib/dial.rb` | widget | `Gtk.DrawingArea` | 1 |
| | controller | `Gtk.GestureDrag`, `Gtk.GestureClick` | 1 each |
| | signal | `drag-begin`, `drag-update`, `drag-end`, `pressed`, `notify` | 1 each |
| `lib/application.rb` | action | `shortcuts`, `openAbout`, `quit` | 1 each |
| | signal | `activate` | 4 |
| `lib/shortcuts_dialog.rb` | widget | `Adw.ShortcutsDialog` | 1 |
| | type | `Adw.ShortcutsSection`, `Adw.ShortcutsItem` | built in a loop: 2 sections, 7 items |
| `lib/about_dialog.rb` | widget | `Adw.AboutDialog` | 1 |
| `lib/alarm.rb` | type | `Gtk.MediaFile`, `Gio::Notification` | 1 each |
| `lib/style.rb` | type | `Gtk.CssProvider` | 1 |
| `lib/main_menu.rb` | type | `Gio::Menu` | 2 (menu + section) |
| `lib/background_portal.rb` | — | raw `Gio::DBusConnection` calls to `org.freedesktop.portal.Background` | |
| `lib/state_machine.rb` | — | one transition table, 7 hooks, `GLib::Timeout` ticker | |
| `lib/settings.rb` | — | JSON file under `XDG_CONFIG_HOME`, not `Gio::Settings` | |

The port's `Adwaita::ShortcutsSection`/`ShortcutsItem` counts in the raw scan
(1 and 2) are **wrong** — they are repeater sites, not instances. `SECTIONS` is
a frozen hash of 2 sections holding 7 items, built by `each`. Corrected by
reading, per the repeater rule.

The port's `Adw.ApplicationWindow 3` / `Gtk.ApplicationWindow 1` /
`Adw.Dialog 1` / `Adw.Application 1` rows in `lib/main_window.rb` are prose
inside the file header comment, not constructed widgets. One
`Adwaita::ApplicationWindow` is built. Same for `lib/dial.rb`'s
`Gtk.DrawingArea 2` (one construction, one comment) and
`Gtk.GestureDrag 2` (one construction, one `signal_connect` block arg).

## File mapping

```
assets/resources/window.blp + internal/components/main_window.go  -> lib/main_window.rb
assets/resources/window.blp (menu main_menu)                      -> lib/main_menu.rb
assets/resources/shortcuts-dialog.blp                             -> lib/shortcuts_dialog.rb
internal/components/application.go                                -> lib/application.rb
internal/components/application.go + metainfo.xml.in              -> lib/about_dialog.rb
internal/components/dial.go                                       -> lib/dial.rb
internal/components/main_window.go (alarm hooks)                  -> lib/alarm.rb
internal/components/main_window.go (portal calls)                 -> lib/background_portal.rb
pkg/state/machine.go + pkg/state/constants.go                     -> lib/state_machine.rb
assets/resources/index.gschema.xml                                -> lib/settings.rb  (+ data/*.gschema.xml, unused)
assets/resources/style.css                                        -> lib/style.rb
assets/resources/index.go                                         -> lib/resources.rb
main.go                                                           -> exe/sessions + lib/sessions.rb + lib/sessions/application.rb
assets/meta/*.desktop.in, metainfo.xml.in, icon*.svg, *.oga        -> data/
po/*.po, po/sessions.pot                                          -> (nothing)
com.pojtinger.felicitas.Sessions.json, .github/workflows/flatpak.yaml -> (nothing)
qt/main.go + qt/main.qml                                          -> (nothing)
```

Every upstream file on the left has a port file opposite it except the last
three groups. Those three are carried into `component-parity.md` and
`translation-parity.md` as gaps.

## Scanner defects found

1. **`component-scan.sh` scans no `.go` files.** Its `find` takes
   `*.vala *.c *.py *.js *.ts *.rs *.rb *.cpp`. Against a Go/puregotk upstream
   it returns only the blueprint rows — 24 of them — and silently reports zero
   actions, zero signals, zero controllers and zero runtime CSS for an app whose
   entire behaviour is in Go. Everything in "read by hand" above exists only
   because the scan was not trusted. Fix: add `-o -name '*.go'` and a Go arm to
   the type/signal/action matchers.
2. **`component-scan.sh` counts comment text as widgets.** `Adw.Dialog`,
   `Gtk.ApplicationWindow` and `Adw.Application` appear in the port's rows
   purely from the file header comments. Fix: skip `#`-leading lines in Ruby,
   as `test-census.sh` already does.
