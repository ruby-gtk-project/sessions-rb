# Translation parity — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `14fcee4` |
| Domain | `sessions` — upstream's. `domain_matches: true` |
| Upstream messages | **33** |
| Ported, byte-identical | **33 / 33** |
| Missing | **0** |
| **Extra (untranslated in 26/26 languages)** | **4** |
| Upstream languages | 26 `.po` |
| Languages shipped by the port | **26 `.po`, all `cmp`-identical to upstream's** |
| Donated strings preserved | **676 translated, 182 untranslated, 0 fuzzy** — identical totals |
| `linguas_matches_files` | true (26 names, 26 files) |
| Build | `rake gettext:mo` → `po/<lang>/LC_MESSAGES/sessions.mo`; `rake gettext:data` merges into `.desktop` and metainfo |
| Verified on screen | `LANGUAGE=de xvfb-run -a ruby test/drive_translations.rb` → 5/5, `tmp/shots/de-initial.png`, `de-shortcuts.png` |
| Round | six |

**33/33 upstream messages survive byte for byte. 26/26 languages ship
unmodified. 676 donated strings still resolve. The domain is still `sessions`,
so the `.mo` lookup path is unchanged.** That is the headline and it is real.

Two things are wrong anyway, and the second is new to this round.

---

## Method

```sh
git show origin/main:po/sessions.pot | grep '^msgid' | sort > up.ids
grep '^msgid' po/sessions.pot        | sort > port.ids
diff up.ids port.ids
```

```
2a3
> msgid ""            # a wrapped multi-line msgid, not a new key
6a8,9
> msgid "Contribute"
> msgid "Donate"
22a26
> msgid "Source Code"
32a37
> msgid "Translate"
```

Nothing on the `<` side: **no upstream key is missing.** Four on the `>` side,
all four from `lib/about_dialog.rb`. The three bare `msgid ""` lines in the
port's `.pot` are the header plus two continuation lines of wrapped msgids
(`Sessions is a simple visual timer…` and `The last manually set timer
position…`); upstream wraps the same two, its `.pot` just wraps them at a
different column. They are not keys.

Catalogue identity, checked per file rather than in aggregate:

```sh
for f in $(git ls-tree -r --name-only origin/main -- po | grep '\.po$'); do
  git show origin/main:$f | cmp -s - $f || echo "DIFFERS: $f"
done
# no output
```

All 26 identical. Per-language `msgfmt --statistics`:

| | | | | | |
|---|---|---|---|---|---|
| bn 22/11 | ca 0/33 | cs 33 | de 33 | en_GB 33 | en_US 33 |
| es 22/11 | et 33 | fi 9/24 | fr 33 | fr_CA 33 | hi 0/33 |
| hr 33 | hu 33 | ia 25/8 | oc 33 | pl 33 | pt 33 |
| pt_BR 33 | ru 19/14 | sv 33 | tr 33 | uk 18/15 | vi 33 |
| zh_Hans 24/9 | zh_Hant 9/24 | | | | |

676 translated, 182 untranslated, 0 fuzzy — the same numbers upstream has,
because they are the same files.

---

## The messages

Grouped by upstream source → the port file that replaced it. One row per key.

### `assets/resources/window.blp` → `lib/main_window.rb`, `lib/main_menu.rb`

| msgid | Port site | State |
|---|---|---|
| `Sessions` | `main_window.rb:154,164` (window title + `Adw::WindowTitle`) | ported |
| `Main Menu` | `main_window.rb:170` | ported |
| `05:00` | `main_window.rb:215` | ported |
| `Remaining Time` | `main_window.rb:210`, substituted into `TIMER_ROW_UI` | ported — substituted rather than `translatable="yes"`, because Builder would look the msgid up in GTK's domain |
| `Remove 30 seconds` | `main_window.rb:239` | ported |
| `_Start Timer` | `main_window.rb:251,383` | ported — mnemonic inside the msgid, as upstream marks it |
| `Add 30 seconds` | `main_window.rb:262` | ported |
| `_Keyboard Shortcuts` | `main_menu.rb:35` | ported |
| `_About Sessions` | `main_menu.rb:36` | ported |

