# frozen_string_literal: true

# ActiveJob fixture with ordinary Ruby the semantic analyzer must survive:
# blocks, if/elsif/else, case, and self-returning methods.
class ReportJob < ApplicationJob
  queue_as :default

  def self.default_queue
    :default
  end

  def perform(user_id)
    user = User.find(user_id)
    case user.status
    when :active then render_report(user)
    when :banned then nil
    else
      user.each { |key, value| value.to_s }
      false
    end
  end

  def render_report(user)
    if user.nil?
      nil
    elsif user.empty?
      ""
    else
      user.first
    end
  end
end
