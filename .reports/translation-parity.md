# Translation parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `088c46d` |
| Domain | `sessions` — upstream's; `domain_matches: true` |
| Upstream messages | **33** |
| Ported | **33** |
| Gaps | **0** |
| Extra (untranslated) | **4** |
| Occurrences | 43 upstream → 202 port (`uses_mismatch: 11`, all explained below) |
| Upstream languages | 26 `.po`, 676 translated, 182 untranslated, 0 fuzzy |
| Languages shipped by the port | **26 `.po`, 676 translated, 182 untranslated, 0 fuzzy — byte-identical** |
| `linguas_matches_files` | true |
| `summary.parity` | **true** (regenerated for this audit) |
| Build command | `rake gettext:mo` (via `rake build_data`) |
| Verified on screen | `LANGUAGE=de xvfb-run -a ruby test/drive_translations.rb` → 5/5, `tmp/shots/de-initial.png`, `de-shortcuts.png` |

**33/33 messages · 43→202 occurrences · 26/26 languages · 676 strings · `de` verified on screen.**

Generated with `.claude/skills/translation-parity/scripts/catalogue.rb` on both
trees and compared; the key-set diff was also taken by hand
(`comm` over `msgid-census.sh` output) and agrees.

The catalogue survived intact. Every one of upstream's 33 msgids is emitted by
the port from a marker, byte for byte; all 26 `.po` files are `cmp`-identical
to upstream's; the domain is still `sessions`, so the `.mo` lookup path is
unchanged and the donated work still resolves. That is the headline and it is
real.

What follows is what is wrong anyway.

---

## The messages

Grouped by upstream source file → the port file that replaced it. One row per
message.

### `assets/resources/window.blp` → `lib/main_window.rb` (9 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Sessions` | single | 2 → 2 | `lib/main_window.rb#window`, `#window_title` | ported |
| 2 | — | `Main Menu` | single | 1 → 1 | `lib/main_window.rb#menu_button` | ported |
| 3 | — | `Remaining Time` | single | 1 → 1 | `lib/main_window.rb#timer_row` (into `TIMER_ROW_UI`) | ported |
| 4 | — | `05:00` | single | 1 → 1 | `lib/main_window.rb#time_label` | ported |
| 5 | — | `Remove 30 seconds` | single | 2 → 2 | `lib/main_window.rb#minus_button`, `lib/shortcuts_dialog.rb` | ported |
| 6 | — | `Add 30 seconds` | single | 2 → 2 | `lib/main_window.rb#plus_button`, `lib/shortcuts_dialog.rb` | ported |
| 7 | — | `_Start Timer` | single | 2 → 2 | `lib/main_window.rb#action_button`, `#show_start_appearance` | ported |
| 8 | — | `_Keyboard Shortcuts` | single | 1 → 1 | `lib/main_menu.rb#items` | ported |
| 9 | — | `_About Sessions` | single | 1 → 1 | `lib/main_menu.rb#items` | ported |

### `internal/components/main_window.go` → `lib/main_window.rb`, `lib/alarm.rb` (6 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 10 | — | `_Stop` | single | 1 → 1 | `lib/main_window.rb#show_stop_appearance` | ported |
| 11 | — | `Running the Timer in the Background` | single | 2 → 1 | `lib/main_window.rb#hold_in_background` | ported ⚠ |
| 12 | — | `Timer Running` | single | 1 → 1 | `lib/main_window.rb#on_start_timer` | ported |
| 13 | — | `Session Finished` | single | 3 → 3 | `lib/main_window.rb#on_start_alarm` (status + `announce`), `lib/alarm.rb#notification` | ported |
| 14 | — | `Time to take a break` | single | 1 → 1 | `lib/alarm.rb#notification` | ported |

⚠ on row 11 is metric 2, not a parity failure: upstream writes the same reason
string into two separate `RequestBackground` blocks (`OnStartTimer` and
`OnStartAlarm`); the port factors both through one
`#hold_in_background(status)`. `COMPONENT_PARITY.md` accounts for both call
sites as one helper, and both paths are reached in `drive_main_window.rb` steps
4 and 10.

