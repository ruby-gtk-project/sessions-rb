# frozen_string_literal: true

require 'rexml/document'

require_relative 'resources'

# Metainfo reads the AppStream component this port ships, which is the data
# upstream's About dialog is built from.
#
# Ported from the `adw_about_dialog_new_from_appdata` call in
# internal/components/application.go:76 together with
# assets/resources/metainfo.xml.in, which is the file that call reads.
# `adw_about_dialog_new_from_appdata` takes a *resource* path — it reads the
# compiled metainfo out of the GResource bundle — and this port has no bundle,
# so the same component is parsed from the file in data/ and handed to the
# dialog's setters one at a time.
#
# Reading the file rather than restating its contents in Ruby is what keeps one
# source of truth: the summary, the description's paragraphs and bullets, and
# the twenty-one release entries exist once, in
# data/com.pojtinger.felicitas.Sessions.metainfo.xml.in, and both the About
# dialog and AppStream render the same text.
#
# The `.in` template is preferred over the generated file on purpose. Both
# carry the same English, but `rake gettext:data` adds `xml:lang` variants to
# the generated one for twenty-six languages, and the About dialog takes its
# translations from the gettext catalogue at display time instead — so the
# template is the one with exactly one copy of each string in it.
#
class Metainfo
  def self.load(path = nil) = new(path).tap(&:parse)

  def initialize(path = nil)
    @path = path || default_path
  end

  def parse
    @component = REXML::Document.new(File.read(@path)).root
    self
  end

  # The one-line summary: metainfo.xml.in:8, and the same msgid the desktop
  # entry's Comment field carries.
  def summary = text_of(@component.elements['summary'])

  # The description, as the paragraphs and bullet items it is written in, in
  # document order. The About dialog's comments field is plain text, so the
  # bullets come back separately and the caller decides how to mark them.
  #
  # Only the untranslated nodes. `msgfmt --xml` merges every catalogue into the
  # generated metainfo.xml as sibling elements carrying `xml:lang`, so the
  # generated file holds twenty copies of each paragraph and bullet. Before
  # this filter the About dialog's comments field was the description in every
  # language at once, one after the other, which is what driving it showed —
  # and the `_()` around each paragraph in lib/about_dialog.rb only ever
  # resolves if what it is handed is the English msgid.
  def description_paragraphs
    untranslated('description/p').map { |node| text_of(node) }
  end

  def description_bullets
    untranslated('description/ul/li').map { |node| text_of(node) }
  end

  # Every <release>, newest first, as it is written in the file.
  def releases
    @component.elements.to_a('releases/release').map do |node|
      {
        version: node.attributes['version'],
        date:    node.attributes['date'],
        notes:   release_notes(node),
      }
    end
  end

  # The release notes for one version, in the Pango-ish subset
  # Adwaita::AboutDialog parses: <p>, <ul>, <ol>, <li>, <em>, <code>.
  def notes_for(version)
    releases.find { |release| release[:version] == version }&.fetch(:notes)
  end

  private

    # The nodes at `xpath` that carry no `xml:lang`, which in a merged
    # metainfo file is the source language's own copy.
    def untranslated(xpath)
      @component.elements.to_a(xpath).reject { |node| node.attributes['xml:lang'] }
    end

    # The generated file is preferred when a build has produced it, because a
    # packaged copy may ship only that one; a checkout has only the template.
    def default_path
      [Resources::METAINFO_PATH, Resources::METAINFO_TEMPLATE_PATH]
        .find { |candidate| File.exist?(candidate) } || Resources::METAINFO_TEMPLATE_PATH
    end

    # The template wraps long paragraphs across lines and indents them, and
    # `translate="no"` nodes are skipped so a translated copy of the file does
    # not yield the same string twice.
    def text_of(node)
      node.nil?.then do |missing|
        if missing
          ''
        else
          node.texts.join.gsub(/\s+/, ' ').strip
        end
      end
    end

    def release_notes(node)
      node.elements.to_a('description/*').map { |child| markup_of(child) }.join
    end

    def markup_of(node)
      if node.name == 'ul' || node.name == 'ol'
        "<#{node.name}>#{node.elements.to_a('li').map { |li| "<li>#{text_of(li)}</li>" }.join}</#{node.name}>"
      else
        "<#{node.name}>#{text_of(node)}</#{node.name}>"
      end
    end
end
