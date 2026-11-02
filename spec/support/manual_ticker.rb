# frozen_string_literal: true

# ManualTicker is lib/ticker.rb with the clock taken out: it holds the
# scheduled callback instead of handing it to GLib, and an example advances
# fake time a second at a time.
#
# It stands in for `testing/synctest`, which upstream's three end-to-end tests
# wrap the whole state machine in so that `time.Sleep(90 * time.Second)`
# returns immediately and the ticker fires ninety times. Ruby has no
# equivalent, so the seam is the ticker object itself.
#
# The contract is lib/ticker.rb's: `schedule` returns a handle, `cancel` takes
# one back, and a callback answering `false` retires its own source — which is
# how GLib::Timeout behaves and what the state machine relies on when a tick
# stops the countdown from inside itself.
class ManualTicker
  def initialize
    @callbacks = {}
    @handles = 0
  end

  def schedule(_seconds, &callback)
    @handles += 1
    @callbacks[@handles] = callback
    @handles
  end

  def cancel(handle) = @callbacks.delete(handle)

  # Whether a beat is still scheduled, which is what upstream asks its ticker
  # context (`sm.tickerCtx.Err()`).
  def scheduled? = !@callbacks.empty?

  # One second of fake time per step. Advancing past the end of the countdown
  # is deliberate in the end-to-end examples: a tick that fired after the
  # alarm started would show up as an extra argument.
  def advance(seconds)
    seconds.times { beat }
  end

  private

    def beat
      @callbacks.keys.last.then do |handle|
        unless handle.nil?
          retire(handle, @callbacks.fetch(handle).call)
        end
      end
    end

    # A callback may have replaced itself while running — a plus press while
    # counting down cancels the ticker and schedules a new one — so the handle
    # is only dropped if it is still the one registered.
    def retire(handle, again)
      if again == false
        @callbacks.delete(handle)
      end
    end
end
