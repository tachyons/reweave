# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "reweave"
  spec.version = "0.1.0"
  spec.authors = ["Reweave Contributors"]
  spec.email = ["reweave@example.com"]

  spec.summary = "Native Ruby source transformation framework inspired by OpenRewrite"
  spec.description = "Reweave is a Ruby-native framework for automated code refactoring, " \
                     "modernization, and large-scale source transformations using Prism parser."
  spec.homepage = "https://github.com/tachyons/reweave"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + Dir.glob("bin/*") + %w[README.md LICENSE]
  spec.bindir = "bin"
  spec.executables = ["reweave"]
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", "~> 2.1"
  spec.add_dependency "diffy", "~> 3.4"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "yard", "~> 0.9"
end
