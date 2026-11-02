# frozen_string_literal: true

# Resources carries the constants upstream keeps in assets/resources/index.go,
# plus the identity, credits and links that assets/resources/metainfo.xml.in
# declares.
#
# Upstream compiles its blueprint UI, stylesheet, metainfo and alarm sound into
# a GResource bundle and reads them back by resource path. This port builds its
# widget trees in Ruby and ships the files that are still data — the alarm
# sound, the icons, the desktop entry, the metainfo, the schema, the gettext
# catalogues — under `data/` and `po/`, so the resource paths become plain file
# paths.
#
module Resources
  APP_ID = 'com.pojtinger.felicitas.Sessions'
  APP_VERSION = '0.1.20'

  # The GSettings object path upstream derives in index.go, and the one the
  # schema in data/ declares. lib/settings.rb passes it to Gio::Settings when
  # it has to build the settings object from a looked-up schema rather than by
  # ID.
  APP_PATH = '/com/pojtinger/felicitas/Sessions'

  # The settings key name, identical to the one in
  # assets/resources/index.gschema.xml.
  SCHEMA_LAST_POSITION_KEY = 'last-position'

  # `gettextPackage` from main.go:19. Upstream's domain, not a port-specific
  # one: a catalogue is looked up as <path>/<lang>/LC_MESSAGES/<domain>.mo, so
  # the domain is the filename and renaming it orphans every .po file in po/.
  GETTEXT_DOMAIN = 'sessions'

  APP_NAME = 'Sessions'
  APP_ICON = APP_ID

  APP_DEVELOPER_NAME = 'Felicitas Pojtinger'
  APP_DEVELOPERS = ['Felicitas Pojtinger', 'Guido Günther'].freeze
  APP_ARTISTS = ['Felicitas Pojtinger', 'Mirabelle Salles'].freeze
  APP_COPYRIGHT = "© 2026 #{APP_DEVELOPERS.join(', ')}"

  APP_WEBSITE = 'https://apps.gnome.org/Sessions/'
  APP_ISSUE_URL = 'https://github.com/pojntfx/sessions/issues'
  APP_SUPPORT_URL = 'https://matrix.to/#/#sessions:matrix.org'

  # The metainfo's other four `<url>` entries — donation, translate, vcs-browser
  # and contribute — had constants here to feed four `add_link` rows in the
  # About dialog. Upstream's dialog renders no link rows (see the comment at the
  # top of lib/about_dialog.rb), the rows are gone, and constants nothing reads
  # are how the next round ends up re-adding them.

  # Where upstream's gresource files live in this port.
  DATA_DIR = File.expand_path('../data', __dir__)
  ALARM_SOUND_PATH = File.join(DATA_DIR, 'alarm-clock-elapsed.oga')
  METAINFO_PATH = File.join(DATA_DIR, "#{APP_ID}.metainfo.xml")
  METAINFO_TEMPLATE_PATH = "#{METAINFO_PATH}.in"

  # main.go declares `LocaleDir` and `SchemaDir` as package variables so the
  # Flatpak build can point them at /app/share with a linker flag. Ruby has no
  # link step, so the same two overrides are environment variables, set by the
  # wrapper in flake.nix and by the Flatpak manifest. From a checkout both fall
  # back to the directories in the tree, which is upstream's `SchemaDir == ""`
  # case.
  LOCALE_DIR = ENV.fetch('SESSIONS_LOCALE_DIR', File.expand_path('../po', __dir__))
  SCHEMA_DIR = ENV.fetch('SESSIONS_SCHEMA_DIR', DATA_DIR)
end
