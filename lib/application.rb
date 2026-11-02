# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'main_window'
require_relative 'resources'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'style'

# App is the application object: the two application-scoped actions, their
# accelerators, and the window they belong to.
#
# Ported from internal/components/application.go together with the parts of
# main.go that set the app up. Upstream registers a GObject subclass of
# AdwApplication and overrides its activate vfunc; the bindings make
# Adwaita::Application unusable, so this is a Gtk::Application with Adwaita.init
# called first — every Adwaita widget inside it works normally.
#
# Upstream's activate handler returns early and presents the existing window on
# a second activation, which is what the memoized #activated_window does here:
# the actions are installed, the stylesheet loaded and the window built exactly
# once, however many times the app is activated. That matters because
# app.stopAlarmPlayback activates the app to bring the window back after a
# notification is clicked.
#
# `app.shortcuts` is an addition. Upstream binds an accelerator to it and its
# menu points at it, but nothing in the Go code installs it, so the shortcuts
# window that assets/resources/shortcuts-dialog.blp describes is unreachable;
# here the action presents it.
#
class App
  ACCELERATORS = {
    'app.shortcuts' => ['<Primary>question'],
    'app.quit'      => ['<Primary>q'],
  }.freeze

  def initialize(settings: nil)
    @settings = settings || Settings.new
  end

  def build
    app.tap do |a|
      a.signal_connect('activate') { activated_window.present }
    end
  end

  def run = app.run([])

  # Memoized widget methods

  def app
    @app ||= begin
      Adwaita.init
      Gtk::Application.new(Resources::APP_ID, :default_flags)
    end
  end

  def main_window = @main_window ||= MainWindow.new(app: app, settings: @settings)
  def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new
  def about_dialog = @about_dialog ||= AboutDialog.new

  # Actions

  def shortcuts_action = @shortcuts_action ||= Gio::SimpleAction.new('shortcuts', nil)
  def open_about_action = @open_about_action ||= Gio::SimpleAction.new('openAbout', nil)
  def quit_action = @quit_action ||= Gio::SimpleAction.new('quit', nil)

  def app_actions
    @app_actions ||= [shortcuts_action, open_about_action, quit_action]
  end

  private

    # Everything upstream's activate handler does, done once.
    def activated_window
      @activated_window ||= main_window.build.tap do |window|
        Style.install

        shortcuts_action.signal_connect('activate') { shortcuts_dialog.build.present(window) }
        open_about_action.signal_connect('activate') { about_dialog.build.present(window) }
        quit_action.signal_connect('activate') { app.quit }

        app_actions.each { |action| app.add_action(action) }
        ACCELERATORS.each { |name, accels| app.set_accels_for_action(name, accels) }
      end
    end
end
