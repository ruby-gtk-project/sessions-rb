# frozen_string_literal: true

# Drives the dial's high-contrast branch: the six shapes lib/dial.rb draws only
# when `Adwaita::StyleManager#high_contrast?` answers true.
#
#   nix develop --command xvfb-run -a ruby test/drive_high_contrast.rb
#
# Written because that branch had never been executed by anything. The main
# window driver is 175 checks and not one of them turned high contrast on, so
# every verdict about the hairlines was a reading of the source — and two of
# the five rows read as parity were in fact defects: the filled wedge was never
# outlined at all, and the start cap's hairline was drawn clockwise, into the
# arc's own interior, instead of counter-clockwise as upstream draws it.
#
# `high-contrast` is a read-only AdwStyleManager property: it is whatever the
# session's a11y setting says, and setting it from Ruby raises. libadwaita's
# own override for it is the ADW_DEBUG_HIGH_CONTRAST environment variable,
# which AdwSettings reads when it initialises — so it is set here, before
# `require 'adwaita'`, and this is a driver of its own rather than a step in
# the main one.
ENV['ADW_DEBUG_HIGH_CONTRAST'] = '1'

require 'tmpdir'
require 'fileutils'
require 'cairo'

ENV['GSETTINGS_BACKEND'] = 'memory'
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('sessions-drive-hc-config')
ENV['SESSIONS_SCHEMA_DIR'] ||= File.expand_path('../data', __dir__)

require_relative '../lib/sessions'
require_relative 'gtk_driver'

Translations.install

SHOTS = File.expand_path('../tmp/shots', __dir__)

# The dial draws through a plain Cairo context, so its own draw path can be
# pointed at an image surface and the pixels read back. This is the only way to
# tell a hairline that is there from one that is not: a screenshot shows it to
# a human, a pixel comparison shows it to the exit code.
SURFACE_SIZE = 260

def render_dial(dial)
  Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, SURFACE_SIZE, SURFACE_SIZE).tap do |surface|
    Cairo::Context.new(surface).then do |context|
      dial.send(
        :draw,
        context,
        SURFACE_SIZE,
        SURFACE_SIZE,
      )
    end
    surface.flush
  end
end

# ARGB32 is premultiplied and little-endian, so the bytes come back B, G, R, A.
# One row at a time rather than one pixel at a time: `Cairo::ImageSurface#data`
# hands back the whole buffer as a fresh String, and asking it for a quarter of
# a million individual pixels copies a quarter of a megabyte each time.
def rows_of(surface)
  surface.data.then do |data|
    (0...SURFACE_SIZE).map { |y| data.byteslice(y * surface.stride, SURFACE_SIZE * 4) }
  end
end

# Every pixel two renders of the same dial disagree on. The one shape under
# test is suppressed in the second render, so the disagreement *is* that
# shape's ink — wherever it ended up, and whatever was drawn over it
# afterwards. Which is the question the two defects turned on: not "is there a
# hairline somewhere" but "is it on the side upstream puts it on".
def ink_of(seconds, shape)
  [
    rows_of(render_dial(dial_at(seconds))),
    rows_of(render_dial(dial_at(seconds).tap { |dial| dial.define_singleton_method(shape) { |*_| nil } })),
  ].then do |(with_shape, without_shape)|
    with_shape.zip(without_shape).each_with_index.flat_map do |(drawn, skipped), y|
      if drawn == skipped
        []
      else
        (0...SURFACE_SIZE).filter_map do |x|
          if drawn.byteslice(x * 4, 4) != skipped.byteslice(x * 4, 4)
            [x, y]
          end
        end
      end
    end
  end
end

# A dial of its own rather than the window's, so suppressing a shape in it
# cannot leave the running window half-drawn.
def dial_at(seconds)
  Dial.new.tap { |dial| dial.remaining_time = seconds }
end

settings = Settings.new
settings.last_position = 300

app = App.new(settings: settings)

