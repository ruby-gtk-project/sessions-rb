# frozen_string_literal: true

# Builds the window in German and looks at it.
#
#   nix shell nixpkgs#xvfb-run --command xvfb-run -a \
#     nix develop --command ruby test/drive_translations.rb
#
# The catalogue can be perfect and the app still English — a wrong `path:`, a
# domain typo, `bindtextdomain` in a class nothing instantiates — and none of
# those are visible to `msgfmt`, to the census or to a reading of po/. One run
# in one language catches all three, and `tmp/shots/de-initial.png` is the
# record of it.
#
# German because it is complete upstream and because the four strings asserted
# below come through four different routes: a plain `_()` in a memoized widget
# method, a mnemonic label, the window title, and libadwaita\'s own catalogue
# answering for a title this port deliberately does not set.

require "tmpdir"
require "fileutils"

# Set before anything loads: the `gettext` gem resolves the locale through the
# `locale` gem, which reads these at lookup time, and ENV is the only place a
# test can say which language it wants.
ENV["LANGUAGE"] = "de"
ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("sessions-drive-de")
ENV["SESSIONS_SCHEMA_DIR"] ||= File.expand_path("../data", __dir__)

require_relative "../lib/sessions"
require_relative "gtk_driver"

Translations.install

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.mkdir_p(SHOTS)

app = App.new

GtkDriver.drive(app, shots: SHOTS) do |d, application|
  window = -> { application.main_window }

  d.window { window.call.window }

  d.step("the window is built in German") do
    d.check("the title is translated") { window.call.window.title == "Sitzungen" }
    d.check("the action button is translated, mnemonic and all") do
      window.call.action_button.label == "_Timer starten"
    end
    d.check("the menu button tooltip is translated") do
      window.call.menu_button.tooltip_text == "Hauptmen\u00FC"
    end
    d.check("the minus button tooltip is translated") do
      window.call.minus_button.tooltip_text == "30 Sekunden entfernen"
    end
    d.shot("de-initial")
  end

  d.step("the shortcuts dialog opens") { app.shortcuts_action.activate(nil) }

  d.step("libadwaita translates its own heading too") do
    d.check("the dialog heading is German") do
      app.shortcuts_dialog.title == "Tastenk\u00FCrzel"
    end
    d.shot("de-shortcuts")
  end

  d.step("the dialog closes again") { app.shortcuts_dialog.close }
end
