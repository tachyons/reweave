# frozen_string_literal: true

# Model lookups fixture: deprecated finders that ReplaceDeprecatedFind modernizes.
class UserManager
  def active_users
    User.find(:all)
  end

  def user_by_name(name)
    User.find_by_name(name)
  end
end
