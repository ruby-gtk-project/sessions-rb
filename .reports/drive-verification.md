# Drive verification — sessions-rb, round six

**Status: unconfirmed since `14fcee4`.** Everything below the line is what
round five observed; this round could not reproduce it and the file was
wrongly left to assert `DRIVE OK` as if it still described the current tree.

| | |
|---|---|
| Branch | `ruby` |
| Attempted this round | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |
| Result this round | **Not observed.** `nix develop` never finished evaluating/building the
devshell's closure inside this round's time budget. |
| Cause | `flake.nix` has a single `devShells.default` that unconditionally pulls in
`qtGems` (the `ruby-qt6-*` Rice/C++ extensions against qtbase/qtdeclarative/qtwidgets),
so *any* use of the devshell — even to drive the GTK frontend, which never
loads Qt — pays for compiling those extensions first. `ps aux` during this
round's attempt showed several other `nixbld*` users compiling
`ruby-qt6-qtwidgets` and other large native extensions concurrently on this
shared build box, and `cc1plus` was still running on `.cpp` translation units
well past the point this round had to give up. This is build-machine
contention, not a defect in the drive script or the port.
| Specs | Not attempted this round for the same reason; `rake spec` needs the same devshell. |

Nothing in this file below "round five" has been re-observed. Treat every
check count under it as a claim from a prior round, not a current fact. The
root ledgers (`COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`)
are the ones to check for whether a later round re-ran these drivers; this
file should be regenerated from an actual run — not hand-edited to assert a
result — the next time the shared machine has capacity, and on the same
cadence as those root ledgers so it cannot go stale silently again.

---

## Round five (last confirmed run, now unconfirmed against HEAD)

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

Round six's note: the `qtGems` addition after round five is what now makes
*every* use of this shell, including a GTK-only drive, pay the Qt native
extension build. A future round should split the Qt frontend into its own
`devShells.qt` so `nix develop` (the default) and `nix develop .#qt` are
independent builds.
