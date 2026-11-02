# frozen_string_literal: true

require 'qt6/qtwidgets'
require 'qt6/qtquick'
require 'qt6/qtquickcontrols2'

require_relative 'resources'
require_relative 'state_machine'

# QtApp is the second frontend: the same timer brain behind a Qt Quick /
# Kirigami window instead of a GTK4 / Libadwaita one.
#
# Ported from qt/main.go, which is upstream's own second frontend and 46 lines
# long. It is a skeleton, and this port is a skeleton of the same shape,
# because the shape is the spec. Upstream's file does exactly four things:
#
#   1. `qt6.NewQApplication(os.Args)`              → RubyQt6's QApplication
#   2. `qml.NewQQmlApplicationEngine()` + `Load`   → QQmlApplicationEngine#load
#   3. `state.NewStateMachine(ctx, time.Minute*5, log, &state.Hooks{...})`
#      with all seven hook fields written `func(...) error { return nil }`
#   4. `s.FlushPermittedTriggers(ctx)` and `qt6.QApplication_Exec()`
#
# Nothing in qt/main.qml is bound to the machine: the three buttons carry no
# `onClicked`, the label's text is the literal `"05:00"`, and the seven hooks
# are empty, so firing a trigger would change nothing a viewer could see. That
# is upstream's state of this frontend at ad77fb2, and `data/qt/main.qml` is
# upstream's file byte for byte. A reader comparing the two frontends should
# come away knowing the GTK one is the finished app and this one is the
# beginning of a second.
#
# `StateMachine#initialize` takes `hooks:` as a hash and calls through `&.call`,
# so a hash without a key behaves exactly like upstream's `return nil` field:
# the no-op is the default and seven empty lambdas would only be seven lines
# claiming to do something. `#flush_permitted_triggers` is still called, at the
# same point upstream calls it, and `#machine` is public so a driver can read
# the state it announced.
#
# The machine's beat is `lib/ticker.rb`, a `GLib::Timeout`, which belongs to a
# GLib main loop and not to Qt's. Nothing here starts the countdown — no
# trigger is ever fired — so no beat is ever scheduled; wiring the QML up to
# the machine means handing `StateMachine.new` a ticker built on `QTimer`,
# which is the seam `ticker:` exists for.
#
class QtApp
  def build
    qt_app.tap do
      engine.tap { |e| e.load(qml_url) }

      machine.flush_permitted_triggers
    end
  end

  # Upstream's `qt6.NewQApplication(os.Args)` is QtWidgets' QApplication, not
  # QGuiApplication: Kirigami's default desktop style draws its controls
  # through QStyle, which only a QApplication installs.
  def qt_app = @qt_app ||= RubyQt6::QtWidgets::QApplication.new
  def engine = @engine ||= RubyQt6::QtQml::QQmlApplicationEngine.new
  def qml_url = @qml_url ||= RubyQt6::QtCore::QUrl.from_local_file(Resources::QML_MAIN_PATH)

  # Upstream writes the initial remaining time out as `time.Minute*5` here
  # rather than reading `state.DefaultInitialRemainingTime`, which holds the
  # same five minutes; the constant is named on this side so the two frontends
  # cannot drift apart silently.
  def machine = @machine ||= StateMachine.new(remaining_time: StateMachine::DEFAULT_INITIAL_REMAINING_TIME)
end
