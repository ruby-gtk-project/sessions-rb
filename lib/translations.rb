# frozen_string_literal: true

require 'gettext'
require 'glib2'

require_relative 'resources'

# Translations binds this port to upstream's gettext catalogue.
#
# Ported from main.go:19-35, which sets `gettextPackage = "sessions"` and calls
# `i18n.InitI18n(gettextPackage, LocaleDir, ...)` from an `init` function, so
# the domain is bound before any widget is built.
#
# The domain is `sessions`, upstream's, never `sessions-rb`: a catalogue is
# found at `<path>/<lang>/LC_MESSAGES/<domain>.mo`, so the domain *is* the
# filename and renaming it orphans all twenty-six donated `.po` files.
#
# Two bindings, because two different pieces of software read the same `.mo`.
# The `gettext` gem answers `_()` for the strings this port's Ruby builds, and
# GLib answers the `<summary>`/`<description>` elements of
# data/com.pojtinger.felicitas.Sessions.gschema.xml, which carries
# `gettext-domain="sessions"` and is translated by GLib at runtime rather than
# by anything in this process.
#
# Include this module in any class with a translatable string. `bindtextdomain`
# binds to the including class's ancestry rather than to the process, so a
# class that forgets the include silently falls back to the default domain and
# ships English.
#
module Translations
  include GetText

  bindtextdomain(Resources::GETTEXT_DOMAIN, path: Resources::LOCALE_DIR)

  # The GLib-side binding, for the GSettings schema's summary and description.
  # Called once at boot from exe/sessions.
  def self.install
    GLib::GetText.bindtextdomain(Resources::GETTEXT_DOMAIN, Resources::LOCALE_DIR)
  end
end
