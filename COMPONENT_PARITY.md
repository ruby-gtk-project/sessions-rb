# Component parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` |
| Verified by | `test/drive_main_window.rb` under `xvfb-run` — 175 checks, 11 screenshots in `tmp/shots/`; `test/drive_translations.rb` — 5 checks, 2 screenshots; `rspec` — 45 examples |
| Binding limits | `FINDINGS.md` |

Every row is a behaviour, not a file. A row is closed when the behaviour is in
the port *and* something has observed it; "the code is written" closes nothing,
which is what round one got wrong about every row in this table.

Open rows are written in the first person, because somebody did or did not do
them.

---

## Closed this round

| Behaviour | Upstream | Port | Observed by |
|---|---|---|---|
| Window, header bar, menu button, dial, time card, three buttons | `window.blp`, `internal/components/main_window.go` | `lib/main_window.rb` | `tmp/shots/01-initial.png` |
| Dial arc, handle, track, dead zone, high-contrast borders | `internal/components/dial.go:296-492` | `lib/dial.rb:148-215` | `tmp/shots/01-initial.png`, `03-counting-down.png` |
| Handle keeps the theme colour's own alpha; only the arc stroke is forced opaque | `dial.go:436-441`, `dial.go:489` | `lib/dial.rb#line_color`, `#draw_arc`, `#draw_handle` | source + `03-counting-down.png` |
| `win.addTime` / `win.removeTime` move the dial and the label | `main_window.go:424-435` | `lib/main_window.rb` | drive steps 1-3 |
| `win.toggleTimer` starts, stops and re-labels the button | `main_window.go:413`, `:340-352` | `lib/main_window.rb#toggle_timer` | drive steps 4-6 |
| `win.closeWindow` | `main_window.go:443` | `lib/main_window.rb` | drive step 18 |
| Dial drag gesture → `start_dragging` / `stop_dragging` | `dial.go:83-95`, `main_window.go:373-383` | `lib/dial.rb#build` | drive step 7 |
| Dial click gesture, including the 15px dead zone | `dial.go:102` | `lib/dial.rb#build` | drive step 9 |
| Alarm: blinking label, notification, sound, insensitive dial | `main_window.go:260-280` | `lib/alarm.rb`, `lib/main_window.rb#on_start_alarm` | drive steps 10-12, `05-alarming.png` |
| Screen-reader announcement on the finished session | `main_window.go:276` | `lib/main_window.rb#announce` | `FINDINGS.md`, "announce exists" |
| `Remaining Time` accessible label on the time row | `window.blp:53-55` | `lib/main_window.rb` `TIMER_ROW_UI` | drive step 0 |
| Shortcuts dialog resolves six accelerators from action names | `shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | `tmp/shots/06-shortcuts.png` shows `Ctrl` + `?`, `Ctrl` + `W` |
| Shortcuts dialog title comes from libadwaita, not from us | `shortcuts-dialog.blp` (sets none) | `lib/shortcuts_dialog.rb` (sets none) | drive step 14 |
| About dialog: summary, description, bullets, release notes, licence, URLs | `application.go:76-92` + `metainfo.xml.in` | `lib/about_dialog.rb`, `lib/metainfo.rb` | drive step 16, `07-about.png` |
| About dialog translator credits | `application.go:88` | `lib/about_dialog.rb#translator_credits` | drive step 41; `TRANSLATION_PARITY.md` |
| Last position in GSettings, with the uninstalled-schema fallback | `main.go:43-58` | `lib/settings.rb` | drive steps 1, 2, 23-26 — the window's writes are read back through a second `Settings` object |
| Stylesheet loaded at application priority | `assets/resources/style.css` in the GResource | `lib/style.rb` | drive step 4; the opaque time card in `tmp/shots/01-initial.png` |
| Background portal: request, status, hold, hide-on-close | `main_window.go:110-140`, `:225-250` | `lib/background_portal.rb` | drive step 20 — no portal on this bus, so the request answers false and `hide-on-close` is never turned on |
| Refused state transitions are reported | thirteen `slog` sites | `lib/main_window.rb#report` | drive steps 23, 25 — the dial's ceiling and floor, with the dimmed button in `tmp/shots/08-ceiling.png` and `09-floor.png` |
| `StateMachine#to_s` / `#to_graph` | `pkg/state/machine.go` exports `String()` / `ToGraph()` | `lib/state_machine.rb` | `spec/state_machine_spec.rb`; drive step 25 |
| Header-bar primary menu: two items on two application actions | `window.blp` `menu main_menu` | `lib/main_menu.rb` | drive steps 27-28, `tmp/shots/10-main-menu.png` |
| Alarm notification and sound, and `app.stopAlarmPlayback` silencing both | `main_window.go:260-280` | `lib/alarm.rb` | drive steps 18-19 |
| The countdown's one-second beat | `pkg/state` `time.Ticker` | `lib/ticker.rb` | drive step 21 |
| The six accelerators, resolvable in both directions | `application.go`, `main_window.go` | `lib/application.rb`, `lib/main_window.rb` | drive step 30 |
| The About dialog's description is one language, not every catalogue at once | `adw_about_dialog_new_from_appdata` | `lib/metainfo.rb#untranslated` | drive step 41 — the defect the first run of round five found |
| The shortcuts dialog's no-results state | libadwaita's own | `lib/shortcuts_dialog.rb` | drive steps 36-39, `tmp/shots/11-shortcuts-no-results.png` |
| `gtk4` / `adwaita` / `gettext` / `rexml` are runtime dependencies | n/a | `sessions-rb.gemspec:115-123` | `bundle check` |
| Desktop entry, metainfo, icons, schema and catalogues are installed | Flatpak manifest build-commands | `rake install_data`, `flake.nix` `installPhase` | source |
| The AGPL-3.0 text ships with the program, as the licence it declares | `LICENSE` | `LICENSE.md` | `Gem::Specification.load("sessions-rb.gemspec").files` lists it; `md5sum` matches upstream's `LICENSE` |

