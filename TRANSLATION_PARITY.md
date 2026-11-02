# Translation parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` |
| Domain | `sessions` — upstream's, never `sessions-rb` |
| Catalogues | 26 `.po`, copied from upstream unchanged |
| Messages | 33 upstream msgids; **33 of 33 present in the port, and no extras** |
| Census | `.claude/skills/translation-parity/scripts/msgid-census.sh` |

Round one shipped no `po/` directory, no gettext gem, no `bindtextdomain` and
not one `_()`: 0 of 33 messages marked, 0 of 26 languages shipped, and the
only note about it said the catalogues were "not ported yet", which read as a
sequencing decision for work that was not scheduled.

This file has also given three different counts for the same thing: 31 msgids
in the table above, 32 in the paragraph above, 30 in `PORTING.md`, and 27
catalogues there against 26 here. The count, from
`msgcat --no-location --sort-output` over both `.pot` files and `ls po/*.po`:
**33 msgids, 26 catalogues.** The port's `.pot` and upstream's now differ only
in the header block upstream extracts with `--omit-header`; every msgid and all
four `TRANSLATORS:` comments match.

---

## What is in place

### The catalogues

`po/` holds upstream's twenty-six `.po` files byte for byte, plus
`po/LINGUAS` (generated from them) and `po/POTFILES.in` (rewritten to the
Ruby paths, since upstream's extraction names `.go` and `.blp` files this
port does not have). 612 translated strings. **Nothing in this repository
writes to a `.po` file except `rake gettext:merge`, which runs `msgmerge`.**
They are donated work.

`po/sessions.pot` is regenerated, because upstream's referenced
`../internal/components/*.go` and `../assets/resources/*.blp`. The msgid set is
upstream's exactly: it carried four extra link titles until this round, and
those are gone with the rows that needed them.

**`rake gettext:merge` will still churn all twenty-six catalogues.** The four
extra keys that would have added empty `msgstr` entries are resolved, but
`msgmerge --update` also rewrites every `#:` reference line from upstream's
`../assets/resources/*` and `../internal/components/*` to this port's `data/`
and `lib/` paths. That destroys the `cmp`-identical property, which is the
cheapest available proof that no donated string has been touched — so the task
is not a routine one to run, and `rakelib/gettext.rake` says so at its
definition.

### The binding

`lib/translations.rb` binds the domain twice, because two different pieces of
software read the same `.mo`:

* the `gettext` gem answers `_()` for the strings this port's Ruby builds;
* `GLib::GetText.bindtextdomain` covers the GSettings schema, whose
  `<summary>` and `<description>` GLib translates at runtime from
  `gettext-domain="sessions"`.

`exe/sessions` calls `Translations.install` before building anything, which is
where `main.go:19-35` does it from an `init` function. Every class with a
translatable string includes `Translations`; `bindtextdomain` binds to the
including class's ancestry, not to the process, so a class that forgets the
include ships English silently.

`Resources::LOCALE_DIR` defaults to `po/` in the tree and is overridden by
`SESSIONS_LOCALE_DIR`, which is upstream's `LocaleDir` package variable — set
by a linker flag there, by `flake.nix`'s wrapper here.

### The build steps

| Task | What it does | Upstream equivalent |
|---|---|---|
| `rake gettext:mo` | one `.mo` per language, `msgfmt -c --check-format` | `po/index.go` go:generate #3 |
| `rake gettext:data` | `msgfmt --desktop --template` and `msgfmt --xml -L metainfo --template` over `po/`, writing the installed `.desktop` and `.metainfo.xml` | upstream's build |
| `rake gettext:pot` | re-extract, `rxgettext` for Ruby + `xgettext -j` for the three non-Ruby sources | go:generate #1 |
| `rake gettext:merge` | `msgmerge --update --backup=none` | go:generate #2 |
| `rake install_data` | installs the catalogues to `share/locale/<lang>/LC_MESSAGES/sessions.mo` | Flatpak build-commands |

`-c --check-format` rather than a bare `msgfmt`, because upstream's catalogues
carry `#, c-format` flags and that is the check that stops a translator's
`%s` typo from crashing the app in one language only.

### The twelve msgids that live in data files

