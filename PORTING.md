# Porting — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` (Go + puregotk, blueprint UI in a GResource) |
| Port | `ruby` (GTK4 + Libadwaita through ruby-gnome) |
| Ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |

The cursor: where the port is, what is next, and how to run it.

---

## Unit cursor

| Unit | State |
|---|---|
| Inventory | done — `.reports/component-inventory.md` |
| Components | **all GTK components ported and observed**; two rows open (Qt/QML frontend, Flatpak manifest) — `COMPONENT_PARITY.md` |
| Tests | upstream's ten state-machine functions mirrored, 45 examples green; widget layer has a driver, not a suite — `TEST_PARITY.md` |
| Translations | 26 catalogues, domain `sessions`, 31 of 31 upstream msgids marked; four new link titles untranslated — `TRANSLATION_PARITY.md` |
| Packaging | install step done (`rake install_data`, `flake.nix`); no Flatpak manifest |

**Next**, in order:

1. Specs for `lib/metainfo.rb` and `lib/settings.rb` — both display-free
   (`TEST_PARITY.md`).
2. A long-string language through `test/drive_translations.rb` against the
   360px window — `ca`, `pt_BR` or `uk` (`TRANSLATION_PARITY.md`).
3. The Flatpak manifest, or a decision not to ship one
   (`COMPONENT_PARITY.md`).
4. The Qt/QML frontend row, which currently has no owner.

---

## File map

One upstream source file, one `lib/*.rb`.

| Upstream | Port |
|---|---|
| `main.go` (i18n init, settings, app construction) | `exe/sessions`, `lib/translations.rb`, `lib/settings.rb` |
| `internal/components/application.go` | `lib/application.rb`, `lib/about_dialog.rb` |
| `internal/components/main_window.go` + `assets/resources/window.blp` | `lib/main_window.rb`, `lib/main_menu.rb`, `lib/alarm.rb`, `lib/background_portal.rb` |
| `internal/components/dial.go` | `lib/dial.rb` |
| `pkg/state/machine.go`, `pkg/state/constants.go` | `lib/state_machine.rb`, `lib/ticker.rb` |
| `assets/resources/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` |
| `assets/resources/style.css` | `lib/style.rb` |
| `assets/resources/index.go` | `lib/resources.rb` |
| `assets/resources/metainfo.xml.in` | `data/…metainfo.xml.in` + `lib/metainfo.rb` |
| `po/index.go` (go:generate lines) | `rakelib/gettext.rake` |
| `pkg/state/machine_test.go` | `spec/state_machine_spec.rb`, `spec/support/manual_ticker.rb` |
| `qt/main.go`, `qt/main.qml` | *nothing — open row* |
| `com.pojtinger.felicitas.Sessions.json` | *nothing — open row* |

`lib/ticker.rb` has no upstream file of its own: it is the seam that replaces
`testing/synctest`, and `TEST_PARITY.md` says why it had to exist.

---

## Running it

```sh
direnv allow          # or: nix develop
```

The devshell carries Ruby 3.4, GTK4, Libadwaita, the introspection typelibs,
GStreamer (for the alarm), gettext, glib-compile-schemas and Xvfb.

```sh
# Build what a desktop needs: catalogues, merged data files, compiled schema.
rake build_data

# Run it.
ruby -Ilib exe/sessions

# The state machine, no display needed.
rspec spec/state_machine_spec.rb

# The widgets, headless, with screenshots in tmp/shots/.
xvfb-run -a ruby test/drive_main_window.rb

# The same window in German.
xvfb-run -a ruby test/drive_translations.rb

# Install the desktop entry, metainfo, icons, schema and catalogues.
rake install_data PREFIX=$HOME/.local
```

`require "gtk4"` calls `gtk_init`, which fails with no display on this stack —
hence `xvfb-run` for anything that touches a widget. `FINDINGS.md` has the
details, along with the `GEM_PATH` trap that makes a correctly-installed gtk4
look missing.

---

## House shape

Set by the pilot port at `../gnome-contacts-rb` and by
`.claude/skills/ruby-gtk`:

* one upstream source file maps to one `lib/<thing>.rb`;
* every file opens with `# frozen_string_literal: true`, then `require
  'adwaita'` and `require_relative` for siblings;
* every class carries a comment naming the upstream file it was ported from,
  plus any behaviour worth knowing;
* widgets are built declaratively with memoized accessors and `.tap` blocks,
  never long imperative constructors;
* widget methods stay **public** — the driver reaches them by name, and a
  stray `private` above the memoized section locks the tests out of the UI.

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies.
