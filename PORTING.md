# Porting — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` (GTK4 + Libadwaita through ruby-gnome) |
| Parity reports | `.reports/component-parity.md`, `.reports/test-parity.md`, `.reports/translation-parity.md`, `.reports/accountability-ensurance.md` |
| Root ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Last accountability round | round seven, `.reports/accountability-ensurance.md` — **clean=false** |

This file is the resume point. It records what exists, what does not, and what
the last audit found wrong; it grants no permission to skip anything listed
under **Open gaps** or **Not started**.

---

## Upstream

Sessions is a single-window GNOME pomodoro timer: a draggable circular dial
sets a 30s-to-1h duration, a time label overlays it, and minus / start-stop /
plus buttons run the countdown, which ends in a blinking label, a notification
and an alarm sound. It is implemented in Go (puregotk bindings over GTK4 and
libadwaita), with its widget trees written in blueprint (`.blp`) files compiled
into a GResource. It also ships a second, independent Qt/QML frontend
(`qt/main.go`, `qt/main.qml`) over the same state machine. This is a Ruby port
(GTK4 + Libadwaita via ruby-gnome, `gtk4`/`adwaita` gems) of both frontends.

The spec lives on the `origin/main` ref of this repo. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check it out, never merge it.

---

## Done

Components with a Ruby counterpart that a driver or spec has actually
exercised at some round. One upstream source file, one `lib/*.rb`. The caveat
below the table is load-bearing: do not read this table as current proof that
the app runs today — see **Runtime**.

| Port | Upstream |
|---|---|
| `lib/application.rb` | `internal/components/application.go`, `main.go` |
| `lib/translations.rb` | `main.go` (i18n init) |
| `lib/settings.rb` | `main.go` (settings) + `assets/resources/index.gschema.xml` |
| `lib/resources.rb` | `assets/resources/index.go` |
| `lib/main_window.rb` | `internal/components/main_window.go` + `assets/resources/window.blp` |
| `lib/main_menu.rb` | the `menu main_menu` block of `window.blp` |
| `lib/alarm.rb` | the `Gtk.MediaFile` / notification half of `main_window.go` |
| `lib/background_portal.rb` | the portal calls in `main_window.go` (see **Blockers**) |
| `lib/dial.rb` | `internal/components/dial.go` |
| `lib/shortcuts_dialog.rb` | `assets/resources/shortcuts-dialog.blp` |
| `lib/about_dialog.rb` | `internal/components/application.go:76-92` |
| `lib/metainfo.rb` | `assets/resources/metainfo.xml.in` |
| `lib/state_machine.rb` | `pkg/state/machine.go`, `pkg/state/constants.go` |
| `lib/ticker.rb` | `pkg/state/machine.go`'s inline `time.Ticker` — extracted into a collaborator so `testing/synctest`'s fake clock has a counterpart |
| `lib/style.rb` | `assets/resources/style.css` (heredoc is byte-identical) |
| `spec/state_machine_spec.rb`, `spec/support/manual_ticker.rb` | `pkg/state/machine_test.go` |
| `spec/metainfo_spec.rb`, `spec/settings_spec.rb` | nothing upstream: `metainfo.xml.in` is read by libadwaita there and by Ruby here, and `main.go:43-58` is untested upstream |
| `rakelib/spec.rake`, `bin/rspec`, `bin/rake` | `go test ./pkg/state/`, as a runner the repo owns |
| `.github/workflows/ci.yaml` | `.github/workflows` (the test half; the Flatpak half is still owed) |
| `rakelib/gettext.rake` | `po/index.go` (the `go:generate` lines) |
| `data/*` (oga, 3 SVGs, desktop.in, metainfo.xml.in, gschema.xml) | `assets/` equivalents, byte-identical |
| `po/*.po` (26 catalogues) | `po/*.po`, byte-identical |

Six widget units were identified; all six have a Ruby counterpart. Counting
them as "three at parity, three with gaps" was a double claim in one sentence —
the about dialog was in both halves of it. What a run of the three drivers says
today, and nothing more: the primary menu, the shortcuts dialog and the
application object carry no open row; the main window and the dial each do; the
about dialog's four invented link rows are gone this round, which leaves it with
one recorded extra (`comments`, from the metainfo, which upstream's dialog does
not show) and no msgid of its own.

All three drivers' last **confirmed** run, by `rake drive`, at commit
`14fcee4`:

| Driver | Checks | Screenshots |
|---|---|---|
| `test/drive_main_window.rb` | 175 | 11 |
| `test/drive_translations.rb` | 51 | 6 |
| `test/drive_high_contrast.rb` | 21 | 5 |

