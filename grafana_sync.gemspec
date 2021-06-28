require_relative 'lib/grafana_sync/version'

Gem::Specification.new do |spec|
  spec.name          = "grafana_sync"
  spec.version       = GrafanaSync::VERSION
  spec.authors       = ["Nikolay Epifanov", "Rustam Safin"]
  spec.email         = ["nik.epifanov@gmail.com"]
  spec.licenses      = ["MIT"]

  spec.summary       = "Syncs dashboards between Grafana instances."
  spec.description = <<-EOF
    Grafana HTTP API tool to fetch, diff and create/update dashboards to
    ease the burden of migrating changes between Grafana instances for each
    environment.
  EOF
  spec.homepage      = "https://github.com/staring-frog/grafana_sync"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(sample_repo|test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activesupport', '~> 6.0'
  spec.add_runtime_dependency 'methadone', '~> 2.0'
  spec.add_runtime_dependency 'http', '>= 4.0'
  spec.add_runtime_dependency 'httplog', '>= 1.4'
  spec.add_runtime_dependency 'diffy', '~> 3.3'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
end
