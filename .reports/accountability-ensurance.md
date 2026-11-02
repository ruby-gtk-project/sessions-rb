# Accountability ensurance — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `14fcee4` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Code scan | `grep -rniE "TODO\|FIXME\|XXX\|HACK\|not implemented\|unimplemented\|for now\|in a future\|placeholder\|stub\|we don't need\|simplified\|good enough" lib/ exe/` |
| Verdict | **`clean = false`** |
| Hits | **11**, of which **6 are false statements in a ledger** and **1 is a false premise in source** |
| Round | six |

The shape of this round's finding is different from round five's and worse.
Round five found true sentences in the wrong place — reasons why work was hard,
sitting where the reader looks for whether it is owed. Those have mostly been
rewritten. **This round finds sentences that are not true**: six ledger claims
that contradict what the tree does today, and one premise written into a source
comment that contradicts libadwaita's own introspection data. A false green is
the most serious finding this skill can make; a false *red* is only slightly
better, because it spends a reader's attention on work that is already done and
teaches them the ledger cannot be trusted either way.

---

## `lib/` and `exe/` are clean

```
$ grep -rniE "TODO|FIXME|XXX|HACK|not implemented|unimplemented|for now|in a
  future|placeholder|stub|we don't need|simplified|good enough" lib/ exe/
NO HITS
```

Zero hits across 19 files. Not one deferral marker. The `deliberately`s in the
tree (`lib/about_dialog.rb:92`, `lib/shortcuts_dialog.rb:25`,
`lib/sessions/rb.rb:10`) each describe something upstream itself decided —
`translate="no"` on the release notes, a dialog title libadwaita supplies, a
`require` that must not call `gtk_init` — so none converts a gap into
architecture.

`FINDINGS.md`'s header is still the right control and is worth quoting back,
because it is what keeps binding defects out of the gap sentences:

> **This file is why a gap is hard. It is never why a gap is acceptable** — the
> gap itself has a row in `COMPONENT_PARITY.md`, `TEST_PARITY.md` or
> `TRANSLATION_PARITY.md`, written in the first person, and that row is what
> has to be closed.

`FINDINGS.md:70`'s `TODO:` is quoted binding output (`TODO: in Ruby ->
GIArgument(array/C)[interface(enum)](GtkAccessibleProperty)`), not the port's
own marker. Not a hit.

---

## 1 — A false premise, written into source, that turns a gap into "libadwaita would have done this anyway"

**The most serious hit in this audit.**

`lib/about_dialog.rb:25-34` says:

> One thing upstream's dialog has that this one does not: the Donate and
> Translate rows upstream gets for free from the appdata's `<url
> type="donation">` and `<url type="translate">` carry labels out of
> libadwaita's own catalogue, translated into every language libadwaita ships.
> I add them with `add_link` and my own labels instead, so those two row titles
> — and only those — are English in the other twenty-five languages.

`.reports/component-parity.md` (round five) repeated it as a parity table row:
"libadwaita builds them from `<url type="donation">` / `<url type="translate">`,
**with its own translated labels**".

**It is not true.** `Adw-1.gir`, libadwaita 1.9.3, documents
`adw_about_dialog_new_from_appdata` as automatically setting exactly nine
properties:

```
application-icon, application-name, developer-name, version,
website (<url type="homepage">), support-url (<url type="help">),
issue-url (<url type="bugtracker">), license-type (<project_license>),
release-notes + release-notes-version
```

No link row is among them. `git grep -n AddLink origin/main` returns nothing.
`internal/components/application.go:76-92` calls `SetDevelopers`,
`SetArtists`, `SetCopyright` and `SetTranslatorCredits` and nothing else.
**Upstream's About dialog has no Donate row, no Translate row, no Source Code
row and no Contribute row at all.**

So the true statement is: *the port added four rows upstream does not render,
and paid for them with four msgids that exist in none of the 26 donated
catalogues.* The comment converts that into a loss the port merely failed to
avoid — which is the exact move this skill exists to catch, made in the worst
possible place, because a source comment is inherited by every future reader
without a second check.

Rewrite owed, in `lib/about_dialog.rb`:

> I added four link rows upstream does not have and invented four English
> msgids to title them, because I am an idiot who assumed what a libadwaita
> constructor does instead of reading its introspection data.
> Upstream: `internal/components/application.go:76-92`;
> `adw_about_dialog_new_from_appdata` sets nine properties and adds no links.
> Port: `lib/about_dialog.rb#links:105-112` — `Donate`, `Translate`,
> `Source Code`, `Contribute`, none of them in any `.po`.

