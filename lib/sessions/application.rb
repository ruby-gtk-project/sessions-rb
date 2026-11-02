# frozen_string_literal: true

require_relative '../application'

module Sessions
  # The port's classes live one per upstream source file at the top of lib/,
  # which is the house shape the pilot port set. This is the gem-facing name
  # exe/sessions boots; the implementation is lib/application.rb.
  Application = ::App
end
