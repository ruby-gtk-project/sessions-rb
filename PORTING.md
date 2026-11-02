# Porting — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` (GTK4 + Libadwaita through ruby-gnome) |
| Parity reports | `.reports/component-parity.md`, `.reports/test-parity.md`, `.reports/translation-parity.md`, `.reports/accountability-ensurance.md` |
| Root ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |

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
into a GResource. It also ships a second, independent Qt/QML frontend over the
same state machine.

The spec lives on the `origin/main` ref of this repo. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check it out, never merge it.

---

## Done

Components implemented and believed complete. One upstream source file, one
`lib/*.rb`.

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

All three drivers were last run green, by `rake drive`:

| Driver | Checks | Screenshots |
|---|---|---|
| `test/drive_main_window.rb` | 173 | 11 |
| `test/drive_translations.rb` | 51 | 6 |
| `test/drive_high_contrast.rb` | 21 | 5 |

---

## Not started

Upstream components with no Ruby counterpart at all.

| Upstream | Port |
|---|---|
| `qt/main.go`, `qt/main.qml` — a whole second frontend over `pkg/state` | nothing |
| `com.pojtinger.felicitas.Sessions.json` — the Flatpak manifest | nothing |
| `.github/workflows/flatpak.yaml` | nothing |
| `LICENSE` — the full AGPL v3 text | `LICENSE.md`, md5-identical to upstream's (`4ae09d45eac4aa08d013b5f2e01c67f6`); this row is closed, and it was closed when the previous revision said the file did not exist |
| `sessions.doap` | nothing |
| `assets/meta/screenshot-initial.png`, `screenshot-running.png` | nothing; the port's metainfo cites upstream's `raw.githubusercontent.com` URLs |

Nothing here has an owner. A row closes when the behaviour is in the port.

---

## Open gaps

The last accountability audit (`.reports/accountability-ensurance.md`) reported
**10 hits** and `clean=false`. All ten were in the ledgers, not in `lib/` or
`exe/` — those two trees scan clean for deferral markers. The pattern it names:
a true sentence about why work is hard, placed where the reader looks for
whether the work is owed.

All ten are rewritten as of this round, and the audit's own eight "rewrites
owed" with them; the list is kept rather than deleted so that the next reader
can check the rewrites instead of trusting that they happened. Each entry now
says what it said and what it says instead:

1. `COMPONENT_PARITY.md` — three gap entries carried a `Why it is hard:` line inside the gap. The phrase is gone from the file: the Qt and Flatpak rows say "What is in the way (not a reason to stop)" and the About-dialog row is closed outright.
2. The Flatpak gap's "because" slot held an environment constraint instead of the admission. It now opens with "I have not written a Flatpak manifest", carries an `Owner:` that closes only when `flatpak install` gets somebody the app, and names the two load-bearing finish-args (`--socket=pulseaudio` for the alarm, portal access for `lib/background_portal.rb`).
3. The Qt row could close "or upstream drops the frontend". It now closes only when a Plasma user can run this port, and its real size — 46 + 52 lines, not 87 + 121 — is in the entry.
4. The GResource entry said "nothing user-visible depends on this" and "I am not planning to add a bundle", and the About-dialog gap leaned on it. The About-dialog gap is closed and the entry now says what the missing bundle actually costs: the appdata constructor takes a resource path, which is why `lib/metainfo.rb` exists.
5. `COMPONENT_PARITY.md` carried a literal `n/a` in the Upstream column. It names `go.mod` / `go.sum` now: an `n/a` in a parity table claims upstream has nothing there, and upstream pins its dependencies in two files. The two "no upstream file" slots in the **Done** table above are named too.
6. `TEST_PARITY.md:8` — the green was real but unreachable. 45 examples did run, under `rspec --options /dev/null --require spec_helper --format progress spec`; what failed was every documented spelling, because `.rspec` ended in `--format RspecJunitFormatter` and that gem is not in the dev shell's `GEM_PATH`. Restating it as "zero examples have been executed" was wrong in the other direction. Fixed this round: the two formatter lines are out of `.rspec`, `bin/rspec` exists, and `rake spec`, `rspec spec` and `bin/rspec spec` all run the suite — 75 examples, 0 failures.
7. `TEST_PARITY.md` had neutral noun-phrase headings where the other ledgers write first person. The one open entry there now reads "I have not written a spec suite for the widget layer, only drivers"; the other two are closed.
8. "so this is not a parity gap against upstream" led a gap entry with a reason to stop reading. The entry now says that recording it does not make it smaller, and counts what the drivers actually are: 245 checks a human has to read the output of.
9. `PORTING.md:29` (the previous revision) — "or a decision not to ship one" pre-authorised skipping the Flatpak manifest in the first file a new agent reads.
10. `PORTING.md:18-21` (the previous revision) — the cursor table repeated the false green and claimed "all GTK components ported and observed", which the dial's two high-contrast gaps contradict.

