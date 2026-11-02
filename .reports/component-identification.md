# Component identification — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` (Go + puregotk, blueprint UI compiled into a GResource) |
| Port | `ruby` @ `14fcee4` |
| Symbol table | `.claude/skills/component-identification/scripts/symbols.tsv` (built in the port's `nix develop` shell) |
| Scans | `component-scan.sh` over a `git archive` of `origin/main` and over the working tree, then every file read |
| Round | six — re-run from scratch for this audit, not inherited |

Step 1 of the skill first. Upstream's declarative UI is two blueprint files:

```
assets/resources/window.blp              1 template root + 1 menu block
assets/resources/shortcuts-dialog.blp    1 top-level NAMED object, not a template
```

`shortcuts-dialog.blp` declares `Adw.ShortcutsDialog shortcuts_dialog { … }` at
column zero — a named root, not `template $Foo:`. Matching `template` alone
finds one of the two declarative units, i.e. half the declarative UI. The port
has no `.blp`/`.ui` at all, as the house style requires, so its side is
scan-plus-reading throughout.

---

## Unit list

Six units, in the order a user meets them.

| # | Unit | Upstream files | Port file(s) |
|---|---|---|---|
| 1 | application object | `main.go`, `internal/components/application.go`, `internal/components/constants.go` | `lib/application.rb`, `lib/translations.rb`, `lib/resources.rb`, `lib/settings.rb`, `lib/style.rb`, `exe/sessions` |
| 2 | main window | `internal/components/main_window.go` + `assets/resources/window.blp` | `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb` |
| 3 | primary menu | the `menu main_menu` block of `window.blp` | `lib/main_menu.rb` |
| 4 | dial | `internal/components/dial.go` | `lib/dial.rb` |
| 5 | shortcuts dialog | `assets/resources/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` |
| 6 | about dialog | `application.go:76-92` + `assets/resources/metainfo.xml.in` | `lib/about_dialog.rb`, `lib/metainfo.rb` |

Non-widget units that still carry behaviour:

| Upstream | Port |
|---|---|
| `pkg/state/machine.go`, `pkg/state/constants.go` | `lib/state_machine.rb`, `lib/ticker.rb` |
| `assets/resources/style.css` | `lib/style.rb` |
| `assets/resources/index.gschema.xml` | `data/com.pojtinger.felicitas.Sessions.gschema.xml` + `lib/settings.rb` |

**A seventh unit exists upstream and has no port counterpart at all:** the
Qt/Kirigami frontend, `qt/main.go` (46 lines, `miqt/qt6` + `qml`) and
`qt/main.qml` (52 lines, `Kirigami.ApplicationWindow` → `ColumnLayout` → one
`Controls.Label` + three `Controls.Button`). The scan produces **no rows** for
either file — the regexes know GTK and libadwaita, not QtQuick — so it is
invisible to the TSV and had to be found by reading `git ls-tree`. It drives the
same `pkg/state` machine the port already has. It is counted as a gap in
`component-parity.md`, not as a unit with parity.

---

## Scan totals

A map of how much app there is, not an inventory to act on. Upstream's raw scan
is 4253 rows, almost all of it noise: the 26 `.po` files carry `#:` source
references that the CSS and signal regexes match. Scoped to the six source
files that actually build UI:

| | widget | css | signal | action | controller | type |
|---|---:|---:|---:|---:|---:|---:|
| upstream (6 files, scoped) | 35 | 10 | 9 | 16 | 2 | 12 |
| port (`lib/`, 7 files with rows) | 14 | 8 | 7 | 13 | 2 | 9 |

Per file:

```
upstream                                      port
assets/resources/shortcuts-dialog.blp   5     lib/about_dialog.rb       2
assets/resources/window.blp            19     lib/alarm.rb              1
internal/components/application.go     12     lib/application.rb        5
internal/components/dial.go            16     lib/dial.rb               9
internal/components/main_window.go     28     lib/main_window.rb       29
main.go                                 4     lib/shortcuts_dialog.rb   5
                                              lib/style.rb              2
```

The widget-row difference is not a parity gap and must not be read as one.
Upstream's 35 widget rows include its `gobject.TypeRegisterStaticSimple`
plumbing — `Adw.ApplicationGLibType()`, `Gtk.WidgetGLibType()`,
`gtk.NewMediaFileForResource`, `gio.NewSettingsFull`, `gtk.WidgetClass`,
`gtk.Snapshot` — none of which the Ruby bindings need. The reverse under-report
is real and listed below.

---

## What the scan under-reports, resolved by reading

Every one of these was followed into the source; none is left as "the scan
says".

| Shape | Where | Resolution |
|---|---|---|
| **Repeaters** | `lib/shortcuts_dialog.rb#sections` | 1 scan row → **2** `Adw::ShortcutsSection` and **7** `Adw::ShortcutsItem` on screen, driven by the literal table in `#sections`. Upstream's blueprint spells all nine out. |
| **Repeaters** | `lib/main_menu.rb#items` | 1 row → 2 `Gio::Menu` items. |
| **Repeaters** | `lib/about_dialog.rb#links` | 1 `add_link` call site → **4** link rows. |
| **Shared factory** | `lib/shortcuts_dialog.rb#item` | one `Adwaita::ShortcutsItem.new` → 7 widgets. Count the call sites in `#sections`, not the constructor. |
| **Widget built from a Builder snippet** | `lib/main_window.rb:58-68`, `#timer_row` | `Gtk::ListBoxRow` + its `<accessibility><property name="label">` come from a one-object `TIMER_ROW_UI` heredoc, so no `Gtk::ListBoxRow.new` exists to match. The scan sees nothing; the widget and its accessible label are both real. |
| **CSS class behind a constant** | `lib/main_window.rb:345,355` | `Style::ALARMING_CLASS`, not the literal `"dial__display--alarming"`. The scan's `css` stream misses it on the port side; `lib/style.rb:62` defines it. |
| **Actions built from a hash** | `lib/main_window.rb:70-75`, `lib/application.rb:34-37` | Accelerator names live as hash keys in `ACCELERATORS`; the action names are literal in the `SimpleAction.new` calls, so these happen to survive, but the `action` stream was still re-derived by opening every `add_action` / `SimpleAction.new` site. 13 port rows vs 16 upstream — the difference is upstream repeating `app.shortcuts`, `win.addTime` etc. across both `SetAccelsForAction` and the `.blp`. |
| **Dial drawing** | `lib/dial.rb` | Nine rows for a widget whose whole identity is ~200 lines of Cairo. The shapes are not components the scan can see; they are compared shape-by-shape in `component-parity.md` Unit 4. |
| **Controllers** | both sides | 2 and 2: `Gtk::GestureDrag`, `Gtk::GestureClick`. Compared on the signal axis of the dial, never in the widget count. |
| **Menu model** | `window.blp:124-137` | All-lowercase blueprint keywords, so zero scan rows. Counted by hand: 1 `section`, 2 `item`, no `custom:` slots. |
| **Upstream's own GObject subclasses** | `SessionsApplication`, `SessionsMainWindow`, `SessionsDial` | None is a GTK type, so none is a row. All three are real component boundaries and all three have a port file. |

---

## Dead code found upstream, and what it means for the port

`app.shortcuts` **is never installed upstream.** `git grep -n shortcut
origin/main` returns the accelerator
(`application.go:111: SetAccelsForAction("app.shortcuts", …)`), the menu item
(`window.blp:130`), the resource path constant
(`index.go:36: ResourceShortcutsDialogUIPath`), the gresource entry, and the
nine strings in `shortcuts-dialog.blp`. **No `gio.NewSimpleAction("shortcuts",
…)` exists anywhere in the Go tree**, and nothing loads
`ResourceShortcutsDialogUIPath`. So upstream ships a shortcuts dialog that
cannot be opened: the menu item is insensitive and `<Primary>?` does nothing.

Consequence for the inventory: unit 5 is a component that exists in upstream's
*resources* and not in upstream's *running app*. The port installs the action
(`lib/application.rb:66,81`) and presents the dialog, which is an **extra** —
correctly labelled as one in `component-parity.md`, and the only reason unit 5
is reachable at all.

---

## Inventory

### 1 — `main.go` + `internal/components/application.go` → the application object

| Item | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` subclass (`SessionsApplication`) | 1 | — | `activate` (vfunc override) | returns early and re-presents on a second activation |
| `Gio.SimpleAction` `openAbout` | 1 | — | `activate` → `aboutDialog.Present(window)` | |
| `Gio.SimpleAction` `quit` | 1 | — | `activate` → `Application.Quit()` | |
| `Adw.AboutDialog` | 1 | — | — | built by `NewAboutDialogFromAppdata`; see unit 6 |
| accel `app.shortcuts` → `<Primary>question` | 1 | — | — | points at an action upstream never installs |
| accel `app.quit` → `<Primary>q` | 1 | — | — | |
| `Gio.Settings` | 1 | — | — | two construction paths, keyed on `SchemaDir == ""` |
| gettext init | 1 | — | — | domain `sessions`, `LocaleDir` a link-time variable |
| `Gio.Resource` registration | 1 | — | — | the whole GResource bundle |

Repeaters: none. Conditional: the settings construction path.

### 2 — `assets/resources/window.blp` + `internal/components/main_window.go` → the main window

| Widget | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | — | 360×380, title `Sessions` |
| `Adw.ToolbarView` | 1 | — | — | `[top]` header bar, `content` box |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | `Sessions` |
| `Gtk.MenuButton` | 1 | — | `menu-model: main_menu` | `open-menu-symbolic`, `primary: true`, tooltip `Main Menu` |
| `Gtk.Box` | 4 | — | — | content (vertical), dial pane (vertical, spacing 12, valign centre, vexpand, margins 12), `dial_area` (260×260), button pane (horizontal, spacing 12, halign centre, margins 12) |
| `Gtk.Overlay` | 1 | — | — | `dial_area` is the child, the list box the overlay |
| `Gtk.ListBox` | 1 | `boxed-list`, `boxed-list--opaque` | `selection-mode: none` | halign/valign centre |
| `Gtk.ListBoxRow` | 1 | — | `activatable: false` | accessible label `Remaining Time` |
| `Gtk.Label` | 1 | `title-1`, `dial__display`, `dial__display--alarming` (dynamic, added while alarming) | bound to the dial's `remaining-time` through a transform function | `05:00`, margins 12; `Announce(…, HIGH)` on alarm |
| `Gtk.Button` minus | 1 | `circular` | `win.removeTime` | `list-remove-symbolic`, tooltip `Remove 30 seconds`, valign centre |
| `Gtk.Button` action | 1 | `pill`, `suggested-action` ⇄ `destructive-action` (dynamic) | `win.toggleTimer` | icon + label `_Start Timer` / `_Stop`, `use-underline` |
| `Gtk.Button` plus | 1 | `circular` | `win.addTime` | `list-add-symbolic`, tooltip `Add 30 seconds`, valign centre |
| `Gio.SimpleAction` | 5 | — | `activate` ×5 | `toggleTimer`, `addTime`, `removeTime`, `closeWindow` on the window; `stopAlarmPlayback` on the **application** |
| `Gtk.MediaFile` | 1 | — | — | `NewMediaFileForResource(alarm-clock-elapsed.oga)` |
| `Gio.Notification` | 1 | — | default action `app.stopAlarmPlayback` | `Session Finished` / `Time to take a break`, priority HIGH, id `session-finished` |
| accels | 4 | — | — | `win.closeWindow`→`<Primary>w`, `win.toggleTimer`→`<Primary>space`, `win.addTime`→`<Primary>plus` **and** `<Primary>equal`, `win.removeTime`→`<Primary>minus` |
| background portal | 1 | — | — | `RequestBackground(reason)` then `SetStatus(message)`; `app.Hold()` + `SetHideOnClose(true)` only once granted |

Repeaters: none. Conditional: the portal dance runs only when `!held`;
`dial__display--alarming` only while alarming; the action button's appearance
switches on the permitted-trigger set.
Error states: a portal error and a portal denial are both logged and the app
stays in the foreground. Thirteen `log.Error` sites cover every refused
transition.

### 3 — the `menu main_menu` block → the primary menu

| Item | × | Action | Text |
|---|---:|---|---|
| `section` | 1 | — | — |
| `item` | 1 | `app.shortcuts` | `_Keyboard Shortcuts` |
| `item` | 1 | `app.openAbout` | `_About Sessions` |

No `custom:` slots. Mnemonics are inside the msgid on both sides.

### 4 — `internal/components/dial.go` → the dial

| Facet | Value |
|---|---|
| Type | `Gtk.Widget` subclass (`SessionsDial`) overriding `snapshot`, drawing with `Gsk.PathBuilder` |
| Properties | `remaining-time` (`ParamSpecInt`, 0…3600, default 300), `counting-down` (`ParamSpecBoolean`, default false) |
| Signals it defines | `drag-begin`, `drag-end` (`SignalNewv`, RUN_FIRST, no args) |
| Controllers | `Gtk.GestureDrag` (`drag-begin`, `drag-update`, `drag-end`), `Gtk.GestureClick` (`pressed`) |
| Signals it consumes | `notify` on `Adw.StyleManager` → `QueueDraw` |
| CSS | none of its own |
| Geometry | `r = min(cx,cy) − 15`; 10px track; 8px handle; 15px dead zone; 120 intervals of 30s; `intervals == 0` means a full hour |
| Colours | `accent_bg_color`, `error_color`, `destructive_color`, `window_bg_color`, `window_fg_color` looked up per frame; track is a hand-sampled grey (`#343437` dark / `#D8D8D8` light) |
| Conditional shapes | insensitive → track becomes destructive·0.5 over window-bg; `countingDown && remaining == 0` → arc skipped entirely; high contrast → **six** extra hairlines (outer r+5 ring, inner r−5 ring, outer r+5 arc, inner r−5 arc, the start cap, the handle) **plus** a stroke of the filled wedge (or of the full fill ring when the arc closes) |

### 5 — `assets/resources/shortcuts-dialog.blp` → the shortcuts dialog

| Widget | × | Text | Notes |
|---|---:|---|---|
| `Adw.ShortcutsDialog` | 1 | — | no title set; libadwaita supplies its own, already translated |
| `Adw.ShortcutsSection` | 2 | `General`, `Timer` | |
| `Adw.ShortcutsItem` | 7 | `Open menu`, `Show keyboard shortcuts`, `Close window`, `Quit`, `Start or stop timer`, `Add 30 seconds`, `Remove 30 seconds` | 1 literal accelerator (`F10`), 6 resolved from action names |

Empty state: libadwaita's own "no results" status page, reached by typing into
the dialog's search entry. Unreachable in upstream's build (see above).

### 6 — `application.go:76-92` + `metainfo.xml.in` → the about dialog

Upstream builds this with `adw_about_dialog_new_from_appdata(path, version)`.
Per `Adw-1.gir` (libadwaita 1.9.3) that constructor sets **exactly nine**
things: `application-icon`, `application-name`, `developer-name`, `version`,
`website` (from `<url type="homepage">`), `support-url` (`help`), `issue-url`
(`bugtracker`), `license-type` (`<project_license>`), and
`release-notes`/`release-notes-version`. Upstream then sets `developers`,
`artists`, `copyright` and `translator-credits` by hand.

| Row | Source |
|---|---|
| name, icon, version, developer name | appdata |
| developers (2), artists (2), copyright | `index.go` constants, set by hand |
| licence `AGPL-3.0-or-later` | `<project_license>` |
| release notes for 0.1.20 | appdata, `translate="no"` |
| website / support / issue rows | appdata urls |
| translator credits | `L("translator-credits")` |
| **comments / description** | **not set** — `new_from_appdata` does not touch `comments` |
| **link rows** | **none** — the constructor adds no `add_link` rows, and nothing in `application.go` calls `AddLink` |

The `<url type="donation">`, `translate`, `vcs-browser`, `contribute`,
`contact` and `faq` entries in the metainfo are therefore **consumed by nothing
in upstream's About dialog.** They exist for AppStream stores. That matters for
unit 6's parity verdict and is the one place where round five's inventory was
wrong; see `component-parity.md`.

---

## Files that belong to no unit

Carried for completeness, each with a verdict rather than a shrug:

| Upstream | Port | Verdict |
|---|---|---|
| `LICENSE` | `LICENSE.md` (34 523 bytes, AGPL v3 text) | **present** — closed since round five |
| `assets/meta/icon{,-alt,-symbolic}.svg` | `data/com.pojtinger.felicitas.Sessions{,-alt,-symbolic}.svg` | `cmp`-identical |
| `assets/resources/alarm-clock-elapsed.oga` | `data/alarm-clock-elapsed.oga` | `cmp`-identical |
| `assets/meta/*.desktop.in` | `data/com.pojtinger.felicitas.Sessions.desktop.in` | `diff`-identical |
| `assets/resources/metainfo.xml.in` | `data/com.pojtinger.felicitas.Sessions.metainfo.xml.in` | `diff`-identical |
| `assets/resources/index.gschema.xml` | `data/com.pojtinger.felicitas.Sessions.gschema.xml` | `diff`-identical |
| `po/*.po` (26) | `po/*.po` (26) | all 26 `cmp`-identical |
| `com.pojtinger.felicitas.Sessions.json` | — | **gap** |
| `.github/workflows/flatpak.yaml` | — | **gap** (`.github/workflows/` does not exist in the port) |
| `qt/main.go`, `qt/main.qml` | — | **gap** |
| `sessions.doap` | — | **gap** |
| `assets/meta/screenshot-{initial,running}.png` | — | **gap**; the port's metainfo cites them from `raw.githubusercontent.com/pojntfx/sessions` |
| `README.md` (overview, tutorial, build instructions) | `README.md` (gem-template boilerplate) | **gap** — the port's metainfo `<url type="faq">` points at upstream's README `#tutorial`, a section the port's README does not have |
| `go.mod`, `go.sum`, `go.mod.json`, `modules.txt` | `Gemfile`, `nix/Gemfile`, `gemset.nix`, `flake.nix` | build-system correspondence |

## Rules observed

- No widget type is listed without its CSS classes and its signals.
- No scan row was struck as "not a widget" without opening the file; the
  symbol table did the mechanical part and every unknown row was read.
- Dynamic CSS classes are listed with every value they can take:
  `dial__display--alarming`, and `suggested-action` ⇄ `destructive-action`.
- Where a widget's handler is the only thing it does, the handler is named.
