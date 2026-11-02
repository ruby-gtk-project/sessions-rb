# frozen_string_literal: true

require 'glib2'

# Ticker is the countdown's one-second beat.
#
# It exists as a collaborator rather than as two lines inside
# lib/state_machine.rb because upstream's countdown is a goroutine over a
# `time.Ticker` whose clock `pkg/state/machine_test.go` replaces wholesale with
# `testing/synctest`'s fake time — three of its ten test functions assert the
# exact sequence of tick arguments for a whole ninety- or hundred-and-fifty-
# second session. Ruby has no synctest, so the seam is explicit: the state
# machine asks whatever it was given to schedule its beat, and
# spec/state_machine_spec.rb hands it a ticker it can advance by hand.
#
# `schedule` returns an opaque handle and `cancel` takes it back; the state
# machine never looks inside one.
#
class Ticker
  # GLib::Timeout.add counts milliseconds, and the callback's return value
  # decides whether the source fires again — which is the state machine's
  # answer, passed straight through.
  def schedule(seconds, &callback) = GLib::Timeout.add(Integer(seconds * 1000), &callback)

  def cancel(handle) = GLib::Source.remove(handle)
end