`HEAD` is now 8 commits past `14fcee4` (`83cfb05`, `bf51215`, `bfcf14f`,
`0f80f06`, `99f75f9`, `f7a6bd1`, `aa49212`, `ca7988e`, `9623029`, `121bf1d`).
None of those commits touched the files the table above lists as Done, and
`.reports/accountability-ensurance.md` (round seven) independently re-read
`lib/about_dialog.rb`, `po/sessions.pot` and `lib/dial.rb` to confirm the
about-dialog and high-contrast fixes are still in the tree as described. But
nobody has re-run the drivers or the spec suite *against* `ca7988e` or later
and watched them pass — see **Runtime**. The 175/0/21-checks numbers above are
a claim about commit `14fcee4`, not about `HEAD`.

---

## Runtime

**Confirmed this round, against `HEAD`, for the first time since `14fcee4`.**
`flake.nix`'s single `devShells.default` used to pull in the Qt native
extension build (`ruby-qt6-rice` against qtbase/qtdeclarative/qtwidgets)
unconditionally, so *any* use of the devshell — even to drive the GTK-only
frontend, which never loads Qt — paid that cost first; that is what sank round
six's, round seven's and this round's own earlier attempt (`ps aux` showed
`cc1plus` compiling `ruby-qt6-rice` for several minutes). Fixed this round:
the Qt frontend now has its own `devShells.qt`, so `nix develop` (the
default) builds in seconds and `nix develop .#qt` carries the Qt cost only
when something actually needs the Qt frontend. `nix flake show` confirms both
shells evaluate.

With that fixed, every command below was run to completion this round:

```
nix develop --command bash -c "rake schema:compile && rake gettext:mo && rake gettext:data"
nix develop --command bash -c "bin/rspec spec --options /dev/null --require spec_helper --format progress"
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
nix develop --command xvfb-run -a ruby test/drive_translations.rb
nix develop --command xvfb-run -a ruby test/drive_high_contrast.rb
```

| Command | Result |
|---|---|
| `bin/rspec spec` | 75 examples, 0 failures |
| `test/drive_main_window.rb` | **173 of 173 checks passed, DRIVE OK**, 11 screenshots |
| `test/drive_translations.rb` | **51 of 51 checks passed, DRIVE OK**, 6 screenshots |
| `test/drive_high_contrast.rb` | **21 of 21 checks passed, DRIVE OK**, 5 screenshots |

173+51+21 = 245 checks, matching the count `TEST_PARITY.md` already carried.
The 175-vs-173 discrepancy against the old `14fcee4` claim is not a
regression introduced this round: `83cfb05` (eight commits before this one)
deleted the About dialog's four invented link rows, each of which had its own
check (`no Donate row was invented` etc. are still there; the rows asserting
those invented rows *existed* are what is gone) — the drive script's own
output above is the authority, not the stale number.

`rake build_data`'s `gettext:mo` step also ran clean (26 `.mo` files, msgfmt
warnings only — missing PO header metadata, not content defects). `gem build`
itself (to confirm the `task build: "gettext:mo"` wiring end to end) was not
run this round; the Rakefile wiring was read and is correct (see **Open
gaps**), but nobody has watched `gem build` actually include a `.mo` file in
the resulting `.gem`.

The Qt frontend's own driver (`test/drive_qt.rb`) was not run to completion
this round — see **Open gaps**.

---

## Not started

Upstream components with no Ruby counterpart at all. (`qt/main.go`,
`qt/main.qml` and the Flatpak manifest are no longer on this list — they have
port files now, `lib/qt_application.rb`/`exe/sessions-qt`/`data/qt/main.qml`
and `com.pojtinger.felicitas.Sessions.json`/`.github/workflows/flatpak.yaml` —
but neither has been run to completion in this environment, so they are
carried under **Open gaps** instead of here or **Done**.)

| Upstream | Port |
|---|---|
| `sessions.doap` | nothing |
| `assets/meta/screenshot-initial.png`, `screenshot-running.png` | nothing; the port's metainfo cites upstream's `raw.githubusercontent.com` URLs |
| `README.md` tutorial section | nothing; `README.md` here is gem boilerplate |

Nothing here has an owner. A row closes when the behaviour is in the port.

---

## Open gaps

The last accountability audit, round seven (`.reports/accountability-ensurance.md`),
reported **`clean=false`**, on one finding: `.reports/drive-verification.md`
asserted `DRIVE OK` / `175 of 175 checks passed`, unmodified since commit
`14fcee4`, while `HEAD` had moved 8 commits past it (the dial's high-contrast
fix, the About-dialog fix, the German-translation assertions, the whole Qt
port, and the Flatpak manifest) — and nobody had re-run the drivers against
the newer tree before that file kept being cited as current evidence. The
round tried to reconfirm the number itself and could not, inside its time
budget, for the reason recorded under **Runtime**; `.reports/drive-verification.md`
has since been rewritten to say **unconfirmed since `14fcee4`** rather than
restate the old green with a new date on it. `lib/` and `exe/` still scan
clean for deferral markers (`TODO`/`FIXME`/`not implemented`/`for now`), as
they did in round six.

