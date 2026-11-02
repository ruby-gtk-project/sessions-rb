# frozen_string_literal: true

# Builds the window in German and looks at it.
#
#   nix develop --command xvfb-run -a ruby test/drive_translations.rb
#   nix develop --command rake drive:translations
#
# The catalogue can be perfect and the app still English — a wrong `path:`, a
# domain typo, `bindtextdomain` in a class nothing instantiates — and none of
# those are visible to `msgfmt`, to the census or to a reading of po/. One run
# in one language catches all three, and the screenshots are the record of it.
#
# German because it is the one catalogue that is complete at 33 of 33, which
# makes every msgid in the port assertable here. The first version of this file
# asserted four of them: the window title, the action button, two tooltips and
# libadwaita's own dialog heading. The other twenty-nine were carried as
# "translated because the catalogue has them", which is the same reasoning that
# let the About dialog render its description in twenty languages at once for a
# whole round.
#
# Three routes are asserted differently, because they are the three that can
# fail while the catalogue is perfect:
#
#   * `#_` through the component that owns the string, not through a top-level
#     `_()`. `bindtextdomain` binds to the including class's ancestry rather
#     than to the process, so a class that forgets `include Translations`
#     ships English while every other class is translated — and a top-level
#     assertion would not notice.
#   * the rendered label, read back off the widget, for everything libadwaita
#     or GTK puts on screen itself.
#   * the merged `data/` files, for the eleven msgids no Ruby ever sees:
#     `msgfmt --desktop --template` and `msgfmt --xml -L metainfo --template`
#     write them at build time and nothing was checking the merge.

require "tmpdir"
require "fileutils"

# Set before anything loads: the `gettext` gem resolves the locale through the
# `locale` gem, which reads these at lookup time, and ENV is the only place a
# test can say which language it wants.
ENV["LANGUAGE"] = "de"
ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("sessions-drive-de")
ENV["SESSIONS_SCHEMA_DIR"] ||= File.expand_path("../data", __dir__)

require_relative "../lib/sessions"
require_relative "gtk_driver"

Translations.install

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.mkdir_p(SHOTS)

# Every widget in the tree under `widget`, in tree order — libadwaita's own
# composite widgets expose nothing to ask about from the outside, so the labels
# they build are what is read instead.
def descendants(widget, found = [])
  widget.first_child.then do |first|
    first.then do |child|
      cursor = child
      while cursor
        found << cursor
        descendants(cursor, found)
        cursor = cursor.next_sibling
      end
    end
  end

  found
end

def labels_under(widget) = descendants(widget).grep(Gtk::Label).map(&:label)

app = App.new

