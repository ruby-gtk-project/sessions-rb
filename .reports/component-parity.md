# Component parity — sessions

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `4f87634` |
| Units with parity | **0 / 12** |
| Checks not run | Step 4 (screenshot) and Step 5 (drive the signals) — **neither was run**, see below |

## The two checks that did not run

`gtk4` is not loadable in this environment (`require 'gtk4'` → `LoadError`,
both bare and under `bundle exec`). So:

- **Nothing in this port has ever been rendered.** No screenshot exists for any
  unit. Every CSS row below is a reading of `add_css_class`, not of a pixel.
- **No signal in this port has ever been fired.** Every Behaviour row below is a
  reading of `signal_connect`, which the skill says explicitly is not a working
  signal.

Three binding call sites are therefore unverified and each one fails silently
or loudly on first run. They are listed as gaps because an unverified
correspondence is a gap:

| Call | File | What happens if the bindings disagree |
|---|---|---|
| `Gtk::CssProvider#load(string: CSS)` | `lib/style.rb:69` | ruby-gnome's `load` takes `:data`/`:file`/`:path`/`:resource`. If `:string` is not accepted this raises on startup, unrescued, and the app never opens. If it silently no-ops, `.boxed-list--opaque` and `.dial__display--alarming` do nothing: the time card is translucent and the alarm never blinks |
| `Gtk::MediaFile.new(path)` | `lib/alarm.rb:65` | `Gtk::MediaFile.new` takes no arguments in ruby-gnome; the file constructor is `for_filename`. A wrong signature raises `ArgumentError`, which the `rescue StandardError` on line 66 swallows into a `warn` and returns `nil` — so the alarm sound is **silently** never played, for the lifetime of the port, and the only symptom is a line on stderr |
| `Gtk::Label#announce(message, :high)` | `lib/main_window.rb:428` | wrapped in `rescue StandardError` on line 429. If `announce` is not exposed, a screen-reader user is never told the session finished, and nothing in the UI says so |

Two of those three rescues convert a missing feature into a warning on stderr.
That is the mechanism this whole report exists to catch, and it is in the code
rather than in prose.

---

## Unit: main window — `assets/resources/window.blp` + `internal/components/main_window.go` → `lib/main_window.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `win.toggleTimer`, `win.addTime`, `win.removeTime`, `win.closeWindow` installed; `hide-on-close` toggled | ✗ | **gap**: `_("Sessions")` built as bare `'Sessions'` via `Resources::APP_NAME` |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✗ | **gap**: `_("Sessions")` unmarked |
| `Gtk.MenuButton` | 1 | 1 | — | ✓ `menu-model`, `primary: true` (F10) | ✗ | **gap**: `_("Main Menu")` tooltip unmarked |
| `Gtk.Box` | 4 | 4 | — | — | — | parity |
| `Gtk.Overlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list`, `boxed-list--opaque` | ✓ `selection-mode: none` | — | parity |
| `Gtk.ListBoxRow` | 1 | 1 | — | ✓ `activatable: false` | ✗ | **gap**: upstream sets `accessibility { label: _("Remaining Time") }` (`window.blp:53-55`). `lib/main_window.rb:190-194` sets only `activatable`. The row has no accessible name at all |
| `Gtk.Label` | 1 | 1 | ✓ `title-1`, `dial__display`, `dial__display--alarming` | ✓ updated from the dial's change callback instead of a property binding — correspondence, `lib/main_window.rb:258` | ✗ | **gap**: upstream's default label is `_("05:00")` (`window.blp:58`); the port computes `format_time(300)` and emits no msgid |
| `Gtk.Button` (minus) | 1 | 1 | ✓ `circular` | ✓ `win.removeTime` | ✗ | **gap**: `_("Remove 30 seconds")` unmarked |
| `Gtk.Button` (action) | 1 | 1 | ✓ `suggested-action`+`pill` ↔ `destructive-action`+`pill` | ✓ `win.toggleTimer`, icon/label swap in upstream's order | ✗ | **gap**: `_("_Start Timer")` and `_("_Stop")` unmarked |
| `Gtk.Button` (plus) | 1 | 1 | ✓ `circular` | ✓ `win.addTime` | ✗ | **gap**: `_("Add 30 seconds")` unmarked |
| `Gtk.MediaFile` | 1 | 1 | — | ✓ seek(0)+play on alarm, playing=false+seek(0) on stop | — | **gap**: constructor unverified, see above |
| `Gio.Notification` | 1 | 1 | — | ✓ high priority, default action `app.stopAlarmPlayback`, withdrawn on stop | ✗ | **gap**: `_("Session Finished")` and `_("Time to take a break")` unmarked |

