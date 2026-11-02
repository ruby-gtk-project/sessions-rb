# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "../lib/metainfo"

# lib/metainfo.rb is the port's stand-in for the GResource bundle
# `adw_about_dialog_new_from_appdata` reads upstream, and every string in the
# About dialog comes through it. It had no spec of its own until now: the only
# thing that touched it was four checks in test/drive_main_window.rb, which
# needs a display and runs nothing in CI.
#
# It is also where round five shipped a defect — the dialog's comments field
# came out as the description in twenty languages at once, because the merged
# metainfo.xml carries one `xml:lang` sibling per catalogue and nothing was
# filtering them. So the examples here are written against a fixture that has
# the same shapes the real file has: wrapped and indented paragraphs, translated
# siblings, a bullet list, inline markup, and releases with and without notes.
RSpec.describe Metainfo do
  FIXTURE = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <component type="desktop-application">
      <id>com.example.Fixture</id>
      <summary>Focus with timed
        work intervals</summary>
      <summary xml:lang="de">Konzentration mit festen Arbeitsintervallen</summary>
      <description>
        <p>
          Sessions is a Pomodoro timer
          that wraps across lines.
        </p>
        <p xml:lang="de">Sessions ist ein Pomodoro-Timer.</p>
        <p>It enables you to:</p>
        <ul>
          <li>Set a timer</li>
          <li xml:lang="de">Einen Timer stellen</li>
          <li>Take regular breaks</li>
          <li xml:lang="de">Regelm&#228;&#223;ige Pausen machen</li>
        </ul>
      </description>
      <releases>
        <release version="2.0.0" date="2026-10-01">
          <description translate="no">
            <p>A paragraph of notes</p>
            <ul>
              <li>One change</li>
              <li>Another change</li>
            </ul>
          </description>
        </release>
        <release version="1.0.0" date="2025-01-01"/>
      </releases>
    </component>
  XML

  subject(:metainfo) { described_class.load(path) }

  let(:directory) { Dir.mktmpdir("sessions-metainfo-spec") }
  let(:path) { File.join(directory, "fixture.metainfo.xml").tap { |file| File.write(file, FIXTURE) } }

  after { FileUtils.remove_entry(directory) }

  describe "#summary" do
    it "collapses the template's wrapping and indentation into one line" do
      expect(metainfo.summary).to eq("Focus with timed work intervals")
    end

    it "takes the untranslated element, not the first one with the name" do
      expect(metainfo.summary).not_to include("Konzentration")
    end
  end

  describe "#description_paragraphs" do
    it "returns the untranslated paragraphs in document order" do
      expect(metainfo.description_paragraphs).to eq(
        [
          "Sessions is a Pomodoro timer that wraps across lines.",
          "It enables you to:",
        ],
      )
    end

    it "leaves every xml:lang sibling out" do
      expect(metainfo.description_paragraphs.join).not_to include("Pomodoro-Timer")
    end
  end

  describe "#description_bullets" do
    it "returns the untranslated list's items" do
      expect(metainfo.description_bullets).to eq(["Set a timer", "Take regular breaks"])
    end

    # `msgfmt --xml` puts every language's item inside the one <ul>, tagged
    # with xml:lang, rather than adding a translated <ul> of its own — so the
    # filter has to be on the item, which is what lib/metainfo.rb filters.
    it "leaves the translated items in the same list out" do
      expect(metainfo.description_bullets.join).not_to include("Einen Timer")
    end
  end

  describe "#releases" do
    it "returns every release in the order the file writes them" do
      expect(metainfo.releases.map { |release| release[:version] }).to eq(["2.0.0", "1.0.0"])
    end

    it "carries each release's date" do
      expect(metainfo.releases.first[:date]).to eq("2026-10-01")
    end
  end

  describe "#notes_for" do
    it "renders the notes in the markup subset AdwAboutDialog parses" do
      expect(metainfo.notes_for("2.0.0")).to eq(
        "<p>A paragraph of notes</p><ul><li>One change</li><li>Another change</li></ul>",
      )
    end

    it "answers nil for a version the file does not carry" do
      expect(metainfo.notes_for("0.0.0")).to be_nil
    end

    it "answers an empty string for a release with no description" do
      expect(metainfo.notes_for("1.0.0")).to eq("")
    end
  end

  # `#text_of` is private and is what every other reader is built on, so it is
  # pinned through the readers above and directly here: it joins a node's own
  # text children, collapses every run of whitespace to one space and strips
  # the ends. Two consequences worth having written down rather than
  # rediscovered: a missing node answers the empty string rather than raising,
  # and text inside an inline child — `<em>`, `<code>` — is not the node's own
  # text child and so is dropped.
  describe "#text_of" do
    it "answers an empty string for a node that is not there" do
      expect(metainfo.send(:text_of, nil)).to eq("")
    end

    it "collapses newlines, tabs and runs of spaces to single spaces" do
      REXML::Document.new("<p>a\n\tb    c </p>").root.then do |node|
        expect(metainfo.send(:text_of, node)).to eq("a b c")
      end
    end

    it "drops the text of an inline child, which is not a text child of its own" do
      REXML::Document.new("<p>plain <em>emphasised</em> tail</p>").root.then do |node|
        expect(metainfo.send(:text_of, node)).to eq("plain tail")
      end
    end
  end

  describe ".load" do
    it "parses on the way out, so the component is ready to read" do
      expect(described_class.load(path).summary).not_to be_empty
    end

    it "prefers the generated metainfo over the template when both exist" do
      expect(described_class.new.send(:default_path)).to eq(Resources::METAINFO_PATH)
    end
  end
end
