# Translation parity — sessions

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `4f87634` |
| Domain | `sessions` (from `main.go:19`, `gettextPackage = "sessions"`; confirmed against `po/sessions.pot`) |
| Port domain | **none** — no gettext, no `bindtextdomain` |
| Upstream messages | **32** |
| Ported | **0** |
| Gaps | **32** |
| Extra (untranslated) | **4** |
| Upstream occurrences | 35 across 32 messages (3 reused) |
| Port occurrences | 0 through any marker |
| Upstream languages | **26** `.po` files, 682 translated, 182 untranslated, 0 fuzzy over 864 entries |
| Languages shipped by the port | **0** |
| Build command | none exists |
| Checks not run | the app under a non-English locale — `gtk4` is not loadable here, so nothing was observed on screen; `msgfmt` was never invoked because there is no `po/` to compile |

## The headline

Upstream carries **26 catalogues and 682 translated strings**, contributed
through [Weblate](https://hosted.weblate.org/projects/sessions/). The port
carries **none**. There is no `po/` directory, no `LINGUAS`, no `POTFILES.in`,
no `.pot`, no `gettext` gem in `Gemfile` or `sessions-rb.gemspec`, no
`bindtextdomain` call, and not one `_()` anywhere in `lib/` or `exe/`.

`msgid-census.sh` on the port returns 14 rows, and every single one comes from a
`data/` file rather than from Ruby. The port's Ruby emits **zero** catalogue
keys.

## Upstream messages by source

Counts verified three ways: the committed `po/sessions.pot` (32 messages,
`POT-Creation-Date` absent from the header), `msgid-census.sh` over the tree,
and a per-`.po` reconciliation (26 files × 33 `msgid` lines including one header
each).

| Source | Messages |
|---|---:|
| `assets/resources/window.blp` | 9 (`Sessions` ×2 sites) |
| `assets/resources/shortcuts-dialog.blp` | 9 (`Add 30 seconds`, `Remove 30 seconds` shared with `window.blp`) |
| `internal/components/main_window.go` (`L(...)`) | 6 |
| `internal/components/application.go` (`L(...)`) | 1 |
| `assets/resources/metainfo.xml.in` | 9 |
| `assets/meta/*.desktop.in` | 3 (`Sessions` shared) |
| `assets/resources/index.gschema.xml` | 2 |

**Scanner defect:** `msgid-census.sh` does not know the `L(...)` marker that
`github.com/pojntfx/go-gettext/pkg/i18n` exports, so it finds **none** of the 7
Go-side messages (`Running the Timer in the Background`, `Timer Running`,
`Session Finished`, `Time to take a break`, `_Start Timer`, `_Stop`,
`translator-credits`) — and `_Start Timer` only survives the census at all
because the blueprint also declares it. Those seven were censused by hand from
`grep -n 'L("' internal/components/*.go`, and the `.pot` confirms all seven.
Fix: add `L` to the marker alternation.

---

### `assets/resources/window.blp` + `internal/components/main_window.go` → `lib/main_window.rb`, `lib/alarm.rb`, `lib/background_portal.rb`

| # | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|
| 1 | `Sessions` | single | 3 → 0 | `lib/resources.rb:27` as bare `'Sessions'`; also `data/*.desktop:4`, `data/*.metainfo.xml:7` | **gap** | `Sessions` |
| 2 | `Main Menu` | single | 1 → 0 | `lib/main_window.rb:152` bare `'Main Menu'` | **gap** | `Main Menu` |
| 3 | `Remaining Time` | single | 1 → 0 | **nowhere** — the accessible label is not set at all (`lib/main_window.rb:190-194`) | **gap** | `Remaining Time` |
| 4 | `05:00` | single | 1 → 0 | **nowhere** — `format_time(300)` produces the same five characters and no key (`lib/main_window.rb:197`, `:423`) | **gap** | `05:00` |
| 5 | `Remove 30 seconds` | single | 2 → 0 | `lib/main_window.rb:221` bare | **gap** | `Remove 30 seconds` |
| 6 | `Add 30 seconds` | single | 2 → 0 | `lib/main_window.rb:243` bare | **gap** | `Add 30 seconds` |
| 7 | `_Start Timer` | single | 2 → 0 | `lib/main_window.rb:47` bare `START_LABEL` | **gap** | `_Start Timer` |
| 8 | `_Stop` | single | 1 → 0 | `lib/main_window.rb:48` bare `STOP_LABEL` | **gap** | `_Stop` |
| 9 | `_Keyboard Shortcuts` | single | 1 → 0 | `lib/main_menu.rb:14` bare | **gap** | `_Keyboard Shortcuts` |
| 10 | `_About Sessions` | single | 1 → 0 | `lib/main_menu.rb:15` bare | **gap** | `_About Sessions` |
| 11 | `Running the Timer in the Background` | single | 2 → 0 | `lib/main_window.rb:43` bare | **gap** | `Running the Timer in the Background` |
| 12 | `Timer Running` | single | 1 → 0 | `lib/main_window.rb:44` bare | **gap** | `Timer Running` |
| 13 | `Session Finished` | single | 3 → 0 | `lib/main_window.rb:45` and `lib/alarm.rb:26` — **two separate bare literals for one upstream msgid** | **gap** | `Session Finished` |
| 14 | `Time to take a break` | single | 1 → 0 | `lib/alarm.rb:27` bare | **gap** | `Time to take a break` |

Row 13 is worth naming: upstream reaches one key from three call sites. The port
duplicates the English in two constants in two files, so closing this gap means
one `_()` and one shared constant, not two.

Rows 3 and 4 are the two that are invisible in an English screenshot *and*
invisible to a reading of the diff: in both cases the port produces the right
characters by a route no extractor can see, so the English looks right forever
and no language will ever get them.

### `assets/resources/shortcuts-dialog.blp` → `lib/shortcuts_dialog.rb`

| # | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|
| 15 | `General` | single | 1 → 0 | `lib/shortcuts_dialog.rb:18` bare | **gap** | `General` |
| 16 | `Open menu` | single | 1 → 0 | `:19` bare | **gap** | `Open menu` |
| 17 | `Show keyboard shortcuts` | single | 1 → 0 | `:20` bare | **gap** | `Show keyboard shortcuts` |
| 18 | `Close window` | single | 1 → 0 | `:21` bare | **gap** | `Close window` |
| 19 | `Quit` | single | 1 → 0 | `:22` bare | **gap** | `Quit` |
| 20 | `Timer` | single | 1 → 0 | `:24` bare | **gap** | `Timer` |
| 21 | `Start or stop timer` | single | 1 → 0 | `:25` bare | **gap** | `Start or stop timer` |

(`Add 30 seconds` and `Remove 30 seconds` are rows 5–6; the dialog is their
second call site.)

### `internal/components/application.go` → `lib/about_dialog.rb`

| # | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|
| 22 | `translator-credits` | single | 1 → 0 | **nowhere** — deliberately unset, see `accountability-ensurance.md` | **gap** | `translator-credits` |

### `assets/resources/metainfo.xml.in` → `data/com.pojtinger.felicitas.Sessions.metainfo.xml`

Byte-identical copy (diffed, no differences), so all nine keys are present.

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 23 | `Sessions` | single | — | row 1 | **gap** (see below) |
| 24 | `Focus with timed work intervals` | single | 2 → 2 | `data/*.metainfo.xml`, `data/*.desktop:5` | **gap** |
| 25 | `Sessions is a simple visual timer application designed specifically for the pomodoro technique, helping you stay productive by breaking work into focused sessions with regular breaks.` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 26 | `It enables you to:` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 27 | `Start focused work sessions with customizable timer durations` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 28 | `Track your progress with a clean, distraction-free interface` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 29 | `Take regular breaks to maintain productivity` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 30 | `Setting up a new timer session` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |
| 31 | `Timer running during a work session` | single | 1 → 1 | `data/*.metainfo.xml` | **gap** |

### `assets/meta/*.desktop.in` → `data/com.pojtinger.felicitas.Sessions.desktop`

Byte-identical copy.

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 32 | `pomodoro;timer;productivity;focus;work intervals;task management;` | single | 1 → 1 | `data/*.desktop:13` | **gap** |

### `assets/resources/index.gschema.xml` → `data/com.pojtinger.felicitas.Sessions.gschema.xml`

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 33 | `Last timer position` | single | 1 → 1 | `data/*.gschema.xml` | **gap** |
| 34 | `The last manually set timer position that will be restored when the app starts` | single | 1 → 1 | `data/*.gschema.xml` | **gap** |

(Rows 33–34 bring the hand count to 34 rows over 32 distinct messages, because
`Sessions`, `Add 30 seconds` and `Remove 30 seconds` each appear in two
sections. One key, one row in the count; the duplicate appearances are
grouping, and both are flagged in their `Uses` cells.)

## Why the twelve "present" keys are still gaps

The key-set diff says 12 of 32 upstream keys exist in the port. Not one of them
is `ported`, and the reason is the delivery half of the pass condition.

Upstream's `assets/resources/index.go` declares the build steps:

```
//go:generate sh -c "msgfmt --desktop --template ...desktop.in -d ../../po -o - -f > ...desktop"
//go:generate sh -c "msgfmt --xml -L metainfo --template ...metainfo.xml.in -d ../../po -o - -f > ...metainfo.xml"
```

Those two commands are what turn the **templates** into the **shipped** files,
injecting `Name[de]=`, `Comment[fr]=`, `Keywords[zh_Hans]=` and 26 languages'
worth of `<summary xml:lang="…">` from `po/`. The port copied the `.in`
templates, dropped the `.in` suffix, and has no such step. So those 12 keys sit
in files that will be installed as pure English, in 26 languages' worth of
desktops, with the translations sitting in a directory the port does not have.

Equivalently: **0 of 32 messages reach a user in any language other than
English, and 20 of the 32 cannot even be extracted.**

## Extra — keys the port emits that upstream never had

Each is English-only forever; nobody will ever translate a fork's strings.

| Port string | Site | Why it exists |
|---|---|---|
| `Keyboard Shortcuts` | `lib/shortcuts_dialog.rb:33` | the port sets a title upstream leaves unset. Upstream's `Adw.ShortcutsDialog` title comes from libadwaita, already translated into 26 languages. Setting it in English throws that away |
| `Donate` | `lib/about_dialog.rb:25` | should be `donations_url=`, which libadwaita renders with its own translated label |
| `Translate` | `:26` | should be `translate_url=`, same |
| `Source Code` | `:27` | upstream's metainfo has `<url type="vcs-browser">`, which libadwaita renders with its own translated label |

All four are **removals**, not translations. Each one is a string the port
invented in place of one libadwaita already ships in 26 languages.

## `POTFILES.in` completeness

Upstream has no `POTFILES.in` at all — `xgettext` is never run; the `.pot` is
produced by Weblate against the whole tree. So there is nothing for the port to
copy and nothing to check against. The port needs one anyway once it has a
`po/`, and the check is the census, not a grep:

```sh
comm -13 <(grep -v '^#' po/POTFILES.in | sort) \
         <(msgid-census.sh . | cut -f4 | cut -d: -f1 | grep -v '^po/' | sort -u)
```

## `po/` observations carried from upstream

- **No `LINGUAS` is committed.** `assets/resources/index.go:9` generates it from
  the `.po` filenames at build time. So there is no `LINGUAS`-vs-files check to
  run; the port must generate it the same way or commit it.
- **`po/index.go`** sits in the catalogue directory and is Go source, not a
  catalogue. The port has no equivalent and needs none, but a naive
  `cp -r po/` would carry it across.
- **0 fuzzy entries** across all 26 files — unusually clean. 182 untranslated
  entries over 864, so completeness ranges per language but every file ships,
  and must keep shipping: an untranslated entry falls back to the msgid, and a
  deleted language starts its next contributor at zero.

## Report line

```
0/32 messages · 0/35 occurrences · 0/26 languages · 0/682 strings · no locale verified on screen
```

Parity: **false**. 32 gaps, 4 extra, 26 languages missing, domain does not
match (there is no domain).