**Actions and accelerators.** All five actions exist with upstream's exact
names, and all four accelerator sets match byte for byte, including
`win.addTime`'s two accels. `stopAlarmPlayback` is installed on the application,
not the window, as upstream requires.

**Accessibility announcement.** Upstream `main_window.go:276` announces
`"Session Finished"` at high priority. Port `lib/main_window.rb:427-431` calls
it inside a rescue. **gap** until it is driven.

**Background portal.** Upstream calls `background.RequestBackground` and
`background.SetStatus` through a Go portal library. The port writes the D-Bus
calls by hand (`lib/background_portal.rb`), including the handle-token
subscribe-before-call ordering the portal spec asks for. This is the single most
substantial piece of work in the port and it is a genuine correspondence — but
it has never been run against a live portal, so **gap** on the same grounds as
the three calls above. Its two status strings are also unmarked:
`_("Running the Timer in the Background")`, `_("Timer Running")`,
`_("Session Finished")`.

**Error state the port drops.** Upstream logs every failed state transition and
every portal failure through `slog` (`main_window.go` lines 122, 136, 169, 234,
248, 299, 367, 378, 388, 399, 418, 429, 450). The port's
`StateMachine#fire` returns `false` on a denied trigger and **no caller looks at
the return value** (`lib/main_window.rb:109-111`). A press that cannot be
honoured produces nothing at all — no log, no diagnostic. **gap.**

Stylesheet: `.boxed-list--opaque`, `.dial__display` and
`.dial__display--alarming` are byte-identical between
`assets/resources/style.css` and the `CSS` heredoc in `lib/style.rb:24-52`
(diffed, no difference). `circular`, `pill`, `suggested-action`,
`destructive-action`, `title-1` and `boxed-list` are platform classes and need
no rule. The CSS text axis is clean; the **attachment** axis is clean; the
**delivery** axis is the unverified `load(string:)` above.
Messages: 10 upstream, 0 marked in the port. **gap** — all ten rows are open in
`translation-parity.md`.
Driven: nothing. Screenshot: none.

## Unit: primary menu — `assets/resources/window.blp` (`menu main_menu`) → `lib/main_menu.rb`

| Component | Up × | Port × | Signals / actions | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Gio.Menu` section | 1 | 1 | — | — | parity |
| item → `app.shortcuts` | 1 | 1 | ✓ | ✗ | **gap**: `_("_Keyboard Shortcuts")` unmarked |
| item → `app.openAbout` | 1 | 1 | ✓ | ✗ | **gap**: `_("_About Sessions")` unmarked |

Both action names match. Mnemonic underscores are preserved, which matters —
stripping one would also have been a text-axis gap.

## Unit: shortcuts dialog — `assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

| Component | Up × | Port × | Signals / actions | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | ✗ | **gap**: the port sets `title = 'Keyboard Shortcuts'` (`lib/shortcuts_dialog.rb:33`). Upstream sets no title. An invented, unmarked, untranslatable string — see `## Extra` in `translation-parity.md` |
| `Adw.ShortcutsSection` | 2 | 2 | — | ✗ | **gap**: `_("General")`, `_("Timer")` unmarked |
| `Adw.ShortcutsItem` | 7 | 7 | ✗ | ✗ | **gap**, two ways — below |

