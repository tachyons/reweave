# frozen_string_literal: true

require_relative "../../../reweave/recipe/scanning_recipe"

module Reweave
  module Recipes
    module Security
      # Verify and report on security patches applied by recipes
      class PatchVerification < ScanningRecipe
        display_name "Security Patch Verification"
        description "Verify security patches don't break tests and generate reports"

        option :run_tests, type: [TrueClass, FalseClass], default: true, description: "Run test suite after applying patches"
        option :test_command, type: String, default: "bundle exec rspec", description: "Command to run tests"
        option :generate_report, type: [TrueClass, FalseClass], default: true, description: "Generate verification report"

        def initial_accumulator
          {patches_applied: [], test_results: {}, verification_status: :pending}
        end

        def scan(source_file, accumulator, context)
          # Track which patches were applied to which files
          # This is called during the scanning phase
        end

        def generate(accumulator, project)
          return [] unless config[:generate_report]

          if config[:run_tests]
            accumulator[:test_results] = run_tests(project)
          end

          accumulator[:verification_status] = determine_status(accumulator[:test_results])

          content = generate_report(accumulator, project)

          [Reweave::Results::FileChange.new(
            path: File.join(project.root, "SECURITY_PATCH_VERIFICATION.md"),
            original_source: "",
            updated_source: content,
            recipes: [display_name],
            change_type: :created
          )]
        end

        private

        def run_tests(project)
          cmd = config[:test_command]
          Dir.chdir(project.root) do
            stdout, stderr, status = Open3.capture3(cmd)
            {
              success: status.success?,
              stdout: stdout,
              stderr: stderr,
              exit_code: status.exitstatus
            }
          end
        end

        def determine_status(test_results)
          return :passed if test_results[:success]
          :failed
        end

        def generate_report(accumulator, project)
          lines = []
          lines << "# Security Patch Verification Report"
          lines << ""
          lines << "Generated: #{Time.now.iso8601}"
          lines << "Project: #{File.basename(project.root)}"
          lines << ""

          lines << "## Verification Status"
          lines << ""
          lines << "**Status**: #{accumulator[:verification_status].to_s.upcase}"
          lines << ""

          if config[:run_tests]
            lines << "## Test Results"
            lines << ""
            test_results = accumulator[:test_results]
            lines << "- **Success**: #{test_results[:success] ? "Yes" : "No"}"
            lines << "- **Exit Code**: #{test_results[:exit_code]}" if test_results[:exit_code]
            lines << ""
            lines << "### STDOUT"
            lines << "```"
            lines << test_results[:stdout].lines.last(20).join
            lines << "```"
            lines << ""
            if test_results[:stderr] && !test_results[:stderr].empty?
              lines << "### STDERR"
              lines << "```"
              lines << test_results[:stderr].lines.last(20).join
              lines << "```"
              lines << ""
            end
          end

          lines << "## Patches Applied"
          lines << ""
          # This would be populated by the transformation recipes
          lines << "See individual recipe reports for details."
          lines << ""

          lines << "## Recommendations"
          lines << ""
          if accumulator[:verification_status] == :failed
            lines << "- ⚠️ Tests failed after applying patches. Review changes before deploying."
            lines << "- Run tests locally to identify failures."
            lines << "- Consider reverting patches that cause failures."
          else
            lines << "- ✅ All tests passed. Patches verified successfully."
            lines << "- Safe to deploy."
          end
          lines << ""

          lines.join("\n")
        end
      end
    end
  end
end
