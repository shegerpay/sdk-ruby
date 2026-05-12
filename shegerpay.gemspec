Gem::Specification.new do |spec|
  spec.name          = "shegerpay"
  spec.version       = "2.2.0"
  spec.authors       = ["ShegerPay"]
  spec.email         = ["developers@shegerpay.com"]

  spec.summary       = "Official Ruby SDK for ShegerPay — Ethiopian payment verification"
  spec.description   = "Ruby client library for the ShegerPay payment verification API."
  spec.homepage      = "https://shegerpay.com"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "net-http", ">= 0.1"
  spec.add_dependency "json", ">= 2.0"
end
