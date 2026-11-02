# frozen_string_literal: true

require_relative "../lib/state_machine"
require_relative "support/manual_ticker"

# A one-for-one port of upstream's pkg/state/machine_test.go: the same ten test
# functions in the same order, each of its table entries a parameterised
# example, and each entry asserting what upstream asserts about it.
#
# Three translations recur:
#
#   * `require.NoError(t, s.PlusTimer(ctx))` becomes `expect(...).to be(true)`.
#     Upstream's triggers answer an error when `stateless` refuses them; the
#     port's answer whether they were taken, so a refused trigger is `false`.
#   * Durations are plain seconds. Upstream's `time.Duration` constants are the
#     same numbers (`RemainingTimerAdjustmentInterval` is 30s), and
#     `DefaultInitialRemainingTime + time.Millisecond*50` — the "not divisible
#     by the adjustment interval" case — becomes 300.5.
#   * `testing/synctest`'s fake clock becomes ManualTicker, which the state
#     machine takes as its ticker and the examples advance a second at a time.
#     That is the whole reason lib/ticker.rb exists as a collaborator.
#
# `timerFinished` is unexported upstream and private here, and both test suites
# drive it directly, so the examples fire the trigger through `send`.
RSpec.describe StateMachine do
  # Every hook upstream's tests install, as counters and last-seen values, so
  # an example asserts the same quantities its upstream twin does.
  class HookRecorder
    attr_reader :on_start_timer_called,
      :on_stop_timer_called,
      :on_start_alarm_called,
      :on_stop_alarm_called,
      :initial_remaining_time,
      :tick_arguments,
      :permitted_triggers,
      :on_permitted_triggers_change_called

    def initialize(initial_remaining_time)
      @on_start_timer_called = 0
      @on_stop_timer_called = 0
      @on_start_alarm_called = 0
      @on_stop_alarm_called = 0
      @initial_remaining_time = initial_remaining_time
      @tick_arguments = []
      @permitted_triggers = []
      @on_permitted_triggers_change_called = 0
    end

    def hooks
      {
        on_start_timer:                   -> { @on_start_timer_called += 1 },
        on_stop_timer:                    -> { @on_stop_timer_called += 1 },
        on_initial_remaining_time_change: ->(seconds) { @initial_remaining_time = seconds },
        on_current_remaining_time_tick:   ->(seconds) { @tick_arguments << seconds },
        on_start_alarm:                   -> { @on_start_alarm_called += 1 },
        on_stop_alarm:                    -> { @on_stop_alarm_called += 1 },
        on_permitted_triggers_change:     lambda { |triggers|
          @on_permitted_triggers_change_called += 1
          @permitted_triggers = triggers
        },
      }
    end
  end

  let(:interval) { described_class::ADJUSTMENT_INTERVAL }
  let(:minimum) { described_class::MIN_INITIAL_REMAINING_TIME }
  let(:maximum) { described_class::MAX_INITIAL_REMAINING_TIME }
  let(:default_remaining_time) { described_class::DEFAULT_INITIAL_REMAINING_TIME }
  let(:ticker) { ManualTicker.new }

  def build_machine(remaining_time, recorder)
    described_class.new(remaining_time: remaining_time, hooks: recorder.hooks, ticker: ticker)
  end

  # TestPlusTimer
  describe "#plus_timer" do
    [
      {initial: :minimum, plus_times: 1, expect_refusal_at: -1},
      {initial: :below_maximum, plus_times: 1, expect_refusal_at: -1},
      {initial: :below_maximum, plus_times: 2, expect_refusal_at: 1},
    ].each do |table_entry|
      [true, false].each do |from_counting_down|
        it "initial #{table_entry[:initial]} plus_times #{table_entry[:plus_times]} " \
           "from_counting_down #{from_counting_down}" do
          initial = {minimum: minimum, below_maximum: maximum - interval}.fetch(table_entry[:initial])
          recorder = HookRecorder.new(initial)
          machine = build_machine(initial, recorder)

          if from_counting_down
            expect(machine.start_dragging).to be(true)
            expect(machine.stop_dragging(initial)).to be(true)

            # After we stop dragging the timer is running. Only the initial
            # remaining time is asserted here; whether the timer runs is
            # TestEndToEnd's job.
            expect(recorder.on_start_timer_called).to eq(1)
          end

          expected = initial
          table_entry[:plus_times].times do |attempt|
            if attempt == table_entry[:expect_refusal_at]
              expect(machine.plus_timer).to be(false)
            else
              expect(machine.plus_timer).to be(true)
              expected += interval
            end
          end

          if from_counting_down
            # The timer is still running if we increased while counting down,
            # because the reentry restarts the countdown.
            expect(recorder.on_start_timer_called).to eq(2)
          end

          expect(recorder.initial_remaining_time).to eq(expected)
        end
      end
    end
  end

  # TestMinusTimer
  describe "#minus_timer" do
    [
      {initial: :maximum, minus_times: 1, expect_refusal_at: -1},
      {initial: :above_minimum, minus_times: 1, expect_refusal_at: -1},
      {initial: :above_minimum, minus_times: 2, expect_refusal_at: 1},
      {initial: :minimum, minus_times: 1, expect_refusal_at: 0},
    ].each do |table_entry|
      [true, false].each do |from_counting_down|
        it "initial #{table_entry[:initial]} minus_times #{table_entry[:minus_times]} " \
           "from_counting_down #{from_counting_down}" do
          initial = {
            minimum:       minimum,
            above_minimum: minimum + interval,
            maximum:       maximum,
          }.fetch(table_entry[:initial])
          recorder = HookRecorder.new(initial)
          machine = build_machine(initial, recorder)

          if from_counting_down
            expect(machine.start_dragging).to be(true)
            expect(machine.stop_dragging(initial)).to be(true)
            expect(recorder.on_start_timer_called).to eq(1)
          end

          expected = initial
          table_entry[:minus_times].times do |attempt|
            if attempt == table_entry[:expect_refusal_at]
              expect(machine.minus_timer).to be(false)
            else
              expect(machine.minus_timer).to be(true)
              expected -= interval
            end
          end

          if from_counting_down
            # A decrease that is refused on the very first attempt never
            # restarts the countdown, so the timer started exactly once — when
            # dragging stopped.
            expect(recorder.on_start_timer_called).to eq(table_entry[:expect_refusal_at].zero? ? 1 : 2)
          end

          expect(recorder.initial_remaining_time).to eq(expected)
        end
      end
    end
  end

  # TestStartDragging
  describe "#start_dragging" do
    [
      {
        name:           "can transition from initial state to dragging",
        prepare:        ->(_machine) {},
        expect_refusal: false,
      },
      {
        name:           "can not transition from dragging state to dragging",
        prepare:        ->(machine) { machine.start_dragging },
        expect_refusal: true,
      },
      {
        name:           "can transition from counting down state to dragging",
        prepare:        lambda { |machine|
          machine.start_dragging
          machine.stop_dragging(300)
        },
        expect_refusal: false,
      },
      {
        name:           "can not transition from alarming state to dragging",
        prepare:        lambda { |machine|
          machine.start_timer
          machine.send(:fire, described_class::TIMER_FINISHED)
        },
        expect_refusal: true,
      },
      {
        name:                  "transitioning from counting down state to dragging cancels running timer",
        prepare:               lambda { |machine|
          machine.start_dragging
          machine.stop_dragging(300)
        },
        expect_refusal:        false,
        expect_ticker_stopped: true,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        expect(machine.start_dragging).to be(!table_entry[:expect_refusal])

        if table_entry[:expect_ticker_stopped]
          # Upstream reads `sm.tickerCtx.Err()`; here the ticker itself is the
          # one that knows whether a beat is still scheduled.
          expect(ticker).not_to be_scheduled
        end
      end
    end
  end

  # TestStopDragging
  describe "#stop_dragging" do
    [
      {
        name:                  "can transition from dragging state to counting down state with valid initial remaining time",
        remaining_time:        300,
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        false,
        on_start_timer_called: 1,
      },
      {
        name:                  "can not transition from dragging state to counting down state with initial " \
              "remaining time below minimum remaining time",
        remaining_time:        0,
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        true,
        on_start_timer_called: 0,
      },
      {
        name:                  "can not transition from dragging state to counting down state with initial " \
              "remaining time above maximum remaining time",
        remaining_time:        3630,
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        true,
        on_start_timer_called: 0,
      },
      {
        name:                  "can not transition from dragging state to counting down state with initial " \
              "remaining time that's not divisible by the adjustment interval",
        remaining_time:        300.5,
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        true,
        on_start_timer_called: 0,
      },
      {
        name:                  "can not transition from initial to counting down state",
        remaining_time:        300,
        prepare:               ->(_machine) {},
        expect_refusal:        true,
        on_start_timer_called: 0,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        # CanStopDragging is asserted before the trigger, as upstream does,
        # because it is the only permission question the machine cannot answer
        # from #permitted_triggers.
        expect(machine.can_stop_dragging?(table_entry[:remaining_time]))
          .to be(!table_entry[:expect_refusal])

        expect(machine.stop_dragging(table_entry[:remaining_time]))
          .to be(!table_entry[:expect_refusal])

        unless table_entry[:expect_refusal]
          expect(recorder.initial_remaining_time).to eq(table_entry[:remaining_time])
        end

        expect(recorder.on_start_timer_called).to eq(table_entry[:on_start_timer_called])
      end
    end
  end

  # TestStopTimer
  describe "#stop_timer" do
    [
      {
        name:                 "can transition from counting down state to stopped state",
        prepare:              lambda { |machine|
          machine.start_dragging
          machine.stop_dragging(300)
        },
        expect_refusal:       false,
        on_stop_timer_called: 1,
      },
      {
        name:                 "can not transition from dragging state to stopped state",
        prepare:              ->(machine) { machine.start_dragging },
        expect_refusal:       true,
        on_stop_timer_called: 0,
      },
      {
        name:                 "can not transition from alarming state to stopped state",
        prepare:              lambda { |machine|
          machine.start_timer
          machine.send(:fire, described_class::TIMER_FINISHED)
        },
        expect_refusal:       true,
        # Entering the alarming state stops the countdown, so on_stop_timer has
        # already fired once by the time the refused trigger is tried.
        on_stop_timer_called: 1,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        expect(machine.stop_timer).to be(!table_entry[:expect_refusal])
        expect(recorder.on_stop_timer_called).to eq(table_entry[:on_stop_timer_called])
      end
    end
  end

  # TestStartTimer
  describe "#start_timer" do
    [
      {
        name:                  "can transition from stopped state to counting down state",
        prepare:               ->(_machine) {},
        expect_refusal:        false,
        on_start_timer_called: 1,
      },
      {
        name:                  "can not transition from dragging state to counting down state",
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        true,
        on_start_timer_called: 0,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        expect(machine.start_timer).to be(!table_entry[:expect_refusal])
        expect(recorder.on_start_timer_called).to eq(table_entry[:on_start_timer_called])
      end
    end
  end

  # TestTimerFinished
  describe "the timer_finished trigger" do
    [
      {
        name:                  "can transition from counting down state to alarming state",
        prepare:               ->(machine) { machine.start_timer },
        expect_refusal:        false,
        on_start_alarm_called: 1,
      },
      {
        name:                  "can not transition from dragging state to alarming state",
        prepare:               ->(machine) { machine.start_dragging },
        expect_refusal:        true,
        on_start_alarm_called: 0,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        expect(machine.send(:fire, described_class::TIMER_FINISHED))
          .to be(!table_entry[:expect_refusal])
        expect(recorder.on_start_alarm_called).to eq(table_entry[:on_start_alarm_called])
      end
    end
  end

  # TestStopAlarming
  describe "#stop_alarming" do
    [
      {
        name:                 "can transition from alarming state to stopped state",
        prepare:              lambda { |machine|
          machine.start_timer
          machine.send(:fire, described_class::TIMER_FINISHED)
        },
        expect_refusal:       false,
        on_stop_alarm_called: 1,
        on_stop_timer_called: 1,
      },
      {
        name:                 "can not transition from counting down state to stopped state",
        prepare:              ->(machine) { machine.start_timer },
        expect_refusal:       true,
        on_stop_alarm_called: 0,
        on_stop_timer_called: 0,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        table_entry[:prepare].call(machine)

        expect(machine.stop_alarming).to be(!table_entry[:expect_refusal])
        expect(recorder.on_stop_alarm_called).to eq(table_entry[:on_stop_alarm_called])
        expect(recorder.on_stop_timer_called).to eq(table_entry[:on_stop_timer_called])
      end
    end
  end

  # TestEndToEnd — three whole sessions over fake time, asserting the exact
  # tick sequence, every hook's call count, the triggers permitted at the end,
  # and how many times the permitted set was announced. The last of those is
  # what pins the ordering inside a transition: one announcement per
  # transition plus one per tick, and nothing else.
  describe "a whole session" do
    [
      {
        name:                                "can set an alarm for 60s, wait for it to finish, and stop the alarm",
        plus_times:                          2,
        # *4, not *3, so a tick after the alarm would show up as an extra
        # argument.
        advance_intervals:                   4,
        stop_alarming:                       true,
        on_start_timer_called:               1,
        initial_remaining_time_intervals:    3,
        on_stop_timer_called:                1,
        on_start_alarm_called:               1,
        on_stop_alarm_called:                1,
        permitted_triggers:                  %i[start_timer plus_timer minus_timer start_dragging],
        on_permitted_triggers_change_called: 96,
      },
      {
        name:                                "can set an alarm for 120s, wait for it to finish, and stop the alarm",
        plus_times:                          4,
        advance_intervals:                   6,
        stop_alarming:                       true,
        on_start_timer_called:               1,
        initial_remaining_time_intervals:    5,
        on_stop_timer_called:                1,
        on_start_alarm_called:               1,
        on_stop_alarm_called:                1,
        permitted_triggers:                  %i[start_timer plus_timer minus_timer start_dragging],
        on_permitted_triggers_change_called: 158,
      },
      {
        name:                                "can set an alarm for 120s, wait for it to finish, and keep the alarm running",
        plus_times:                          4,
        advance_intervals:                   6,
        stop_alarming:                       false,
        on_start_timer_called:               1,
        initial_remaining_time_intervals:    5,
        on_stop_timer_called:                1,
        on_start_alarm_called:               1,
        on_stop_alarm_called:                0,
        permitted_triggers:                  %i[stop_alarming],
        on_permitted_triggers_change_called: 157,
      },
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)

        expected_initial = interval * table_entry[:initial_remaining_time_intervals]
        expected_ticks = (expected_initial - described_class::TICKER_INTERVAL)
          .step(0, -described_class::TICKER_INTERVAL).to_a

        table_entry[:plus_times].times { expect(machine.plus_timer).to be(true) }
        expect(machine.start_timer).to be(true)

        ticker.advance(interval * table_entry[:advance_intervals])

        if table_entry[:stop_alarming]
          expect(machine.stop_alarming).to be(true)
        end

        expect(recorder.on_start_timer_called).to eq(table_entry[:on_start_timer_called])
        expect(recorder.initial_remaining_time).to eq(expected_initial)
        expect(recorder.tick_arguments).to eq(expected_ticks)
        expect(recorder.on_stop_timer_called).to eq(table_entry[:on_stop_timer_called])
        expect(recorder.on_start_alarm_called).to eq(table_entry[:on_start_alarm_called])
        expect(recorder.on_stop_alarm_called).to eq(table_entry[:on_stop_alarm_called])
        expect(recorder.permitted_triggers).to match_array(table_entry[:permitted_triggers])

        # Flushing re-announces the same set, which is the only thing it is
        # for, and costs exactly one more announcement.
        machine.flush_permitted_triggers
        expect(recorder.permitted_triggers).to match_array(table_entry[:permitted_triggers])
        expect(recorder.on_permitted_triggers_change_called)
          .to eq(table_entry[:on_permitted_triggers_change_called])
      end
    end
  end

  # TestGetInitialRemainingTimeFromCurrentRemainingTime — the 15-second
  # rounding boundary, which is what makes a plus or minus press while counting
  # down land on a round number.
  describe "deriving the initial remaining time from the current one" do
    [
      {name: "0s plus 1 interval results in 30s", current: 0, intervals: 1, expected: 30},
      {name: "0s plus 2 intervals results in 60s", current: 0, intervals: 2, expected: 60},
      {name: "5s plus 2 intervals results in 60s", current: 5, intervals: 2, expected: 60},
      {name: "14s plus 2 intervals results in 60s", current: 14, intervals: 2, expected: 60},
      {name: "15s plus 2 intervals results in 90s", current: 15, intervals: 2, expected: 90},
      {name: "30s plus 2 intervals results in 90s", current: 30, intervals: 2, expected: 90},
    ].each do |table_entry|
      it table_entry[:name] do
        recorder = HookRecorder.new(minimum)
        machine = build_machine(minimum, recorder)
        machine.instance_variable_set(:@current_remaining_time, table_entry[:current])

        expect(machine.send(:initial_remaining_time_from_current, table_entry[:intervals]))
          .to eq(table_entry[:expected])
      end
    end
  end

  # Not an upstream test function: upstream exports String() and ToGraph() from
  # pkg/state/machine.go and `stateless` tests them itself, so the port's own
  # renderings are what need covering.
  describe "#to_s and #to_graph" do
    let(:machine) { build_machine(default_remaining_time, HookRecorder.new(default_remaining_time)) }

    it "reports the state and what can be done from it" do
      expect(machine.to_s).to eq(
        "StateMachine { state: stopped, initial_remaining_time: 300, " \
        "current_remaining_time: 300, permitted_triggers: " \
        "[plus_timer, minus_timer, start_dragging, start_timer] }",
      )
    end

    it "renders every transition, marking the guarded ones" do
      expect(machine.to_graph).to include(
        "  stopped -> dragging [label=\"start_dragging\"];",
        "  stopped -> stopped [label=\"plus_timer [guard]\", style=dashed];",
        "  alarming -> stopped [label=\"stop_alarming\"];",
      )
    end

    it "names every state the table can reach" do
      expect(machine.to_graph.scan(/^  (\w+) -> (\w+)/).flatten.uniq)
        .to match_array(%w[stopped dragging counting_down alarming])
    end
  end
end
