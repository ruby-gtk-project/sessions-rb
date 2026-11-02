# frozen_string_literal: true

require 'gio2'

require_relative 'translations'

# MainMenu is the header bar's primary menu, ported from the `menu main_menu`
# block at the bottom of assets/resources/window.blp.
#
# One section with two items, both pointing at application-scoped actions that
# lib/application.rb installs. The underscores are mnemonics, and they are
# inside the translatable string because a translator picks a mnemonic that
# works in their language — which is also how upstream's blueprint marks them.
#
class MainMenu
  include Translations

  def build
    menu.tap do |m|
      m.append_section(nil, section)

      section.tap do |s|
        items.each { |label, action| s.append(label, action) }
      end
    end
  end

  def menu = @menu ||= Gio::Menu.new
  def section = @section ||= Gio::Menu.new

  private

    def items
      [
        [_('_Keyboard Shortcuts'), 'app.shortcuts'],
        [_('_About Sessions'), 'app.openAbout'],
      ]
    end
end