---

## 2 — `PORTING.md:101` is a false red: it still says zero examples have ever run

> 6. `TEST_PARITY.md:8` — **a false green.** The cell reads "45 examples, 0
>    failures". `rspec` is in neither the devshell nor the root `Gemfile`,
>    there is no `Gemfile.lock`, and the documented command exits `exec: rspec:
>    not found`. Zero examples have been executed.

Verified this session:

```
$ nix develop --command which rspec
/nix/store/qs662rfczraday6vxpssrc0mkr9nj41j-ruby3.4-rspec-core-3.13.6/bin/rspec
$ nix develop --command rspec --options /dev/null --require spec_helper \
    --format progress spec
45 examples, 0 failures
```

The devshell carries rspec-core and the banner prints the invocation.
`TEST_PARITY.md:8` is now **correct** and `PORTING.md:101` calls it a lie. The
first file a new agent reads therefore tells them the suite has never run, which
will send them to rebuild a runner that already exists — and, worse, teaches
them that the ledger's assessments are stale, which is the thing that makes
every *real* gap in it easy to dismiss.

The underlying problem did not vanish, it moved: `rspec spec/state_machine_spec.rb`
— the command `PORTING.md:192` and `TEST_PARITY.md:57` document — still fails,
now with `LoadError: cannot load such file -- rspec_junit_formatter`, because
`.rspec` ends in a formatter the devshell does not carry. So the honest sentence
is "the suite runs under one undocumented invocation and under none of the
documented ones", and nobody has written it. `.reports/test-parity.md` now does.

---

## 3 — `PORTING.md:77` says the AGPL text is missing; `COMPONENT_PARITY.md:51` says it is present. The second one is right

`PORTING.md`'s "Not started" table:

| `LICENSE` — the full AGPL v3 text | nothing; `sessions-rb.gemspec:66` packages `LICENSE.md`, which does not exist |

```
$ md5sum LICENSE.md;  git show origin/main:LICENSE | md5sum
4ae09d45eac4aa08d013b5f2e01c67f6  LICENSE.md
4ae09d45eac4aa08d013b5f2e01c67f6  -
```

34 523 bytes, md5-identical to upstream's `LICENSE`. The gap is **closed** and
`COMPONENT_PARITY.md:51` already records it closed, correctly, with the same
md5 check. Two root ledgers now contradict each other on whether the program
ships the licence it declares — for a copyleft licence that is not a tidiness
point, and "the ledgers disagree" is the worst possible answer to it.

---

## 4 — Three ledgers carry drive counts from two rounds ago

| Claim | Says | Actually |
|---|---|---|
| `PORTING.md:63` | `drive_main_window.rb` → 34/34, 7 screenshots | **175/175, 11 screenshots** |
| `TEST_PARITY.md:9` | 19 steps, 34 checks, 7 screenshots | **47 steps, 175 checks, 11 screenshots** |
| `.reports/component-parity.md` (round five, every reference) | 34/34 | **175/175** |

A stale count is not a neutral typo here, because the whole claim that a
component is *verified* rests on the driver. 34 checks over 15 classes is thin
enough that a reader would be right to doubt the coverage; 175 is not. Under-
reporting the evidence makes the parity verdicts look less supported than they
are, and the one place the coverage genuinely *is* thin — high contrast, zero
checks — is invisible in both numbers.

