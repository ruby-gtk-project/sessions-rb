# frozen_string_literal: true

# The backend has to be chosen before the first Gio::Settings is built, and
# GLib caches it process-wide, so this is the earliest point there is. Nothing
# in this file may touch the developer's own dconf: last-position is a real key
# in a real schema, and a spec that wrote to it would move the timer position
# of the installed app.
ENV["GSETTINGS_BACKEND"] = "memory"

require "tmpdir"

require_relative "../lib/settings"

# lib/settings.rb keeps both of upstream's construction paths — main.go:40-58 —
# and only one of them had ever been executed. Every driver run and every
# checkout takes the SettingsSchemaSource path, because data/gschemas.compiled
# is there; the plain `Gio::Settings.new(APP_ID)` path is the one a Flatpak or
# a distro install takes, where the schema is installed system-wide and
# SchemaDir is empty. That path was carried as parity on a reading.
#
# Both are exercised here. The schema is found through GSETTINGS_SCHEMA_DIR,
# which flake.nix's dev shell points at data/, so the installed case is the
# same lookup an installed copy does.
RSpec.describe Settings do
  # The memory backend is one store for the whole process, so an example that
  # writes the key would otherwise decide what the next example reads — and
  # .rspec runs in random order. Every example starts from the schema's own
  # default.
  before do
    Gio::Settings.new(Resources::APP_ID).reset(Resources::SCHEMA_LAST_POSITION_KEY)
  end

  # A directory holding a compiled schema that is not the app's, which is the
  # one way to reach the nil the port checks for: GLib raises before the
  # lookup if there is no gschemas.compiled at all.
  def compiled_schema_directory(id)
    Dir.mktmpdir("sessions-settings-spec") do |directory|
      File.write(
        File.join(directory, "#{id}.gschema.xml"),
        %(<schemalist><schema id="#{id}" path="/com/example/Other/"><key name="k" type="b">) +
          %(<default>false</default></key></schema></schemalist>),
      )
      unless system("glib-compile-schemas", directory, out: File::NULL, err: File::NULL)
        raise "glib-compile-schemas is not on PATH; run the specs in the dev shell"
      end

      yield(directory)
    end
  end

  # Upstream's `SchemaDir == ""` case: no directory to build a source over, so
  # the schema is expected on the default source. Subclassed rather than
  # stubbed, so the spec exercises the real `#build_settings` branch rather
  # than a double standing in for it.
  class InstalledSettings < Settings
    private

      def schema_source_directory = nil
  end

  describe "the SettingsSchemaSource path" do
    subject(:settings) { described_class.new }

    it "finds the schema in the directory beside the source" do
      expect(settings.send(:schema_source_directory)).to eq(Resources::SCHEMA_DIR)
    end

    it "reads the schema's own default back for last-position" do
      expect(settings.last_position).to eq(300)
    end

    # GSettings paths end in a slash and Resources::APP_PATH does not, because
    # it is also what #location prints. The schema is the authority on the
    # path, which is why lib/settings.rb passes `schema.path` rather than the
    # constant.
    it "builds its settings against the path the schema declares" do
      expect(settings.send(:settings_from_directory, Resources::SCHEMA_DIR).path)
        .to eq("#{Resources::APP_PATH}/")
    end

    it "raises with the schema and the directory named when the schema is not in it" do
      compiled_schema_directory("com.example.Other") do |directory|
        expect { settings.send(:settings_from_directory, directory) }
          .to raise_error(RuntimeError, /#{Resources::APP_ID}.*#{Regexp.escape(directory)}/)
      end
    end

    # Not the port's own error: GLib raises before the lookup can answer nil,
    # so a directory that #schema_source_directory would have rejected is not
    # the case the port's message covers.
    it "lets GLib's own error through for a directory with nothing compiled in it" do
      Dir.mktmpdir("sessions-settings-spec") do |empty|
        expect { settings.send(:settings_from_directory, empty) }
          .to raise_error(GLib::FileError, /gschemas\.compiled/)
      end
    end
  end

  describe "the installed-schema path" do
    subject(:settings) { InstalledSettings.new }

    it "builds without a schema source, from the application id alone" do
      expect(settings.last_position).to eq(300)
    end

    it "writes and reads back through the memory backend" do
      settings.last_position = 1800
      expect(settings.last_position).to eq(1800)
    end

    it "answers the same schema path as the other construction path" do
      expect(described_class.new.location).to eq(settings.location)
    end
  end

  describe "the key the app reads" do
    subject(:settings) { described_class.new(settings: Gio::Settings.new(Resources::APP_ID)) }

    it "takes an injected Gio::Settings rather than building one" do
      expect(settings.last_position).to eq(300)
    end

    it "round-trips through the keyed accessors" do
      settings[Resources::SCHEMA_LAST_POSITION_KEY] = 900
      expect(settings[Resources::SCHEMA_LAST_POSITION_KEY]).to eq(900)
    end

    it "answers the value from the keyed writer, as an assignment does" do
      expect(settings[Resources::SCHEMA_LAST_POSITION_KEY] = 60).to eq(60)
    end

    it "coerces a float duration to the int64 the schema declares" do
      settings.last_position = 330.9
      expect(settings.last_position).to eq(330)
    end

    it "names where the preference lives" do
      expect(settings.location).to eq("#{Resources::APP_ID} at #{Resources::APP_PATH}")
    end

    it "sees what another Settings over the same schema wrote" do
      settings.last_position = 450
      expect(described_class.new.last_position).to eq(450)
    end
  end
end
