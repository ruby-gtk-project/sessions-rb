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
| `lib/ticker.rb` | no upstream file — the seam that replaces `testing/synctest` |
| `lib/style.rb` | `assets/resources/style.css` (heredoc is byte-identical) |
| `spec/state_machine_spec.rb`, `spec/support/manual_ticker.rb` | `pkg/state/machine_test.go` |
| `rakelib/gettext.rake` | `po/index.go` (the `go:generate` lines) |
| `data/*` (oga, 3 SVGs, desktop.in, metainfo.xml.in, gschema.xml) | `assets/` equivalents, byte-identical |
| `po/*.po` (26 catalogues) | `po/*.po`, byte-identical |

Six widget units were identified; all six have a Ruby counterpart. Three are at
parity (primary menu, shortcuts dialog, about dialog); three carry open gaps
(application object's unit is clean, main window, dial, about dialog rows — see
below). Both widget drivers were last run green:
`xvfb-run -a ruby test/drive_main_window.rb` → 34/34 with 7 screenshots, and
`test/drive_translations.rb` → 5/5.

---

## Not started

Upstream components with no Ruby counterpart at all.

| Upstream | Port |
|---|---|
| `qt/main.go`, `qt/main.qml` — a whole second frontend over `pkg/state` | nothing |
| `com.pojtinger.felicitas.Sessions.json` — the Flatpak manifest | nothing |
| `.github/workflows/flatpak.yaml` | nothing |
| `LICENSE` — the full AGPL v3 text | nothing; `sessions-rb.gemspec:66` packages `LICENSE.md`, which does not exist |
| `sessions.doap` | nothing |
| `assets/meta/screenshot-initial.png`, `screenshot-running.png` | nothing; the port's metainfo cites upstream's `raw.githubusercontent.com` URLs |

Nothing here has an owner. A row closes when the behaviour is in the port.

---

## Open gaps

The last accountability audit (`.reports/accountability-ensurance.md`) reported
**10 hits** and `clean=false`. All ten are in the ledgers, not in `lib/` or
`exe/` — those two trees scan clean for deferral markers. The pattern it names:
a true sentence about why work is hard, placed where the reader looks for
whether the work is owed. Five of the ten are sentences that belong in
`FINDINGS.md`.

The ten, owed as rewrites in place (delete none):

1. `COMPONENT_PARITY.md:65,82,96` — three gap entries carry a `Why it is hard:` line inside the gap itself.
2. `COMPONENT_PARITY.md:85-87` — the Flatpak gap's "because" slot is filled with an environment constraint instead of the admission.
3. `COMPONENT_PARITY.md:63-64` — "or upstream drops the frontend" lets the Qt row close with nothing built; `Owner:` is a status field.
4. `COMPONENT_PARITY.md:103-105` — "nothing user-visible depends on this" plus "I am not planning to add a bundle"; this paragraph is what the About-dialog gap leans on.
5. `COMPONENT_PARITY.md:43` — a literal `n/a` in the Upstream column; the counterpart is `go.mod` / `go.sum`.
6. `TEST_PARITY.md:8` — **a false green.** The cell reads "45 examples, 0 failures". `rspec` is in neither the devshell nor the root `Gemfile`, there is no `Gemfile.lock`, and the documented command exits `exec: rspec: not found`. Zero examples have been executed.
7. `TEST_PARITY.md:54,69,84` — neutral noun-phrase headings where the other ledgers write first person.
8. `TEST_PARITY.md:73-74` — "so this is not a parity gap against upstream" leads a gap entry with a reason to stop reading.
9. `PORTING.md:29` (the previous revision) — "or a decision not to ship one" pre-authorised skipping the Flatpak manifest in the first file a new agent reads.
10. `PORTING.md:18-21` (the previous revision) — the cursor table repeated the false green and claimed "all GTK components ported and observed", which the dial's two high-contrast gaps contradict.

The substantive parity gaps those ledgers are supposed to carry:

| Gap | Reports |
|---|---|
| No Flatpak manifest — upstream is installable from a Flatpak remote, this port by Nix users only | component, unit 2 |
| Dial: the filled wedge gets no high-contrast hairline (`dial.go:432-433`, `:421-422`); `lib/dial.rb#fill_pie` fills and returns | component, unit 4 |
| Dial: the arc's start-cap hairline sweeps the wrong way — `lib/dial.rb:207-210` runs `-π/2`→`+π/2` against upstream's `sweep=false` (`dial.go:457-458`) | component, unit 4 |
| About dialog: Donate / Translate / Source Code / Contribute row titles are four new English msgids in no `.po`, where libadwaita would have supplied translated ones | component unit 6, translation |
| Qt/QML frontend absent | component, no unit |
| `LICENSE` absent for a copyleft licence declared in three places | component, no unit |
| DOAP record and both screenshots absent | component, no unit |
| 42 state-machine examples cannot be executed — no runner installed | test |
| No specs for `lib/metainfo.rb` or `lib/settings.rb`, both display-free | test |
| Widget layer has a driver, not a spec suite | test |
| Catalogues are not wired into the gem build, so a released gem is English-only | translation |
| The 360px window has never been seen in a long-string language (`ca`, `pt_BR`, `uk`) | translation |

The dial is **not** driven under high contrast, which is why its two gaps were
read out of the sources rather than observed.

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
- **GSettings needs a compiled, installed schema**, so the single
  `last-position` key is backed by a JSON file under `XDG_CONFIG_HOME` — the
  same approach as the `gnome-contacts-rb` pilot — preserving key name, type
  and default.
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
- **`adw_about_dialog_new_from_appdata` has no Ruby equivalent.** About-dialog
  fields are filled from the metainfo values by hand via `lib/metainfo.rb`;
  release notes are transcribed rather than read by libadwaita.
- **No gettext wiring in the port's build.** 27 `po/` catalogues (30 messages)
  are present and byte-identical, but translation parity is a separate unit,
  not part of the component port.
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
xvfb-run -a ruby test/drive_main_window.rb     # widgets, headless, shots in tmp/shots/
xvfb-run -a ruby test/drive_translations.rb    # the same window in German
rake install_data PREFIX=$HOME/.local
```

`rspec spec/state_machine_spec.rb` is the intended command for the state
machine and **does not currently run** — see gap 6 above. `require "gtk4"`
calls `gtk_init`, which fails with no display on this stack, hence `xvfb-run`
for anything touching a widget; `FINDINGS.md` has that and the `GEM_PATH` trap.

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
