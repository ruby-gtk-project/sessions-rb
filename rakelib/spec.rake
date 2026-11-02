# frozen_string_literal: true

# The three runners this port has, as rake targets.
#
# Upstream's equivalent is `go test ./pkg/state/`, one command named in its
# README and run by .github/workflows on every push. This port had three
# runners and no target for any of them: `rake -T` in the dev shell listed
# seventeen tasks and not one of them was spec, test or drive, so the suite was
# reachable only by typing an rspec invocation by hand — and the invocation the
# docs gave did not work.
#
# The specs are defined only when nothing else has: kettle-dev's rake tasks
# define `spec` too, and in a bundle that has them theirs is the one that knows
# about coverage and appraisals. The dev shell does not have them, which is
# where this definition matters.

DRIVERS = {
  main_window:   "test/drive_main_window.rb",
  translations:  "test/drive_translations.rb",
  high_contrast: "test/drive_high_contrast.rb",
}.freeze

# Every driver needs a display and a compiled schema: `require "gtk4"` raises
# Gtk::InitError with no display, and lib/settings.rb looks for
# data/gschemas.compiled before it will build a Gio::Settings from a checkout.
def drive(script)
  sh(
    "xvfb-run",
    "-a",
    RbConfig.ruby,
    script,
  )
end

# RUBYOPT is cleared because rake itself is run out of a bundle in the dev
# shell: bundler puts `-rbundler/setup` in RUBYOPT, the child ruby inherits it,
# and rspec's binstub then refuses to start because rspec-core is not in a
# bundle that does not exist. The suite runs through bin/rspec so that the rake
# target, the dev shell banner and .gitlab-ci.yml all name the same runner.
unless Rake::Task.task_defined?("spec")
  desc "Run the RSpec suite (no display needed)"
  task spec: "schema:compile" do
    sh(
      { "RUBYOPT" => nil },
      RbConfig.ruby,
      File.join("bin", "rspec"),
      "spec",
    )
  end
end

unless Rake::Task.task_defined?("test")
  desc "Run the RSpec suite"
  task test: "spec"
end

namespace :drive do
  DRIVERS.each do |name, script|
    desc "Drive #{script} headlessly under Xvfb"
    task name => "schema:compile" do
      drive(script)
    end
  end
end

desc "Run every UI driver headlessly under Xvfb"
task drive: DRIVERS.keys.map { |name| "drive:#{name}" }

desc "Run the specs and every driver"
task check: ["spec", "drive"]
