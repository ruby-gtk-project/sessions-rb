# Translation parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` |
| Domain | `sessions` — upstream's, never `sessions-rb` |
| Catalogues | 26 `.po`, copied from upstream unchanged |
| Messages | 31 upstream msgids; **31 of 31 present in the port** |
| Census | `.claude/skills/translation-parity/scripts/msgid-census.sh` |

Round one shipped no `po/` directory, no gettext gem, no `bindtextdomain` and
not one `_()`: 0 of 32 messages marked, 0 of 26 languages shipped, and the
only note about it said the catalogues were "not ported yet", which read as a
sequencing decision for work that was not scheduled.

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
`../internal/components/*.go` and `../assets/resources/*.blp`. The msgid set
is upstream's plus the four link titles described below.

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

### Four link titles in the About dialog are English everywhere

`Donate`, `Translate`, `Source Code` and `Contribute`. They are marked with
`_()` and they are in `po/sessions.pot`, so a translator can supply them — but
they are not in any of the twenty-six donated catalogues, because upstream
never had to translate them: `adw_about_dialog_new_from_appdata` adds those
rows with titles out of libadwaita's own catalogue.

So a German user sees four English words in an otherwise German dialog, and
will keep doing so until either a Weblate round picks the new msgids up or the
port finds a way to reach libadwaita's domain.
Upstream: `internal/components/application.go:76`.
Port: `lib/about_dialog.rb#links`.
Why it is hard: `FINDINGS.md`, "AdwAboutDialog has no donations-url".

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
