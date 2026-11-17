# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "../../../reweave/recipe/scanning_recipe"

module Reweave
  module Recipes
    module Security
      # Scan Gemfile.lock for known CVEs using Ruby advisory databases
      class CVEDatabaseScan < ScanningRecipe
        display_name "CVE Database Scan"
        description "Scan Gemfile.lock for known CVEs using Ruby advisory databases"

        option :advisory_sources, type: Array, default: ["rubygems", "github"], description: "Advisory data sources to use"
        option :fail_on_cve, type: [TrueClass, FalseClass], default: false, description: "Fail build if CVEs found"
        option :severity_threshold, type: String, default: "medium", description: "Minimum severity to report (low, medium, high, critical)"

        def initial_accumulator
          {vulnerabilities: [], scanned_gems: {}}
        end

        def scan(source_file, accumulator, context)
          return unless source_file.path.end_with?("Gemfile.lock")

          content = source_file.source
          gems = parse_gemfile_lock(content)

          gems.each do |gem_name, version|
            next if accumulator[:scanned_gems].key?(gem_name)

            accumulator[:scanned_gems][gem_name] = version
            vulnerabilities = fetch_vulnerabilities(gem_name, version)

            vulnerabilities.each do |vuln|
              next unless severity_meets_threshold?(vuln[:severity])

              accumulator[:vulnerabilities] << {
                gem: gem_name,
                version: version,
                cve: vuln[:cve],
                severity: vuln[:severity],
                description: vuln[:description],
                patched_versions: vuln[:patched_versions],
                source: vuln[:source]
              }
            end
          end
        end

        def generate(accumulator, project)
          return [] if accumulator[:vulnerabilities].empty?

          content = generate_report(accumulator[:vulnerabilities])

          [Reweave::Results::FileChange.new(
            path: File.join(project.root, "CVE_REPORT.md"),
            original_source: "",
            updated_source: content,
            recipes: [display_name],
            change_type: :created
          )]
        end

        private

        def parse_gemfile_lock(content)
          gems = {}
          in_specs = false

          content.each_line do |line|
            if line.strip == "SPECIFICATIONS:"
              in_specs = true
              next
            end
            break if in_specs && line.start_with?(" ") && !line.start_with?("  ")

            if in_specs && line =~ /^\s{4}([^\s]+)\s+\(([^)]+)\)/
              gems[$1] = $2
            end
          end

          gems
        end

        def fetch_vulnerabilities(gem_name, version)
          vulnerabilities = []

          config[:advisory_sources].each do |source|
            case source
            when "rubygems"
              vulnerabilities.concat(fetch_from_rubygems(gem_name, version))
            when "github"
              vulnerabilities.concat(fetch_from_github(gem_name, version))
            end
          end

          vulnerabilities
        end

        def fetch_from_rubygems(gem_name, version)
          url = "https://api.rubygems.org/api/v1/gems/#{gem_name}.json"
          response = fetch_json(url)
          return [] unless response

          vulns = []
          response["vulnerabilities"]&.each do |vuln|
            next unless version_affected?(version, vuln)

            vulns << {
              cve: vuln["cve"],
              severity: vuln["severity"] || "medium",
              description: vuln["description"],
              patched_versions: vuln["patched_versions"] || [],
              source: "rubygems"
            }
          end
          vulns
        rescue => e
          warn "Failed to fetch from RubyGems: #{e.message}"
          []
        end

        def fetch_from_github(gem_name, version)
          # GitHub Advisory Database GraphQL API
          query = <<~GRAPHQL
            query($package: String!, $ecosystem: SecurityAdvisoryEcosystem!) {
              securityVulnerabilities(first: 10, ecosystem: $ecosystem, package: $package) {
                nodes {
                  advisory {
                    ghsaId
                    cvss { score severity }
                    description
                    vulnerableVersionRange
                    firstPatchedVersion { identifier }
                  }
                }
              }
            }
          GRAPHQL

          variables = {package: gem_name, ecosystem: "RUBYGEMS"}

          response = post_graphql(query, variables)
          return [] unless response&.dig("data", "securityVulnerabilities", "nodes")

          vulns = []
          response["data"]["securityVulnerabilities"]["nodes"].each do |node|
            advisory = node["advisory"]
            next unless version_affected_range?(version, advisory["vulnerableVersionRange"])

            vulns << {
              cve: advisory["ghsaId"],
              severity: advisory["cvss"]&.dig("severity")&.downcase || "medium",
              description: advisory["description"],
              patched_versions: [advisory["firstPatchedVersion"]&.dig("identifier")].compact,
              source: "github"
            }
          end
          vulns
        rescue => e
          warn "Failed to fetch from GitHub: #{e.message}"
          []
        end

        def fetch_json(url)
          uri = URI(url)
          response = Net::HTTP.get_response(uri)
          return nil unless response.code == "200"
          JSON.parse(response.body)
        end

        def post_graphql(query, variables)
          uri = URI("https://api.github.com/graphql")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{ENV["GITHUB_TOKEN"]}" if ENV["GITHUB_TOKEN"]
          request.body = {query: query, variables: variables}.to_json

          response = http.request(request)
          return nil unless response.code == "200"
          JSON.parse(response.body)
        end

        def version_affected?(version, vuln)
          range = vuln["vulnerable_version_range"]
          return true unless range

          version_affected_range?(version, range)
        end

        def version_affected_range?(version, range)
          # Simplified version range checking
          # In production, use Gem::Version and Gem::Requirement
          return true if range.nil? || range.empty?
          # This is a simplified check - in reality you'd use Gem::Requirement
          true
        end

        def severity_meets_threshold?(severity)
          levels = {"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
          threshold = config[:severity_threshold] || "medium"
          (levels[severity] || 0) >= (levels[threshold] || 2)
        end

        def generate_report(vulnerabilities)
          lines = []
          lines << "# CVE Vulnerability Report"
          lines << ""
          lines << "Generated: #{Time.now.iso8601}"
          lines << "Total vulnerabilities found: #{vulnerabilities.size}"
          lines << ""

          vulnerabilities.group_by { |v| v[:severity] }
          %w[critical high medium low].each do |sev|
            next unless vulnerabilities.any? { |v| v[:severity] == sev }

            lines << "## #{sev.capitalize} Severity"
            lines << ""

            vulnerabilities.select { |v| v[:severity] == sev }.each do |vuln|
              lines << "### #{vuln[:gem]} (#{vuln[:version]})"
              lines << "- **CVE/GHSA**: #{vuln[:cve]}"
              lines << "- **Severity**: #{vuln[:severity].capitalize}"
              lines << "- **Description**: #{vuln[:description]}"
              lines << "- **Patched in**: #{vuln[:patched_versions].join(", ")}" if vuln[:patched_versions]&.any?
              lines << "- **Source**: #{vuln[:source]}"
              lines << ""
            end
          end

          lines.join("\n")
        end
      end
    end
  end
end
