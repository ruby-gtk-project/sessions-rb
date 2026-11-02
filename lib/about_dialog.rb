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
# out of the GResource bundle and sets nine properties from it — the icon, the
# name, the developer name, the version, the website, the support and issue
# URLs, the licence type and the release notes for one version — then sets the
# developers, artists, copyright and translator credits by hand.
#
# There is no bundle here, so lib/metainfo.rb parses the same AppStream
# component out of data/ and this class hands its fields to the dialog's
# setters one at a time. The strings themselves still go through `_()`, so the
# dialog is translated by the gettext catalogue in po/ rather than by AppStream
# — the msgids are the ones xgettext took out of the metainfo, so they resolve
# against the donated translations unchanged.
#
# Earlier rounds of this file carried four `add_link` rows — Donate,
# Translate, Source Code, Contribute — above a comment saying that libadwaita
# builds the first two out of the appdata's `<url type="donation">` and `<url
# type="translate">` "with its own translated labels", and that the port merely
# reproduced them in English. That was false, and it was false in the one place
# where every later reader would inherit it. `adw_about_dialog_new_from_appdata`
# sets exactly nine properties — application-icon, application-name,
# developer-name, version, website, support-url, issue-url, license-type and
# release-notes/release-notes-version (Adw-1.gir, libadwaita 1.9.3) — and adds
# no link row at all, and `git grep AddLink origin/main` returns nothing.
# Upstream's About dialog has no Donate, Translate, Source Code or Contribute
# row. What I had actually done was add four components upstream does not
# render and four msgids none of the twenty-six donated catalogues can answer,
# so a Hungarian reader got four English titles under a Hungarian heading; then
# I wrote a comment that made the addition read as parity, and the round-five
# component-parity table repeated it. The four rows and the four msgids are
# gone as of this round.
# Upstream: `internal/components/application.go:84` calls the appdata
# constructor and then only `SetDevelopers`, `SetArtists`, `SetCopyright` and
# `SetTranslatorCredits`.
#
# One addition does stay, and it is an addition, not parity: `comments`. The
# appdata constructor does not set it either, so upstream's dialog shows no
# description where this one shows the metainfo's summary, paragraphs and
# bullet list. It is kept because it costs no new msgid — the keys are the ones
# xgettext took out of upstream's own metainfo, so all twenty-six catalogues
# answer them — and COMPONENT_PARITY.md records it as an extra rather than as a
# match.
#
class AboutDialog
  include Translations

  # Memoized: the dialog is presented again on every menu press.
  def build = @build ||= dialog

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
      # TRANSLATORS: Replace "translator-credits" with your name/username, and optionally an email or URL.
      _('translator-credits').then do |credits|
        if credits == 'translator-credits'
          ''
        else
          credits
        end
      end
    end
end
