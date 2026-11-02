# frozen_string_literal: true

require 'json'
require 'fileutils'

require_relative 'resources'

# Settings holds the same key as upstream's GSettings schema,
# assets/resources/index.gschema.xml: `last-position`, an int64 count of
# seconds, defaulting to 300, which records the timer position the user last
# chose so it can be restored on the next start.
#
# Upstream reads it through Gio::Settings, which needs the schema compiled with
# glib-compile-schemas and installed into the system's glib-2.0/schemas
# directory — the app panics on startup without it. Requiring an install step
# to run the port from a checkout is worse than the alternative, so the same
# key, default and semantics are backed by a small JSON file under
# XDG_CONFIG_HOME instead. The schema itself still ships in data/ for
# packaging.
#
class Settings
  DEFAULTS = {
    Resources::SCHEMA_LAST_POSITION_KEY => 300,
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  def location = @path

  # The one key the app reads, named so callers do not repeat the string.
  def last_position = Integer(self[Resources::SCHEMA_LAST_POSITION_KEY])
  def last_position=(seconds)
    self[Resources::SCHEMA_LAST_POSITION_KEY] = Integer(seconds)
  end

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'sessions-rb',
        'settings.json',
      )
    end

    def read
      File.exist?(@path).then do |exists|
        if exists
          JSON.parse(File.read(@path))
        else
          {}
        end
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    rescue SystemCallError => e
      warn "Could not write #{@path}: #{e.message}"
    end
end
