# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of assets/resources/shortcuts-dialog.blp: two sections,
# "General" and "Timer", with the same seven items in the same order.
#
# Upstream names an action on most of its items and lets Adw.ShortcutsItem ask
# the application which accelerator is bound to it. The accelerators are spelled
# out here instead, because they are the same list lib/application.rb and
# lib/main_window.rb pass to set_accels_for_action and an item that resolves to
# nothing would render blank.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  SECTIONS = {
    'General' => [
      ['Open menu', 'F10'],
      ['Show keyboard shortcuts', '<Control>question'],
      ['Close window', '<Control>w'],
      ['Quit', '<Control>q'],
    ],
    'Timer'   => [
      ['Start or stop timer', '<Control>space'],
      ['Add 30 seconds', '<Control>plus'],
      ['Remove 30 seconds', '<Control>minus'],
    ],
  }.freeze

  def initialize
    super()
    self.title = 'Keyboard Shortcuts'
  end

  # Memoized: the dialog is presented again on every shortcut press, and the
  # sections must not be appended a second time.
  def build
    @build ||= tap do |dialog|
      SECTIONS.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, accelerator| section.add(item(label, accelerator)) }
      end
    end

  # Positional, not keyword, arguments — even though the error a no-argument
  # new raises advertises the signatures as "title: utf8, accelerator: utf8".
  # Passing them as keywords fails; passing them positionally works.
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
