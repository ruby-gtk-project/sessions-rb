# frozen_string_literal: true

# Builds the Qt frontend, loads its QML and looks at what came out.
#
#   nix develop --command xvfb-run -a ruby test/drive_qt.rb
#   nix develop --command rake drive:qt
#
# This does not use test/gtk_driver.rb: that harness runs its steps off
# GLib::Timeout inside a Gtk::Application's main loop, and there is no GTK
# anything here. It needs much less, too. QML object creation is synchronous —
# `QQmlApplicationEngine#load` of a document whose root is an object
# declaration has built the whole tree by the time it returns — so the tree can
# be read straight after `build` with no loop running.
#
# What is worth asserting is exactly what upstream's qt/main.qml declares and
# nothing more. The three buttons have no `onClicked` upstream and none here,
# so there is no behaviour to drive; what can go wrong is the part a reading of
# the source cannot see:
#
#   * `import org.kde.kirigami` resolving. A missing QML module does not raise
#     — `load` reports the error to stderr and leaves `root_objects` empty — so
#     a Kirigami that is not on QML_IMPORT_PATH looks exactly like a frontend
#     that was never written.
#   * the QPA platform plugin loading, which is what makes the difference
#     between a Plasma user running this and a process that exits at startup.
#     The last step runs the real event loop and shows the window.
#   * the state machine reaching the Qt process at all, with the five minutes
#     and the three triggers upstream's `FlushPermittedTriggers` announces.

require 'tmpdir'

# Qt Quick asks for an OpenGL context at window-creation time; Xvfb has no GLX,
# so the scene graph's software backend is what renders here. Upstream's own
# CI never runs this frontend at all, so there is no upstream setting to match.
ENV['QT_QUICK_BACKEND'] ||= 'software'
ENV['QT_QPA_PLATFORM'] ||= 'xcb'
# Qt writes its per-user configuration under XDG_CONFIG_HOME; a driver must not
# leave anything in the real one.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('sessions-drive-qt')
# Kirigami's desktop style reads a KDE colour scheme if one is configured; a
# driver asserts on the object tree and not on colours, and an absent runtime
# directory makes Qt complain on stderr about a path it then does not use.
ENV['XDG_RUNTIME_DIR'] ||= Dir.mktmpdir('sessions-drive-qt-runtime')

require_relative '../lib/sessions/qt'

CHECKS = []

def check(description)
  yield.then do |ok|
    puts(ok ? "    ok   #{description}" : "    FAIL #{description}")
    CHECKS << [description, ok]
    ok
  end
rescue StandardError => e
  puts "    FAIL #{description} (#{e.class}: #{e.message})"
  CHECKS << [description, false]
  false
end

def step(name)
  puts name
  yield
rescue StandardError => e
  puts "    ERROR #{e.class}: #{e.message}"
  puts "      #{e.backtrace.first(3).join("\n      ")}"
  CHECKS << [name, false]
end

# A QObject property comes back as a QVariant; `#value` unwraps it, and a
# QString unwraps to a QString rather than to a Ruby String.
def prop(object, name)
  object.property(name).value.then do |value|
    value.nil? ? nil : value.to_s
  end
end

# Every QObject under `object`, in tree order. QML `id:` is not `objectName`,
# so `find_child` cannot see any of upstream's four ids — and giving them
# object names would mean editing a file that is upstream's byte for byte.
def descendants(object, found = [])
  object.children.each do |child|
    found << child
    descendants(child, found)
  end
  found
end

app = Sessions::QtApplication.new

step('[0] build the application and load data/qt/main.qml') do
  app.build

  check('the QML document produced exactly one root object') do
    app.engine.root_objects.length == 1
  end
end

window = app.engine.root_objects.first
tree = [window].compact.flat_map { |root| [root] + descendants(root) }

step('[1] the window qt/main.qml declares') do
  check('the root object is a QQuickWindow') { window.inherits('QQuickWindow') }

  # `Kirigami.ApplicationWindow` is a subclass of QtQuick.Controls'
  # ApplicationWindow, which is a QQuickApplicationWindow; if the Kirigami
  # import had failed the root object would not exist at all.
  check('the root object is an ApplicationWindow') do
    window.inherits('QQuickApplicationWindow')
  end

  check('title is "Sessions"') { prop(window, 'title') == 'Sessions' }
  check('width is 360') { window.property('width').value.to_i == 360 }
  check('height is 360') { window.property('height').value.to_i == 360 }
end

step('[2] the four controls in the ColumnLayout') do
  tree.filter_map { |object| prop(object, 'text') }.reject(&:empty?).then do |texts|
    check('the analog time label reads "05:00"') { texts.include?('05:00') }
    check('the minus button reads "Remove 30 seconds"') do
      texts.include?('Remove 30 seconds')
    end
    check('the action button reads "Start Timer"') { texts.include?('Start Timer') }
    check('the plus button reads "Add 30 seconds"') do
      texts.include?('Add 30 seconds')
    end

    # Upstream's QML holds no other text, and a frontend that had grown real
    # buttons would show it here first.
    check('no other text is on screen') { texts.uniq.length == 4 }
  end
end

step('[3] three buttons and one label, which is all qt/main.qml declares') do
  check('three buttons') do
    tree.count { |object| object.inherits('QQuickAbstractButton') } == 3
  end

  check('one label') { tree.count { |object| object.inherits('QQuickLabel') } == 1 }

  # ColumnLayout and RowLayout are both QQuickLinearLayout in C++; what the
  # QML names is the subclass, and `inherits` sees the base.
  check('they are laid out in a QtQuick.Layouts linear layout') do
    tree.any? { |object| object.inherits('QQuickLinearLayout') }
  end
end

step('[4] the state machine qt/main.go builds') do
  check('five minutes, as time.Minute*5') do
    app.machine.initial_remaining_time == 300
  end

  check('the machine starts stopped') { app.machine.state == StateMachine::STOPPED }

  # What upstream's `FlushPermittedTriggers` announces into its seven no-op
  # hooks, and the one thing in this frontend that is the real brain rather
  # than a label.
  check('plusTimer, minusTimer, startDragging and startTimer are permitted') do
    app.machine.permitted_triggers.sort == [
      StateMachine::MINUS_TIMER,
      StateMachine::PLUS_TIMER,
      StateMachine::START_DRAGGING,
      StateMachine::START_TIMER,
    ].sort
  end
end

step('[5] show the window and run the real event loop') do
  window.set_property('visible', RubyQt6::QtCore::QVariant.new(true))

  # The loop has to actually spin for the QPA plugin to create a surface; a
  # quarter of a second is long enough for Xvfb to map the window and short
  # enough that a hung frontend is still a failure and not a stuck driver.
  RubyQt6::QtCore::QTimer.single_shot(250, app.qt_app, 'quit')

  check('the event loop ran and exited cleanly') { app.qt_app.exec.zero? }
  check('the window became visible') { window.property('visible').value == true }
end

puts
CHECKS.count { |(_, ok)| ok }.then do |passed|
  puts "#{passed} of #{CHECKS.length} checks passed"
  CHECKS.reject { |(_, ok)| ok }.each { |(description, _)| puts "  failed: #{description}" }
  (CHECKS.length - passed).then do |failed|
    puts(failed.zero? ? 'DRIVE OK' : "DRIVE FAILED (#{failed})")
    exit(failed.zero? ? 0 : 1)
  end
end
