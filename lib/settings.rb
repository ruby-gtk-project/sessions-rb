# frozen_string_literal: true

require 'gio2'

require_relative 'resources'

# Settings is the app's one preference: `last-position`, an int64 count of
# seconds defaulting to 300, which records the timer position the user last
# chose so it can be restored on the next start.
#
# Ported from main.go:40-58 together with assets/resources/index.gschema.xml.
# It is a Gio::Settings against the schema in data/, which is where the desktop
# keeps preferences: `gsettings get com.pojtinger.felicitas.Sessions
# last-position` answers, dconf-editor shows the key, backup and sync tools
# that understand GSettings pick it up, and a Flatpak's settings permission
# covers it.
#
# Upstream's two construction paths are both kept, because the second is what
# makes the first optional. With no `SchemaDir` the schema is expected to be
# installed and `gio.NewSettings(AppID)` finds it on the default source; with
# `SchemaDir` set — which the Flatpak build does with a linker flag, and
# flake.nix and the Rakefile do with an environment variable — a
# SettingsSchemaSource is built over that directory with the default source as
# its parent, the schema looked up in it, and the settings object built from
# the schema and the path the schema declares. That second path is what lets
# the app run from a checkout: `rake schema:compile` writes
# data/gschemas.compiled and nothing has to be installed system-wide.
#
# An uninstalled schema with no compiled copy to fall back on aborts the
# process inside GLib rather than raising, exactly as upstream panics, so the
# lookup is checked and a missing schema is raised as a Ruby error with the
# directory in it instead.
#
class Settings
  # The constructor takes an injected Gio::Settings so a test can pass one
  # backed by Gio::MemorySettingsBackend and leave the user's dconf alone.
  def initialize(settings: nil)
    @settings = settings || build_settings
  end

  def [](key) = @settings[key.to_s]

  def []=(key, value)
    @settings[key.to_s] = value
    value
  end

  # The one key the app reads, named so callers do not repeat the string.
  def last_position = @settings.get_int64(Resources::SCHEMA_LAST_POSITION_KEY)

  def last_position=(seconds)
    @settings.set_int64(Resources::SCHEMA_LAST_POSITION_KEY, Integer(seconds))
  end

  # Where the preference actually lives, for the record and for diagnostics.
  def location = "#{Resources::APP_ID} at #{Resources::APP_PATH}"

  private

    def build_settings
      schema_source_directory.then do |directory|
        if directory.nil?
          Gio::Settings.new(Resources::APP_ID)
        else
          settings_from_directory(directory)
        end
      end
    end

    # Upstream's `SchemaDir == ""` test, spelled as a question about the
    # directory rather than about the variable: a compiled schema next to the
    # source is what makes a directory usable.
    def schema_source_directory
      Resources::SCHEMA_DIR.then do |directory|
        if File.exist?(File.join(directory.to_s, 'gschemas.compiled'))
          directory
        end
      end
    end

    def settings_from_directory(directory)
      Gio::SettingsSchemaSource
        .new(directory, Gio::SettingsSchemaSource.default, true)
        .lookup(Resources::APP_ID, false)
        .then do |schema|
          if schema.nil?
            raise "could not find schema #{Resources::APP_ID} in #{directory}"
          end

          Gio::Settings.new(schema: schema, path: schema.path)
        end
    end
end