GtkDriver.drive(app, shots: SHOTS) do |d, application|
  window = -> { application.main_window }

  d.window { window.call.window }

  d.step('the session is in high contrast, so the hairlines are live') do
    d.check('the style manager says high contrast') do
      Adwaita::StyleManager.default.high_contrast?
    end
    d.check('the dial agrees') { window.call.dial.send(:high_contrast?) }
    d.check('the border colour is the half-opaque window foreground') do
      window.call.dial.send(:border_color).last == 0.5
    end
    d.check('the dial starts at the restored five minutes') do
      window.call.dial.remaining_time == 300
    end
  end

  d.step('the idle dial has rendered with its outlines') { d.shot('hc-01-idle') }

  d.step('the countdown starts, so the wedge and arc turn red') do
    window.call.toggle_timer_action.activate(nil)
    d.check('the dial is counting down') { window.call.dial.counting_down? }
  end

  d.step('the counting-down dial has redrawn') { d.shot('hc-02-counting-down') }

  d.step('the arc is taken round to a full ring') do
    window.call.toggle_timer_action.activate(nil)
    until window.call.dial.remaining_time >= StateMachine::MAX_INITIAL_REMAINING_TIME
      window.call.add_time_action.activate(nil)
    end

    d.check('the dial is at the hour') do
      window.call.dial.remaining_time == StateMachine::MAX_INITIAL_REMAINING_TIME
    end
    d.check('the full-ring branch is the one the draw takes') do
      window.call.dial.then do |dial|
        dial.send(:full_ring?, dial.send(:arc_angle))
      end
    end
  end

  d.step('the full ring has redrawn') { d.shot('hc-03-full-ring') }

  d.step('the alarm goes off, which makes the dial insensitive') do
    window.call.state_machine.start_timer
    window.call.state_machine.send(:fire, StateMachine::TIMER_FINISHED)
    d.check('the dial went insensitive') { window.call.dial.area.sensitive? == false }
    d.check('so the arc is not drawn at all') { window.call.dial.send(:arc_visible?) == false }
  end

  d.step('the insensitive dial has redrawn, outlines and no arc') do
    d.shot('hc-04-alarming')
  end

  d.step('the alarm is dismissed and the dial walked back to a quarter ring') do
    window.call.state_machine.stop_alarming
    window.call.dial.remaining_time = 900
    d.check('the dial is at fifteen minutes') { window.call.dial.remaining_time == 900 }
    d.check('that is not the full-ring branch') do
      window.call.dial.then { |dial| !dial.send(:full_ring?, dial.send(:arc_angle)) }
    end
  end

  d.step('the quarter-ring dial has redrawn') { d.shot('hc-05-quarter-ring') }

  # The wedge: upstream strokes the path it filled, radial edges included, so
  # the translucent fill has an edge against the track. At a quarter ring the
  # two radial edges run due north and due east from the centre.
  # Upstream: `internal/components/dial.go:432-433`.
  d.step('the filled wedge is outlined, radial edges included') do
    ink_of(900, :stroke_pie).then do |ink|
      centre = SURFACE_SIZE / 2
      radius = centre - Dial::PADDING

      d.check('the wedge outline puts ink on the canvas at all') { ink.length > 200 }
      d.check('it reaches from the centre out to the rim') do
        ink.map(&:first).max >= (centre + radius) - Dial::TRACK_WIDTH
      end
      d.check('the northern radial edge is there') do
        ink.any? { |(x, y)| (x - centre).abs <= 1 && y.between?(centre - radius, centre - 20) }
      end
      d.check('the eastern radial edge is there') do
        ink.any? { |(x, y)| (y - centre).abs <= 1 && x.between?(centre + 20, centre + radius) }
      end
    end
  end

  # The start cap: upstream traces it with sweep-flag 0, which in the y-down
  # space both GSK and Cairo use bulges counter-clockwise — left of twelve
  # o'clock, away from the arc. The port drew it with an increasing angle,
  # which put it to the right, inside the arc it is supposed to be capping.
  # Upstream: `internal/components/dial.go:457-458`.
  d.step("the start cap bulges left of twelve o'clock, not into the arc") do
    ink_of(900, :stroke_start_cap).then do |ink|
      centre = SURFACE_SIZE / 2
      radius = centre - Dial::PADDING

      d.check('the cap puts ink on the canvas at all') { ink.length.positive? }
      d.check('every inked pixel is left of twelve') do
        ink.map(&:first).max < centre
      end
      d.check("none of it is to the right, in the arc's interior") do
        ink.none? { |(x, _y)| x > centre }
      end
      d.check('it is no wider than the five-pixel cap it traces') do
        ink.map(&:first).min >= centre - Dial::BORDER_OFFSET - 2
      end
      d.check('and it sits at the top of the dial, where the arc starts') do
        ink.map(&:last).minmax.then do |(top, bottom)|
          top >= centre - radius - Dial::BORDER_OFFSET - 2 &&
            bottom <= centre - radius + Dial::BORDER_OFFSET + 2
        end
      end
    end
  end

  d.step('the window closes') do
    window.call.close_window_action.activate(nil)
    d.check('the window is gone') { window.call.window.visible? == false }
  end
end