**The items lost their `action-name`.** Upstream gives six of its seven items
`action-name:` (`shortcuts-dialog.blp` lines 15, 20, 25, 34, 39, 44) and lets
`Adw.ShortcutsItem` resolve the accelerator from the application's accel map.
The port spells literal accelerator strings instead
(`lib/shortcuts_dialog.rb:18-29`). Three consequences, all user-visible:

1. **The displayed modifier is wrong in principle.** Upstream's accels are
   registered as `<Primary>`, which GTK resolves per platform. The port's
   dialog hardcodes `<Control>`. Where the two differ the dialog tells the user
   a key that does not work.
2. **`win.addTime` loses an accelerator.** Upstream registers two —
   `<Primary>plus` and `<Primary>equal` — and an item resolving from the accel
   map shows both. The port's row shows only `<Control>plus`, so `Ctrl`+`=`
   works and the dialog denies it exists.
3. **The items are no longer activatable.** An `Adw.ShortcutsItem` carrying an
   `action-name` can be triggered from the dialog. The port's items carry none,
   so clicking a row does nothing.

**The one thing the port does better than upstream:** `app.shortcuts` is
actually installed (`lib/application.rb:66`, `:81`), so the dialog is reachable.
On `origin/main` it is dead code. Recorded as a deliberate correspondence, not
an extra.

Messages: 9 upstream, 0 marked, 1 invented. **gap.**
Driven: nothing. Screenshot: none.

## Unit: about dialog — `internal/components/application.go` + `assets/resources/metainfo.xml.in` → `lib/about_dialog.rb`

Upstream is one call — `adw.NewAboutDialogFromAppdata(metainfo.xml, "0.1.20")`
— plus four setters. The port fills the fields by hand. That mapping is a
correspondence; what fell out of it is not.

| Field | Upstream source | Port | Verdict |
|---|---|---|---|
| name, icon, version | appdata + `AppVersion` | `lib/about_dialog.rb:40-42` | parity |
| developer_name | `<developer><name>` | `:43` | parity |
| developers, artists, copyright | setters | `:44-46` | parity |
| license | `<project_license>AGPL-3.0-or-later` | `license_type = AGPL_3_0` `:47` | parity — verified against `Gtk-4.0.gir`: `GTK_LICENSE_AGPL_3_0` is documented as "version 3.0 **or later**", and `AGPL_3_0_ONLY` is the only-variant. The port picked the right one |
| comments / description | `<summary>` + `<description>` | `comments = APP_DESCRIPTION` `:48` | **gap**: the port passes only the long description. Upstream's appdata also supplies `<summary>` ("Focus with timed work intervals") and the `<li>` list ("It enables you to:" + three bullets). Four of upstream's messages render in this dialog and render nowhere in the port |
| website (`homepage`) | `<url type="homepage">` | `:49` | parity |
| issue_url (`bugtracker`) | `<url type="bugtracker">` | `:50` | parity |
| support_url (`help`) | `<url type="help">` | `:51` | parity |
| donations_url | `<url type="donation">` | **not set** — an `add_link('Donate', …)` instead, `:25` | **gap** |
| translate_url | `<url type="translate">` | **not set** — an `add_link('Translate', …)` instead, `:26` | **gap** |
| release notes | 21 `<release>` entries | **absent** | **gap**: the About dialog has no "What's New" section. Twenty-one releases of history, every one of them in `data/com.pojtinger.felicitas.Sessions.metainfo.xml` in this repo already, reachable from nowhere in the port |
| translator_credits | `L("translator-credits")` | **not set** | **gap**: no translator is credited anywhere in the port |

`add_link` instead of `donations_url=`/`translate_url=` is a double gap: it
loses the built-in rows libadwaita already translates into 26 languages, **and**
it invents three English-only labels — `Donate`, `Translate`, `Source Code` —
that upstream never had and nobody will ever translate.