---

## 5 — `TRANSLATION_PARITY.md` gives three different message counts, none of them the right one

```
TRANSLATION_PARITY.md:9    "31 upstream msgids; 31 of 31 present in the port"
TRANSLATION_PARITY.md:13   "0 of 32 messages marked"
PORTING.md:169             "27 po/ catalogues (30 messages)"
```

The true numbers, from the two `.pot` files and `ls po/*.po`: **33** upstream
msgids, **26** catalogues, and the port emits **37** keys (33 + 4 extras).
Four counts for one quantity across two files, all wrong, and the header table
of the translation ledger is the single place a reviewer looks to decide whether
the donated work survived. It did survive — 676 strings, 26 files
`cmp`-identical — which makes the wrong count gratuitous as well as wrong.

`PORTING.md:169` compounds it: "**No gettext wiring in the port's build.**"
`rakelib/gettext.rake` defines `gettext:mo`, `gettext:data`, `gettext:pot` and
`gettext:merge`, and `rake build_data` runs the first two. The wiring exists and
the ledger denies it.

The same line then adds **"translation parity is a separate unit, not part of
the component port"** — a scope redefinition, the exact pattern the scan flags
at `COMPONENT_PARITY.md:64` and that round five was told to stop using. A
translatable string is part of the component that displays it.

---

## 6 — The Qt frontend's size is overstated twofold in two documents

```
COMPONENT_PARITY.md:59-60           "qt/main.go (87 lines) and qt/main.qml (121 lines)"
.reports/component-inventory.md:321  "qt/main.go (87 lines) and qt/main.qml (121 lines)"

$ git show origin/main:qt/main.go  | wc -l   → 46
$ git show origin/main:qt/main.qml | wc -l   → 52
```

This one inflates the gap rather than hiding it, which is why it is listed last
— but a gap entry whose numbers were never checked is a gap entry a reader can
dismiss wholesale, and the Qt frontend is a real missing component (a whole
second UI over the same `pkg/state`). Writing 87 where the file says 46 is how a
true finding gets argued away.

---

## 7 — Green claims that rest on something never executed

Three of them, all in one place.

`.reports/component-parity.md` Unit 4 marks three high-contrast rows **parity**:

| high contrast: hairlines on the r±5 track circles | parity |
| high contrast: hairlines on the r±5 arcs | parity |
| high contrast: hairline on the handle | parity |