GtkDriver.drive(app, shots: SHOTS) do |d, application|
  window = -> { application.main_window }

  d.window { window.call.window }

  d.step("the window is built in German") do
    d.check("the title is translated") { window.call.window.title == "Sitzungen" }
    d.check("the window title widget carries it too") do
      window.call.window_title.title == "Sitzungen"
    end
    d.check("the action button is translated, mnemonic and all") do
      window.call.action_button.label == "_Timer starten"
    end
    d.check("the menu button tooltip is translated") do
      window.call.menu_button.tooltip_text == "Hauptmenü"
    end
    d.check("the minus button tooltip is translated") do
      window.call.minus_button.tooltip_text == "30 Sekunden entfernen"
    end
    d.check("the plus button tooltip is translated") do
      window.call.plus_button.tooltip_text == "30 Sekunden hinzufügen"
    end
    # `05:00` is a msgid because the blueprint hardcodes it as the label's
    # initial text; German answers it with the same five characters, so what
    # this pins is that the lookup happens and does not come back empty.
    d.check("the time label starts at the translated default") do
      window.call.time_label.label == "05:00"
    end
    d.shot("de-initial")
  end

  # The accessible label cannot be read back — GTK4 exposes no getter for an
  # accessible property, which is also why the port sets it through a
  # `Gtk::Builder` snippet. What is assertable is the string that reaches the
  # snippet, through the window's own `#_` and through
  # `REXML::Text.normalize`, which is the step that would mangle a translation
  # containing `&` or `<`.
  d.step("the time row's accessible label is German where it is built") do
    window.call.send(:_, "Remaining Time").then do |translated|
      d.check("the window's own gettext answers in German") do
        translated == "Verbleibende Zeit"
      end
      d.check("it survives XML escaping unchanged") do
        REXML::Text.normalize(translated) == "Verbleibende Zeit"
      end
    end
    d.check("and the row the snippet built is in the tree") do
      window.call.timer_row.is_a?(Gtk::ListBoxRow) &&
        descendants(window.call.timer_list).include?(window.call.timer_row)
    end
  end

  d.step("the primary menu opens") { window.call.menu_button.popup }

  d.step("both menu items are translated") do
    labels_under(window.call.menu_button.popover).then do |labels|
      d.check("Keyboard Shortcuts is German") { labels.include?("_Tastaturkürzel") }
      d.check("About Sessions is German, with the mnemonic moved") do
        labels.include?("Ü_ber Sitzungen")
      end
    end
    d.shot("de-main-menu", window.call.menu_button.popover)
  end

  d.step("the menu closes again") { window.call.menu_button.popdown }

  d.step("the action button turns into the translated Stop") do
    window.call.toggle_timer_action.activate(nil)
    d.check("the label is German") { window.call.action_button.label == "_Stoppen" }
  end

  d.step("the counting-down window has redrawn") { d.shot("de-counting-down") }

  # The portal strings are the reason lib/background_portal.rb exists, and
  # `#hold_in_background` has already run twice by now — once per start. Both
  # strings are asserted through the window, which is the class that marks
  # them.
  d.step("the two background-portal strings are German where they are marked") do
    d.check("the request's reason is German") do
      window.call.send(:_, "Running the Timer in the Background") ==
        "Timer im Hintergrund laufen lassen"
    end
    d.check("the running status is German") do
      window.call.send(:_, "Timer Running") == "Timer läuft"
    end
  end

  d.step("the alarm goes off") do
    window.call.state_machine.send(:fire, StateMachine::TIMER_FINISHED)
    d.check("the state machine is alarming") do
      window.call.state_machine.state == StateMachine::ALARMING
    end
    d.check("the notification was built") do
      window.call.alarm.notification.is_a?(Gio::Notification)
    end
  end

  # Gio::Notification has setters and no getters, so the two strings are
  # asserted through the Alarm instance that set them — after driving the alarm,
  # so the notification really has been built from these lookups.
  d.step("the alarm's two strings are German where they are marked") do
    window.call.alarm.then do |alarm|
      d.check("the notification title is German") do
        alarm.send(:_, "Session Finished") == "Sitzung beendet"
      end
      d.check("the notification body is German") do
        alarm.send(:_, "Time to take a break") == "Zeit für eine Pause"
      end
    end
    d.check("the window announces the same German string") do
      window.call.send(:_, "Session Finished") == "Sitzung beendet"
    end
    d.shot("de-alarming")
  end

  d.step("the alarm is dismissed") do
    window.call.stop_alarm_playback_action.activate(nil)
    d.check("the timer is stopped") do
      window.call.state_machine.state == StateMachine::STOPPED
    end
  end

  d.step("the shortcuts dialog opens") { app.shortcuts_action.activate(nil) }

  d.step("libadwaita translates its own heading, and every row is German") do
    d.check("the dialog heading is German") do
      app.shortcuts_dialog.title == "Tastenkürzel"
    end

    labels_under(app.shortcuts_dialog).then do |labels|
      {
        "General" => "Allgemein",
        "Timer"   => "Timer",
      }.each do |english, german|
        d.check("the #{english} section heading reads #{german}") do
          labels.include?(german)
        end
      end

      [
        "Menü öffnen",
        "Tastaturkürzel anzeigen",
        "Fenster schließen",
        "Beenden",
        "Timer starten oder stoppen",
        "30 Sekunden hinzufügen",
        "30 Sekunden entfernen",
      ].each do |item|
        d.check("the #{item} row is there") { labels.include?(item) }
      end

      d.check("no English shortcut row is left behind") do
        ["Open menu", "Show keyboard shortcuts", "Close window", "Quit",
         "Start or stop timer", "Add 30 seconds", "Remove 30 seconds",
].none? do |english|
          labels.include?(english)
        end
      end
    end
    d.shot("de-shortcuts")
  end

  d.step("the shortcuts dialog closes again") { app.shortcuts_dialog.close }

  d.step("the about dialog opens") { app.open_about_action.activate(nil) }

  d.step("the about dialog's description and credits are German") do
    app.about_dialog.dialog.then do |dialog|
      d.check("the summary is German") do
        dialog.comments.include?("Fokussiere mit getakteten Arbeitsintervallen")
      end
      d.check("the first description paragraph is German") do
        dialog.comments.include?("Sessions ist eine einfache visuelle Timer-Anwendung")
      end
      d.check("the second description paragraph is German") do
        dialog.comments.include?("Es ermöglicht Ihnen:")
      end
      [
        "Fokussierte Arbeitssitzungen mit anpassbaren Timer-Dauern starten",
        "Ihren Fortschritt mit einer sauberen, ablenkungsfreien Benutzeroberfläche verfolgen",
        "Regelmäßige Pausen einlegen, um die Produktivität aufrechtzuerhalten",
      ].each do |bullet|
        d.check("the bullet #{bullet[0, 24]}… is German") { dialog.comments.include?(bullet) }
      end
      # The defect round five shipped was the description in every language at
      # once. In German the English copy must be gone, not merely present
      # alongside.
      d.check("the English description is not in there as well") do
        !dialog.comments.include?("It enables you to:")
      end
      d.check("the translator credits come from the German catalogue") do
        dialog.translator_credits == "Felicitas Pojtinger <felicitas@pojtinger.com>"
      end
      d.shot("de-about")
    end
  end

  d.step("the about dialog closes again") { app.about_dialog.dialog.close }

  # GLib translates the GSettings schema itself at runtime from
  # `gettext-domain="sessions"`, which is a different binding from the gettext
  # gem's: `lib/translations.rb` calls `GLib::GetText.bindtextdomain` for
  # exactly this, and these two strings are the only way to see it work.
  d.step("GLib translates the schema's own summary and description") do
    Gio::SettingsSchemaSource
      .new(Resources::SCHEMA_DIR, Gio::SettingsSchemaSource.default, true)
      .lookup(Resources::APP_ID, false)
      .get_key(Resources::SCHEMA_LAST_POSITION_KEY)
      .then do |key|
        d.check("the key summary is German") { key.summary == "Letzte Timer-Position" }
        d.check("the key description is German") do
          key.description.start_with?("Die letzte Timer-Position")
        end
      end
  end

  # The eleven msgids no Ruby ever sees. `rake gettext:data` merges them, and
  # `rake drive:translations` runs that task first so this step can assert the
  # result rather than skip it.
  d.step("the merged desktop entry carries its three German keys") do
    File.read(File.join(Resources::DATA_DIR, "#{Resources::APP_ID}.desktop")).then do |desktop|
      {
        "Name[de]"     => "Sitzungen",
        "Comment[de]"  => "Fokussiere mit getakteten Arbeitsintervallen",
        "Keywords[de]" => "pomodoro;Timer;Produktivität;Fokus;Arbeitsintervalle;Aufgabenverwaltung;",
      }.each do |key, value|
        d.check("#{key} is merged") { desktop.include?("#{key}=#{value}") }
      end
    end
  end

  d.step("the merged metainfo carries its nine German elements") do
    File.read(Resources::METAINFO_PATH).then do |metainfo|
      d.check("the name is merged") do
        metainfo.include?(%(<name xml:lang="de">Sitzungen</name>))
      end
      d.check("the summary is merged") do
        metainfo.include?(%(<summary xml:lang="de">Fokussiere mit getakteten Arbeitsintervallen</summary>))
      end
      d.check("both description paragraphs are merged") do
        metainfo.scan(/<p xml:lang="de">/).length == 2
      end
      d.check("all three bullets are merged") do
        metainfo.scan(/<li xml:lang="de">/).length == 3
      end
      [
        "Einrichten einer neuen Timer-Sitzung",
        "Timer läuft während einer Arbeitssitzung",
      ].each do |caption|
        d.check("the screenshot caption #{caption[0, 20]}… is merged") do
          metainfo.include?(%(<caption xml:lang="de">#{caption}</caption>))
        end
      end
    end
  end

  d.step("the window closes") { window.call.close_window_action.activate(nil) }
end
