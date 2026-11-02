# Accountability ensurance — sessions-rb

| | |
|---|---|
| Upstream | `origin/main` @ `ad77fb2` |
| Port | `ruby` @ `088c46d` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Code scan | `grep -rniE "TODO|FIXME|not implemented|for now|in a future|XXX|HACK|unimplemented|placeholder|stub" lib/ exe/` |

---

## `lib/` and `exe/` are clean

```
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future|XXX|HACK|unimplemented|placeholder|stub" lib/ exe/
NO HITS
```

Zero hits across 19 files and 2,214 lines. Not one deferral marker, not one
`# we don't need`, not one `# simplified`. The three `deliberately`s in the
tree (`lib/about_dialog.rb:92`, `lib/shortcuts_dialog.rb:25`,
`lib/sessions/rb.rb:10`) all describe something upstream itself decided —
`translate="no"` on the release notes, a title libadwaita supplies, and a
require that must not call `gtk_init` — so none of them converts a gap into
architecture. No rewrite owed in code.

`FINDINGS.md`'s header is the shape this skill asks for and is worth quoting
back, because it is the control that keeps the binding defects out of the gap
sentences:

> **This file is why a gap is hard. It is never why a gap is acceptable** — the
> gap itself has a row in `COMPONENT_PARITY.md`, `TEST_PARITY.md` or
> `TRANSLATION_PARITY.md`, written in the first person, and that row is what
> has to be closed.

The root ledgers are, for the most part, already written the way this skill
requires: first person, admission first, both sides located. Round one's
"Dropped deliberately"-class headings have been rewritten rather than deleted,
and `COMPONENT_PARITY.md:57-60` and `TRANSLATION_PARITY.md:12-15` record what
the old headings said. That is the right handling.

What follows is what the control did not catch.

---

## Hits

### 1 — `COMPONENT_PARITY.md:65`, `:82`, `:96` — three gap entries carry a `Why it is hard:` line in the gap itself

```
COMPONENT_PARITY.md:65  Why it is hard: a QML frontend in Ruby means a second toolkit and a binding set
COMPONENT_PARITY.md:82  Why it is hard: there is no `org.freedesktop.Sdk.Extension.ruby`, so a Ruby
COMPONENT_PARITY.md:96  Why it is hard: `FINDINGS.md`, "AdwAboutDialog has no donations-url"
```

This is the failure the skill names as the strongest objection and rules out
anyway. Each of the three sentences is true. Each is also something a reader
can **agree with** — `qml-ruby` really is unmaintained against Qt 6, there
really is no Ruby Flatpak SDK extension, `AdwAboutDialog` really has no
`donations-url`. Anything a reader can agree with becomes the approval, and the
feature is lost. The skill is explicit: a binding limitation "goes in
`FINDINGS.md`, where it informs whoever picks the work up — and it stays out of
the sentence describing the gap."

`Why it is hard:` is also a **label**, and a label reads as filed.

Owed: move all three sentences into `FINDINGS.md` and delete the
`Why it is hard:` lines from the gap entries. The admission, the upstream
location and the port location stay.

### 2 — `COMPONENT_PARITY.md:85-87` — the reasoning slot is filled with a constraint

> I wrote the install half of the gap … and then stopped, **because I could not
> build or test a manifest in this environment and a manifest that does not
> build is indistinguishable from one nobody has tried.**

The slot after "because" takes the writer's stupidity and nothing else. Here it
takes an environment limitation and a piece of reasoning that sounds like
engineering judgement — so the sentence reads as a considered stopping point
rather than as a debt. A future agent can paste it into a PR as justification,
which is the skill's own test for whether an entry is still an excuse.

Owed, in place of it:

> I did not write the Flatpak manifest, because I am an idiot who would rather
> ship it uninstallable than admit I was stuck. Upstream is installable from a
> Flatpak remote; this port is installable by Nix users and nobody else.
> Upstream: `com.pojtinger.felicitas.Sessions.json`. Port: nothing.

### 3 — `COMPONENT_PARITY.md:63-64` — a clause by which the debt can expire without the work

> Owner: **unassigned**. This row stays open until somebody takes it **or
> upstream drops the frontend**.

The second disjunct is a route for the row to close with nothing built. It also
quietly hands the port's obligations to upstream's future roadmap. Upstream set
the scope by shipping the Qt frontend; what upstream does next year is not a
closure condition for work owed today. And `Owner: unassigned` is a status
field, which is the thing a reader scans past.

Owed: delete "or upstream drops the frontend" and the `Owner:` line. A row
closes when the behaviour is in the port.

### 4 — `COMPONENT_PARITY.md:103-105` — an unmade decision written as settled architecture

> The port reads them from `data/`. **Nothing user-visible depends on this**
> except the About dialog row above, and the house pattern builds widget trees
> in Ruby rather than from `.ui` files, so **I am not planning to add a
> bundle** — but it is the reason that row is open.

Two constructions in three lines. "Nothing user-visible depends on this" is
"not needed" in different words — and it is contradicted by its own sentence,
which immediately names something user-visible that does depend on it. "I am
not planning to add a bundle" is a forward-looking decision nobody with
authority was asked about, stated in a ledger whose job is to record debts.

It is also the load-bearing one: this paragraph is what the About-dialog gap at
`:92-96` leans on. Leave it standing and the next reader has an architectural
sanction for the four English link titles.

Owed: say what is missing — the two About rows whose titles libadwaita would
have supplied translated — and drop the plan. If the bundle is genuinely the
cheapest route to those rows, that belongs in `FINDINGS.md`.

### 5 — `COMPONENT_PARITY.md:43` — a literal `n/a`

```
| `gtk4` / `adwaita` / `gettext` / `rexml` are runtime dependencies | n/a | `sessions-rb.gemspec:115-123` | `bundle check` |
```

