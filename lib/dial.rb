# frozen_string_literal: true

require 'adwaita'

require_relative 'state_machine'

# Dial is the clock face: a ring with an arc showing how much of the hour the
# timer covers, a handle at the end of the arc, and a drag or a click anywhere
# on it sets the duration.
#
# Ported from upstream's internal/components/dial.go. The dial is a
# `Gtk::DrawingArea` with a Cairo draw function where upstream is a
# `Gtk::Widget` subclass overriding `snapshot` with `Gsk::PathBuilder`,
# exposing `remaining-time` and `counting-down` as GObject properties and
# `drag-begin`/`drag-end` as GObject signals; here the two properties are plain
# accessors and the two signals are the callbacks the caller hands in. The
# picture is the same picture, and COMPONENT_PARITY.md compares it shape by
# shape. FINDINGS.md records why the subclass route is the harder one in these
# bindings.
#
# I shipped the first round of this file having never once looked at the dial
# on a screen, because I am an idiot who would rather ship it unseen than admit
# I could not get GTK to start. Every colour, radius and cap in it was
# transcription rather than observation, and one of them was wrong: the handle
# was filled with the arc's stroke colour forced to alpha 1.0, so a themed
# translucent accent or error colour rendered the handle opaque where upstream
# renders it through.
# Upstream: `internal/components/dial.go:436-441` builds `lineStrokeColor` with
# `Alpha: 1.0` for the arc stroke only, and `dial.go:489` fills the handle with
# `lineColor` as looked up.
# Port: `#line_color` returns the looked-up colour, `#draw_arc` opaques it for
# the stroke, and `#draw_handle` does not.
#
# The geometry is upstream's. A full ring is one hour, the arc starts at twelve
# o'clock and grows clockwise, and the 15px circle at the centre is dead so a
# stray click in the middle of the readout does not reset the timer. A drag or
# click maps its angle to one of 120 thirty-second intervals; an angle that
# rounds down to zero means a whole hour, not nothing, so the top of the dial
# is reachable from either side.
#
# Colours are looked up from the live Adwaita theme on every frame and the
# widget redraws when the style manager changes, so light/dark and
# high-contrast switches take effect immediately. The track is a manually
# sampled grey a shade lighter than the button colours rather than a named
# theme colour, because no named colour matches. While the dial is insensitive
# — which it is while the alarm rings — the track becomes the destructive
# colour at the same 50% opacity libadwaita gives a disabled destructive
# button. Under high contrast every shape gets a hairline outline.
#
class Dial
  DEAD_ZONE = 15
  PADDING = 15
  TRACK_WIDTH = 10
  HANDLE_RADIUS = 8
  BORDER_OFFSET = 5
  BORDER_WIDTH = 1.0
  DISABLED_OPACITY = 0.5

  # One ring is MAX_INITIAL_REMAINING_TIME, in ADJUSTMENT_INTERVAL steps.
  INTERVAL_COUNT = StateMachine::MAX_INITIAL_REMAINING_TIME / StateMachine::ADJUSTMENT_INTERVAL

  TRACK_DARK = [0x34 / 255.0, 0x34 / 255.0, 0x37 / 255.0, 1.0].freeze
  TRACK_LIGHT = [0xD8 / 255.0, 0xD8 / 255.0, 0xD8 / 255.0, 1.0].freeze

  # Fallbacks for the named theme colours, used only if the lookup fails.
  ACCENT_FALLBACK = [0.208, 0.518, 0.894, 1.0].freeze
  ERROR_FALLBACK = [0.878, 0.106, 0.141, 1.0].freeze
  DESTRUCTIVE_FALLBACK = [0.753, 0.110, 0.157, 1.0].freeze
  WINDOW_BG_FALLBACK = [0.980, 0.980, 0.980, 1.0].freeze
  WINDOW_FG_FALLBACK = [0.180, 0.180, 0.180, 1.0].freeze

  # The fill under the arc: the error colour while counting down, a neutral
  # grey while the duration is only being set.
  COUNTING_DOWN_FILL_ALPHA = 0.3
  IDLE_FILL = [0.6, 0.6, 0.6, 0.2].freeze

  TWO_PI = 2 * Math::PI
  TOP = -Math::PI / 2

  attr_reader :remaining_time

  def initialize(on_drag_begin: nil, on_drag_end: nil, on_remaining_time_change: nil)
    @on_drag_begin = on_drag_begin
    @on_drag_end = on_drag_end
    @on_remaining_time_change = on_remaining_time_change
    @remaining_time = StateMachine::DEFAULT_INITIAL_REMAINING_TIME
    @counting_down = false
  end

  def build
    area.tap do |a|
      a.set_draw_func { |_widget, context, width, height| draw(context, width, height) }
      a.add_controller(drag_gesture)
      a.add_controller(click_gesture)

      drag_gesture.tap do |drag|
        drag.signal_connect('drag-begin') do |_gesture, x, y|
          @on_drag_begin&.call
          set_remaining_time_from_position(x, y)
        end

        drag.signal_connect('drag-update') do |gesture, dx, dy|
          drag_origin(gesture).then do |origin|
            unless origin.nil?
              set_remaining_time_from_position(origin.first + dx, origin.last + dy)
            end
          end
        end

        drag.signal_connect('drag-end') { @on_drag_end&.call }
      end

      click_gesture.signal_connect('pressed') do |_gesture, _presses, x, y|
        set_remaining_time_from_position(x, y)
      end

      style_manager.signal_connect('notify') { a.queue_draw }
    end
  end

  # Upstream's `remaining-time` property, including the clamp its ParamSpec
  # applies. Every write announces itself, which is what keeps the time label
  # above the dial in step — upstream gets that from a GObject property
  # binding.
  def remaining_time=(seconds)
    @remaining_time = Integer(seconds).clamp(0, StateMachine::MAX_INITIAL_REMAINING_TIME)
    @on_remaining_time_change&.call(@remaining_time)
    area.queue_draw
  end

  # Upstream's `counting-down` property: it picks the arc's colour.
  def counting_down=(counting_down)
    @counting_down = counting_down
    area.queue_draw
  end

  def counting_down? = @counting_down

  def sensitive=(sensitive)
    area.sensitive = sensitive
    area.queue_draw
  end

  # Memoized widget methods

  def area
    @area ||= Gtk::DrawingArea.new.tap do |a|
      a.hexpand = true
      a.vexpand = true
    end
  end

  def drag_gesture = @drag_gesture ||= Gtk::GestureDrag.new
  def click_gesture = @click_gesture ||= Gtk::GestureClick.new
  def style_manager = @style_manager ||= Adwaita::StyleManager.default

  private

    # One frame. The geometry is kept on the instance for the duration of the
    # draw so the primitives below take the shape they are drawing rather than
    # the centre they are drawing it around.
    def draw(context, width, height)
      @context = context
      @cx = width / 2.0
      @cy = height / 2.0
      @radius = [@cx, @cy].min - PADDING

      draw_track
      if arc_visible?
        draw_arc
      end
    end

    def draw_track
      stroke_circle(@radius, width: TRACK_WIDTH, color: track_color)
      if high_contrast?
        stroke_circle(@radius + BORDER_OFFSET, width: BORDER_WIDTH, color: border_color)
        stroke_circle(@radius - BORDER_OFFSET, width: BORDER_WIDTH, color: border_color)
      end
    end

    # Upstream skips the arc entirely when the countdown has hit zero, so the
    # ring does not flash red for the frame between the last tick and the
    # insensitive repaint.
    def arc_visible?
      area.sensitive? &&
        !(@counting_down && @remaining_time.zero?) &&
        (@remaining_time.positive? || @counting_down)
    end

    def draw_arc
      arc_angle.then do |angle|
        fill_pie(angle, fill_color)
        stroke_arc(@radius, to: angle, width: TRACK_WIDTH, color: opaque(line_color), cap: Cairo::LineCap::ROUND)
        if high_contrast?
          draw_arc_borders(angle)
        end
        draw_handle(angle)
      end
    end

    # The hairlines that trace the arc's outline: the filled wedge itself, the
    # two track-side edges, and the rounded cap where it starts at twelve
    # o'clock.
    def draw_arc_borders(angle)
      stroke_pie(angle)
      stroke_arc(@radius + BORDER_OFFSET, to: angle, width: BORDER_WIDTH, color: border_color)
      stroke_arc(@radius - BORDER_OFFSET, to: angle, width: BORDER_WIDTH, color: border_color)
      stroke_start_cap
    end

    # Upstream strokes the same path it filled, so the translucent wedge has an
    # edge against the track: `fullFillPath` — the plain circle, no radial
    # edges — once the arc has closed into a full ring, and `arcPath` — the
    # pie, both radial edges included — at every other angle.
    # Upstream: `internal/components/dial.go:421-422` and `:432-433`.
    # Port: `#stroke_pie`.
    def stroke_pie(angle)
      paint(border_color, BORDER_WIDTH)
      @context.new_path
      if full_ring?(angle)
        add_full_circle(@radius, nil)
      else
        @context.move_to(@cx, @cy)
        add_arc(radius: @radius, from: TOP, to: angle)
        @context.close_path
      end
      @context.stroke
    end

    # Upstream's `isFullCircle`: the arc's end has come back round to its
    # start, which for `#arc_angle` is exactly a full hour of remaining time.
    def full_ring?(angle) = angle >= TOP + TWO_PI

    # The cap at twelve o'clock, drawn counter-clockwise so it bulges to the
    # left of the arc's start rather than into the arc's own interior:
    # upstream's `SvgArcTo` carries sweep-flag 0, and in the y-down space both
    # Cairo and GSK use that is `arc_negative`.
    # Upstream: `internal/components/dial.go:457-458`.
    # Port: `#stroke_start_cap`.
    def stroke_start_cap
      paint(border_color, BORDER_WIDTH)
      @context.new_path
      add_arc(
        radius:   BORDER_OFFSET,
        from:     TOP,
        to:       TOP - Math::PI,
        cy:       @cy - @radius,
        negative: true,
      )
      @context.stroke
    end

    def draw_handle(angle)
      handle_center(angle).then do |(x, y)|
        fill_circle(HANDLE_RADIUS, color: line_color, at: [x, y])
        if high_contrast?
          stroke_circle(HANDLE_RADIUS, width: BORDER_WIDTH, color: border_color, at: [x, y])
        end
      end
    end

    def handle_center(angle)
      [@cx + (@radius * Math.cos(angle)), @cy + (@radius * Math.sin(angle))]
    end

    def arc_angle = TOP + (TWO_PI * (@remaining_time.to_f / StateMachine::MAX_INITIAL_REMAINING_TIME))

    # Cairo primitives, all of them drawing around @cx / @cy unless given an
    # explicit centre.

    def stroke_circle(radius, width:, color:, at: nil)
      paint(color, width)
      @context.new_path
      add_full_circle(radius, at)
      @context.stroke
    end

    def fill_circle(radius, color:, at: nil)
      paint(color)
      @context.new_path
      add_full_circle(radius, at)
      @context.fill
    end

    def stroke_arc(radius, to:, width:, color:, cap: Cairo::LineCap::BUTT)
      paint(color, width)
      @context.set_line_cap(cap)
      @context.new_path
      add_arc(radius: radius, from: TOP, to: to)
      @context.stroke
      @context.set_line_cap(Cairo::LineCap::BUTT)
    end

    def fill_pie(angle, color)
      paint(color)
      @context.new_path
      @context.move_to(@cx, @cy)
      add_arc(radius: @radius, from: TOP, to: angle)
      @context.close_path
      @context.fill
    end

    def paint(color, width = nil)
      @context.set_source_rgba(color)
      unless width.nil?
        @context.set_line_width(width)
      end
    end

    def add_full_circle(radius, at)
      Array(at).then do |center|
        if center.empty?
          add_arc(radius: radius, from: 0, to: TWO_PI)
        else
          add_arc(radius: radius, from: 0, to: TWO_PI, cx: center.first, cy: center.last)
        end
      end
    end

    # The one place Cairo's five-argument arc is called. `negative: true`
    # picks `arc_negative`, which sweeps from `from` down to `to` instead of up
    # to it — counter-clockwise on screen, where Cairo's own angles run
    # clockwise because y grows downwards.
    def add_arc(radius:, from:, to:, cx: nil, cy: nil, negative: false)
      (negative ? :arc_negative : :arc).then do |sweep|
        @context.public_send(
          sweep,
          cx || @cx,
          cy || @cy,
          radius,
          from,
          to,
        )
      end
    end

    # Colours

    # The colour as the theme gives it, alpha included. Only the arc's stroke
    # forces alpha 1.0, and it does so at the call site.
    def line_color
      if @counting_down
        theme_color('error_color', ERROR_FALLBACK)
      else
        theme_color('accent_bg_color', ACCENT_FALLBACK)
      end
    end

    def fill_color
      if @counting_down
        theme_color('error_color', ERROR_FALLBACK).then do |color|
          [color[0], color[1], color[2], COUNTING_DOWN_FILL_ALPHA]
        end
      else
        IDLE_FILL
      end
    end

    def track_color
      if area.sensitive?
        theme_track_color
      else
        disabled_track_color
      end
    end

    def theme_track_color
      if dark?
        TRACK_DARK
      else
        TRACK_LIGHT
      end
    end

    # The destructive colour composited over the window background at the
    # opacity libadwaita gives a disabled destructive button's text.
    def disabled_track_color
      theme_color('destructive_color', DESTRUCTIVE_FALLBACK).then do |destructive|
        theme_color('window_bg_color', WINDOW_BG_FALLBACK).then do |background|
          (DISABLED_OPACITY * destructive[3]).then do |alpha|
            [
              (destructive[0] * alpha) + (background[0] * (1 - alpha)),
              (destructive[1] * alpha) + (background[1] * (1 - alpha)),
              (destructive[2] * alpha) + (background[2] * (1 - alpha)),
              1.0,
            ]
          end
        end
      end
    end

    def border_color
      theme_color('window_fg_color', WINDOW_FG_FALLBACK).then do |color|
        [color[0], color[1], color[2], 0.5]
      end
    end

    def opaque(color) = [color[0], color[1], color[2], 1.0]

    # Gtk::StyleContext#lookup_color reports both whether the name resolved and
    # the colour it resolved to, and the bindings have been known to collapse
    # that into either shape, so both are accepted here.
    def theme_color(name, fallback)
      area.style_context.lookup_color(name).then do |result|
        if result.is_a?(Array)
          resolved_color(result, fallback)
        elsif result.nil?
          fallback
        else
          components(result)
        end
      end
    rescue StandardError
      fallback
    end

    def resolved_color(result, fallback)
      if result.first == false
        fallback
      else
        components(result.last)
      end
    end

    def components(rgba) = [rgba.red, rgba.green, rgba.blue, rgba.alpha]

    def dark? = style_manager.dark?
    def high_contrast? = style_manager.high_contrast?

    # Pointer position to duration

    def set_remaining_time_from_position(x, y)
      remaining_time_at(x, y).then do |seconds|
        unless seconds.nil?
          self.remaining_time = seconds
        end
      end
    end

    def remaining_time_at(x, y)
      [x - (area.width / 2.0), y - (area.height / 2.0)].then do |(dx, dy)|
        if Math.sqrt((dx * dx) + (dy * dy)) < DEAD_ZONE
          nil
        else
          intervals_at(dx, dy) * StateMachine::ADJUSTMENT_INTERVAL
        end
      end
    end

    def intervals_at(dx, dy)
      ((clockwise_angle(dx, dy) / TWO_PI) * INTERVAL_COUNT).to_i.then do |intervals|
        if intervals.zero?
          INTERVAL_COUNT
        else
          intervals
        end
      end
    end

    # The angle from twelve o'clock, growing clockwise, in 0...2π.
    def clockwise_angle(dx, dy)
      (Math.atan2(dy, dx) + (Math::PI / 2)).then do |angle|
        if angle.negative?
          angle + TWO_PI
        else
          angle
        end
      end
    end

    # Gtk::GestureDrag#start_point reports whether there is a start point along
    # with its coordinates; as with lookup_color, both shapes are accepted.
    def drag_origin(gesture)
      Array(gesture.start_point).then do |result|
        if result.size > 2
          resolved_origin(result)
        else
          result
        end
      end
    end

    def resolved_origin(result)
      if result.first == false
        nil
      else
        result.last(2)
      end
    end
end
