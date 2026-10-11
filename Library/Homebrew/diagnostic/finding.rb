# typed: strict
# frozen_string_literal: true

require "utils/output"

module Homebrew
  # Module containing diagnostic checks.
  module Diagnostic
    extend Utils::Output::Mixin

    class Finding
      class Remediation
        sig { returns(String) }
        attr_accessor :text

        sig { returns(T::Array[String]) }
        attr_reader :commands

        sig { params(commands: T::Array[String], text: String).void }
        def initialize(commands: [], text: "")
          @commands = commands
          @text = text
        end

        sig { returns(String) }
        def to_s
          return "" if @commands.empty? && @text.empty?

          @text.presence || "You can solve this by running:\n  #{@commands.join("\n  ")}"
        end

        sig { returns(T::Hash[Symbol, T.any(String, T::Array[String])]) }
        def to_h
          { commands:, text: }
        end
      end

      sig { returns(String) }
      attr_reader :text

      sig { returns(T.any(Integer, Symbol)) }
      attr_reader :tier

      sig { returns(T::Array[String]) }
      attr_reader :affects

      sig { returns(T::Array[String]) }
      attr_reader :links

      sig { returns(T.nilable(Remediation)) }
      attr_reader :remediation

      sig { params(text: String, tier: T.any(Integer, Symbol), affects: T::Array[String], links: T::Array[String], remediation: T.any(T.nilable(Remediation), String)).void }
      def initialize(text, tier: 1, affects: [], links: [], remediation: nil)
        @text = text
        @tier = tier
        @affects = affects
        @links = links
        @remediation ||= T.let(
          if remediation.is_a?(String)
            Remediation.new(text: remediation)
          else
            remediation
          end,
          T.nilable(Homebrew::Diagnostic::Finding::Remediation),
        )
      end

      sig {
        returns(T::Hash[Symbol,
                        T.any(Integer, Symbol, String, T::Array[String], T.nilable(T::Hash[Symbol, T.any(String, T::Array[String])]))])
      }
      def to_h
        {
          text:,
          tier:,
          affects:,
          links:,
          remediation: @remediation&.to_h,
        }
      end

      sig { returns(String) }
      def to_s
        <<~EOS.rstrip
          #{text}
          #{remediation.to_s.strip}
        EOS
      end

      sig { params(tiers: T::Array[T.any(Integer, Symbol)]).returns(T.any(Integer, Symbol)) }
      def self.support_tier(tiers)
        return :unsupported if tiers.include?(:unsupported)

        tiers.grep(Integer).max || 1
      end

      sig { params(findings: T::Array[Finding]).returns(T.nilable(String)) }
      def self.support_tier_message(findings)
        tier = support_tier(findings.map(&:tier))
        return if tier == 1

        tier_title, tier_slug, tier_issues = if tier == :unsupported
          ["an Unsupported", "unsupported", "Do not report any issues"]
        else
          ["a Tier #{tier}", "tier-#{tier}", "You can report issues with Tier #{tier} configurations"]
        end

        tier_issues = "Report issues to the upstream Nix project, not" if OS.nix_managed_homebrew?

        [
          "This is #{tier_title} configuration:",
          *findings.select { it.tier == tier }.map { "- #{it.text.partition("\n\n").first.split.join(" ")}" }.uniq,
          Formatter.bold("#{tier_issues} to Homebrew/* repositories!"),
          "Read the following before opening any issues or PRs:",
          "  #{Formatter.url("https://docs.brew.sh/Support-Tiers##{tier_slug}")}",
          *("  #{Formatter.url(OS::ISSUES_URL)}" if defined?(OS::ISSUES_URL)),
        ].join("\n")
      end
    end
  end
end