### `internal/components/main_window.go` → `lib/main_window.rb`, `lib/alarm.rb`

| msgid | Port site | State |
|---|---|---|
| `_Stop` | `main_window.rb:392` | ported |
| `Running the Timer in the Background` | `main_window.rb:435` | ported — TRANSLATORS comment carried |
| `Timer Running` | `main_window.rb:325` | ported — TRANSLATORS comment carried |
| `Session Finished` | `main_window.rb:343,347`, `alarm.rb:56` | ported — three sites for the one key (portal status, screen-reader announcement, notification title), as upstream has three |
| `Time to take a break` | `alarm.rb:57` | ported |

### `assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

| msgid | Port site | State |
|---|---|---|
| `General` | `:50` | ported |
| `Open menu` | `:52` | ported |
| `Show keyboard shortcuts` | `:53` | ported |
| `Close window` | `:54` | ported |
| `Quit` | `:55` | ported |
| `Timer` | `:59` | ported |
| `Start or stop timer` | `:61` | ported |
| `Add 30 seconds` | `:63` | ported — shared with the plus button's tooltip, one key both sides |
| `Remove 30 seconds` | `:62` | ported — likewise |

### `internal/components/application.go` → `lib/about_dialog.rb`

| msgid | Port site | State |
|---|---|---|
| `translator-credits` | `:96` | ported — TRANSLATORS comment carried; an untranslated answer becomes `''`, which is gettext's own convention |

### `assets/meta/*.desktop.in` → `data/*.desktop.in`

| msgid | State |
|---|---|
| `Sessions` | ported — same file, `diff`-identical |
| `Focus with timed work intervals` | ported |
| `pomodoro;timer;productivity;focus;work intervals;task management;` | ported — "do NOT translate the semicolons" comment carried |

### `assets/resources/metainfo.xml.in` → `data/*.metainfo.xml.in`

| msgid | State |
|---|---|
| `Focus with timed work intervals` | ported — same key as the desktop summary |
| `Sessions is a simple visual timer application designed specifically for the pomodoro technique, …` | ported |
| `It enables you to:` | ported |
| `Start focused work sessions with customizable timer durations` | ported |
| `Track your progress with a clean, distraction-free interface` | ported |
| `Take regular breaks to maintain productivity` | ported |
| `Setting up a new timer session` | ported |
| `Timer running during a work session` | ported |

All eight are `diff`-identical in the source file, so they cannot drift.

### `assets/resources/index.gschema.xml` → `data/*.gschema.xml`

| msgid | State |
|---|---|
| `Last timer position` | ported |
| `The last manually set timer position that will be restored when the app starts` | ported |

Translated by GLib at runtime from `gettext-domain="sessions"`;
`Translations.install` performs the GLib-side `bindtextdomain`.

---

## Open

### 1 — I invented four English msgids for four rows upstream does not have, and told myself libadwaita would have translated them

```
lib/about_dialog.rb:107  _('Donate')
lib/about_dialog.rb:108  _('Translate')
lib/about_dialog.rb:109  _('Source Code')
lib/about_dialog.rb:110  _('Contribute')
```

None of those four keys exists in any of the 26 `.po` files, because those files
are upstream's and upstream never had the keys. So those four link-row titles
are **English in all twenty-five non-English languages** while every other
string in the same dialog is translated — a Hungarian user reads "Donate" under
a Hungarian heading.

Per the skill, a marked string whose msgid has no upstream counterpart is an
**extra** and an extra is a gap: four keys nobody has translated, and four rows
upstream does not render.

The excuse that shipped with it is worse than the strings. `lib/about_dialog.rb:25-34`
says libadwaita gets the Donate and Translate rows "for free from the appdata's
`<url type="donation">` and `<url type="translate">`" with "labels out of
libadwaita's own catalogue", and that the port is merely reproducing in English
what upstream has in twenty-six languages. **That is not what libadwaita does.**
`Adw-1.gir` (libadwaita 1.9.3) documents `adw_about_dialog_new_from_appdata` as
setting exactly nine properties — `application-icon`, `application-name`,
`developer-name`, `version`, `website`, `support-url`, `issue-url`,
`license-type`, `release-notes`/`release-notes-version` — and no link row is
among them. Nothing in `internal/components/application.go` calls `AddLink`.
Upstream's About dialog has no Donate row at all.

