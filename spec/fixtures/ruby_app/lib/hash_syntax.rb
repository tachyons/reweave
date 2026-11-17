# frozen_string_literal: true

# Legacy syntax fixture: hash rockets that DeclarativeModernizeSyntax converts.
module Legacy
  OPTIONS = { :a => 1, :b => 2 }

  def mapping
    { :x => OPTIONS[:a], :y => 2 }
  end
end
