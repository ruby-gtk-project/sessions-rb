# frozen_string_literal: true

require 'gio2'

# MainMenu is the header bar's primary menu, ported from the `menu main_menu`
# block at the bottom of assets/resources/window.blp.
#
# One section with two items, both pointing at application-scoped actions that
# lib/application.rb installs. The underscores are mnemonics, which GMenu picks
# up from the label itself.
#
class MainMenu
  ITEMS = [
    ['_Keyboard Shortcuts', 'app.shortcuts'],
    ['_About Sessions', 'app.openAbout'],
  ].freeze

  def build
    menu.tap do |m|
      m.append_section(nil, section)

      section.tap do |s|
        ITEMS.each { |label, action| s.append(label, action) }
      end
    end
  end

  def menu = @menu ||= Gio::Menu.new
  def section = @section ||= Gio::Menu.new
end
