# Findings — Ruby GTK4 / Libadwaita bindings

| | |
|---|---|
| Port | `ruby` |
| Upstream | `origin/main` @ `ad77fb2` |
| Bindings | gtk4 4.3.9, adwaita 4.3.9, glib2 4.3.9, gobject-introspection 4.3.9 |
| Stack | GTK 4.20 / libadwaita 1.9 / GLib 2.88.3, nixpkgs-unstable |

Binding defects and limitations, each one checked by running it rather than
read off a signature. **This file is why a gap is hard. It is never why a gap
is acceptable** — the gap itself has a row in `COMPONENT_PARITY.md`,
`TEST_PARITY.md` or `TRANSLATION_PARITY.md`, written in the first person, and
that row is what has to be closed.

Everything here was reproduced inside `nix develop`, under `xvfb-run`.

---

## Confirmed working — three claims from round one that were wrong

All three were written up as defects in `.reports/` without being tried. The
code that was hedged against them has had the hedge removed.

### `Gtk::CssProvider#load(string:)` and `load(data:)` both work

Round one said ruby-gnome's `load` takes only `:data`, `:file`, `:path` and
`:resource`, so `lib/style.rb` "either raises on startup or silently loads
nothing". Neither:

```ruby
Gtk::CssProvider.new.tap { |p| p.load(string: ".probe{color:rgb(1,2,3);}") }.to_s
# => ".probe {\n  color: rgb(1,2,3);\n}\n"
Gtk::CssProvider.new.tap { |p| p.load(data: ".probe{color:rgb(1,2,3);}") }.to_s
# => ".probe {\n  color: rgb(1,2,3);\n}\n"
```

`lib/style.rb` uses `data:`, which is the documented spelling, and the time
card renders opaque — `tmp/shots/01-initial.png`.

### `Gtk::Label#announce(message, priority)` exists

`Gtk::Accessible#announce` is in `instance_methods` and
`label.announce('hi', :high)` returns without raising. The `rescue
StandardError` that wrapped it in `lib/main_window.rb` is gone: a
screen-reader announcement that silently does not happen is the one failure
mode a warning on stderr cannot be noticed through.

### `Gtk::MediaFile.new(path)` is the file constructor

There is no `Gtk::MediaFile.for_filename`. `Gtk::MediaFile.singleton_class`
carries only GObject's own methods and `initialize` takes `*arguments`;
`Gtk::MediaFile.new(path)` gets as far as constructing a `GstPlay`, which is
where it aborts if GStreamer has no `playbin3` element — see below. The
`rescue` that turned a wrong constructor into a permanently silent alarm is
gone.

---

## Real defects

### `Gtk::Accessible#update_property` raises NotImplementedError

The route a blueprint's `accessibility { label: _("Remaining Time") }` block
would take in Ruby:

```ruby
Gtk::ListBoxRow.new.update_property([Gtk::AccessibleProperty::LABEL], ['Remaining Time'])
# gobject-introspection/loader.rb:722:in 'invoke':
#   TODO: in Ruby -> GIArgument(array/C)[interface(enum)](GtkAccessibleProperty)
#   (NotImplementedError)
```

gobject-introspection cannot marshal a C array of enum values. The scalar form
is not an alternative — the binding requires an Array and raises `TypeError` on
anything else — and `Gtk::Widget#at_context` is `nil` before the widget is
realised, so there is no second route through the AT context either.

**Worked around.** `Gtk::Builder` handles the `<accessibility>` element, so
`lib/main_window.rb` builds the one row that needs an accessible label from a
one-object interface string with the translated label substituted in. The
substitution rather than `translatable="yes"` is deliberate: Builder would look
that msgid up in GTK's own domain, not in `sessions`.

Affects: `COMPONENT_PARITY.md` row "Remaining Time accessible label".

### `Adwaita::AboutDialog` has no `donations-url` or `translate-url`

```ruby
Adwaita::AboutDialog.new.set_property('donations-url', 'https://x/')
# GLib::NoPropertyError: No such property: donations-url
```

This is libadwaita, not the Ruby layer: `AdwAboutDialog` genuinely has no such
properties. Upstream does not set them either — it calls
`adw_about_dialog_new_from_appdata`, which reads `<url type="donation">` and
`<url type="translate">` out of the AppStream component and adds link rows
whose *titles* come from libadwaita's own gettext catalogue, translated into
every language libadwaita ships.

`adw_about_dialog_new_from_appdata` takes a **resource** path, and this port has
no GResource bundle, so that constructor is not reachable from a file in
`data/`.

**Partly worked around.** `lib/about_dialog.rb` adds the same rows with
`add_link` and its own `_()`-marked titles. Every other field the appdata
constructor would have supplied — summary, description, bullets, release notes,
licence, URLs — is set from `lib/metainfo.rb`. What stays English in the other
twenty-five languages is four row titles: Donate, Translate, Source Code,
Contribute.

Affects: `COMPONENT_PARITY.md` and `TRANSLATION_PARITY.md` rows "About dialog
link titles".

### `Adwaita::ShortcutsItem.new` has two indistinguishable signatures

```
available signatures:
Adwaita::ShortcutsItem#initialize(title: utf8, accelerator: utf8)
Adwaita::ShortcutsItem#initialize(title: utf8, action_name: utf8)
```

