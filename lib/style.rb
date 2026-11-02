# frozen_string_literal: true

require 'gtk4'

# Style is the app's stylesheet, ported verbatim from
# assets/resources/style.css.
#
# Upstream ships the CSS inside its GResource bundle, where libadwaita picks it
# up automatically as the application stylesheet. With no bundle, the port
# loads the same text into a Gtk::CssProvider and installs it on the default
# display at GTK_STYLE_PROVIDER_PRIORITY_APPLICATION, which is the priority
# libadwaita gives an application stylesheet it loads from a bundle.
#
# The `string:` keyword is checked, not assumed: both `load(string: ...)` and
# `load(data: ...)` are accepted by gtk4 4.3.9, and a provider loaded either
# way returns the parsed stylesheet from `#to_s`. `data:` is the spelling the
# bindings document, so that is the one used here. FINDINGS.md records the
# check.
#
# The three rules matter: `.boxed-list--opaque` makes the time readout's card
# fully opaque so the dial cannot show through it, `.dial__display` asks for
# tabular figures so the digits do not jitter as they count down, and
# `.dial__display--alarming` is the blink the label does once the session has
# finished — behind a prefers-reduced-motion query, so it simply does not
# animate for anyone who has asked for less motion.
#
class Style
  # GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
  PRIORITY = 600

  CSS = <<~CSS
    .boxed-list--opaque {
      /* Explictly set the background color since the default one is slightly transparent */
      background-color: var(--headerbar-bg-color);
    }

    .dial__display {
      font-feature-settings: "tnum";
    }

    @media (prefers-reduced-motion: no-preference) {
      @keyframes dial-display-alarm-blink {
        0%,
        49% {
          opacity: 1;
        }
        50%,
        99% {
          opacity: 0;
        }
        100% {
          opacity: 1;
        }
      }
      .dial__display--alarming {
        animation: dial-display-alarm-blink 1s linear infinite;
      }
    }
  CSS

  # The CSS class the window adds to the time label while the alarm rings.
  ALARMING_CLASS = 'dial__display--alarming'

  def self.install = new.install

  def install
    Gdk::Display.default.then do |display|
      unless display.nil?
        Gtk::StyleContext.add_provider_for_display(display, provider, PRIORITY)
      end
    end
  end

  def provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load(data: CSS)
    end
  end
end
