# frozen_string_literal: true

require 'adwaita'

require_relative 'metainfo'
require_relative 'resources'
require_relative 'translations'

# AboutDialog is the app's about window.
#
# Ported from the activate handler in internal/components/application.go:76-92
# together with assets/resources/metainfo.xml.in. Upstream builds the dialog
# with `adw_about_dialog_new_from_appdata`, which reads the compiled metainfo
# out of the GResource bundle and fills in the name, summary, description,
# release notes, licence and link rows from it, then sets the developers,
# artists, copyright and translator credits by hand.
#
# There is no bundle here, so lib/metainfo.rb parses the same AppStream
# component out of data/ and this class hands its fields to the dialog's
# setters one at a time. The strings themselves still go through `_()`, so the
# dialog is translated by the gettext catalogue in po/ rather than by AppStream
# — the msgids are the ones xgettext took out of the metainfo, so they resolve
# against the donated translations unchanged.
#
# One thing upstream's dialog has that this one does not: the Donate and
# Translate rows upstream gets for free from the appdata's `<url
# type="donation">` and `<url type="translate">` carry labels out of
# libadwaita's own catalogue, translated into every language libadwaita ships.
# I add them with `add_link` and my own labels instead, so those two row titles
# — and only those — are English in the other twenty-five languages. The reason
# is in FINDINGS.md: libadwaita's AdwAboutDialog has no `donations-url` or
# `translate-url` property to set, and the appdata constructor that would
# supply them needs a GResource.
# Upstream: `internal/components/application.go:76`.
# Port: `lib/about_dialog.rb#links`.
#
class AboutDialog
  include Translations

  # Memoized: the dialog is presented again on every menu press, and the links
  # must not be appended a second time.
  def build
    @build ||= dialog.tap do |d|
      links.each { |title, uri| d.add_link(title, uri) }
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
      d.comments = comments
      d.website = Resources::APP_WEBSITE
      d.issue_url = Resources::APP_ISSUE_URL
      d.support_url = Resources::APP_SUPPORT_URL

      # The "What's New" section. Adwaita renders the notes for one version
      # only, the one `release-notes-version` names, which is what
      # `adw_about_dialog_new_from_appdata(path, version)` does upstream.
      d.release_notes_version = Resources::APP_VERSION
      d.release_notes = release_notes

      # "translator-credits" is a msgid, not a label: each catalogue answers it
      # with that language's list of translators, and gettext's own convention
      # is that an untranslated answer means nobody is credited.
      d.translator_credits = translator_credits
    end
  end

  def metainfo = @metainfo ||= Metainfo.load

  private

    # The summary, then the description's paragraphs, then its bullet list —
    # the same order the metainfo writes them in. AdwAboutDialog's comments
    # field is plain text, so the `<li>` items become a dash list.
    def comments
      [
        _(metainfo.summary),
        *metainfo.description_paragraphs.map { |paragraph| _(paragraph) },
        *metainfo.description_bullets.map { |bullet| "— #{_(bullet)}" },
      ].reject(&:empty?).join("\n\n")
    end

    # `translate="no"` on every release description upstream, so these are the
    # one group of strings in the dialog that are deliberately not translated.
    def release_notes = metainfo.notes_for(Resources::APP_VERSION).to_s

    def translator_credits
      _('translator-credits').then do |credits|
        if credits == 'translator-credits'
          ''
        else
          credits
        end
      end
    end

    def links
      [
        [_('Donate'), Resources::APP_DONATION_URL],
        [_('Translate'), Resources::APP_TRANSLATE_URL],
        [_('Source Code'), Resources::APP_VCS_URL],
        [_('Contribute'), Resources::APP_CONTRIBUTE_URL],
      ]
    end
end
