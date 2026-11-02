# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  unless error.message.include?("kettle")
    raise error
  end
end

# External RSpec & related config
#
# kettle-test is a development dependency, and the Nix gem bundle this port
# runs under does not contain it — so the suite that covers the port itself
# would be unrunnable in the dev shell if this require were unconditional.
# Rescued the same way kettle-soup-cover is above, and for the same reason:
# the harness helpers documented in spec/README.md are a convenience the
# port's own specs do not use, and a missing convenience is not a reason for
# zero examples to run.
begin
  require "kettle/test/rspec"
rescue LoadError => error
  unless error.message.include?("kettle")
    raise error
  end
end

# This library
require "sessions/rb"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
