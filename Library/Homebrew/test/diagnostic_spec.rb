# typed: strict
# frozen_string_literal: true

require "diagnostic"
require "install"

RSpec.describe Homebrew::Diagnostic do
  before do
    allow(described_class).to receive(:support_findings).and_return([])
  end

  it "reports only the least supported tier after all checks" do
    checks = instance_double(Homebrew::Diagnostic::Checks,
                             supported_configuration_checks: ["check_access_directories"],
                             check_access_directories:       [
                               Homebrew::Diagnostic::Finding.new("First warning", tier: 2),
                               Homebrew::Diagnostic::Finding.new("Second warning", tier: 3),
                             ])
    allow(Homebrew::Diagnostic::Checks).to receive(:new).and_return(checks)

    expect do
      described_class.checks(:supported_configuration_checks, fatal: false)
      described_class.report_support_tier
      described_class.report_support_tier
    end.to output(<<~EOS).to_stderr
      Warning: First warning
      Warning: Second warning

      #{Homebrew::Diagnostic::Finding.support_tier_message(
        [Homebrew::Diagnostic::Finding.new("Second warning", tier: 3)],
      )&.chomp}
    EOS
  end

  it "includes a custom compiler in the final tier without repeating the tier warning" do
    expect do
      Homebrew::Install.check_cc_argv("clang")
      described_class.support_findings << Homebrew::Diagnostic::Finding.new("Tier 2 warning", tier: 2)
      described_class.report_support_tier
    end.to output(<<~EOS).to_stderr
      Warning: You passed `--cc=clang`.

      #{Homebrew::Diagnostic::Finding.support_tier_message(
        [Homebrew::Diagnostic::Finding.new("You passed `--cc=clang`.", tier: 3)],
      )&.chomp}
    EOS
  end

  it "reports the final tier on exit without depending on brew.rb" do
    _, stderr, status = Open3.capture3(
      *HOMEBREW_RUBY_EXEC_ARGS,
      "-I", $LOAD_PATH.join(File::PATH_SEPARATOR),
      "-rglobal", "-rdiagnostic",
      "-e", "diagnostic = Homebrew::Diagnostic",
      "-e", "diagnostic.support_findings.concat([2, 3, 2].map { diagnostic::Finding.new(it.to_s, tier: it) })",
      "-e", 'abort "command failed"'
    )

    expect([stderr.scan(/^This is a Tier \d configuration:\n- \d/), status.exitstatus])
      .to eq([["This is a Tier 3 configuration:\n- 3"], 1])
  end
end
