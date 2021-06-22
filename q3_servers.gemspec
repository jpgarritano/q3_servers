require_relative 'lib/q3_servers/version'

Gem::Specification.new do |spec|
  spec.name          = "q3_servers"
  spec.version       = Q3Servers::VERSION
  spec.authors       = ["Juan Pablo Garritano"]
  spec.email         = ["tuny22@gmail.com"]

  spec.summary       = "Browse servers from Quake3/Urban-Terror game"
  spec.homepage      = "https://github.com/jpgarritano/q3_servers"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jpgarritano/q3_servers"
  spec.metadata["changelog_uri"] = "https://github.com/jpgarritano/q3_servers"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
end