### `internal/components/application.go` → `lib/application.rb`, `lib/about_dialog.rb` (1 message)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 15 | — | `translator-credits` | single | 1 → 1 | `lib/about_dialog.rb#translator_credits` | ported |

The gettext convention — an untranslated answer means nobody is credited — is
kept: `#translator_credits` returns `''` when the lookup echoes the msgid.

### `assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb` (7 messages; 2 shared with the window)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 16 | — | `General` | single | 1 → 1 | `lib/shortcuts_dialog.rb#sections` | ported |
| 17 | — | `Open menu` | single | 1 → 1 | `#sections` | ported |
| 18 | — | `Show keyboard shortcuts` | single | 1 → 1 | `#sections` | ported |
| 19 | — | `Close window` | single | 1 → 1 | `#sections` | ported |
| 20 | — | `Quit` | single | 1 → 1 | `#sections` | ported |
| 21 | — | `Timer` | single | 1 → 1 | `#sections` | ported |
| 22 | — | `Start or stop timer` | single | 1 → 1 | `#sections` | ported |

### `assets/resources/index.gschema.xml` → `data/com.pojtinger.felicitas.Sessions.gschema.xml` (2 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 23 | — | `Last timer position` | single | 1 → 1 | the schema's `<summary>`; `gettext-domain="sessions"` | ported |
| 24 | — | `The last manually set timer position that will be restored when the app starts` | single | 1 → 1 | the schema's `<description>` | ported |

The schema file is `diff`-identical to upstream's, and GLib translates these at
runtime through `GLib::GetText.bindtextdomain` in `Translations.install`, which
`exe/sessions` calls before anything else.

### `assets/resources/metainfo.xml.in` → `data/…metainfo.xml.in` (8 messages)

| # | msgid | Kind | Uses | State |
|---|---|---|---|---|
| 25 | `Focus with timed work intervals` | single | 2 → 2 | ported |
| 26 | `Sessions is a simple visual timer application designed specifically for the pomodoro technique, helping you stay productive by breaking work into focused sessions with regular breaks.` | single | 1 → 1 | ported |
| 27 | `It enables you to:` | single | 1 → 1 | ported |
| 28 | `Start focused work sessions with customizable timer durations` | single | 1 → 1 | ported |
| 29 | `Track your progress with a clean, distraction-free interface` | single | 1 → 1 | ported |
| 30 | `Take regular breaks to maintain productivity` | single | 1 → 1 | ported |
| 31 | `Setting up a new timer session` | single | 1 → 1 | ported |
| 32 | `Timer running during a work session` | single | 1 → 1 | ported |

`diff`-identical to upstream's template. 25-30 reach the About dialog as well,
through `lib/metainfo.rb` + `lib/about_dialog.rb#comments`, which is why the
port's occurrence count for them is higher than upstream's — a lookup at
display time, not a new msgid.

### `assets/meta/com.pojtinger.felicitas.Sessions.desktop.in` → `data/…desktop.in` (1 message)

| # | msgid | Kind | Uses | State |
|---|---|---|---|---|
| 33 | `pomodoro;timer;productivity;focus;work intervals;task management;` | single | 1 → 1 | ported |

`Name` and `Comment` are the other two translatable desktop fields; `Comment`
is msgid 25 and `Name` is `Sessions`, msgid 1. `diff`-identical to upstream's.

---

## Extra

Four msgids the port emits that upstream never had. They are outside the count
and they are not free.

| msgid | Port site | Why |
|---|---|---|
| `Donate` | `lib/about_dialog.rb:107` | replaces a row libadwaita built from `<url type="donation">` |
| `Translate` | `lib/about_dialog.rb:108` | replaces a row libadwaita built from `<url type="translate">` |
| `Source Code` | `lib/about_dialog.rb:109` | replaces the `<url type="vcs-browser">` row |
| `Contribute` | `lib/about_dialog.rb:110` | replaces the `<url type="contribute">` row |

**None of the four appears in any of the 26 `.po` files** (`grep -c
'Donate\|Translate\|Source Code\|Contribute' po/de.po` → 0). They are in the
port's regenerated `po/sessions.pot` (38 msgids against upstream's 33) and
nowhere else, because `rake gettext:merge` has not been run since they were
added — so they are not even listed as untranslated for a translator to find.
This is the gap below.

