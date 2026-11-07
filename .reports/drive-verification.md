# Drive verification — sessions-rb, round eight

**Status: confirmed against `HEAD`.** Rounds six and seven both tried and
failed to reconfirm `.reports/drive-verification.md`'s old round-five numbers
against a tree that had moved eight-plus commits past them, and each found
the same cause: `flake.nix`'s single `devShells.default` pulled in `qtGems`
(the `ruby-qt6-*` Rice/C++ extensions against qtbase/qtdeclarative/qtwidgets)
unconditionally, so *any* use of the devshell — even to drive the GTK-only
frontend, which never loads Qt — paid for compiling those extensions first,
and a shared build machine running other agents' concurrent Qt builds meant
neither `nix develop` nor the extension build it waited on reliably finished
inside a round's time budget. Round six named the fix and did not make it;
this round made it: `flake.nix` now has a separate `devShells.qt`, and
`devShells.default` carries neither `qtGems` nor `qmlStack`. `nix develop
--command true` now returns in under 10 seconds.

With that fixed, every command below was run to completion and its output
read, this round, against `HEAD`:

| | |
|---|---|
| Branch | `ruby` |
| `rake schema:compile && rake gettext:mo && rake gettext:data` | ran clean — 26 `.mo` files, the desktop entry and metainfo merged |
| `bin/rspec spec --options /dev/null --require spec_helper --format progress` | **75 examples, 0 failures** |
| `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` | **173 of 173 checks passed, `DRIVE OK`**, 11 screenshots |
| `nix develop --command xvfb-run -a ruby test/drive_translations.rb` | **51 of 51 checks passed, `DRIVE OK`**, 6 screenshots |
| `nix develop --command xvfb-run -a ruby test/drive_high_contrast.rb` | **21 of 21 checks passed, `DRIVE OK`**, 5 screenshots |

173 + 51 + 21 = 245 checks, the count `TEST_PARITY.md` already carried from a
prior round's static read of the drive scripts — this round is the first to
have actually watched all three reach that number by running them.

The 175-vs-173 difference against the old round-five number is not a
regression from anything in this round: `83cfb05`, eight commits before the
round that first produced the 175 figure went stale, deleted the About
dialog's four invented link rows and their four checks. The scripts'
behaviour is the authority; the stale number was simply never corrected
until now.

Not attempted this round: `test/drive_qt.rb` (the Qt frontend's own driver).
`nix develop .#qt --command true` was started and, inside this round's time,
was still compiling `ruby-qt6-rice`'s C++ extensions (`cc1plus` confirmed
running against its `.cpp` translation units via `ps aux`) — the native
build itself, not shell evaluation, is now the bottleneck, and it is isolated
to `devShells.qt` rather than blocking the GTK work above. `COMPONENT_PARITY.md`
carries this as the Qt frontend's own open row.

Nothing below "round five" in this file's prior revisions was re-observed by
any round between five and seven; this revision replaces the
"unconfirmed"/"not observed" status those rounds left with an actual
re-run. Regenerate this file from a fresh run rather than hand-editing it, on
the same cadence as the root ledgers.

---

## Round five (superseded by the confirmed re-run above, kept for history)

| | |
|---|---|
| Branch | `ruby` |
| Command | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |
| Result | `175 of 175 checks passed` / `DRIVE OK`, 11 screenshots |
| German | `nix develop --command xvfb-run -a ruby test/drive_translations.rb` — `5 of 5` / `DRIVE OK` |
| Specs | `nix develop --command rspec --options /dev/null --require spec_helper --format progress spec` — 45 examples, 0 failures |

### Components exercised

All fifteen classes under `lib/`, plus the two entry shims:

`application.rb`, `main_window.rb`, `dial.rb`, `state_machine.rb`,
`main_menu.rb`, `shortcuts_dialog.rb`, `about_dialog.rb`, `metainfo.rb`,
`settings.rb`, `alarm.rb`, `background_portal.rb`, `ticker.rb`, `style.rb`,
`resources.rb`, `translations.rb` (the last through
`test/drive_translations.rb`, which builds the whole window in German).

Every window and application action is fired, both gestures on the dial are
emitted, the three buttons are clicked as widgets, all six accelerators are
resolved in both directions, the primary menu is opened and read, both dialogs
are opened, read, closed and rebuilt, and the empty state (the shortcuts
dialog with a search that matches nothing) and the refusal states (the dial at
its ceiling and its floor) are both driven and screenshotted.

### Defects that round found by running the app

#### 1 — The About dialog showed its description in twenty languages at once

`lib/metainfo.rb` read every `description/p` and `description/ul/li` out of
`data/com.pojtinger.felicitas.Sessions.metainfo.xml`. That file is the
`msgfmt --xml` merge of all twenty-six catalogues, so each paragraph and
bullet is present once per language as an `xml:lang` sibling. The About
dialog's comments field was therefore the whole description in German,
French, Czech, Ukrainian and the rest, one after another — and the `_()`
`lib/about_dialog.rb` wraps each paragraph in could never match, because what
it was handed was already a translation.

No static reading caught this across four rounds; the existing checks were
`comments.include?('Focus with timed')`, which is true of the broken output
too. It came out of printing the dialog's actual comments.

Fixed: `Metainfo#untranslated` rejects nodes carrying `xml:lang`. Pinned by
`the comments are in one language, not twenty` and `no translation leaked into
the comments`.

#### 2 — The driver re-armed its whole step chain on a second activation

`test/gtk_driver.rb` connected `schedule` to `activate`. This port's
`app.stopAlarmPlayback` calls `@app.activate` to bring the window back after
the notification is clicked — upstream behaviour, correctly ported — so
driving that action started a second, interleaved run of every step. Fixed
with a one-shot guard in the driver; no port code changed.

### Binding limitations, not port bugs

- **`Gtk::Widget#activate` is a no-op on `Gtk::Button`.** It returns `nil` and
  does not activate the button's `action-name`. It fails silently, so a check
  written against it passes for a button wired to nothing. The drive script
  emits `clicked` instead. `FINDINGS.md` records it. No GObject symbol is
  missing — `gtk_widget_activate` is bound, it simply does nothing here.
- **`Adwaita::ShortcutsDialog` renders every row twice** (the list, plus the
  search-results list behind it), so a widget-tree walk finds two labels per
  shortcut. Correct behaviour; the memoisation check compares counts across a
  second `#build` rather than asserting one.
- **The application icon does not resolve from a checkout.** `data/*.svg` are
  installed into hicolor by `rake install_data`; with no install the About
  dialog renders the broken-image placeholder (`tmp/shots/07-about.png`). The
  five symbolic icons the window names all resolve, and are checked.
- No `add_breakpoint` is called anywhere in this port, so the
  `GIArgument(array/C)[interface(enum)]` defect that stopped Chess-Clock-rb
  and Junction-rb does not arise here.

### Dev shell (as of round five)

`flake.nix` had no `rspec` and no `RUBYLIB`, so `bundle exec rspec` answered
`command not found` and the spec suite had never been run in the shell. Both
added, along with the banner naming the app, drive and spec commands.
`spec/spec_helper.rb` required `kettle/test/rspec` unconditionally; kettle-test
is not in the Nix gem bundle, so every example died before its first
assertion. It is now rescued the same way `kettle-soup-cover` already was
above it — the port's own specs use none of its helpers.

Round six's note (made good in round eight above): the `qtGems` addition
after round five is what made *every* use of this shell, including a
GTK-only drive, pay the Qt native extension build. A future round should
split the Qt frontend into its own `devShells.qt` so `nix develop` (the
default) and `nix develop .#qt` are independent builds.
