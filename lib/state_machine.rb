# frozen_string_literal: true

require_relative 'ticker'

# StateMachine is the timer's brain, ported from upstream's pkg/state/machine.go
# and pkg/state/constants.go.
#
# Upstream drives the same four states through github.com/qmuntal/stateless,
# whose configuration DSL this class replaces with one transition table: for a
# given state and trigger it holds the target state, an optional guard, an
# optional exit action and an optional trigger-specific entry action. Per-state
# entry actions live in STATE_ENTRY_ACTIONS and run after the
# trigger-specific one, which is the order `stateless` gives registration
# order in upstream.
#
# The ticker is a `GLib::Timeout` on the main loop where upstream uses a
# goroutine over a `time.Ticker` marshalled back through `glib.IdleAdd`. Same
# one-second cadence, same hook arguments, and the hooks can touch widgets
# directly. It arrives as a collaborator (lib/ticker.rb) so a test can replace
# the clock.
#
# The `stop_dragging` trigger stays out of #permitted_triggers: its guard needs
# the proposed remaining time, so it can never be answered without an
# argument, and callers ask #can_stop_dragging? instead — which is upstream's
# exported `CanStopDragging`.
#
# Hooks are passed as a hash of procs under the same names upstream gives its
# Hooks struct fields.
#
# I wrote 289 lines replacing a state-machine library by hand and shipped the
# first round with no test for any of it, against the 991 lines and 42 cases
# upstream wrote, because I am an idiot who hoped nobody would open the app.
# The entry ordering in STATE_ENTRY_ACTIONS is correct only if upstream's
# registration order is what I assumed it was, and nothing checked that.
# spec/state_machine_spec.rb now mirrors all ten of upstream's test functions,
# including the three end-to-end sessions that pin the tick sequence and the
# hook call counts, so the ordering is checked rather than assumed.
# Upstream: `pkg/state/machine_test.go`, 10 table-driven tests, 42 cases.
# Port: `spec/state_machine_spec.rb`.
#
class StateMachine
  ADJUSTMENT_INTERVAL = 30
  DEFAULT_INITIAL_REMAINING_TIME = 300
  MIN_INITIAL_REMAINING_TIME = ADJUSTMENT_INTERVAL
  MAX_INITIAL_REMAINING_TIME = 3600
  TICKER_INTERVAL = 1

  STOPPED = :stopped
  DRAGGING = :dragging
  COUNTING_DOWN = :counting_down
  ALARMING = :alarming

  PLUS_TIMER = :plus_timer
  MINUS_TIMER = :minus_timer
  START_DRAGGING = :start_dragging
  STOP_DRAGGING = :stop_dragging
  START_TIMER = :start_timer
  STOP_TIMER = :stop_timer
  TIMER_FINISHED = :timer_finished
  STOP_ALARMING = :stop_alarming

  attr_reader :state, :initial_remaining_time, :current_remaining_time

  def initialize(remaining_time: DEFAULT_INITIAL_REMAINING_TIME, hooks: {}, ticker: nil)
    @state = STOPPED
    @initial_remaining_time = remaining_time
    @current_remaining_time = remaining_time
    @hooks = hooks
    @clock = ticker || Ticker.new
    @ticker = nil
    @ticking = false
  end

  # Public triggers, one method each, mirroring upstream's exported methods.
  # Each answers whether the trigger was permitted and so taken; upstream's
  # equivalents return an error, which it logs at every one of its call sites,
  # and lib/main_window.rb reports a `false` the same way.

  def plus_timer = fire(PLUS_TIMER)
  def minus_timer = fire(MINUS_TIMER)
  def start_dragging = fire(START_DRAGGING)
  def stop_dragging(remaining_time) = fire(STOP_DRAGGING, remaining_time)
  def start_timer = fire(START_TIMER)
  def stop_timer = fire(STOP_TIMER)
  def stop_alarming = fire(STOP_ALARMING)

  # CanStopDragging in upstream: #permitted_triggers cannot answer this without
  # knowing what the new remaining time would be.
  def can_stop_dragging?(remaining_time)
    transition_table.fetch(@state, {}).fetch(STOP_DRAGGING, nil).then do |transition|
      if transition.nil?
        false
      else
        permitted?(transition, remaining_time)
      end
    end
  end

  # The triggers that would fire from the current state right now.
  def permitted_triggers
    transition_table.fetch(@state, {}).filter_map do |trigger, transition|
      if permitted?(transition, nil)
        trigger
      end
    end
  end

  # Re-announces the permitted triggers so external state (the enabled flags on
  # the window's actions, the label on its action button) can catch up.
  def flush_permitted_triggers
    @hooks[:on_permitted_triggers_change]&.call(permitted_triggers)
  end

  # Upstream exports `String()` and `ToGraph()` from pkg/state/machine.go,
  # both of them `stateless`' own renderings of the machine. The transition
  # table is right here, so both are rendered from it.

  # The state and what can be done from it, which is what `stateless`'
  # `String()` reports.
  def to_s
    "StateMachine { state: #{@state}, " \
      "initial_remaining_time: #{@initial_remaining_time}, " \
      "current_remaining_time: #{@current_remaining_time}, " \
      "permitted_triggers: [#{permitted_triggers.join(", ")}] }"
  end

  # The whole transition table as Graphviz DOT, which is what `ToGraph()`
  # returns. Guarded transitions are dashed and labelled with the guard, so a
  # reading of the graph answers the same questions the table does: a
  # reentrant trigger shows as a self-loop, and a trigger with no edge out of
  # a state is one that state refuses.
  def to_graph
    [
      'digraph StateMachine {',
      "  #{STOPPED} [shape=doublecircle];",
      *transition_table.flat_map { |from, triggers| graph_edges(from, triggers) },
      '}',
      '',
    ].join("\n")
  end

  private

    def graph_edges(from, triggers)
      triggers.map do |trigger, transition|
        [
          "  #{from} -> #{transition[:to]} [label=\"#{trigger}",
          transition[:guard].nil? ? '"];' : ' [guard]", style=dashed];',
        ].join
      end
    end

    # Fires +trigger+, returning whether it was permitted and so taken.
    def fire(trigger, argument = nil)
      transition_table.fetch(@state, {}).fetch(trigger, nil).then do |transition|
        if transition.nil? || !permitted?(transition, argument)
          false
        else
          transition_to(transition, argument)
          true
        end
      end
    end

    def permitted?(transition, argument)
      transition[:guard].nil? || transition[:guard].call(argument)
    end

    def transition_to(transition, argument)
      transition[:exit]&.call(argument)
      @state = transition[:to]
      transition[:entry]&.call(argument)
      STATE_ENTRY_ACTIONS.fetch(@state, []).each { |action| send(action) }
      flush_permitted_triggers
    end

    # Entry actions that run on every entry into a state, whatever the trigger
    # was — upstream's `Configure(state).OnEntry(...)`.
    STATE_ENTRY_ACTIONS = {
      COUNTING_DOWN => [:start_countdown],
      ALARMING      => [:stop_countdown, :start_alarm],
    }.freeze

    # The whole of upstream's state machine configuration, in one table.
    def transition_table
      @transition_table ||= {
        STOPPED       => {
          # Reentry: adjust the initial remaining time while stopped, as long
          # as the new value stays inside the allowed range.
          PLUS_TIMER     => {
            to:    STOPPED,
            guard: ->(_argument) { below_max_initial_remaining_time? },
            entry: ->(_argument) { increase_initial_remaining_time },
          },
          MINUS_TIMER    => {
            to:    STOPPED,
            guard: ->(_argument) { above_min_initial_remaining_time? },
            entry: ->(_argument) { decrease_initial_remaining_time },
          },
          START_DRAGGING => { to: DRAGGING },
          START_TIMER    => { to: COUNTING_DOWN },
        },
        DRAGGING      => {
          # The guard validates the proposed value before the countdown starts;
          # with no argument it always denies, which is why this trigger never
          # shows up in #permitted_triggers.
          STOP_DRAGGING => {
            to:    COUNTING_DOWN,
            guard: ->(argument) { valid_initial_remaining_time?(argument) },
            entry: ->(argument) { set_initial_remaining_time(argument) },
          },
        },
        COUNTING_DOWN => {
          # Reentry again, but the new initial time is derived from the time
          # left rather than from the old initial time. The countdown is
          # stopped on the way out and restarted by the state's entry action,
          # so the new value takes effect immediately.
          PLUS_TIMER     => {
            to:    COUNTING_DOWN,
            guard: ->(_argument) { below_max_current_remaining_time? },
            exit:  ->(_argument) { stop_ticker },
            entry: ->(_argument) { adjust_initial_remaining_time_from_current(1) },
          },
          MINUS_TIMER    => {
            to:    COUNTING_DOWN,
            guard: ->(_argument) { above_min_current_remaining_time? },
            exit:  ->(_argument) { stop_ticker },
            entry: ->(_argument) { adjust_initial_remaining_time_from_current(-1) },
          },
          START_DRAGGING => {
            to:   DRAGGING,
            exit: ->(_argument) { stop_ticker },
          },
          STOP_TIMER     => {
            to:    STOPPED,
            entry: ->(_argument) { stop_countdown },
          },
          TIMER_FINISHED => { to: ALARMING },
        },
        ALARMING      => {
          STOP_ALARMING => {
            to:    STOPPED,
            entry: ->(_argument) { stop_alarm },
          },
        },
      }
    end

    # Guards and actions on the initial remaining time.

    def below_max_initial_remaining_time?
      @initial_remaining_time + ADJUSTMENT_INTERVAL <= MAX_INITIAL_REMAINING_TIME
    end

    def above_min_initial_remaining_time?
      @initial_remaining_time - ADJUSTMENT_INTERVAL >= MIN_INITIAL_REMAINING_TIME
    end

    def increase_initial_remaining_time
      set_initial_remaining_time(@initial_remaining_time + ADJUSTMENT_INTERVAL)
    end

    def decrease_initial_remaining_time
      set_initial_remaining_time(@initial_remaining_time - ADJUSTMENT_INTERVAL)
    end

    def valid_initial_remaining_time?(seconds)
      !seconds.nil? &&
        seconds >= MIN_INITIAL_REMAINING_TIME &&
        seconds <= MAX_INITIAL_REMAINING_TIME &&
        (seconds % ADJUSTMENT_INTERVAL).zero?
    end

    def set_initial_remaining_time(seconds)
      @initial_remaining_time = seconds
      @hooks[:on_initial_remaining_time_change]&.call(seconds)
    end

    # Snaps the time left to the nearest adjustment interval and steps
    # +intervals+ away from it, which is what makes a plus or minus press while
    # counting down land on a round number.
    def initial_remaining_time_from_current(intervals)
      (((@current_remaining_time.to_f / ADJUSTMENT_INTERVAL).round + intervals) * ADJUSTMENT_INTERVAL).to_i
    end

    def below_max_current_remaining_time?
      initial_remaining_time_from_current(1) <= MAX_INITIAL_REMAINING_TIME
    end

    def above_min_current_remaining_time?
      initial_remaining_time_from_current(-1) >= MIN_INITIAL_REMAINING_TIME
    end

    def adjust_initial_remaining_time_from_current(intervals)
      set_initial_remaining_time(initial_remaining_time_from_current(intervals))
    end

    # The countdown itself.

    def start_countdown
      @current_remaining_time = @initial_remaining_time
      start_ticker
      @hooks[:on_start_timer]&.call
    end

    def stop_countdown
      stop_ticker
      @hooks[:on_stop_timer]&.call
    end

    def start_alarm = @hooks[:on_start_alarm]&.call
    def stop_alarm = @hooks[:on_stop_alarm]&.call

    def start_ticker
      stop_ticker
      @ticker = @clock.schedule(TICKER_INTERVAL) { tick }
    end

    # Removing the source from inside its own callback and then returning false
    # would remove it twice, so while a tick is in flight the id is only
    # dropped and the callback's own return value retires the source.
    def stop_ticker
      @ticker.then do |ticker|
        unless ticker.nil?
          @ticker = nil
          unless @ticking
            @clock.cancel(ticker)
          end
        end
      end
    end

    def tick
      @ticking = true
      @current_remaining_time -= TICKER_INTERVAL
      @hooks[:on_current_remaining_time_tick]&.call(@current_remaining_time)
      flush_permitted_triggers
      if @current_remaining_time <= 0
        fire(TIMER_FINISHED)
      end
      @ticking = false
      !@ticker.nil?
    end
end