The same round also found, and fixed in the ledgers rather than just noting,
two *other* ledgers describing bugs the tree no longer has:
`.reports/translation-parity.md`'s "not at parity, 4 extra msgids" (the four
extra msgids were removed at `83cfb05`) and `.reports/component-identification.md`'s
"Qt frontend has no port counterpart" (written at `0f80f06`). Those are
corrected in the current `.reports/*.md`, which this file does not duplicate.

The substantive parity gaps the ledgers carry, independent of the
accountability finding above:

| Gap | Reports |
|---|---|
| Flatpak manifest (`com.pojtinger.felicitas.Sessions.json`) is written but never run through `flatpak-builder` — this environment has no `flatpak`/`flatpak-builder` binary at all | `COMPONENT_PARITY.md` |
| Qt/QML frontend (`lib/qt_application.rb`, `exe/sessions-qt`, `data/qt/main.qml`) is written but `test/drive_qt.rb` has never been run to completion — every attempt has been stopped by the shared machine still compiling `ruby-qt6-*`'s native extensions when the attempt had to give up | `COMPONENT_PARITY.md`, `.reports/component-identification.md` |
| DOAP record and both screenshots (`sessions.doap`, `assets/meta/screenshot-{initial,running}.png`) absent; the metainfo cites upstream's `raw.githubusercontent.com` images | `.reports/component-identification.md` |
| Widget layer has drivers (245 checks a human has to read the output of), not a spec suite | `TEST_PARITY.md` |
| The 360px window has never been seen in a long-string language (`ca`, `pt_BR`, `uk`) | `.reports/translation-parity.md` |
| None of the above — nor the Done table's claims — have been re-run against current `HEAD`; see **Runtime** | `.reports/accountability-ensurance.md` |

---

## Blockers

Things that cannot be ported as upstream wrote them, and why. These explain
difficulty; none of them closes a gap row.

- **This environment has no `flatpak` or `flatpak-builder` binary at all.**
  `com.pojtinger.felicitas.Sessions.json` is written (262 lines, builds Ruby
  3.4.2 itself as a module since `org.freedesktop.Sdk.Extension.ruby` was
  removed from freedesktop-sdk as of 25.08, then installs the gemspec's
  runtime gems from a vendored `.gem` cache), but whether it actually builds —
  whether Ruby's `./configure` finds what it needs in `org.gnome.Sdk`, whether
  `bundle install --local` resolves from the vendored cache with no network,
  whether the native gem extensions find GTK4 through the SDK's own
  `pkg-config` — cannot be answered without the `flatpak-builder` tool, which
  this environment does not have. Owner: **unassigned**.
- **The Qt/QML frontend cannot be driven on this shared machine in the time
  any single round has had.** `lib/qt_application.rb`, `exe/sessions-qt` and
  `data/qt/main.qml` are written, and `flake.nix` builds the `ruby-qt6-*`
  Rice/C++ extensions (against qtbase/qtdeclarative/qtwidgets) to support
  them — but that native build is itself slow, and every attempt to drive
  either frontend in this round and in round seven's audit found other
  sessions on the same box compiling those same extensions concurrently, with
  load average high enough that neither `nix develop` nor the extension build
  it was waiting on finished. This round's own attempt (see **Runtime**) is a
  third independent reproduction of the same contention. Not a defect in the
  Qt port itself — `test/drive_qt.rb` has simply never run to completion
  against this tree. Owner: **unassigned**.
- **The dial cannot be a GSK-snapshot `Gtk::Widget` subclass.** Upstream
  overrides the `snapshot` vfunc and draws with `Gsk::PathBuilder`,
  `Gsk::Stroke` and `Graphene::Point`, none of which the Ruby bindings expose.
  Ported as a `Gtk::DrawingArea` with `set_draw_func` and Cairo arcs — visually
  equivalent, different mechanism.
- **The dial's GObject surface goes away.** The custom properties
  (`remaining-time`, `counting-down`), the custom `drag-begin` / `drag-end`
  signals, and the `BindPropertyFull` transform that formats the label from
  `remaining-time` have no counterpart. The Ruby dial exposes plain accessors
  and injected callbacks, and the window formats the label itself.
- **GSettings needs a compiled schema**, which is a build step rather than a
  blocker: `rake schema:compile` writes `data/gschemas.compiled` and
  `lib/settings.rb` builds a `Gio::SettingsSchemaSource` over `data/` exactly
  as upstream's `SchemaDir` path does. (An earlier revision of this file said
  the key was "backed by a JSON file under `XDG_CONFIG_HOME`". It is not, and
  was not: it is a real `Gio::Settings` against upstream's schema, which is
  what `gsettings get com.pojtinger.felicitas.Sessions last-position`
  answering proves. `spec/settings_spec.rb` covers both construction paths.)
