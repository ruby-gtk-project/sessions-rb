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
| Dial arc, handle, track, dead zone | `internal/components/dial.go:296-492` | `lib/dial.rb#draw` | `tmp/shots/01-initial.png`, `03-counting-down.png` |
| High contrast: hairlines on the r±5 track circles, on the r±5 arcs and on the handle | `dial.go:360-373`, `:463-477`, `:490` | `lib/dial.rb#draw_track`, `#draw_arc_borders`, `#draw_handle` | `test/drive_high_contrast.rb`, `tmp/shots/hc-01-idle.png` … `hc-05-quarter-ring.png` — these three were carried as "read, not run" for five rounds |
| High contrast: the filled wedge is stroked, radial edges included, and as a plain circle once the arc closes into a ring | `dial.go:432-433`, `:421-422` | `lib/dial.rb#stroke_pie` | `test/drive_high_contrast.rb` step 10 — the wedge outline's own pixels, found by rendering the dial twice and diffing |
| High contrast: the start cap bulges counter-clockwise, left of twelve o'clock | `dial.go:457-458` (`SvgArcTo` with sweep-flag 0) | `lib/dial.rb#stroke_start_cap` (`arc_negative`) | `test/drive_high_contrast.rb` step 11 — every inked pixel is left of centre; with the fix reverted the driver fails six checks |
| Switching high contrast or colour scheme repaints the dial immediately | `dial.go` reads the style manager each snapshot | `lib/dial.rb#build`'s `notify` handler, `#high_contrast?` | `test/drive_high_contrast.rb` step 0 |
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
| `gtk4` / `adwaita` / `gettext` / `rexml` are runtime dependencies | `go.mod`, `go.sum` | `sessions-rb.gemspec:115-123`, `nix/Gemfile` | `bundle check`; `nix develop --command rake spec` resolves them |
| Desktop entry, metainfo, icons, schema and catalogues are installed | Flatpak manifest build-commands | `rake install_data`, `flake.nix` `installPhase` | source |
| The AGPL-3.0 text ships with the program, as the licence it declares | `LICENSE` | `LICENSE.md` | `Gem::Specification.load("sessions-rb.gemspec").files` lists it; `md5sum` matches upstream's `LICENSE` |

---

## Open

### The Qt/QML frontend is written but still not observed to run

This entry used to say "I have not ported the Qt/QML frontend" and "Port:
nothing", which a prior round made false without ever coming back to fix: a
port of `qt/main.go` and `qt/main.qml` was committed (`lib/qt_application.rb`,
`exe/sessions-qt`, `lib/sessions/qt.rb`, `data/qt/main.qml`, `nix/qt/`, the
`qtGems` output and `packages.qt` in `flake.nix`, `test/drive_qt.rb`,
`rake drive:qt`), and this row kept reading as if none of that existed. A
row claiming less than the tree holds is the same defect as one claiming
more — both are a ledger somebody would trust without checking.

