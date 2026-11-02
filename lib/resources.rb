# frozen_string_literal: true

# Resources carries the constants upstream keeps in assets/resources/index.go,
# plus the identity, credits and links that assets/resources/metainfo.xml.in
# declares.
#
# Upstream compiles its blueprint UI, stylesheet, metainfo and alarm sound into
# a GResource bundle and reads them back by resource path. This port builds its
# widget trees in Ruby and ships the files that are still data — the alarm
# sound, the icons, the desktop entry, the metainfo — under `data/`, so the
# resource paths become plain file paths.
#
module Resources
  APP_ID = 'com.pojtinger.felicitas.Sessions'
  APP_VERSION = '0.1.20'

  # The GSettings object path upstream derives in index.go. Nothing in this
  # port dereferences it, but it is the identity the schema in data/ declares,
  # so it stays next to the ID it belongs to.
  APP_PATH = '/com/pojtinger/felicitas/Sessions'

  # The settings key name, identical to the one in
  # assets/resources/index.gschema.xml so the JSON-backed Settings in this port
  # and a compiled schema would read the same name.
  SCHEMA_LAST_POSITION_KEY = 'last-position'

  APP_NAME = 'Sessions'
  APP_ICON = APP_ID
  APP_SUMMARY = 'Focus with timed work intervals'
  APP_DESCRIPTION = 'Sessions is a simple visual timer application designed specifically for ' \
                    'the pomodoro technique, helping you stay productive by breaking work ' \
                    'into focused sessions with regular breaks.'

  APP_DEVELOPER_NAME = 'Felicitas Pojtinger'
  APP_DEVELOPERS = ['Felicitas Pojtinger', 'Guido Günther'].freeze
  APP_ARTISTS = ['Felicitas Pojtinger', 'Mirabelle Salles'].freeze
  APP_COPYRIGHT = "© 2026 #{APP_DEVELOPERS.join(', ')}"

  APP_WEBSITE = 'https://apps.gnome.org/Sessions/'
  APP_ISSUE_URL = 'https://github.com/pojntfx/sessions/issues'
  APP_SUPPORT_URL = 'https://matrix.to/#/#sessions:matrix.org'
  APP_DONATION_URL = 'https://github.com/sponsors/pojntfx'
  APP_TRANSLATE_URL = 'https://hosted.weblate.org/projects/sessions/'
  APP_VCS_URL = 'https://github.com/pojntfx/sessions/'

  # Where upstream's gresource files live in this port.
  DATA_DIR = File.expand_path('../data', __dir__)
  ALARM_SOUND_PATH = File.join(DATA_DIR, 'alarm-clock-elapsed.oga')
end
