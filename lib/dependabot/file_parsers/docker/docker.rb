# frozen_string_literal: true

require "docker_registry2"

require "dependabot/dependency"
require "dependabot/file_parsers/base"
require "dependabot/errors"

module Dependabot
  module FileParsers
    module Docker
      class Docker < Dependabot::FileParsers::Base
        require "dependabot/file_parsers/base/dependency_set"

        # Detials of Docker regular expressions is at
        # https://github.com/docker/distribution/blob/master/reference/regexp.go
        DOMAIN_COMPONENT = /(?:[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])/
        DOMAIN = /(?:#{DOMAIN_COMPONENT}(?:\.#{DOMAIN_COMPONENT})+)/
        REGISTRY = /(?<registry>#{DOMAIN}(?::[0-9]+)?)/

        NAME_COMPONENT = /(?:[a-z0-9]+(?:(?:[._]|__|[-]*)[a-z0-9]+)*)/
        IMAGE = %r{(?<image>#{NAME_COMPONENT}(?:/#{NAME_COMPONENT})*)}

        FROM = /[Ff][Rr][Oo][Mm]/
        TAG = /:(?<tag>[\w][\w.-]{0,127})/
        DIGEST = /@(?<digest>[^\s]+)/
        NAME = /\s+AS\s+(?<name>[a-zA-Z0-9_-]+)/
        FROM_LINE =
          %r{^#{FROM}\s+(#{REGISTRY}/)?#{IMAGE}#{TAG}?#{DIGEST}?#{NAME}?}

        def parse
          dependency_set = DependencySet.new

          dockerfiles.each do |dockerfile|
            dockerfile.content.each_line do |line|
              next unless FROM_LINE.match?(line)

              parsed_from_line = FROM_LINE.match(line).named_captures

              version = version_from(parsed_from_line)
              next unless version

              dependency_set << Dependency.new(
                name: parsed_from_line.fetch("image"),
                version: version,
                package_manager: "docker",
                requirements: [
                  requirement: nil,
                  groups: [],
                  file: dockerfile.name,
                  source: source_from(parsed_from_line)
                ]
              )
            end
          end

          dependency_set.dependencies
        end

        private

        def dockerfiles
          # The Docker file fetcher only fetches Dockerfiles, so no need to
          # filter here
          dependency_files
        end

        def version_from(parsed_from_line)
          return parsed_from_line.fetch("tag") if parsed_from_line.fetch("tag")

          version_from_digest(
            registry: parsed_from_line.fetch("registry"),
            image: parsed_from_line.fetch("image"),
            digest: parsed_from_line.fetch("digest")
          )
        end

        def source_from(parsed_from_line)
          source = {}

          if parsed_from_line.fetch("registry")
            source[:registry] = parsed_from_line.fetch("registry")
          end

          if parsed_from_line.fetch("tag")
            source[:tag] = parsed_from_line.fetch("tag")
          end

          if parsed_from_line.fetch("digest")
            source[:digest] = parsed_from_line.fetch("digest")
          end

          source
        end

        def version_from_digest(registry:, image:, digest:)
          return unless digest

          repo = image.split("/").count < 2 ? "library/#{image}" : image

          registry_client = docker_registry_client(registry)
          registry_client.tags(repo).fetch("tags").find do |tag|
            digest == registry_client.digest(repo, tag)
          rescue DockerRegistry2::NotFound
            # Shouldn't happen, but it does. Example of existing tag with
            # no manifest is "library/python", "2-windowsservercore".
            false
          end
        rescue DockerRegistry2::RegistryAuthenticationException
          raise if standard_registry?(registry)

          raise PrivateSourceAuthenticationFailure, registry
        end

        def docker_registry_client(registry)
          if registry
            credentials = registry_credentials(registry)

            DockerRegistry2::Registry.new(
              "https://#{registry}",
              user: credentials&.fetch("username"),
              password: credentials&.fetch("password")
            )
          else
            DockerRegistry2::Registry.new("https://registry.hub.docker.com")
          end
        end

        def registry_credentials(registry_url)
          credentials.
            select { |cred| cred["type"] == "docker_registry" }.
            find { |cred| cred["registry"] == registry_url }
        end

        def standard_registry?(registry)
          return true if registry.nil?

          registry == "registry.hub.docker.com"
        end

        def check_required_files
          # Just check if there are any files at all.
          return if dependency_files.any?

          raise "No Dockerfile!"
        end
      end
    end
  end
end
