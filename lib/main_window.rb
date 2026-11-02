# frozen_string_literal: true

require 'adwaita'
require 'rexml/text'

require_relative 'alarm'
require_relative 'background_portal'
require_relative 'dial'
require_relative 'main_menu'
require_relative 'resources'
require_relative 'state_machine'
require_relative 'style'
require_relative 'translations'

# MainWindow is the whole app: a dial with the remaining time written across
# it, and minus / start-stop / plus underneath.
#
# Ported from assets/resources/window.blp — which supplies the widget tree —
# and internal/components/main_window.go, which supplies the behaviour: the
# four window actions, the state machine's hooks, and the background-portal
# dance that lets the timer keep running once the window is closed.
#
# The hooks are where the behaviour lives, and they are upstream's, in
# upstream's order. Starting the timer colours the dial red and asks to run in
# the background; stopping it restores the dial to the last duration the user
# chose and gives the background permission back. Every change to that
# duration is written straight through to the settings, which is how the app
# reopens where it was left. The alarm blinks the label, sends a notification
# and plays a sound, and dismissing it undoes all three.
#
# Two differences from upstream, both consequences of lib/state_machine.rb
# running its countdown on the main loop rather than in a goroutine. The hooks
# touch widgets directly rather than wrapping every line in glib.IdleAdd. And
# the time label is updated from the dial's change callback instead of a
# GObject property binding with a transform function.
#
# The time readout's row carries the accessible label upstream's blueprint
# gives it (window.blp:53-55). `Gtk::Accessible#update_property` cannot set it
# — the bindings raise NotImplementedError on an array of GtkAccessibleProperty
# — so the row is built from a one-object Gtk::Builder snippet, which is the
# same `<accessibility>` element a blueprint compiles to. FINDINGS.md records
# the binding defect.
#
class MainWindow
  include Translations

  WIDTH = 360
  HEIGHT = 380
  DIAL_SIZE = 260

  START_ICON = 'media-playback-start-symbolic'
  STOP_ICON = 'media-playback-stop-symbolic'

  # The time readout's row, with the accessible label window.blp:53-55 gives
  # it. The label is substituted rather than written in, because it is
  # translated and Builder's own `translatable="yes"` would look the msgid up
  # in GTK's domain rather than in this app's.
  TIMER_ROW_UI = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <object class="GtkListBoxRow" id="timer_row">
        <property name="activatable">False</property>
        <accessibility>
          <property name="label">%<label>s</property>
        </accessibility>
      </object>
    </interface>
  XML

  ACCELERATORS = {
    'win.closeWindow' => ['<Primary>w'],
    'win.toggleTimer' => ['<Primary>space'],
    'win.addTime'     => ['<Primary>plus', '<Primary>equal'],
    'win.removeTime'  => ['<Primary>minus'],
  }.freeze

  def initialize(app:, settings:)
    @app = app
    @settings = settings
    @last_initial_remaining_time = settings.last_position
    @held = false
    @can_stop_timer = false
    @can_stop_alarming = false
  end

  def build
    window.tap do |win|
      win.content = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = content_box

        header_bar.tap do |bar|
          bar.title_widget = window_title
          bar.pack_end(menu_button)
        end
      end

      content_box.tap do |box|
        box.append(dial_pane)
        box.append(button_pane)

        dial_pane.tap do |pane|
          pane.append(overlay)

          overlay.tap do |ov|
            ov.child = dial_area
            ov.add_overlay(timer_list)

            dial_area.append(dial.build)

            timer_list.tap do |list|
              list.append(timer_row)
              timer_row.child = time_label
            end
          end
        end

        button_pane.tap do |pane|
          pane.append(minus_button)
          pane.append(action_button)
          pane.append(plus_button)
        end
      end

      toggle_timer_action.signal_connect('activate') { toggle_timer }
      add_time_action.signal_connect('activate') { report(:plus_timer, state_machine.plus_timer) }
      remove_time_action.signal_connect('activate') { report(:minus_timer, state_machine.minus_timer) }
      close_window_action.signal_connect('activate') { win.close }
      stop_alarm_playback_action.signal_connect('activate') { stop_alarm_playback }

      window_actions.each { |action| win.add_action(action) }
      @app.add_action(stop_alarm_playback_action)
      ACCELERATORS.each { |name, accels| @app.set_accels_for_action(name, accels) }

      # The dial starts at the duration the previous run ended on, and the
      # permitted triggers are flushed once so the buttons start out in the
      # right state.
      dial.remaining_time = @last_initial_remaining_time
      state_machine.flush_permitted_triggers
    end
  end

  # Memoized widget methods

  # Adwaita::ApplicationWindow, not Gtk::ApplicationWindow: upstream's template
  # is an Adw.ApplicationWindow with a `content` rather than a titlebar, and
  # the Adwaita window is also what keeps an Adwaita::Dialog inside the window
  # instead of spawning a second toplevel. (Adwaita::Application is still
  # broken in the bindings, so the application object stays a Gtk one.)
  def window
    @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
      win.title = _('Sessions')
      win.icon_name = Resources::APP_ICON
      win.set_default_size(WIDTH, HEIGHT)
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def window_title
    @window_title ||= Adwaita::WindowTitle.new(_('Sessions'), '')
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = _('Main Menu')
      button.primary = true
      button.menu_model = main_menu.build
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

  def dial_pane
    @dial_pane ||= Gtk::Box.new(:vertical, 12).tap do |pane|
      pane.valign = :center
      pane.vexpand = true
      pane.margin_top = 12
      pane.margin_bottom = 12
      pane.margin_start = 12
      pane.margin_end = 12
    end
  end

  def overlay = @overlay ||= Gtk::Overlay.new

  def dial_area
    @dial_area ||= Gtk::Box.new(:vertical, 0).tap do |area|
      area.width_request = DIAL_SIZE
      area.height_request = DIAL_SIZE
    end
  end

  def timer_list
    @timer_list ||= Gtk::ListBox.new.tap do |list|
      list.halign = :center
      list.valign = :center
      list.selection_mode = :none
      list.add_css_class('boxed-list')
      list.add_css_class('boxed-list--opaque')
    end
  end

  def timer_row
    @timer_row ||= Gtk::Builder.new(
      string: format(TIMER_ROW_UI, label: REXML::Text.normalize(_('Remaining Time'))),
    )['timer_row']
  end

  def time_label
    @time_label ||= Gtk::Label.new(_('05:00')).tap do |label|
      label.margin_top = 12
      label.margin_bottom = 12
      label.margin_start = 12
      label.margin_end = 12
      label.add_css_class('title-1')
      label.add_css_class('dial__display')
    end
  end

  def button_pane
    @button_pane ||= Gtk::Box.new(:horizontal, 12).tap do |pane|
      pane.halign = :center
      pane.margin_top = 12
      pane.margin_bottom = 12
      pane.margin_start = 12
      pane.margin_end = 12
    end
  end

  def minus_button
    @minus_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.removeTime'
      button.icon_name = 'list-remove-symbolic'
      button.tooltip_text = _('Remove 30 seconds')
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  # Upstream's blueprint gives this button both an icon and a label, in that
  # order; GtkButton's label replaces the icon, so the label is what shows.
  def action_button
    @action_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.toggleTimer'
      button.icon_name = START_ICON
      button.label = _('_Start Timer')
      button.use_underline = true
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def plus_button
    @plus_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.addTime'
      button.icon_name = 'list-add-symbolic'
      button.tooltip_text = _('Add 30 seconds')
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  def main_menu = @main_menu ||= MainMenu.new
  def alarm = @alarm ||= Alarm.new(@app)
  def background_portal = @background_portal ||= BackgroundPortal.new

  def dial
    @dial ||= Dial.new(
      on_drag_begin:            -> { state_machine.start_dragging },
      on_drag_end:              -> { state_machine.stop_dragging(dial.remaining_time) },
      on_remaining_time_change: ->(seconds) { time_label.label = format_time(seconds) },
    )
  end

  def state_machine
    @state_machine ||= StateMachine.new(
      remaining_time: @settings.last_position,
      hooks:          hooks,
    )
  end

  # Actions

  def toggle_timer_action = @toggle_timer_action ||= Gio::SimpleAction.new('toggleTimer', nil)
  def add_time_action = @add_time_action ||= Gio::SimpleAction.new('addTime', nil)
  def remove_time_action = @remove_time_action ||= Gio::SimpleAction.new('removeTime', nil)
  def close_window_action = @close_window_action ||= Gio::SimpleAction.new('closeWindow', nil)

  # Application-scoped, not window-scoped: it is the notification's default
  # action, and no window need be focused when the notification is clicked.
  def stop_alarm_playback_action
    @stop_alarm_playback_action ||= Gio::SimpleAction.new('stopAlarmPlayback', nil)
  end

  def window_actions
    @window_actions ||= [
      toggle_timer_action,
      add_time_action,
      remove_time_action,
      close_window_action,
    ]
  end

  private

    def hooks
      @hooks ||= {
        on_start_timer:                   -> { on_start_timer },
        on_stop_timer:                    -> { on_stop_timer },
        on_initial_remaining_time_change: ->(seconds) { on_initial_remaining_time_change(seconds) },
        on_current_remaining_time_tick:   ->(seconds) { dial.remaining_time = seconds },
        on_start_alarm:                   -> { on_start_alarm },
        on_stop_alarm:                    -> { on_stop_alarm },
        on_permitted_triggers_change:     ->(triggers) { on_permitted_triggers_change(triggers) },
      }
    end

    def on_start_timer
      dial.counting_down = true
      hold_in_background(_('Timer Running'))
    end

    def on_stop_timer
      dial.remaining_time = @last_initial_remaining_time
      dial.counting_down = false
      release_from_background
    end

    def on_initial_remaining_time_change(seconds)
      @last_initial_remaining_time = seconds
      dial.remaining_time = seconds
      @settings.last_position = seconds
    end

    def on_start_alarm
      dial.remaining_time = 0
      dial.counting_down = true
      hold_in_background(_('Session Finished'))
      dial.sensitive = false
      time_label.add_css_class(Style::ALARMING_CLASS)
      alarm.start
      announce(_('Session Finished'))
    end

    def on_stop_alarm
      dial.remaining_time = @last_initial_remaining_time
      dial.counting_down = false
      release_from_background
      dial.sensitive = true
      time_label.remove_css_class(Style::ALARMING_CLASS)
      alarm.stop
    end

    # The button is enabled whenever any of the three triggers it stands for is
    # permitted, and it shows "Start" or "Stop" depending on which. Upstream
    # writes the start appearance first and lets the stop appearance override
    # it, which is the order kept here.
    def on_permitted_triggers_change(triggers)
      @can_stop_timer = triggers.include?(StateMachine::STOP_TIMER)
      @can_stop_alarming = triggers.include?(StateMachine::STOP_ALARMING)

      toggle_timer_action.enabled =
        triggers.include?(StateMachine::START_TIMER) || @can_stop_timer || @can_stop_alarming
      remove_time_action.enabled = triggers.include?(StateMachine::MINUS_TIMER)
      add_time_action.enabled = triggers.include?(StateMachine::PLUS_TIMER)

      if triggers.include?(StateMachine::START_TIMER)
        show_start_appearance
      end
      if @can_stop_timer || @can_stop_alarming
        show_stop_appearance
      end
    end

    def show_start_appearance
      action_button.tap do |button|
        button.icon_name = START_ICON
        button.label = _('_Start Timer')
        button.remove_css_class('destructive-action')
        button.add_css_class('suggested-action')
      end
    end

    def show_stop_appearance
      action_button.tap do |button|
        button.icon_name = STOP_ICON
        button.label = _('_Stop')
        button.remove_css_class('suggested-action')
        button.add_css_class('destructive-action')
      end
    end

    def toggle_timer
      if @can_stop_timer
        report(:stop_timer, state_machine.stop_timer)
      elsif @can_stop_alarming
        report(:stop_alarming, state_machine.stop_alarming)
      else
        report(:start_timer, state_machine.start_timer)
      end
    end

    # Upstream logs every refused transition — thirteen `log.Error` /
    # `log.Warn` sites across internal/components/main_window.go, each on the
    # error `stateless` returns when a trigger is not permitted from the
    # current state. The port's triggers answer `false` instead of an error,
    # and before this nothing read the answer, so a press that could not be
    # honoured produced nothing at all: no sound, no label change, no trace.
    def report(trigger, fired)
      unless fired
        warn("sessions: #{trigger} is not permitted from #{state_machine.state}; #{state_machine}")
      end

      fired
    end

    # The notification's default action: silence the alarm and bring the window
    # back up.
    def stop_alarm_playback
      report(:stop_alarming, state_machine.stop_alarming)
      @app.activate
    end

    # Holding the application keeps it alive with no window on screen, and
    # hide-on-close turns the close button into a hide — but only once the
    # session has agreed to it, so a denied request leaves the app behaving
    # exactly as it did before.
    def hold_in_background(status)
      unless @held
        background_portal.request(reason: _('Running the Timer in the Background')) do |granted|
          if granted
            background_portal.status = status
            @app.hold
            window.hide_on_close = true
            @held = true
          end
        end
      end
    end

    def release_from_background
      if @held
        background_portal.status = ''
        window.hide_on_close = false
        @app.release
        @held = false
      end
    end

    def format_time(seconds) = format('%02d:%02d', seconds / 60, seconds % 60)

    # Announcing the finished session is what makes the alarm reach a screen
    # reader, which the blinking label on its own would not. Upstream:
    # `internal/components/main_window.go:276`.
    #
    # Not rescued. `Gtk::Label#announce(message, priority)` is a method these
    # bindings expose and a call that goes through without raising; if it ever
    # stops being one, a backtrace is the only way anybody finds out, because
    # a missing announcement is silent by definition.
    def announce(message) = time_label.announce(message, :high)
end