The substantive parity gaps those ledgers are supposed to carry:

| Gap | Reports |
|---|---|
| No Flatpak manifest — upstream is installable from a Flatpak remote, this port by Nix users only | component, unit 2 |
| Qt/QML frontend absent — `qt/main.go` (46 lines) and `qt/main.qml` (52 lines) | component, no unit |
| DOAP record and both screenshots absent; the metainfo cites upstream's `raw.githubusercontent.com` images | component, no unit |
| Widget layer has drivers, not a spec suite | test |
| Catalogues are not wired into the gem build, so a released gem is English-only | translation |
| The 360px window has never been seen in a long-string language (`ca`, `pt_BR`, `uk`) | translation |

Closed this round, each by a run rather than a reading:

- The dial's two high-contrast defects are fixed. `lib/dial.rb#stroke_pie`
  strokes the wedge it filled, radial edges included, and the full circle when
  the arc closes into a ring (`dial.go:421-422`, `:432-433`);
  `#stroke_start_cap` sweeps counter-clockwise through `arc_negative`
  (`dial.go:457-458`).
- The branch they live on is now executed. `test/drive_high_contrast.rb` turns
  high contrast on through `ADW_DEBUG_HIGH_CONTRAST`, renders the dial in five
  states and reads the pixels back: with the two fixes reverted it fails six
  checks, which is what makes its green worth having.
- The about dialog's four invented link rows and their four msgids are gone.
  `po/sessions.pot` now holds the same 33 msgids as upstream's, with the same
  four TRANSLATORS comments.
- The suite runs. `rake spec`, `rspec spec` and `bin/rspec spec` all give 75
  examples, 0 failures, and `rake drive` runs all three drivers.
- `lib/metainfo.rb` and `lib/settings.rb` have specs, the second of them
  covering both of upstream's two schema-construction paths.
- All 33 msgids are now observed resolving in German, where four were before:
  `test/drive_translations.rb` is 51 checks over six screenshots, and it
  asserts each string through the component that marks it, because
  `bindtextdomain` binds per class ancestry.

---

## Blockers

Things that cannot be ported as upstream wrote them, and why. These explain
difficulty; none of them closes a gap row.

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
- **The catalogues are not wired into the *gem* build.** This was written as
  "no gettext wiring in the port's build", with "translation parity is a
  separate unit, not part of the component port" after it. Both halves were
  false: `rakelib/gettext.rake` provides `gettext:pot`, `gettext:mo`,
  `gettext:data` and `gettext:merge`, plus `schema:compile`, `build_data` and
  `install_data`, and translation parity is part of this port, not a separate
  unit. What is actually missing is narrower and is still owed: nothing in
  `sessions-rb.gemspec` builds or packages the `.mo` files, so `gem install
  sessions-rb` gets an English-only app while `rake install_data` gets a
  translated one. The catalogues themselves are 26 `.po` files answering 33
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
