# frozen_string_literal: true

# The French half of test/drive_translations.rb's wrapping check.
#
#   nix develop --command xvfb-run -a ruby test/drive_translations_fr_window.rb
#
# This is its own process, not a step inside drive_translations.rb, because
# `lib/translations.rb`'s `bindtextdomain` resolves its catalogue from
# `ENV["LANGUAGE"]` once, at `require` time via the `locale` gem — setting
# `Locale.current =` after the fact does not make a bound domain re-resolve,
# and every string built so far stays whatever language the process started
# in. The German run already owns the process that drive_translations.rb
# boots, so French gets a process of its own.
#
# French rather than another complete catalogue because its action-button
# string, "_Démarrer le minuteur", is the longest translation of the whole
# port's shortest-lived label — the one most likely to wrap or clip inside
# the 360px window lib/main_window.rb::WIDTH fixes. A screenshot of it is the
# only way to see whether it does.

require "tmpdir"
require "fileutils"

ENV["LANGUAGE"] = "fr"
ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("sessions-drive-fr")
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

  d.step("the window is built in French, the longest-string catalogue") do
    d.check("the action button carries the French translation, untruncated") do
      window.call.action_button.label == "_Démarrer le minuteur"
    end
    # There is no reliable pixel assertion for "did not wrap or clip" — a
    # button's minimum width already accounts for its own label, so this is
    # a look-at-the-picture check, same as every other screenshot this
    # harness takes. See it at tmp/shots/fr-wrapping.png.
    d.shot("fr-wrapping")
  end

  d.step("the window closes") { window.call.close_window_action.activate(nil) }
end
