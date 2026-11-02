# frozen_string_literal: true

require_relative "rb/version"

# `sessions/rb` is the gem-named entry point: the gem is published as
# `sessions-rb`, so `require "sessions/rb"` is the path a consumer and
# spec/spec_helper.rb reach for. Before this file existed, spec_helper.rb:26
# required it and every spec died of a LoadError before its first assertion.
#
# It deliberately loads only the version constant, and not the application.
# `require "sessions"` is what boots the app, and that pulls in gtk4 and
# adwaita, whose load calls gtk_init — which needs a display and aborts without
# one. Keeping that out of the default require is what lets the specs covering
# non-widget code (lib/state_machine.rb, lib/metainfo.rb) run with no display
# at all; a spec that drives widgets requires `sessions` itself.
module Sessions
  module Rb
  end
end