**No test, driver or spec in this repository ever sets high contrast.**
`grep -rn high_contrast test/ spec/` returns nothing; `lib/dial.rb:382` is the
only site. So those three verdicts are transcription against transcription — and
the same branch already contains **two confirmed defects** found by reading
(`#fill_pie` never stroked; the start cap's arc sweeping the wrong way). A branch
with a 2-for-5 known error rate is not a branch whose remaining rows should be
printed as parity without a qualifier.

This round's copy of that report carries the qualifier and counts the
unverifiability as its own open row. That is the minimum; what actually closes it
is one driver step — flip `Adwaita::StyleManager.default.high_contrast`, redraw,
screenshot.

Two smaller instances of the same shape, recorded rather than ranked:

- **`Settings#build_settings`' first path** — `Gio::Settings.new(APP_ID)`, the
  branch a Flatpak or distro install takes — is executed by nothing. Only the
  `SettingsSchemaSource` branch runs from a checkout.
- **`rake gettext:merge`** is described in `rakelib/gettext.rake:238` as "the
  only thing that edits them" and has evidently never been run against the
  current `.pot`: the `.pot` carries 4 keys the 26 `.po` files do not. The first
  run will rewrite every donated file. Nothing warns about that.

---

## Scan output, every hit dispositioned

`find-excuses.sh .` returns 24 lines. None is in `lib/` or `exe/`.

| Location | Phrase | Disposition |
|---|---|---|
| `lib/`, `exe/` | — | **clean** |
| `LICENSE.md:423,425` | "Not Required", "not required" | **not a hit** — the AGPL's own text |
| `.reports/accountability-ensurance.md:20,38,112,125-134,183` | "we don't need", "Dropped deliberately", "not needed", "n/a" ×4, "not ported" | **not a hit** — this file quoting the phrases it was reporting. Preserved in this round's copy only where quoted as evidence |
| `COMPONENT_PARITY.md:49` | "n/a" in the Upstream column (the runtime-dependency row) | **open** — the counterpart is `go.mod`/`go.sum`; round five's rewrite list item 5, still unrewritten |
| `COMPONENT_PARITY.md:57` | "not ported" | **acceptable** — the heading is first person ("I have not ported the Qt/QML frontend") and the line below admits the redefinition; but see hit 6 for its numbers |
| `COMPONENT_PARITY.md:64` | "Out of scope" | **acceptable** — quoted as the phrase that was removed, with the admission attached |
| `TRANSLATION_PARITY.md:13-14` | "not ported yet" | **acceptable** — quoted as round one's wording, with the admission attached; but see hit 5 for its count |
| `PORTING.md:70` | "no Ruby counterpart" | **open** — a table header over rows that are behaviours, not counterparts; and one of its rows, `:77`, is false (hit 3) |
| `PORTING.md:100` | "n/a" | **open** |
| `PORTING.md:104` | "skipping" | **acceptable** — describes what a previous revision pre-authorised |
| `PORTING.md:165-168` | "no Ruby equivalent" | **open** — `adw_about_dialog_new_from_appdata`'s problem is that it needs a GResource, not that it has no equivalent; and this is the line whose misreading produced hit 1 |
| `.reports/component-parity.md:143,214` | "skipped", "n/a" | **acceptable** — "the arc is skipped" is upstream's own behaviour |
| `.reports/component-identification.md:203` | "skipped" | **acceptable** — same |
| `.reports/component-inventory.md:155,318,321` | "skipped", "out of scope", "not ported" | **open** — `:318` is a scope sentence in a document nothing else in `.reports/` now refers to; it also carries hit 6's wrong line counts |

---

## Rewrites owed

In the order they do damage.

1. `lib/about_dialog.rb:25-34` — the libadwaita premise. It is false and it is in source.
2. `PORTING.md:101` — "Zero examples have been executed". Restate: the suite runs under one invocation and under neither documented one.
3. `PORTING.md:77` — the `LICENSE` row. The file exists and is md5-identical.
4. `PORTING.md:63`, `TEST_PARITY.md:9` — 34 checks → 175.
5. `TRANSLATION_PARITY.md:9,13`, `PORTING.md:169` — 31/32/30 messages and 27 catalogues → 33 messages, 26 catalogues, 4 extras; and delete "no gettext wiring" and "translation parity is a separate unit".
6. `COMPONENT_PARITY.md:59-60`, `.reports/component-inventory.md:321-322` — 87/121 lines → 46/52.
7. `COMPONENT_PARITY.md:49`, `PORTING.md:100,165-168` — the three remaining `n/a` / "no Ruby equivalent" slots.
8. `PORTING.md:60-61` — says the about dialog is one of three units at parity *and* that it carries open gaps, in the same sentence.

None of these is a deletion. Every one is a sentence that has to say what the
tree says.

---

## Verdict

**`clean = false`.** 11 hits: one false premise in source, six false or stale
statements in the ledgers, one unrewritten scope sentence, and three green
verdicts resting on a code path nothing has ever executed.

The port's *code* remains clean of deferral markers and its gap entries remain
written in the first person, which is the hard part and it is holding. What has
decayed is the ledgers' agreement with the tree: `LICENSE.md` exists and one
ledger says it does not; the suite runs and one ledger says it never has; the
driver is 175 checks and three documents say 34. A parity ledger that is wrong
in both directions is not a ledger, and the single sentence that most needs
deleting is the one in `lib/about_dialog.rb` that explains away four
untranslated strings with a libadwaita behaviour libadwaita does not have.