Messages: upstream's About dialog renders 7 of the catalogue's messages; the
port marks 0 and invents 3. **gap.**
Driven: nothing. Screenshot: none.

## Unit: dial — `internal/components/dial.go` → `lib/dial.rb`

The mechanism is substituted: a `Gtk.Widget` subclass overriding `snapshot` and
drawing with `Gsk::PathBuilder` becomes a `Gtk::DrawingArea` with
`set_draw_func` and Cairo. That is the house pattern for custom drawing and it
is a correspondence. The geometry was transcribed carefully and most of it
holds.

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `remaining-time` | int property, 0…3600, default 300, `QueueDraw` on set | `attr_reader` + `remaining_time=` clamping 0…3600, `queue_draw` (`lib/dial.rb:111-115`) | correspondence |
| `counting-down` | bool property, default false | `counting_down=` / `counting_down?` (`:118-123`) | correspondence |
| `drag-begin` / `drag-end` signals | `gobject.SignalNewv` on the class, emitted from the gesture | `on_drag_begin:` / `on_drag_end:` callbacks (`:68-74`) | correspondence |
| `Gtk.GestureDrag` | `drag-begin` + `drag-update` (via `GetStartPoint`) + `drag-end` | all three (`:83-96`) | parity |
| `Gtk.GestureClick` | `pressed` | `pressed` (`:99`) | parity |
| style-manager redraw | `app.GetStyleManager().ConnectNotify` | `Adwaita::StyleManager.default` `notify` (`:103`) | parity |
| dead zone | 15px | `DEAD_ZONE = 15` (`:380`) | parity |
| angle → intervals | `atan2 + π/2`, wrap negatives, ×120, 0 means 120 | identical (`:388-407`) | parity |
| padding / track / handle / border widths | 15 / 10 / 8 / 1 at ±5 | identical constants (`:37-42`) | parity |
| track colour | sampled `#343437` / `#D8D8D8`; destructive @ 0.5 over window_bg when insensitive | identical, with fallbacks (`:48-49`, `:315-328`) | parity |
| arc fill | `error_color` @ 0.3 / grey `0.6,0.6,0.6` @ 0.2 | identical (`:60-61`, `:287-295`) | parity |
| arc line | `error_color` / `accent_bg_color`, 10px, round cap | identical (`:279-285`, `:180`) | parity |
| zero-flash edge case | arc skipped when `counting-down && remaining == 0` | identical (`:171-175`) | parity |
| high-contrast hairlines | track ±5, arc ±5, start cap, handle outline | all four present (`:162-165`, `:190-197`, `:203`) | parity |
| **handle fill colour** | `lineColor` — the looked-up colour with **its own alpha** (`dial.go:489`) | `line_color`, which is forced to `alpha = 1.0` by `opaque` (`lib/dial.rb:279-285, 336`) | **gap**: if `accent_bg_color` or `error_color` is ever themed translucent the handle renders opaque where upstream renders it through. Upstream forces alpha 1.0 for the arc *stroke* only (`dial.go:436-441`) and deliberately does not for the handle |
| **the widget has no accessible role or name** | upstream's is a bare `Gtk.Widget` too — same omission | `Gtk::DrawingArea`, no role | parity (upstream's own gap; not the port's to invent) |

Messages: 0 upstream, 0 in the port. Clean.
Driven: nothing. Screenshot: none. **Every colour and every geometric claim in
this table is a reading of the source, not of a rendered dial.** The one check
that would settle this unit is the one that did not run.

## Unit: state machine — `pkg/state/machine.go` + `constants.go` → `lib/state_machine.rb`

Not a widget, and every button's sensitivity, every label and every colour above
is a function of it, so it is compared here in full. `github.com/qmuntal/stateless`
becomes one transition table.

