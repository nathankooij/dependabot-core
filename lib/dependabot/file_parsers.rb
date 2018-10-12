# frozen_string_literal: true

require "dependabot/file_parsers/ruby/bundler"
require "dependabot/file_parsers/python/pip"
require "dependabot/file_parsers/java_script/npm_and_yarn"
require "dependabot/file_parsers/java/maven"
require "dependabot/file_parsers/java/gradle"
require "dependabot/file_parsers/php/composer"
require "dependabot/file_parsers/git/submodules"
require "dependabot/file_parsers/docker/docker"
require "dependabot/file_parsers/elixir/hex"
require "dependabot/file_parsers/rust/cargo"
require "dependabot/file_parsers/dotnet/nuget"
require "dependabot/file_parsers/go/dep"
require "dependabot/file_parsers/go/modules"
require "dependabot/file_parsers/elm/elm_package"
require "dependabot/file_parsers/terraform/terraform"

module Dependabot
  module FileParsers
    # rubocop:disable Metrics/CyclomaticComplexity
    def self.for_package_manager(package_manager)
      case package_manager
      when "bundler" then FileParsers::Ruby::Bundler
      when "npm_and_yarn" then FileParsers::JavaScript::NpmAndYarn
      when "maven" then FileParsers::Java::Maven
      when "gradle" then FileParsers::Java::Gradle
      when "pip" then FileParsers::Python::Pip
      when "composer" then FileParsers::Php::Composer
      when "submodules" then FileParsers::Git::Submodules
      when "docker" then FileParsers::Docker::Docker
      when "hex" then FileParsers::Elixir::Hex
      when "cargo" then FileParsers::Rust::Cargo
      when "nuget" then FileParsers::Dotnet::Nuget
      when "dep" then FileParsers::Go::Dep
      when "go_modules" then FileParsers::Go::Modules
      when "elm-package" then FileParsers::Elm::ElmPackage
      when "terraform" then FileParsers::Terraform::Terraform
      else raise "Unsupported package_manager #{package_manager}"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