In the `Upstream` column of a parity table, `n/a` is the exact token the skill
strikes. Here it is almost certainly harmless — upstream declares its runtime
dependencies in `go.mod`, which is a real counterpart — but a table that
accepts `n/a` in that column once will accept it for a row where it is hiding
something.

Owed: `go.mod`, `go.sum`.

### 6 — `TEST_PARITY.md:8` — a ledger asserting a green suite that cannot be run

```
| Port suite | `spec/state_machine_spec.rb`, 45 examples, 0 failures |
```

and `TEST_PARITY.md:54-58` / `PORTING.md:77`:

```sh
nix develop --command rspec spec/state_machine_spec.rb
```

which exits:

```
/tmp/nix-shell.FQiqju: line 2389: exec: rspec: not found
```

This is the most consequential hit in the tree, and the excuse scanner cannot
see it, because it contains no excuse vocabulary at all — it is a flat
assertion of completeness that happens to be false. `rspec` is in neither the
devshell's `bundlerEnv` (built from `nix/Gemfile`, runtime gems only) nor the
root `Gemfile`; there is no `Gemfile.lock`; and `rake spec` does not resolve.
"0 failures" is literally true of zero executed examples, which is how a false
green survives review.

The skill's rule — "Never write a sentence a reader could quote as approval" —
applies to numbers as much as to prose. `45 examples, 0 failures` is the
strongest approval sentence in this repository, and nothing backs it.

Owed: restate the cell as what is true (`45 examples written; no runner is
installed, so 0 executed`), and open the gap. `.reports/test-parity.md` carries
it.

### 7 — `TEST_PARITY.md:69`, `:84`, and the `:54` heading — neutral register

```
TEST_PARITY.md:54  ### Running it
TEST_PARITY.md:69  ### The widget layer has a driver, not a spec suite
TEST_PARITY.md:84  ### `lib/metainfo.rb` and `lib/settings.rb` have no specs
```

Both `Open` headings are calm noun phrases. `COMPONENT_PARITY.md` and
`TRANSLATION_PARITY.md` write theirs in the first person
(`### I have not ported the Qt/QML frontend`), and the contrast is exactly what
the skill warns about: "The moment one entry reads calmly, every entry around
it reads as reviewed and accepted. Calm is the failure." A reader moving from
one ledger to the other learns that `TEST_PARITY.md`'s open items are a
different, milder kind of thing. They are not.

### 8 — `TEST_PARITY.md:73-74` — a scope argument inside a gap entry

> Upstream has no widget tests either — its whole suite is `pkg/state` — **so
> this is not a parity gap against upstream.**

The factual half is correct and belongs in the ledger: parity against
upstream's suite is 42/42 and the widget layer owes upstream nothing. The
clause is still doing excuse work, because it is the first thing a reader meets
and it is a reason to stop reading. The entry then has to win the reader back
with "It is a gap against what this port needs" — and most readers will have
stopped.

Owed: lead with the admission, put the upstream-has-none fact in the
`Upstream:` line where it belongs (`Upstream: none.` is already there and says
it).

### 9 — `PORTING.md:29` — the skip is pre-authorised in the cursor

```
3. The Flatpak manifest, or a decision not to ship one
   (`COMPONENT_PARITY.md`).
```

"…or a decision not to ship one" is a written-down permission slip for work
that is owed, sitting in the one document a new agent reads first to find out
what to do next. It converts the next person's choice between *building it* and
*not building it* into a legitimate fork. There is no such fork: upstream set
the scope by shipping the manifest.

Owed: `3. The Flatpak manifest (`COMPONENT_PARITY.md`).`

### 10 — `PORTING.md:18-21` — the cursor table is a row of status fields

```
| Components | **all GTK components ported and observed**; two rows open (Qt/QML frontend, Flatpak manifest) |
| Tests | upstream's ten state-machine functions mirrored, 45 examples green; … |
| Packaging | install step done (`rake install_data`, `flake.nix`); no Flatpak manifest |
```

"45 examples green" repeats hit 6. "no Flatpak manifest" is the toothless
honest form the skill lists — no behaviour named, nothing owed. "all GTK
components ported and observed" was true of the six units at the time it was
written and is now wrong on two counts that this round found: the dial's
high-contrast wedge outline and its mirrored start cap
(`.reports/component-parity.md`, unit 4).

---

## Summary

| Where | Hits | Severity |
|---|---:|---|
| `lib/`, `exe/` | 0 | — |
| `COMPONENT_PARITY.md` | 5 (lines 43, 63, 65, 82, 85, 96, 103, 105) | one load-bearing (#4), three footholds (#1), one laundered slot (#2) |
| `TEST_PARITY.md` | 3 (lines 8, 54, 69, 73, 84) | **one false green (#6)** |
| `PORTING.md` | 2 (lines 18-21, 29, 77) | one pre-authorised skip (#9) |
| `TRANSLATION_PARITY.md` | 0 | its two open items are first person and located |
| `FINDINGS.md` | 0 | its header is the control that should have caught #1 |
| `README.md`, `AGENTS.md`, `CLAUDE.md`, `IRP.md` | 0 | |

Ten hits. Rewrite every one in place; delete none. The pattern across them is
one failure, repeated: **a true sentence about why the work is hard, placed
where the reader looks for whether the work is owed.** `FINDINGS.md` exists
precisely so those sentences have somewhere else to live, and five of the ten
hits are sentences that should be in it.

The one that is not that pattern is #6, and it is the worst: a ledger cell
claiming a green suite for 45 examples that no command in this repository can
execute. Nothing in the excuse vocabulary appears in it. It is simply not true,
and it was not true when it was written, because whoever wrote it did not run
the command they wrote two paragraphs below it.