Both are two strings, so the binding cannot tell them apart, and keyword
arguments are rejected outright. `lib/shortcuts_dialog.rb` therefore always
constructs with an empty accelerator and assigns `action_name=` afterwards,
which resolves correctly: the dialog renders `Ctrl` + `?` and `Ctrl` + `W`
rather than the literal `<Control>` strings round one hardcoded
(`tmp/shots/06-shortcuts.png`).

### `require "gtk4"` raises `Gtk::InitError` with no display

`gtk_init` fails without a display server on this stack, whatever `GDK_BACKEND`
is set to and with `DISPLAY`/`WAYLAND_DISPLAY` unset. The `ruby-gtk-testing`
skill says GTK4 renders offscreen and needs no Xvfb; that is not true here, and
it is one of the two reasons round one reported the port as unrunnable.

**Worked around.** `pkgs.xvfb-run` is in the devshell and
`test/drive_main_window.rb` documents the invocation.

### A `GEM_PATH` in the environment hides the app's own gems

`pkgs.bundler` and `pkgs.bundix` each export a `GEM_PATH`, and a `GEM_PATH` in
the environment *replaces* a wrapped ruby's own gem path instead of adding to
it. The symptom is `cannot load such file -- gtk4 (LoadError)` from a devshell
that has gtk4 installed, which is the other reason round one could not run
anything.

**Fixed** in `flake.nix`'s `shellHook`, which prepends the bundlerEnv's gem
directory.

### `Gtk::MediaFile` aborts the process without GStreamer's `playbin3`

```
GStreamer-Play-ERROR: GstPlay: 'playbin3' element not found, please check your setup
Aborted (core dumped)
```

`g_error`, so it is an abort and not an exception: no `rescue` can see it, and
the whole run dies at the step that starts the alarm.

**Fixed** in `flake.nix` by putting `gst-plugins-base` and `gst-plugins-good`
in the devshell and in the package, and setting `GST_PLUGIN_SYSTEM_PATH_1_0`.

### `GtkWidgetPaintable` yields no render node in the same tick as a `queue_draw`

Anything that calls `queue_draw` invalidates the window's cached render node,
and `Gtk::WidgetPaintable#snapshot` then produces nothing until the frame clock
has run again. A screenshot taken in the same driver step as the change it is
meant to show fails with "widget produced no render node", so a run writes its
first picture and silently skips the rest — which is how a drive can report
itself green while showing you nothing.

**Worked around** in `test/drive_main_window.rb`, where every `shot` is its own
step. `test/gtk_driver.rb` also shares one realised `Gsk::CairoRenderer` across
a run and unrealises it before exit, because `GskRenderer` asserts it is
unrealised on dispose and aborts the process if it is not.

### `Gtk::Widget#activate` is a no-op on a `Gtk::Button`

Round four's drive script clicked the window's three buttons with
`button.activate`, on the strength of the C API's `gtk_widget_activate`.
In these bindings it returns `nil` and nothing happens — the action the
button names is never activated:

```ruby
window.plus_button.activate          # => nil
window.dial.remaining_time           # => 300, unchanged
window.plus_button.signal_emit('clicked')
window.dial.remaining_time           # => 330
```

This matters more for testing than for the app, because `activate` fails
*silently*: a check written against it passes for a button wired to nothing at
all, which is the opposite of what a check is for. `test/drive_main_window.rb`
emits `clicked`, which is the signal `GtkButton` turns into an action
activation, so the `action-name` wiring really is under test.

Nothing in `lib/` calls `Gtk::Widget#activate`, so no port code changed.

### `Adwaita::ShortcutsDialog` renders every row twice

Not a defect, but it reads like one from the outside and cost an hour. The
dialog keeps a search-results list behind the list it shows, so a walk of its
widget tree finds two `Gtk::Label`s per shortcut and two per section heading.
A check that each row appears exactly once therefore fails on a dialog that is
perfectly correct. `test/drive_main_window.rb` compares the count before and
after a second `#build` instead, which is what the memoisation claim actually
needs.

### `rexml` is a bundled gem, not a default one

`require "rexml/document"` fails inside a bundlerEnv unless `rexml` is a
declared dependency. It is one now, in `sessions-rb.gemspec` and `nix/Gemfile`.

### GNU `xgettext` has no Ruby mode

Upstream extracts its Go with `--language=C++`, which happens to work for Go's
double-quoted strings. Applied to Ruby it would miss every single-quoted
`_('…')`, which is most of this port. `rake gettext:pot` uses `rxgettext` from
the `gettext` gem for the Ruby pass and joins the desktop, metainfo and gschema
passes onto it with `xgettext -j`.

Related: `metainfo.its` ships with gettext and `gschema.its` ships with glib, so
on a system that keeps packages apart the two ITS rules live in two
directories. `rakelib/gettext.rake` searches for each by name rather than
assuming `/usr/share/gettext/its`.

### No vfunc override for `snapshot`, and no `Gsk` path builder

Upstream's dial is a registered `GObject` subclass of `GtkWidget` overriding
the `snapshot` vfunc, drawing with `Gsk::PathBuilder`, `Gsk::Stroke`,
`AppendFill`/`AppendStroke` and `Graphene::Point`. The Ruby bindings expose
neither a usable vfunc override for `snapshot` nor the `Gsk` path API, so the
mechanism is not available.

This is a reason the mechanism differs. It is **not** a reason the dial could
not be drawn: `lib/dial.rb` draws the same shapes with Cairo arcs in a
`Gtk::DrawingArea` `set_draw_func`, and the result has been looked at
(`tmp/shots/01-initial.png`, `03-counting-down.png`, `05-alarming.png`).