`data/*.desktop.in` and `data/*.metainfo.xml.in` are templates again, and the
generated `data/*.desktop` and `data/*.metainfo.xml` are build output,
`.gitignore`d. After `rake gettext:data` the desktop entry carries 24
`Name[…]`/`Comment[…]` lines and the metainfo 178 `xml:lang` elements. Round
one shipped the templates with the `.in` dropped and no merge step, so those
twelve messages were English in all twenty-six languages however complete
`po/` was.

`data/*.gschema.xml` is **not** a template: it carries
`gettext-domain="sessions"` and GLib translates it at runtime, which is what
upstream does too.

### The two msgids no extractor could see

* `Remaining Time` (`window.blp:53-55`) was not set anywhere in the port.
  It is now the accessible label on the time row, built through
  `Gtk::Builder` because `update_property` raises (`FINDINGS.md`).
* `05:00` (`window.blp:58`) was computed by `format_time(300)`.
  `lib/main_window.rb#time_label` now initialises from `_('05:00')`, matching
  the blueprint default, and the dial overwrites it on the first update as
  before.

---

## Open

### Closed: the four extra link titles are gone

`Donate`, `Translate`, `Source Code` and `Contribute` were four msgids this
port invented, in none of the twenty-six donated catalogues, rendering in
English under a translated heading in all twenty-five non-English languages.
The entry here said libadwaita "adds those rows with titles out of its own
catalogue", which is what `lib/about_dialog.rb` said too, and it is false:
`adw_about_dialog_new_from_appdata` sets nine properties and no link row
(Adw-1.gir, libadwaita 1.9.3), and `git grep AddLink origin/main` is empty.
Upstream's dialog has no such rows, so there was nothing for libadwaita to
translate and nothing for the port to reproduce — there were four components I
added and then described as parity.

The four `add_link` calls are deleted, `po/sessions.pot` is back to upstream's
33 msgids, and `test/drive_main_window.rb` now checks that none of the four
titles appears in the rendered dialog.
Upstream: `internal/components/application.go:84`.
Port: `lib/about_dialog.rb`.

### Closed: all 33 msgids are now seen resolved in German

`test/drive_translations.rb` was five checks over four msgids — the window
title, the action button, two tooltips and libadwaita's own shortcuts heading.
The other twenty-nine were carried as translated because the catalogue has
them, which is the reasoning that let the About dialog render its description
in twenty languages at once for a whole round.

It is 51 checks over six screenshots now, and the three routes that can fail
while the catalogue is perfect are asserted differently:

* through the component's own `#_`, not a top-level `_()`, for anything with no
  getter — the two alarm strings, the two portal strings and `Remaining Time`.
  `bindtextdomain` binds to the including class's ancestry, so a class that
  forgets `include Translations` ships English while everything else is
  translated, and only a lookup through that class can see it.
* off the rendered widget, for everything GTK or libadwaita puts on screen: the
  two menu items, the shortcuts dialog's two sections and seven rows (plus a
  check that no English row is left beside them), `_Stoppen` after the toggle,
  and the About dialog's `comments` and `translator-credits` — including that
  the English description is *not* in `comments` as well.
* off the merged `data/` files, for the eleven msgids no Ruby ever sees;
  `rake drive:translations` runs `gettext:data` first so the step asserts the
  merge instead of skipping it.

The schema's `<summary>` and `<description>` are asserted through
`Gio::SettingsSchemaKey`, which is the only way to see
`GLib::GetText.bindtextdomain` work at all — it is a different binding from the
gettext gem's and nothing had ever exercised it.
Port: `test/drive_translations.rb`, 51 checks over all 33 msgids.

### Twenty-five languages have never been looked at

German has: `test/drive_translations.rb` builds the window under `LANGUAGE=de`
and asserts the title (`Sitzungen`), the action button with its mnemonic
(`_Timer starten`), two tooltips and libadwaita's own dialog heading
(`Tastenkürzel`), with `tmp/shots/de-initial.png` as the record. That one run
is what proves the `path:`, the domain and the `bindtextdomain` placement are
right, and none of those three could have been proved by `msgfmt`, by the
census or by reading `po/`.

The other twenty-five are untried. The one I would expect to show something is
not another Latin-script language but a right-to-left one — and this app ships
none, so the next most useful is a long-string language against a 360px window:
`ca`, `pt_BR` and `uk` all have `Running the Timer in the Background` and
`_Start Timer` noticeably longer than the English.
Port: `test/drive_translations.rb` covers `de` only.
