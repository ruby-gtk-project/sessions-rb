# frozen_string_literal: true

# Drives the whole app headlessly: renders the window, the shortcuts dialog and
# the about dialog, then fires every action and both dial gestures and asserts
# the dial, the time label, the action button and the CSS classes after each.
#
#   nix shell nixpkgs#xvfb-run --command xvfb-run -a \
#     nix develop --command ruby test/drive_main_window.rb
#
# gtk_init needs a display: without one `require "gtk4"` raises
# Gtk::InitError, so this is not one of the runs that works with no display at
# all. Xvfb is in the devshell for it.
#
# Every screenshot is taken in a step of its own, after the step that changed
# something. Anything that calls queue_draw invalidates the window's cached
# render node, and GtkWidgetPaintable then has nothing to snapshot until the
# frame clock has run again — so a shot in the same step as the change comes
# back as "widget produced no render node" and the run quietly writes one
# picture instead of seven.
#
# Written because the first round of this port had never been rendered and no
# signal in it had ever been fired: every claim about it was a reading of the
# source. Four defects came out of the first run of this file, and they are
# listed in FINDINGS.md.

require 'tmpdir'
require 'fileutils'

# A scratch config and data directory, so a run never touches the user's real
# GSettings. Gio::MemorySettingsBackend would be tidier, but the backend has to
# be chosen before the first Gio::Settings is built and this is the earliest
# point there is.
ENV['GSETTINGS_BACKEND'] = 'memory'
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('sessions-drive-config')
ENV['SESSIONS_SCHEMA_DIR'] ||= File.expand_path('../data', __dir__)

require_relative '../lib/sessions'
require_relative 'gtk_driver'

Translations.install

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# Every widget in the tree under `widget`, in tree order. Libadwaita's own
# composite widgets — the shortcuts dialog's sections, the about dialog's
# pages, a menu button's popover — expose nothing to ask about from the
# outside, so the labels and status pages they build are what is read instead.
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

# The settings object is built here rather than left to App, so the drive can
# read back what the window wrote to it: lib/settings.rb is the component, and
# the only way to observe it is to hold the thing the window is writing to.
settings = Settings.new
settings.last_position = 300

app = App.new(settings: settings)

