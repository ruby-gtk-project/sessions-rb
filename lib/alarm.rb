# frozen_string_literal: true

require 'gtk4'
require 'gio2'

require_relative 'resources'
require_relative 'translations'

# Alarm is what happens when a session ends: a high-priority notification and
# the alarm sound, both withdrawn and stopped again when the alarm is
# dismissed.
#
# Ported from the OnStartAlarm and OnStopAlarm hooks in
# internal/components/main_window.go:260-280. Two details from upstream are
# load-bearing and kept exactly. The notification's default action is
# app.stopAlarmPlayback, an application-scoped action rather than a
# window-scoped one, because by the time the notification is clicked there may
# well be no focused window for a win.* action to reach. And stopping the sound
# seeks back to the start as well as pausing, so the next session's alarm
# begins at the beginning rather than at the end of the previous one.
#
# Upstream loads the sound from its GResource bundle with
# `gtk.NewMediaFileForResource`; this port loads the same file from data/ with
# `Gtk::MediaFile.new(path)`, which is the file constructor these bindings
# expose — there is no `Gtk::MediaFile.for_filename`, and the only singleton
# methods on the class are GObject's own. FINDINGS.md records the check.
#
# Nothing here is rescued. A sound file that will not load is a broken install,
# and a session that ends in silence with one line on stderr is worse than one
# that ends in a backtrace, because the silence is indistinguishable from the
# feature working.
#
class Alarm
  include Translations

  NOTIFICATION_ID = 'session-finished'
  DEFAULT_ACTION = 'app.stopAlarmPlayback'

  def initialize(app)
    @app = app
  end

  def start
    @app.send_notification(NOTIFICATION_ID, notification)
    sound.seek(0)
    sound.play
  end

  def stop
    sound.playing = false
    sound.seek(0)
    @app.withdraw_notification(NOTIFICATION_ID)
  end

  def notification
    @notification ||= Gio::Notification.new(_('Session Finished')).tap do |n|
      n.body = _('Time to take a break')
      n.priority = :high
      n.set_default_action(DEFAULT_ACTION)
    end
  end

  def sound = @sound ||= Gtk::MediaFile.new(Resources::ALARM_SOUND_PATH)
end
