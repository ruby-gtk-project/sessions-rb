# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of assets/resources/shortcuts-dialog.blp: two sections,
# "General" and "Timer", with the same seven items in the same order.
#
# Six of the seven carry an action name rather than a literal accelerator,
# exactly as upstream's blueprint does, so Adw.ShortcutsItem asks the
# application which accelerator is bound to that action and renders whatever
# `set_accels_for_action` was given. That is what keeps the dialog honest about
# three things a hardcoded string gets wrong: the modifier is shown the way the
# app registered it (`<Primary>`, which GTK renders as Ctrl), every accelerator
# bound to an action appears rather than only the first — `win.addTime` has two,
# `<Primary>plus` and `<Primary>equal` — and the row stays activatable, so
# clicking it triggers the action.
#
# "Open menu" keeps its literal "F10" because upstream gives it one: F10 is
# GTK's own menu accelerator and no action in this app is bound to it.
#
# The dialog's title is deliberately unset, as upstream leaves it, so
# libadwaita supplies its own already-translated heading.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  include Translations

  def initialize
    super()
  end

  # Memoized: the dialog is presented again on every shortcut press, and the
  # sections must not be appended a second time.
  def build
    @build ||= tap do |dialog|
      sections.each { |title, items| dialog.add(section(title, items)) }
    end
  end

  private

    # Each item is a title and the thing that resolves its accelerator: an
    # action name, or - for the one upstream spells out - a literal.
    def sections
      [
        [
          _('General'),
          [
            [_('Open menu'), accelerator: 'F10'],
            [_('Show keyboard shortcuts'), action: 'app.shortcuts'],
            [_('Close window'), action: 'win.closeWindow'],
            [_('Quit'), action: 'app.quit'],
          ],
        ],
        [
          _('Timer'),
          [
            [_('Start or stop timer'), action: 'win.toggleTimer'],
            [_('Add 30 seconds'), action: 'win.addTime'],
            [_('Remove 30 seconds'), action: 'win.removeTime'],
          ],
        ],
      ]
    end

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, resolver| section.add(item(label, **resolver)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8"
    # and "title: utf8, action_name: utf8". Passing them as keywords fails;
    # passing them positionally works, and because the two signatures are
    # indistinguishable by type the item is always constructed with an empty
    # accelerator and told its action name afterwards.
    def item(label, accelerator: '', action: nil)
      Adwaita::ShortcutsItem.new(label, accelerator).tap do |shortcut|
        unless action.nil?
          shortcut.action_name = action
        end
      end
    end
end