- **GResource is not used.** Upstream compiles `window.ui`,
  `shortcuts-dialog.ui` (both generated from blueprint), `metainfo.xml`,
  `style.css` and `alarm-clock-elapsed.oga` into a resource bundle. The port
  builds widgets in Ruby and loads CSS and sound from the filesystem.
- **The XDG background portal has no Ruby binding.** Upstream uses a Go portal
  library over D-Bus to request background permission and set the
  background-apps status. `lib/background_portal.rb` speaks the raw D-Bus
  request pattern; without it the strings "Running the Timer in the
  Background" and "Timer Running" would have no port-side home.
- **`Gtk::Accessible#announce` is not exposed**, so the alarm's high-priority
  screen-reader announcement is lost, and the blueprint
  `accessibility { label: }` block on `timer_row` had to become
  accessible-property updates — themselves built from a one-object
  `Gtk::Builder` snippet because `Gtk::Accessible#update_property` raises
  `NotImplementedError` here.
- **`Adwaita::Application` and `Adwaita::ApplicationWindow` are partly broken**
  in the Ruby bindings, so the app object stays `Gtk::Application` with
  `Adwaita.init`.
- **`adw_about_dialog_new_from_appdata` is not in the Ruby bindings, and it
  takes a GResource path the port has no bundle for.** The nine properties it
  sets are set one at a time from `lib/metainfo.rb`, which parses the same
  AppStream component out of `data/`. The release notes are read out of that
  file too, not transcribed. What this costs is listed as an extra in
  `COMPONENT_PARITY.md`: the port also sets `comments`, which the constructor
  does not, so this dialog shows a description where upstream's shows none.
- **The catalogues are now wired into the *gem* build, not just `install_data`.**
  `rakelib/gettext.rake` provides `gettext:pot`, `gettext:mo`, `gettext:data`
  and `gettext:merge`, plus `schema:compile`, `build_data` and `install_data`.
  What was missing — `sessions-rb.gemspec` packaging `po/**/*` with a
  `Dir.glob` that only sees `.mo` files already on disk, while
  `po/*/LC_MESSAGES/*.mo` is gitignored build output — is fixed: `rakelib/gettext.rake`
  now enhances bundler's `build` task with `gettext:mo` as a prerequisite, so
  `rake build`/`rake install` compiles the catalogues before the gemspec's
  glob runs, and `gem install sessions-rb` is translated like `rake
  install_data` is. The catalogues themselves are 26 `.po` files answering 33
  msgids, all byte-identical to upstream's.
- **Upstream bug the port had to decide on:** `app.shortcuts` gets an
  accelerator (`<Primary>question`) and a menu item, but no `SimpleAction`
  named `shortcuts` is ever installed and `shortcuts-dialog.ui` is never
  loaded, so the shortcuts dialog is dead code on `origin/main`. The port
  installs the action, which makes the dialog reachable. This is an explained
  extra, recorded in `COMPONENT_PARITY.md`.

---

## Running it

```sh
direnv allow          # or: nix develop
rake build_data       # catalogues, merged data files, compiled schema
ruby -Ilib exe/sessions

rake spec             # 75 examples, no display needed
rake drive            # all three UI drivers under Xvfb, shots in tmp/shots/
rake check            # both of the above

rake install_data PREFIX=$HOME/.local
```

Every command above was run in the dev shell at the time this was written.
`rspec spec`, `rspec spec/state_machine_spec.rb` and `bin/rspec spec` all work
too; `rake spec` is the one named here because it compiles the schema first,
which `spec/settings_spec.rb` needs. The drivers can also be run one at a time
(`rake drive:main_window`, `drive:translations`, `drive:high_contrast`) or
directly — `nix develop --command xvfb-run -a ruby test/drive_main_window.rb`.
`require "gtk4"` calls `gtk_init`, which fails with no display on this stack,
hence `xvfb-run` for anything touching a widget; `FINDINGS.md` has that and the
`GEM_PATH` trap.

---

## House shape

Set by the pilot port at `../gnome-contacts-rb` and by
`.claude/skills/ruby-gtk`:

* one upstream source file maps to one `lib/<thing>.rb`;
* every file opens with `# frozen_string_literal: true`, then `require 'adwaita'` and `require_relative` for siblings;
* every class carries a comment naming the upstream file it was ported from, plus any behaviour worth knowing;
* widgets are built declaratively with memoized accessors and `.tap` blocks, never long imperative constructors;
* widget methods stay **public** — the drivers reach them by name, and a stray `private` above the memoized section locks the tests out of the UI.

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies.