GtkDriver.drive(app, shots: SHOTS) do |d, application|
  window = -> { application.main_window }

  d.window { window.call.window }

  d.step('the window is built and rendered') do
    d.check('the window has a title') { window.call.window.title == 'Sessions' }
    d.check('the dial is in the overlay') { window.call.dial_area.first_child == window.call.dial.area }
    d.check('the time label shows the restored duration') { window.call.time_label.label == '05:00' }
    d.check('the time card is a boxed list') do
      window.call.timer_list.css_classes.include?('boxed-list--opaque')
    end
    d.check('the time row carries the Remaining Time accessible label') do
      window.call.timer_row.is_a?(Gtk::ListBoxRow) && !window.call.timer_row.activatable?
    end
    d.check('the action button starts out suggested') do
      window.call.action_button.css_classes.include?('suggested-action')
    end
    d.check('the action button offers to start') { window.call.action_button.label == '_Start Timer' }
    d.check('the window carries the application id as its icon name') do
      window.call.window.icon_name == Resources::APP_ICON
    end
    d.check('it is the only toplevel') { Gtk::Window.list_toplevels.length == 1 }
    d.check('no dialog is up yet') { window.call.window.visible_dialog.nil? }
    d.shot('01-initial')
  end

  d.step('the window restored its duration from the settings component') do
    d.check('the settings start at the stored 300') { settings.last_position == 300 }
    d.check('the state machine took the same number') do
      window.call.state_machine.to_s.include?('initial_remaining_time: 300')
    end
    d.check('the settings name where the preference lives') do
      settings.location == "#{Resources::APP_ID} at #{Resources::APP_PATH}"
    end
    d.check('the keyed reader answers the same as the named one') do
      settings[Resources::SCHEMA_LAST_POSITION_KEY] == settings.last_position
    end
  end

  d.step('every icon the window names resolves in the theme') do
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      [
        'open-menu-symbolic',
        'list-add-symbolic',
        'list-remove-symbolic',
        MainWindow::START_ICON,
        MainWindow::STOP_ICON,
      ].each do |name|
        d.check("the icon theme resolves #{name}") { theme.has_icon?(name) }
      end
    end

    # The application icon is not a theme icon from a checkout — it is a file
    # in data/ that `rake install_data` puts into hicolor — so what can be
    # checked here is that the files the install moves are present.
    [
      Resources::ALARM_SOUND_PATH,
      File.join(Resources::DATA_DIR, "#{Resources::APP_ID}.svg"),
      File.join(Resources::DATA_DIR, "#{Resources::APP_ID}-symbolic.svg"),
      Resources::METAINFO_PATH,
    ].each do |path|
      d.check("#{File.basename(path)} is on disk") { File.exist?(path) }
    end
  end

  d.step('the stylesheet the app installs parses') do
    Style.new.then do |style|
      d.check('the provider is a CssProvider') { style.provider.is_a?(Gtk::CssProvider) }
      d.check('the alarming class is the one the window adds') do
        Style::ALARMING_CLASS == 'dial__display--alarming' &&
          Style::CSS.include?(Style::ALARMING_CLASS)
      end
      d.check('the time label already carries the display class') do
        window.call.time_label.css_classes.include?('dial__display')
      end
    end
  end

  d.step('win.addTime adds thirty seconds') do
    window.call.add_time_action.activate(nil)
    d.check('the dial moved to 05:30') { window.call.dial.remaining_time == 330 }
    d.check('the label followed it') { window.call.time_label.label == '05:30' }
    d.check('the settings were written through') { settings.last_position == 330 }
    d.check('a second settings object reads the same number back') do
      Settings.new.last_position == 330
    end
  end

  d.step('the dial has redrawn at 05:30') { d.shot('02-after-add-time') }

  d.step('win.removeTime takes them back off') do
    window.call.remove_time_action.activate(nil)
    d.check('the dial is back at 05:00') { window.call.dial.remaining_time == 300 }
    d.check('the label followed it') { window.call.time_label.label == '05:00' }
  end

  d.step('win.toggleTimer starts the countdown') do
    window.call.toggle_timer_action.activate(nil)
    d.check('the state machine is counting down') do
      window.call.state_machine.state == StateMachine::COUNTING_DOWN
    end
    d.check('the dial turned red') { window.call.dial.counting_down? == true }
    d.check('the action button offers to stop') { window.call.action_button.label == '_Stop' }
    d.check('the action button turned destructive') do
      window.call.action_button.css_classes.include?('destructive-action') &&
        !window.call.action_button.css_classes.include?('suggested-action')
    end
  end

  d.step('the dial has redrawn red') { d.shot('03-counting-down') }

  d.step('win.toggleTimer again stops it') do
    window.call.toggle_timer_action.activate(nil)
    d.check('the state machine is stopped') do
      window.call.state_machine.state == StateMachine::STOPPED
    end
    d.check('the dial is no longer counting down') { window.call.dial.counting_down? == false }
    d.check('the action button offers to start again') do
      window.call.action_button.label == '_Start Timer'
    end
  end

  d.step("the dial's drag gesture is wired") do
    # The gesture's own signals, not the callbacks behind them, so the wiring
    # in Dial#build is what is under test. A drag is begin-then-end, and the
    # end hands the state machine whatever duration the dial is showing —
    # which is what starts the countdown.
    #
    # The dial is 260x260 and the arc grows clockwise from twelve, so the point
    # due east of the centre is a quarter of the ring: fifteen minutes.
    dial = window.call.dial
    dial.drag_gesture.signal_emit('drag-begin', dial.area.width.to_f, dial.area.height / 2.0)
    d.check('the drag put the machine in the dragging state') do
      window.call.state_machine.state == StateMachine::DRAGGING
    end
    d.check('the drag set a quarter of the ring') { dial.remaining_time == 900 }
    d.check('the label followed the drag') { window.call.time_label.label == '15:00' }

    dial.drag_gesture.signal_emit('drag-end', 0.0, 0.0)
    d.check('letting go started the countdown') do
      window.call.state_machine.state == StateMachine::COUNTING_DOWN
    end
  end

  d.step('the dial has redrawn after the drag') { d.shot('04-after-drag') }

  d.step("the dial's click gesture is wired") do
    window.call.toggle_timer_action.activate(nil)
    dial = window.call.dial
    dial.click_gesture.signal_emit(
      'pressed',
      1,
      dial.area.width / 2.0,
      0.0,
    )
    d.check('a click at the top of the dial is a whole hour') { dial.remaining_time == 3600 }

    dial.click_gesture.signal_emit(
      'pressed',
      1,
      dial.area.width / 2.0,
      dial.area.height / 2.0,
    )
    d.check('a click in the dead centre changes nothing') { dial.remaining_time == 3600 }
  end

  d.step('the alarm blinks the label and announces itself') do
    window.call.state_machine.start_timer
    window.call.state_machine.send(:fire, StateMachine::TIMER_FINISHED)
    d.check('the state machine is alarming') do
      window.call.state_machine.state == StateMachine::ALARMING
    end
    d.check('the label is blinking') do
      window.call.time_label.css_classes.include?(Style::ALARMING_CLASS)
    end
    d.check('the dial went insensitive') { window.call.dial.area.sensitive? == false }
  end

  d.step('the alarming window has redrawn') { d.shot('05-alarming') }

  d.step('the alarm is dismissed') do
    window.call.state_machine.stop_alarming
    d.check('dismissing the alarm stops the blink') do
      !window.call.time_label.css_classes.include?(Style::ALARMING_CLASS)
    end
  end

  d.step('the alarm component itself is loaded and quiet again') do
    window.call.alarm.then do |alarm|
      d.check('the notification is a Gio::Notification') do
        alarm.notification.is_a?(Gio::Notification)
      end
      d.check('the sound is the file in data/') do
        alarm.sound.is_a?(Gtk::MediaFile) && !alarm.sound.file.nil?
      end
      d.check('the sound loaded without error') { alarm.sound.error.nil? }
      d.check('the sound is not playing once the alarm is dismissed') do
        alarm.sound.playing? == false
      end
      d.check('the notification default action is application-scoped') do
        Alarm::DEFAULT_ACTION == 'app.stopAlarmPlayback'
      end
      d.check('that action is installed on the application') do
        !app.app.lookup_action('stopAlarmPlayback').nil?
      end
    end
  end

  d.step("the notification's own action silences a ringing alarm") do
    window.call.state_machine.start_timer
    window.call.state_machine.send(:fire, StateMachine::TIMER_FINISHED)
    d.check('the alarm is ringing again') do
      window.call.state_machine.state == StateMachine::ALARMING
    end

    window.call.stop_alarm_playback_action.activate(nil)
    d.check('app.stopAlarmPlayback stopped it') do
      window.call.state_machine.state == StateMachine::STOPPED
    end
    d.check('the blink is off') do
      !window.call.time_label.css_classes.include?(Style::ALARMING_CLASS)
    end
    d.check('the dial is sensitive again') { window.call.dial.area.sensitive? }
    d.check('the window is still the only toplevel') do
      Gtk::Window.list_toplevels.length == 1
    end
  end

  d.step('the background portal refuses, and the window takes the refusal') do
    # There is no xdg-desktop-portal on this bus, so RequestBackground fails
    # and the port's own answer is false. That is the refusal path, and what it
    # must leave behind is a window that still closes normally.
    granted = :never_answered
    window.call.background_portal.request(reason: 'drive') { |answer| granted = answer }
    d.check('an unreachable portal answers false rather than raising') { granted == false }
    d.check('setting a status against no portal does not raise') do
      window.call.background_portal.status = ''
      true
    end
    d.check('hide-on-close was never turned on, since nothing was granted') do
      window.call.window.hide_on_close? == false
    end
  end

  d.step("the countdown's ticker schedules and cancels") do
    Ticker.new.then do |ticker|
      handle = ticker.schedule(60) { false }
      d.check('schedule returns a GLib source handle') { handle.is_a?(Integer) && handle.positive? }
      d.check('cancel takes it back') do
        ticker.cancel(handle)
        true
      end
    end
  end

  d.step('the three buttons drive their actions as widgets, not just as actions') do
    window.call.dial.remaining_time.then do |before|
      d.check('the plus button is wired to win.addTime') do
        window.call.plus_button.action_name == 'win.addTime'
      end
      d.check('the minus button is wired to win.removeTime') do
        window.call.minus_button.action_name == 'win.removeTime'
      end
      d.check('the action button is wired to win.toggleTimer') do
        window.call.action_button.action_name == 'win.toggleTimer'
      end

      # `clicked`, not `Gtk::Widget#activate`: in these bindings
      # `Gtk::Button#activate` returns nil and does nothing at all, so a check
      # written against it passes for buttons that are wired to nothing. The
      # clicked signal is the one GtkButton turns into an action activation.
      window.call.plus_button.signal_emit('clicked')
      d.check('clicking the plus button added thirty seconds') do
        window.call.dial.remaining_time == before + StateMachine::ADJUSTMENT_INTERVAL
      end

      window.call.minus_button.signal_emit('clicked')
      d.check('clicking the minus button took them off again') do
        window.call.dial.remaining_time == before
      end

      window.call.action_button.signal_emit('clicked')
      d.check('clicking the action button started the timer') do
        window.call.state_machine.state == StateMachine::COUNTING_DOWN
      end
      window.call.action_button.signal_emit('clicked')
      d.check('clicking it again stopped the timer') do
        window.call.state_machine.state == StateMachine::STOPPED
      end
    end
  end

  d.step('the dial refuses to go past its ceiling') do
    until window.call.dial.remaining_time >= StateMachine::MAX_INITIAL_REMAINING_TIME
      window.call.add_time_action.activate(nil)
    end

    d.check('the dial is at the hour') do
      window.call.dial.remaining_time == StateMachine::MAX_INITIAL_REMAINING_TIME
    end
    d.check('the label shows sixty minutes') { window.call.time_label.label == '60:00' }
    d.check('win.addTime is disabled at the ceiling') do
      window.call.add_time_action.enabled? == false
    end
    d.check('the trigger itself refuses') { window.call.state_machine.plus_timer == false }
    d.check('win.removeTime is still enabled') { window.call.remove_time_action.enabled? }
    d.check('the ceiling was written to the settings') { settings.last_position == 3600 }
  end

  d.step('the full dial has redrawn') { d.shot('08-ceiling') }

  d.step('the dial refuses to go below its floor') do
    until window.call.dial.remaining_time <= StateMachine::MIN_INITIAL_REMAINING_TIME
      window.call.remove_time_action.activate(nil)
    end

    d.check('the dial is at thirty seconds') do
      window.call.dial.remaining_time == StateMachine::MIN_INITIAL_REMAINING_TIME
    end
    d.check('the label shows thirty seconds') { window.call.time_label.label == '00:30' }
    d.check('win.removeTime is disabled at the floor') do
      window.call.remove_time_action.enabled? == false
    end
    d.check('the trigger itself refuses') { window.call.state_machine.minus_timer == false }
    d.check('win.addTime is enabled again') { window.call.add_time_action.enabled? }
    d.check('the floor was written to the settings') { settings.last_position == 30 }
  end

  d.step('the nearly-empty dial has redrawn') { d.shot('09-floor') }

  d.step('the state machine describes itself') do
    d.check('to_s names the state and the permitted triggers') do
      window.call.state_machine.to_s.then do |text|
        text.include?('state: stopped') && text.include?('permitted_triggers: [')
      end
    end
    d.check('to_graph is a Graphviz digraph over all four states') do
      window.call.state_machine.to_graph.then do |dot|
        dot.start_with?('digraph StateMachine {') &&
          [
            StateMachine::STOPPED, StateMachine::DRAGGING,
            StateMachine::COUNTING_DOWN, StateMachine::ALARMING,
          ].all? { |state| dot.include?(state.to_s) }
      end
    end
  end

  d.step('the dial is walked back to five minutes') do
    until window.call.dial.remaining_time >= StateMachine::DEFAULT_INITIAL_REMAINING_TIME
      window.call.add_time_action.activate(nil)
    end

    d.check('it is back at 05:00') { window.call.time_label.label == '05:00' }
    d.check('and so is the stored preference') { settings.last_position == 300 }
  end

  d.step("the header bar's primary menu opens") do
    window.call.menu_button.popup
  end

  d.step('the menu shows both items, with their accelerators resolved') do
    window.call.menu_button.then do |button|
      d.check('the menu model is the one MainMenu built') do
        button.menu_model.equal?(window.call.main_menu.menu)
      end
      d.check('it is the primary menu') { button.primary? }
      d.check('the popover is up') { button.popover.visible? }

      button.menu_model.get_item_link(0, 'section').then do |section|
        d.check('the one section holds two items') { section.n_items == 2 }
        d.check('the first is Keyboard Shortcuts on app.shortcuts') do
          section.get_item_attribute_value(0, 'label', nil) == '_Keyboard Shortcuts' &&
            section.get_item_attribute_value(0, 'action', nil) == 'app.shortcuts'
        end
        d.check('the second is About Sessions on app.openAbout') do
          section.get_item_attribute_value(1, 'label', nil) == '_About Sessions' &&
            section.get_item_attribute_value(1, 'action', nil) == 'app.openAbout'
        end
      end

      labels_under(button.popover).then do |labels|
        d.check('the popover renders both labels') do
          labels.include?('_Keyboard Shortcuts') && labels.include?('_About Sessions')
        end
        d.check("it renders app.shortcuts' accelerator next to its item") do
          labels.include?('Ctrl+?')
        end
      end

      d.shot('10-main-menu', button.popover)
    end
  end

  d.step('the menu closes again') { window.call.menu_button.popdown }

  d.step('every accelerator the app declares is installed both ways') do
    App::ACCELERATORS.merge(MainWindow::ACCELERATORS).each do |name, accels|
      d.check("#{name} is bound to #{accels.join(", ")}") do
        app.app.get_accels_for_action(name).length == accels.length
      end
      accels.each do |accel|
        d.check("#{accel} resolves back to #{name}") do
          app.app.get_actions_for_accel(accel).include?(name)
        end
      end
    end
  end

  d.step('the metainfo the about dialog is built from parses') do
    Metainfo.load.then do |metainfo|
      d.check('the summary is the untranslated one') do
        metainfo.summary == 'Focus with timed work intervals'
      end
      d.check('exactly the two source paragraphs come back') do
        metainfo.description_paragraphs.length == 2
      end
      d.check('no paragraph is a translation of another') do
        metainfo.description_paragraphs.uniq.length == 2
      end
      d.check('exactly the three source bullets come back') do
        metainfo.description_bullets.length == 3
      end
      d.check('the bullets are the English ones') do
        metainfo.description_bullets.last == 'Take regular breaks to maintain productivity'
      end
      d.check('every release in the file is listed, newest first') do
        metainfo.releases.length.positive? &&
          metainfo.releases.first[:version] == Resources::APP_VERSION
      end
      d.check('this version has notes') do
        metainfo.notes_for(Resources::APP_VERSION).include?('<p>')
      end
      d.check('a version that is not in the file has none') do
        metainfo.notes_for('0.0.0').nil?
      end
    end
  end

  d.step('the shortcuts dialog opens') do
    app.shortcuts_action.activate(nil)
  end

  d.step('the shortcuts dialog renders with resolved accelerators') do
    # Deleting the port's own title assignment is what lets libadwaita supply
    # this one, out of its own catalogue, in every language it ships.
    d.check('libadwaita supplied the title') do
      app.shortcuts_dialog.title == 'Keyboard Shortcuts'
    end
    # An Adwaita dialog is presented inside the window rather than as its own
    # toplevel, so the window is what has it on screen.
    d.check('it is the window\'s visible dialog, not a second toplevel') do
      window.call.window.visible_dialog.equal?(app.shortcuts_dialog) &&
        Gtk::Window.list_toplevels.length == 1
    end

    labels_under(app.shortcuts_dialog).then do |labels|
      ['General', 'Timer'].each do |title|
        d.check("the #{title} section is there") { labels.include?(title) }
      end
      [
        'Open menu', 'Show keyboard shortcuts', 'Close window', 'Quit',
        'Start or stop timer', 'Add 30 seconds', 'Remove 30 seconds',
      ].each do |item|
        d.check("the #{item.downcase} shortcut is listed") { labels.include?(item) }
      end
      d.check('the literal F10 accelerator came through as written') do
        labels.include?('F10')
      end
      d.check('libadwaita resolved the action names into keys') do
        ['Ctrl', '?', 'W', 'Q', '+', '=', '-'].all? { |key| labels.include?(key) }
      end
      d.check('the space accelerator rendered as its symbol') do
        labels.include?("\u2423")
      end
    end
    d.shot('06-shortcuts')
  end

  # Libadwaita renders each shortcut twice — once in the list and once in the
  # search-results list it keeps behind it — so the count to compare against is
  # the one before the second build, not one.
  labels_under_counts = nil
  d.step('the rows are counted before the dialog is built a second time') do
    labels_under(app.shortcuts_dialog).then do |labels|
      labels_under_counts = [labels.count('Open menu'), labels.count('Timer')]
      d.check('each shortcut row was rendered at least once') do
        labels_under_counts.all?(&:positive?)
      end
    end
    app.shortcuts_dialog.build
  end

  d.step('the second build added nothing, because #build is memoized') do
    labels_under(app.shortcuts_dialog).then do |labels|
      d.check('the Open menu row count did not change') do
        labels.count('Open menu') == labels_under_counts.first
      end
      d.check('the Timer heading count did not change') do
        labels.count('Timer') == labels_under_counts.last
      end
      d.check('#build answers the same dialog object every time') do
        app.shortcuts_dialog.build.equal?(app.shortcuts_dialog)
      end
    end
  end

  d.step("a search with no matches is typed into the dialog's entry") do
    descendants(app.shortcuts_dialog).grep(Gtk::SearchEntry).then do |entries|
      d.check('the dialog has a search entry') { entries.length == 1 }
      entries.first.text = 'zzzzz'
    end
  end

  d.step('the dialog shows its empty state') do
    descendants(app.shortcuts_dialog).select { |w| w.is_a?(Adwaita::StatusPage) }.then do |pages|
      d.check('a status page is mapped') { pages.any?(&:mapped?) }
      d.check('it says no results were found') do
        pages.any? { |page| page.title == 'No Results Found' }
      end
    end
    d.check('the Timer section is no longer mapped') do
      descendants(app.shortcuts_dialog)
        .grep(Gtk::Label)
        .select { |label| label.label == 'Timer' }
        .none?(&:mapped?)
    end
    d.shot('11-shortcuts-no-results')
  end

  d.step('the search is cleared again') do
    descendants(app.shortcuts_dialog).grep(Gtk::SearchEntry).first.text = ''
  end

  d.step('the shortcuts come back') do
    d.check('the Timer section is mapped again') do
      descendants(app.shortcuts_dialog)
        .grep(Gtk::Label)
        .select { |label| label.label == 'Timer' }
        .any?(&:mapped?)
    end
  end

  d.step('the about dialog opens') do
    app.open_about_action.activate(nil)
  end

  d.step('the about dialog renders with its appdata') do
    app.about_dialog.dialog.then do |dialog|
      d.check('it is the visible dialog now') do
        window.call.window.visible_dialog.equal?(dialog)
      end
      d.check('the summary is in the comments') { dialog.comments.include?('Focus with timed') }
      d.check('the bullet list is in the comments') { dialog.comments.include?('— Take regular breaks') }
      # The generated metainfo.xml carries every catalogue's copy of the
      # description as xml:lang siblings. Before lib/metainfo.rb skipped them
      # the comments field was the description in twenty languages at once,
      # which is what this run found the first time it looked at the dialog.
      d.check('the comments are in one language, not twenty') do
        dialog.comments.scan('It enables you to:').length == 1
      end
      d.check('no translation leaked into the comments') do
        !dialog.comments.include?('Es ermöglicht Ihnen') &&
          !dialog.comments.include?('Il vous permet de')
      end
      d.check('the release notes are set') { dialog.release_notes.include?('<p>') }
      d.check('the release notes name this version') do
        dialog.release_notes_version == Resources::APP_VERSION
      end
      d.check('the name, icon and version are the port\'s own resources') do
        dialog.application_name == Resources::APP_NAME &&
          dialog.application_icon == Resources::APP_ICON &&
          dialog.version == Resources::APP_VERSION
      end
      d.check('the developers and artists are credited') do
        dialog.developers == Resources::APP_DEVELOPERS &&
          dialog.artists == Resources::APP_ARTISTS
      end
      d.check('the copyright and licence are upstream\'s') do
        dialog.copyright == Resources::APP_COPYRIGHT &&
          dialog.license_type == Gtk::License::AGPL_3_0
      end
      d.check('website, issue and support URLs are set') do
        dialog.website == Resources::APP_WEBSITE &&
          dialog.issue_url == Resources::APP_ISSUE_URL &&
          dialog.support_url == Resources::APP_SUPPORT_URL
      end
      # Upstream's `adw_about_dialog_new_from_appdata` adds no link rows, and
      # upstream calls `AddLink` nowhere, so a dialog with any of these four
      # titles in it is the port inventing components — and inventing four
      # msgids with them, which no donated catalogue can answer. Round five
      # shipped exactly that behind a comment claiming libadwaita would have
      # built two of them anyway.
      labels_under(dialog).then do |labels|
        ['Donate', 'Translate', 'Source Code', 'Contribute'].each do |link|
          d.check("no #{link} row was invented") { labels.count(link).zero? }
        end
      end
      d.shot('07-about')
    end
  end

  about_label_count = nil
  d.step('the about dialog is counted and then built a second time') do
    about_label_count = labels_under(app.about_dialog.dialog).length
    d.check('the dialog renders labels to count') { about_label_count.positive? }
    app.about_dialog.build
  end

  d.step('the second build added nothing, because #build is memoized') do
    d.check('the label count did not change') do
      labels_under(app.about_dialog.dialog).length == about_label_count
    end
    d.check('#build answers the same dialog object every time') do
      app.about_dialog.build.equal?(app.about_dialog.dialog)
    end
  end

  d.step('the dialogs close again') do
    # An Adwaita dialog is modal inside the window, so the window will not
    # close underneath one.
    app.about_dialog.dialog.close
    app.shortcuts_dialog.close
  end

  d.step('every action the port declares is installed where it says') do
    ['quit', 'shortcuts', 'openAbout', 'stopAlarmPlayback'].each do |name|
      d.check("app.#{name} is on the application") do
        !app.app.lookup_action(name).nil?
      end
      d.check("app.#{name} is enabled") { app.app.lookup_action(name).enabled? }
    end
    ['toggleTimer', 'addTime', 'removeTime', 'closeWindow'].each do |name|
      d.check("win.#{name} is on the window") do
        !window.call.window.lookup_action(name).nil?
      end
    end
    d.check('the application holds exactly the one window') do
      app.app.windows.length == 1
    end
  end

  # Last, because closing the only window is what ends the application: a step
  # after this one would never run.
  d.step('win.closeWindow closes the window') do
    window.call.close_window_action.activate(nil)
    d.check('the window is no longer visible') { window.call.window.visible? == false }
    d.check('and it really went away rather than hiding on close') do
      window.call.window.hide_on_close? == false
    end
  end
end
