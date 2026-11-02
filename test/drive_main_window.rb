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

app = App.new

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
    d.shot('01-initial')
  end

  d.step('win.addTime adds thirty seconds') do
    window.call.add_time_action.activate(nil)
    d.check('the dial moved to 05:30') { window.call.dial.remaining_time == 330 }
    d.check('the label followed it') { window.call.time_label.label == '05:30' }
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
    d.shot('06-shortcuts')
  end

  d.step('the about dialog opens') do
    app.open_about_action.activate(nil)
  end

  d.step('the about dialog renders with its appdata') do
    app.about_dialog.dialog.then do |dialog|
      d.check('the summary is in the comments') { dialog.comments.include?('Focus with timed') }
      d.check('the bullet list is in the comments') { dialog.comments.include?('— Take regular breaks') }
      d.check('the release notes are set') { dialog.release_notes.include?('<p>') }
      d.check('the release notes name this version') do
        dialog.release_notes_version == Resources::APP_VERSION
      end
      d.shot('07-about')
    end
  end

  d.step('the dialogs close again') do
    # An Adwaita dialog is modal inside the window, so the window will not
    # close underneath one.
    app.about_dialog.dialog.close
    app.shortcuts_dialog.close
  end

  d.step('win.closeWindow closes the window') do
    window.call.close_window_action.activate(nil)
    d.check('the window is no longer visible') { window.call.window.visible? == false }
  end
end
