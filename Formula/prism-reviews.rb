class PrismReviews < Formula
  desc "Expertise-based PR review routing with round-robin rotation"
  homepage "https://github.com/Tengoot/prism-reviews"
  url "https://github.com/Tengoot/prism-reviews.git", branch: "main"
  version "0.1.0"
  license "MIT"

  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec
    system "gem", "build", "prism_reviews.gemspec"
    system "gem", "install", "--no-document", "--install-dir", libexec,
           Dir["prism_reviews-*.gem"].first

    bin.install Dir["#{libexec}/bin/*"]
    bin.env_script_all_files(libexec/"bin", GEM_HOME: libexec)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/prism version")
  end
end