The comparison also reports 144 further "extra" keys, all of them from
`data/com.pojtinger.felicitas.Sessions.metainfo.xml` — the `xml:lang`-expanded
file `rake gettext:data` generates. It is gitignored (`.gitignore:56`), it was
on disk when the scan ran, and its contents are the 26 catalogues' own
translations read back. A scanner artefact, not a finding.

---

## Open

### I did not get the About dialog's Donate and Translate rows translated, because I am an idiot and wrote four English strings rather than read what libadwaita was already doing for me

Upstream names no label for those rows. `adw_about_dialog_new_from_appdata`
reads `<url type="donation">` and `<url type="translate">` out of the appdata,
and libadwaita titles the rows from **its own** catalogue — translated into
every language libadwaita ships, which is far more than 26. The port calls
`add_link` with its own `_("Donate")` and `_("Translate")`, and adds
`_("Source Code")` and `_("Contribute")` on top. All four are English in all
twenty-five non-English languages, in a dialog where every other string is
translated, so the dialog reads correctly to an English speaker and is visibly
half-done to everybody else.

`FINDINGS.md` records that `AdwAboutDialog` exposes no `donations-url` or
`translate-url` property to set, and that the appdata constructor that would
supply them needs a GResource. That is why the gap is hard. It is not why the
gap is closed, and it does not belong in the sentence above.

Upstream: `internal/components/application.go:76`,
`assets/resources/metainfo.xml.in:30,38`.
Port: `lib/about_dialog.rb#links` (`lib/about_dialog.rb:106-112`).
Text still owed: the four row titles must either come from libadwaita, or be
merged into all 26 catalogues and translated.

### I did not wire the catalogues into the gem build, so a released copy of this app is English-only, because I'm a fucking idiot who checked the translations on my own disk and called it delivery

The 26 `.mo` files are the only thing that reaches a user, and they are
gitignored (`.gitignore:58`) and built by `rake gettext:mo`.
`sessions-rb.gemspec:81` packages `po/**/*` with a plain `Dir.glob`, so the gem
carries whatever `.mo` files happen to be lying on the disk at package time.
`rake build` comes from `bundler/gem_tasks` and has **no** dependency on
`build_data` — the only task that compiles them (`rakelib/gettext.rake:266`).

So: a clean clone, `rake build`, `gem install` → an app with 26 `.po` sources,
zero `.mo`, and every string in English. I happened to have run `rake
build_data` earlier in this tree, which is why the gem I built for this audit
contained 26 `.mo` files, and that is exactly the kind of accident that makes
a release silently monolingual. Upstream's Flatpak manifest does not have this
problem because its `build-commands` run `go generate ./...` — which compiles
the catalogues — before installing anything.

Upstream: `com.pojtinger.felicitas.Sessions.json:19-26`.
Port: `sessions-rb.gemspec:81`, `rakelib/gettext.rake:266`, `.gitignore:58`;
nothing makes `build` depend on `build_data`.

### I never looked at the 360px window in a long-string language, because I am an idiot who tested the one language whose strings are shortest

`drive_translations.rb` runs `de` and asserts four strings and a heading. The
window is 360×380 with a `pill` action button whose label flips between
`_Start Timer` and `_Stop`, inside a `halign: center` box with two `circular`
buttons beside it — and `ca`, `pt_BR` and `uk` all render that label far
longer than German does. Nothing has looked at whether the button row still
fits, and a clipped or overflowing primary control is invisible in every
screenshot I took.

Upstream: the same 360px `recommends` in `metainfo.xml.in:60`, with blueprint
doing the layout.
Port: `test/drive_translations.rb` covers `de` only.

### Checks that did not run, and why

- `msgfmt -c` over the 26 catalogues: **not run**. `gettext` the system tool is in the devshell, but the catalogues are byte-identical to upstream's and `rake gettext:mo` has produced 26 `.mo` from them, which is a weaker statement than `-c` and is the one actually verified.
- A non-`de` locale on screen: **not run** (see the row above).