| Facet | Up | Port | Verdict |
|---|---|---|---|
| states | `stopped`, `dragging`, `countingDown`, `alarming` | same four (`:34-37`) | parity |
| triggers | 8, two private | same 8 (`:39-46`); `stop_dragging` stays unreportable because its guard denies with no argument (`:152-156`) | parity |
| constants | 5min / 30s / 30s / 1h / 1s | identical (`:28-32`) | parity |
| ±30s guards from stopped | `new > Max` / `new < Min` deny | `<= MAX` / `>= MIN` permit (`:196-202`) | parity |
| ±30s from counting down | round(current/30) ± 1, stop ticker on exit, restart on entry | identical (`:163-174`, `:227-241`) | parity |
| `stopDragging` guard | min ≤ v ≤ max **and** `v % 30 == 0` | identical (`:212-217`) | parity |
| entering `countingDown` | trigger-specific entry, then `OnEntry(startTimer)` | same order (`:114-127`) | parity |
| entering `alarming` | `OnEntry(stopTimer)` **then** `OnEntry(startAlarm)` — so `OnStopTimer` fires on the alarm path | `STATE_ENTRY_ACTIONS[ALARMING] = [:stop_countdown, :start_alarm]`, and `stop_countdown` calls `on_stop_timer` (`:126`, `:251-254`) | parity |
| entering `stopped` | `OnEntryFrom(stopTimer, stopTimer)` / `OnEntryFrom(stopAlarming, stopAlarm)` — never both | same (`:179-189`) | parity |
| flush after every transition | `OnTransitioned` | `transition_to` ends in `flush_permitted_triggers` (`:119`) | parity |
| ticker | goroutine + `time.Ticker`, hooks marshalled through `glib.IdleAdd` | `GLib::Timeout.add(1000)` on the main loop (`:259-262`) | correspondence |
| finish condition | `currentRemainingTime == 0` | `<= 0` (`:283`) | correspondence, strictly safer |
| `ToGraph()` / `String()` | exported, render the machine as a graph | **absent** | **gap**: two public methods of upstream's API have no counterpart. Nothing in upstream's UI calls them, and they are still API the port does not offer |
| `CanStopDragging` | exported | `can_stop_dragging?` (`:71-79`) | parity — and **dead**: nothing in the port calls it, where upstream's comment says it exists precisely because `OnPermittedTriggersChange` cannot answer it. Upstream does not call it either |
| failed trigger | returns an `error`, logged by every caller | returns `false`, read by nobody (`:99-108`) | **gap**, already recorded against the window |

Messages: 0 / 0. Clean. Driven: nothing — see `test-parity.md`, which is where
this unit's real verdict lives.

## Unit: settings — `assets/resources/index.gschema.xml` → `lib/settings.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| key name | `last-position` | identical (`lib/resources.rb:25`) | parity |
| type / default | int64 / 300 | `Integer` / 300 (`lib/settings.rb:22-24`) | parity |
| read at startup, written on every change | `GetInt64` / `SetInt64` | same, via `last_position` (`:42-45`) | parity |
| **storage** | GSettings, schema `com.pojtinger.felicitas.Sessions` at `/com/pojtinger/felicitas/Sessions/` | a JSON file at `$XDG_CONFIG_HOME/sessions-rb/settings.json` | **gap** |
| schema summary/description | `_("Last timer position")`, `_("The last manually set timer position…")` | the strings are in `data/com.pojtinger.felicitas.Sessions.gschema.xml`, which **nothing reads** | **gap** |

The gap is not the file format. It is that the preference has left the
platform: `gsettings get com.pojtinger.felicitas.Sessions last-position`
returns nothing, the key is invisible to dconf-editor and to backup and sync
tools that know about GSettings, a Flatpak sandbox's `--filesystem` rules no
longer cover it, and the schema the port does ship in `data/` is decoration. The
upstream behaviour — a preference stored where the desktop stores preferences —
is not present.

## Unit: stylesheet — `assets/resources/style.css` → `lib/style.rb`