So the real shape is: the port added four rows upstream does not have, paid for
them with four untranslated keys, and wrote a false premise into a source
comment where the next reader inherits it. Both halves are owed, and the comment
is the one to fix first.

Upstream: `internal/components/application.go:76-92`; `Adw-1.gir`,
`adw_about_dialog_new_from_appdata`.
Port: `lib/about_dialog.rb:25-34` (the false premise), `#links:105-112` (the
four keys).

What closes it: drop the four `add_link` calls, or — if the links are wanted —
keep them and get the four msgids upstream so the translators are asked. There
is no third option in which the rows stay and the strings are fine.

### 2 — The port's `.pot` already carries the four extra keys and the 26 `.po` files have never been merged against it, so the first `rake gettext:merge` will churn all twenty-six donated files

`po/sessions.pot` has **38** `msgid` lines; upstream's has **33**. The port's
`.pot` is therefore *not* identical to upstream's — it already records
`Donate`, `Translate`, `Source Code` and `Contribute` at
`lib/about_dialog.rb:107-110`. The 26 `.po` files, meanwhile, are
byte-identical to upstream's and know nothing about them.

`rakelib/gettext.rake:238-239` defines `gettext:merge` as "the only thing that
edits them", depending on `gettext:pot`. The moment anyone runs it, all 26
donated files gain four `#: ../lib/about_dialog.rb` entries with empty
`msgstr`s, every `#:` reference line in them is rewritten from
`../assets/resources/*` to `data/*` and `lib/*`, and the `cmp`-identical
property this report leans on is gone — which also destroys the cheapest check
there is that no donated string was touched.

That is not a reason not to run it; it is a reason the four extra keys have to
be resolved *before* anyone does. Right now the repository is in a state where
its own catalogue-maintenance task is unsafe to invoke and nothing says so.

Upstream: `po/index.go` regenerates `LINGUAS` and merges nothing by hand.
Port: `po/sessions.pot` (38 keys) vs `po/*.po` (33 keys),
`rakelib/gettext.rake:238-256`.

### 3 — Only four of thirty-three messages have ever been seen translated, because I am an idiot who called a five-check driver "verified on screen"

`test/drive_translations.rb` is 4 steps and **5 checks**. It asserts, in German:
the window title, the action button's label with its mnemonic, the menu
button's tooltip, the minus button's tooltip, and that libadwaita's own
shortcuts-dialog heading is German.

That is **4 of the port's own 33 msgids** ever observed resolving. Never
observed in any non-English locale:

- the shortcuts dialog's section titles (`General`, `Timer`) and all seven item
  titles — nine keys, and the dialog is open in `de-shortcuts.png`, so the
  assertions are a two-line addition
- `Remaining Time`, the accessible label, which goes through a `Gtk::Builder`
  snippet and a `REXML::Text.normalize` — the single most fragile translation
  path in the port
- `05:00`, `Add 30 seconds`
- the alarm strings `Session Finished` and `Time to take a break`
- the portal strings `Running the Timer in the Background`, `Timer Running`
- the About dialog's summary, three bullets, two paragraphs and
  `translator-credits` — a path that shipped a *translation* defect in round
  five (comments rendered in all twenty-six languages at once), and whose only
  check is "the comments are in one language", asserted in English
- the eight metainfo and three desktop keys, which `rake gettext:data` merges
  and nothing verifies after merging

The German catalogue is complete (33/33), so every one of those is assertable
today at the cost of a few lines.

Upstream: no equivalent — upstream has no UI tests at all, so this is owed to
the port.
Port: `test/drive_translations.rb`, 5 checks.

---

## Verdict

**Not at parity**, by the skill's own arithmetic: 33 ported, 0 missing, **4
extra**, and an extra is a gap. The donated work is intact and that is worth
saying plainly — 676 strings across 26 languages, every file `cmp`-identical,
the domain unchanged. What is not intact is the claim that the port's catalogue
*equals* upstream's: it is upstream's plus four keys nobody translated, a
`.pot` that already diverges, a merge task that is unsafe to run, and 29 of 33
messages never once seen in another language.
