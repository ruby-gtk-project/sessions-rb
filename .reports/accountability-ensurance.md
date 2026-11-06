# Accountability ensurance — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `ca7988e` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` over `lib/`, `exe/`, `.reports/`, `PORTING.md`, plus `TODO`/`FIXME`/`not implemented`/`for now`/`in a future` greps |
| Round | seven |
| Verdict | **clean=false** — not because of a new excuse in prose, but because the ledgers this org's own accountability round reports as green cannot be reconfirmed, and were never regenerated after the work that followed them |

`lib/` and `exe/` scan clean. `grep -rniE "TODO|FIXME|not implemented|for now|in a future|XXX" lib/ exe/` returns nothing. That part of round six's finding still holds.

**What is wrong this round is not a sentence anyone wrote. It is a document
that stopped being written.**

---

## The false green: `.reports/drive-verification.md`

This file, unmodified since commit `14fcee4`, says:

> `175 of 175 checks passed` / `DRIVE OK`, 11 screenshots

and is cited by `PORTING.md` and by this org's own practice as the evidence
that the main window, dial, menus and dialogs work. It is **five commits
behind `HEAD`** (`14fcee4..ca7988e`: `83cfb05`, `bf51215`, `bfcf14f`,
`0f80f06`+`99f75f9`+`f7a6bd1`+`aa49212`, `ca7988e`) — the dial's high-contrast
fix, the About-dialog link rows' removal, the German-translation assertions,
the entire Qt frontend, and the Flatpak manifest all post-date the only driver
run this file records.

This round's runtime gate is **`drive_ok=false`, 0 checks passed, 0 failed,
across 8 components.** I tried to reconfirm the 175/175 claim myself, in this
session, in the project's own dev shell:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
nix develop --command bash -c "rake schema:compile && bin/rspec spec ..."
```

Both were started and both sat for **over six minutes and three minutes
respectively, producing zero lines of output**, blocked on a read from the
nix-daemon's unix socket (`/proc/<pid>/wchan` → `unix_stream_read_generic`),
while the host's load average held between 6 and 17 the entire time — other
agents on this shared machine running their own `nix develop` concurrently.
Neither run reached a single check. That is not a reading of the runtime
gate's `drive_ok=false`; it is the same result, reproduced independently.

**So the file that is supposed to be this port's evidence of a working app
asserts a number — 175/175 — that nobody in this round, including me, was able
to make happen even once, on a tree five commits newer than the one it was
measured against.** Whether the drivers would actually pass on `ca7988e` is
unknown. `.reports/drive-verification.md` does not say "unknown"; it says
"DRIVE OK", dated to a commit the repository has moved past. A reader who
trusts the file's own timestamp has no way to know that.

**This is the exact failure mode the skill exists to name**, one level up
from a sentence: a status that was true once, presented with no caveat as
though it still is, read by every subsequent round (`PORTING.md`'s "Done"
table, `COMPONENT_PARITY.md`'s "Driven" row) as current fact. Nobody wrote
"I didn't re-run this" anywhere. The silence is the excuse.

I did not re-run the drivers to completion this round and cannot certify the
175/175 or the 45-example suite as current, because the shared machine would
not finish either job in the time available — and that sentence belongs here,
in the open, rather than left for `.reports/drive-verification.md` to keep
implying by its continued presence that nothing has changed since.

---

## All five `.reports/*.md` are stale relative to `HEAD`, by different amounts

| File | Last touched | Commits behind `HEAD` (`ca7988e`) it does not reflect |
|---|---|---|
| `.reports/drive-verification.md` | `14fcee4` | `83cfb05`, `bf51215`, `bfcf14f`, `0f80f06`, `99f75f9`, `f7a6bd1`, `aa49212`, `ca7988e` — 8 commits, including the dial fix, the About-dialog fix, the German assertions, the whole Qt port, and the Flatpak manifest |
| `.reports/translation-parity.md` | `7b8930e` | predates `83cfb05` (which deleted the four invented About-dialog link msgids this file's Open §1 is built around) and `bfcf14f` (which added the German assertions its Open §3 says do not exist) — **both of its two substantive findings have since been addressed in the tree it is still describing as broken** |
| `.reports/component-identification.md` | `7b8930e` | predates the Qt port and the Flatpak manifest; still describes the Qt frontend as a unit with no port file ("no port counterpart at all"), which has been false since `0f80f06` |
| `.reports/accountability-ensurance.md` (the previous round's copy, overwritten by this one) | `bf51215` | predates the Qt port and the Flatpak manifest entirely |
| `.reports/component-parity.md` | `83cfb05` | predates `bfcf14f`, `bf51215`, and all of the Qt/Flatpak work; its "3/7 units at parity" count has no Qt or Flatpak row at all |

Compare this to the **root-level** ledgers, which this round's commits kept
current: `COMPONENT_PARITY.md` was touched at `ca7988e` itself (the tip),
`TRANSLATION_PARITY.md` at `bfcf14f`, `TEST_PARITY.md` at `bf51215`. The
directory this task asked me to audit and refresh — `.reports/` — is
systematically behind the directory the port's own process already keeps
current. Two ledgers of the same claims exist and they disagree, because one
of them is updated and the other is not.

**Consequence already found by acting on it**: `.reports/translation-parity.md`'s
headline verdict — "**Not at parity**... 4 extra [msgids]" — is wrong *today*.
I independently re-ran the check it describes against current `HEAD`:

```sh
git show origin/main:po/sessions.pot | grep '^msgid' | sort > up.ids
grep '^msgid' po/sessions.pot | sort > port.ids
diff up.ids port.ids
# 2a3
# > msgid ""        — a wrapped continuation line, not a key
```

Zero extra keys, zero missing keys. `lib/about_dialog.rb` no longer calls
`add_link` at all — `commit 83cfb05` removed it. A reader who opened only
`.reports/translation-parity.md`, which this task directed me to, would be
told the port is not at parity for a reason that stopped being true two
rounds ago, and would have no way to know without re-deriving the diff
themselves, which is what found it.

---

## What the scan's other hits are

Every hit `find-excuses.sh` reports outside the above is prose *about* a past
excuse, in a rewrite ledger (`PORTING.md`'s numbered "Open gaps" list,
`.reports/accountability-ensurance.md`'s own prior "worked rewrites" section,
`COMPONENT_PARITY.md`'s note correcting its own Qt row). The skill names this
exemption explicitly — "a document *about* excuses... you should not
rewrite" — and each one I opened quotes the old wording only to say what it
now says instead, which is the rule's own prescribed form, not a live excuse.
`LICENSE.md:423,425` is the AGPL-3.0 text itself ("Not Required"), unrelated
to the port. None of these needed rewriting.

What they do **not** cover is the omission described above, because an
omission has no sentence for the grep to find. That is the whole point of
checking the commit history against the claims rather than the prose alone.

---

## What closes this

1. `.reports/drive-verification.md` needs a real re-run against `ca7988e`,
   not a restatement of `14fcee4`'s numbers with a new date on it. Until the
   shared machine allows one, the file should say **unconfirmed since
   `14fcee4`**, not `DRIVE OK`.
2. `.reports/translation-parity.md`, `.reports/component-parity.md`, and
   `.reports/component-identification.md` need to be regenerated from the
   current tree (this round's copies, below, do that) rather than patched —
   their "Open" sections describe bugs that the commit log says are fixed.
3. Whatever process writes `.reports/` on each round needs to run on every
   round, the same as the one writing the root ledgers does. A ledger that is
   updated four rounds out of five is the fifth round's false green, waiting.
