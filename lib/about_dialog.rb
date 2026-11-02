# frozen_string_literal: true

require 'adwaita'

require_relative 'resources'

# AboutDialog is the app's about window.
#
# Ported from the activate handler in internal/components/application.go
# together with assets/resources/metainfo.xml.in. Upstream builds the dialog
# with adw_about_dialog_new_from_appdata, which reads the compiled metainfo out
# of the GResource bundle and fills in the name, version, licence and links
# from it, then sets the developers, artists, copyright and translator credits
# by hand.
#
# There is no bundle here, so the values the appdata would have supplied are
# set explicitly from lib/resources.rb — the same strings the metainfo
# declares. The translator credits are left unset: upstream gets them from the
# gettext catalogue for the running locale, and the catalogues are not ported
# yet, so the dialog would otherwise show the literal placeholder
# "translator-credits".
#
class AboutDialog
  LINKS = [
    ['Donate', Resources::APP_DONATION_URL],
    ['Translate', Resources::APP_TRANSLATE_URL],
    ['Source Code', Resources::APP_VCS_URL],
  ].freeze

  # Memoized: the dialog is presented again on every menu press, and the links
  # must not be appended a second time.
  def build
    @build ||= dialog.tap do |d|
      LINKS.each { |title, uri| d.add_link(title, uri) }
    end
  end

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |d|
      d.application_name = Resources::APP_NAME
      d.application_icon = Resources::APP_ICON
      d.version = Resources::APP_VERSION
      d.developer_name = Resources::APP_DEVELOPER_NAME
      d.developers = Resources::APP_DEVELOPERS
      d.artists = Resources::APP_ARTISTS
      d.copyright = Resources::APP_COPYRIGHT
      d.license_type = Gtk::License::AGPL_3_0
      d.comments = Resources::APP_DESCRIPTION
      d.website = Resources::APP_WEBSITE
      d.issue_url = Resources::APP_ISSUE_URL
      d.support_url = Resources::APP_SUPPORT_URL
    end
  end
end