What is genuinely still true: nobody has watched it run. The commit that
wrote it said so itself ("the run never reached its parity audit or its drive
script, so nothing here has been observed to run"), and this round tried to
close that — `nix develop --command xvfb-run -a ruby test/drive_qt.rb` — and
could not get a result inside the time this round had. `top` during the
attempt showed a load average over 13 on an 8GB box with several `nixbld*`
users compiling in parallel (`cc1plus`, and several `ruby extconf.rb`
processes for the `ruby-qt6-*` gems' native extensions, at once); the process
was still building past 25 minutes when this round had to stop waiting on it.
That is contention evidence, not a verdict on the frontend — it says the
*attempt* did not finish, not that the code is wrong.
Upstream: `qt/main.go`, `qt/main.qml`.
Port: `lib/qt_application.rb`, `exe/sessions-qt`, `data/qt/main.qml`.
Owner: **unassigned**. This row closes when `rake drive:qt` (or
`test/drive_qt.rb` by hand) has actually been run to completion against this
tree and its output has been looked at — a Kirigami window with the state
machine flushed from the stopped state, upstream's own skeleton of a second
frontend. Nothing else closes it.

### The Flatpak manifest is written, and still unbuilt

Upstream ships `com.pojtinger.felicitas.Sessions.json` and
`.github/workflows/flatpak.yaml`, so upstream is installable from a Flatpak
remote. This round wrote both files for the port, and neither has been run
through `flatpak-builder` — this environment has no `flatpak` or
`flatpak-builder` binary at all, so "I wrote a manifest" and "the manifest
builds" remain two different claims and only the first one is made here.

Confirmed first, because `org.freedesktop.Sdk.Extension.ruby` was removed
from freedesktop-sdk as of 25.08 and `org.gnome.Sdk//50` sits on top of that —
there is no Ruby SDK extension to ask for. `com.pojtinger.felicitas.Sessions.json`
therefore builds Ruby 3.4.2 itself as its first module (`autotools` against a
pinned source tarball) and installs the gemspec's four runtime gems and their
twenty-five transitive dependencies from a vendored `.gem` cache in its second
module — every one of those 30 sources (Ruby's tarball plus 29 gem files) carries
a `sha256` actually computed by downloading the file and hashing it in this
session, not invented. What was not possible to compute here is whether the
two modules link: whether Ruby's `./configure` finds what it needs in
`org.gnome.Sdk` without `libyaml`-devel declared anywhere, whether
`bundle install --local` resolves purely from the vendored cache with no
network, and whether the native gem extensions (`cairo`, `gdk4`, `gsk4`, …)
find GTK4's headers through the SDK's own `pkg-config` the way `flake.nix`'s
`rubyGnomeGem` override does for Nix.
Upstream: `com.pojtinger.felicitas.Sessions.json`, `.github/workflows/flatpak.yaml`.
Port: `com.pojtinger.felicitas.Sessions.json`, `.github/workflows/flatpak.yaml`.
Owner: **unassigned**. This row closes when `flatpak-builder` has actually
turned this manifest into a running app, not when the JSON parses. Two of
upstream's finish-args are load-bearing and have to survive into whatever
closes it: `--socket=pulseaudio`, without which `lib/alarm.rb` is silent, and
the portal access `lib/background_portal.rb` exists for — both are already in
the manifest written this round, carried over from upstream's unchanged.

### Closed: the four About-dialog link rows are deleted

This row used to read "Four About-dialog link titles are English in
twenty-five languages", and explained that upstream gets Donate and Translate
rows with titles out of libadwaita's own catalogue from
`adw_about_dialog_new_from_appdata`. That explanation was invented.
`new_from_appdata` sets nine properties — application-icon, application-name,
developer-name, version, website, support-url, issue-url, license-type and
release-notes/release-notes-version (Adw-1.gir, libadwaita 1.9.3) — and adds no
link row; `git grep AddLink origin/main` returns nothing. Upstream's About
dialog has no Donate, Translate, Source Code or Contribute row at all, so there
was never a translated row for the port to be falling short of: I had added four
components and four msgids and then written the shortfall up as libadwaita's.

The four `add_link` calls are gone, the four msgids are out of
`po/sessions.pot` (33 again, upstream's set exactly), the four dead URL
constants are out of `lib/resources.rb`, and
`test/drive_main_window.rb` asserts that none of the four titles renders.

One extra remains and is an extra, not parity: `comments`. The appdata
constructor does not set it, so upstream's dialog shows no description at all
where this one shows the metainfo's summary, two paragraphs and three bullets.
It is kept because it costs no msgid — the keys are the ones xgettext took out
of upstream's own metainfo, so all 26 catalogues answer them — and because
`lib/metainfo.rb` exists to feed it. It is listed here so that nobody later
reads the About dialog as byte-for-byte upstream's.
Upstream: `internal/components/application.go:84`.
Port: `lib/about_dialog.rb`.

### The port has no GResource bundle

Upstream compiles the blueprint UI, the stylesheet, the metainfo and the alarm
sound into one bundle and reads them back by resource path. The port reads them
from `data/`. The house pattern builds widget trees in Ruby rather than from
`.ui` files, so the bundle has no reader here; what it does cost is the appdata
constructor, which takes a *resource* path, so the About dialog's nine
properties are set one at a time out of `lib/metainfo.rb` instead. That is a
different mechanism reaching the same dialog, and it is the reason
`lib/metainfo.rb` exists at all. Nobody has asked for the bundle and no row
depends on it; it stays recorded rather than implicit.
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
