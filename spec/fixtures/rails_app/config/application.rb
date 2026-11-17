# frozen_string_literal: true

require_relative "boot"

module Dummy
  class Application < Rails::Application
    config.active_job.queue_adapter = :sidekiq
    config.cache_store = :mem_cache_store
  end
end