---

## Open

### I have not ported the Qt/QML frontend

Upstream ships a second frontend of this same app — `qt/main.go` (87 lines)
and `qt/main.qml` (121 lines) — and the port has nothing corresponding to it.
A user who runs upstream's Qt build gets a working timer; a user of this port
has no such option at all.

Round one filed this under a heading reading "Out of scope", which was me
redefining the target until the current state hit it. Upstream set the scope by
shipping the frontend. The heading is gone from
`.reports/component-inventory.md`.
Upstream: `qt/main.go`, `qt/main.qml`.
Port: nothing.
Owner: **unassigned**. This row stays open until somebody takes it or upstream
drops the frontend.
Why it is hard: a QML frontend in Ruby means a second toolkit and a binding set
(`qml-ruby`, `ruby-qml`) that is not in this flake and not maintained against
Qt 6.

### I have not written a Flatpak manifest

Upstream ships `com.pojtinger.felicitas.Sessions.json` and
`.github/workflows/flatpak.yaml`, so upstream is installable from a Flatpak
remote. This port is not installable that way at all.

I wrote the install half of the gap — `rake install_data` and `flake.nix`'s
`installPhase` put the desktop entry, metainfo, icons, compiled schema and
twenty-six catalogues where a desktop reads them — and then stopped, because I
could not build or test a manifest in this environment and a manifest that
does not build is indistinguishable from one nobody has tried.
Upstream: `com.pojtinger.felicitas.Sessions.json`.
Port: nothing.
Why it is hard: there is no `org.freedesktop.Sdk.Extension.ruby`, so a Ruby
manifest has to build Ruby and eight ruby-gnome C extensions from pinned
sources inside the manifest; none of those sha256s can be computed without
running the build.

### Four About-dialog link titles are English in twenty-five languages

Donate, Translate, Source Code and Contribute. Upstream gets these rows, with
titles out of libadwaita's own catalogue, from
`adw_about_dialog_new_from_appdata`; I add them with `add_link` and my own
titles, so a German user sees four English words in an otherwise German
dialog.
Upstream: `internal/components/application.go:76`.
Port: `lib/about_dialog.rb#links`.
Why it is hard: `FINDINGS.md`, "AdwAboutDialog has no donations-url" — the
properties do not exist and the appdata constructor needs a GResource.

### The port has no GResource bundle

Upstream compiles the blueprint UI, the stylesheet, the metainfo and the alarm
sound into one bundle and reads them back by resource path. The port reads them
from `data/`. Nothing user-visible depends on this except the About dialog row
above, and the house pattern builds widget trees in Ruby rather than from `.ui`
files, so I am not planning to add a bundle — but it is the reason that row is
open, and it is recorded here rather than being left implicit.
Upstream: `assets/resources/index.gresource.xml`.
Port: `lib/resources.rb`.

### The port ships no DOAP project description

Upstream ships `sessions.doap`, the RDF project description GNOME's
infrastructure reads for the app's name, homepage, bug database, language,
platforms and maintainer. The port has no such file, so this fork is invisible
to anything that discovers projects that way.

It is not written because every field in it is an assertion about who
maintains the software and where its bugs are filed. Upstream's copy names
Felicitas Pojtinger as maintainer and `github.com/pojntfx/sessions/issues` as
the bug database; copying it across would put that name behind a fork they have
not seen, and inventing a replacement maintainer is not a porting decision.
Upstream: `sessions.doap`.
Port: nothing.
Owner: **unassigned**. Whoever maintains this fork fills in their own `foaf:Person`
and bug database; `<programming-language>` becomes `Ruby`, and the two
`<platform>` elements stay `GTK 4` and `Libadwaita`.
