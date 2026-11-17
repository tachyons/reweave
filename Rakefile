# frozen_string_literal: true

require "bundler/gem_tasks"

desc "Run Standard lint"
task :standard do
  sh "bundle exec standardrb"
end

# Load Reweave rake tasks
load File.expand_path("lib/reweave/tasks/reweave.rake", __dir__)
