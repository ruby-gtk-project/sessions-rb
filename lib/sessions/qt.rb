# frozen_string_literal: true

require_relative '../qt_application'

module Sessions
  # The gem-facing name of the Qt frontend, the way `Sessions::Application` is
  # the gem-facing name of the GTK one; the implementation is
  # lib/qt_application.rb.
  #
  # This file exists separately from lib/sessions.rb for the same reason
  # lib/sessions/rb.rb exists: `require "sessions"` loads gtk4 and adwaita,
  # whose load calls gtk_init, and the Qt frontend must not need a GTK display
  # to start. Requiring `sessions/qt` pulls in RubyQt6 and lib/state_machine.rb
  # and nothing from GTK beyond glib2, which lib/ticker.rb needs.
  QtApplication = ::QtApp
end
