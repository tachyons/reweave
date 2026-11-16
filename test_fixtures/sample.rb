# frozen_string_literal: true

# This is a comment
class User < ApplicationRecord
  include ActiveModel::Validations

  def initialize(name, email = "default@example.com")
    @name = name
    @email = email
  end

  def greet
    puts "Hello, #{@name}!"
  end

  def self.find_by_email(email)
    where(email: email).first
  end
end

users = [User.new("Alice"), User.new("Bob")]

users.each do |user|
  user.greet
end

if users.any?
  puts "Total: #{users.count}"
else
  puts "No users"
end

config = {
  adapter: :solid_queue,
  cache: :solid_cache,
  timeout: 30
}