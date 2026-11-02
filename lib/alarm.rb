# frozen_string_literal: true

require 'gtk4'
require 'gio2'

require_relative 'resources'

# Alarm is what happens when a session ends: a high-priority notification and
# the alarm sound, both withdrawn and stopped again when the alarm is
# dismissed.
#
# Ported from the OnStartAlarm and OnStopAlarm hooks in
# internal/components/main_window.go. Two details from upstream are load-bearing
# and kept exactly. The notification's default action is app.stopAlarmPlayback,
# an application-scoped action rather than a window-scoped one, because by the
# time the notification is clicked there may well be no focused window for a
# win.* action to reach. And stopping the sound seeks back to the start as well
# as pausing, so the next session's alarm begins at the beginning rather than
# at the end of the previous one.
#
# Upstream loads the sound from its GResource bundle; this port loads the same
# file from data/.
#
class Alarm
  NOTIFICATION_ID = 'session-finished'
  NOTIFICATION_TITLE = 'Session Finished'
  NOTIFICATION_BODY = 'Time to take a break'
  DEFAULT_ACTION = 'app.stopAlarmPlayback'

  def initialize(app)
    @app = app
  end

  def start
    @app.send_notification(NOTIFICATION_ID, notification)
    sound.then do |media|
      unless media.nil?
        media.seek(0)
        media.play
      end
    end
  end

  def stop
    sound.then do |media|
      unless media.nil?
        media.playing = false
        media.seek(0)
      end
    end
    @app.withdraw_notification(NOTIFICATION_ID)
  end

  def notification
    @notification ||= Gio::Notification.new(NOTIFICATION_TITLE).tap do |n|
      n.body = NOTIFICATION_BODY
      n.priority = :high
      n.set_default_action(DEFAULT_ACTION)
    end
  end

  # A missing or unplayable sound file must not take the notification down with
  # it, so the lookup is guarded and the alarm simply stays silent.
  def sound
    @sound ||= Gtk::MediaFile.new(Resources::ALARM_SOUND_PATH)
  rescue StandardError => e
    warn "Could not load the alarm sound from #{Resources::ALARM_SOUND_PATH}: #{e.message}"
    nil
  end
end