Rules diffed: identical, all three, including the
`@media (prefers-reduced-motion: no-preference)` wrapper around the blink.
Upstream ships no variant stylesheet, so there is no second comparison.
Verdict: **gap on delivery only** — `load(string:)` unverified, and the
provider is installed at priority 600 against upstream's GResource auto-load,
which is the same cascade position but has never been observed to be.

## Unit: resources / entry point — `assets/resources/index.go` + `main.go` → `lib/resources.rb`, `exe/sessions`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| app ID, version, developers, artists, copyright, key name | `index.go` | `lib/resources.rb` | parity |
| i18n init | `i18n.InitI18n("sessions", LocaleDir, …)` in `main.go:28` | **absent** | **gap**: no `bindtextdomain`, no gettext, see `translation-parity.md` |
| GResource registration | `gio.ResourcesRegister` | n/a — files load from `data/` | correspondence |
| GSettings construction, incl. `SchemaDir` override for an uninstalled schema | `main.go:43-58` | n/a | folded into the settings gap above |

## Units with no port file at all

| Upstream | Verdict |
|---|---|
| `po/` — 26 catalogues, `sessions.pot` | **gap**, whole unit. `translation-parity.md` |
| `com.pojtinger.felicitas.Sessions.json` (Flatpak manifest) + `.github/workflows/flatpak.yaml` | **gap**: upstream ships as a Flatpak. The port cannot be installed by the mechanism its users install it by |
| `assets/resources/index.gresource.xml`, `blueprint-compiler`/`glib-compile-schemas`/`msgfmt` generate steps | **gap**: `sessions-rb.gemspec:80-81` packages `data/**/*` and `po/**/*`, so the files travel with the gem — but no step compiles or installs the gschema, the `.desktop`, the metainfo or the icons into the directories a desktop reads. The app has no launcher and no AppStream entry, and the two `msgfmt` generate steps that inject 26 languages into the `.desktop` and the metainfo have no counterpart at all |
| `qt/main.go` + `qt/main.qml` — a Qt/QML frontend of the same app | **gap**. `.reports/component-inventory.md` filed this under "Out of scope". Upstream shipped it; the scope is upstream's. It is a second frontend nobody has built, and calling it out of scope is the port awarding itself the authority to shrink its own obligations |
| `sessions.doap`, `LICENSE`, `README.md` | carry no components |

## Extras in the port with no upstream counterpart

| Port | Explanation | Verdict |
|---|---|---|
| `lib/sessions/application.rb` — `Sessions::Application = ::App` | gem-facing alias so `exe/sessions` can `require "sessions"` | explained |
| `lib/background_portal.rb` | upstream reaches the portal through a Go library; the port writes the D-Bus calls. One upstream dependency → one port file | explained |
| `Adwaita::ShortcutsDialog` `title = 'Keyboard Shortcuts'` | invented | **remove or mark** |
| `AboutDialog::LINKS` three `add_link` labels | invented | **replace with `donations_url=` / `translate_url=`** |
| the window's `icon_name = Resources::APP_ICON` | upstream does not set it on the window | harmless, explained |

## Summary

| Axis | Upstream distinct | Port distinct | In upstream, not in port |
|---|---:|---:|---:|
| Widget types (window unit) | 11 | 11 | 0 |
| CSS classes attached | 9 | 9 | 0 |
| Actions | 7 | 7 | 0 |
| Accelerator sets | 6 | 6 | 0 |
| Marked messages | 32 | 0 | 32 |
| Units rendered | — | 0 | — |
| Units driven | — | 0 | — |

Read the bottom three rows against the top four. The widget tree, the CSS
attachments, the action names and the accelerators are all there — this is a
careful port, not a thin one. And the text axis is zero across the whole app,
nothing has ever been rendered, and nothing has ever been fired. That is a port
that passes a reading review and has never been shown to work.

**0 of 12 units have parity.**
