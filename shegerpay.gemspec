# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'shegerpay'
  spec.version     = '2.2.1'
  spec.authors     = ['ShegerPay']
  spec.email       = ['support@shegerpay.com']

  spec.summary     = 'Official Ruby SDK for the ShegerPay Payment Verification Gateway'
  spec.description = 'Verify Ethiopian bank and mobile-money payments (CBE, Telebirr, BOA and more), ' \
                     'manage payment links, promo codes, refunds and webhooks through the ShegerPay API.'
  spec.homepage    = 'https://shegerpay.com'
  spec.license     = 'MIT'

  spec.files         = ['shegerpay.rb']
  spec.require_paths = ['.']

  spec.required_ruby_version = '>= 3.0'

  spec.metadata = {
    'homepage_uri' => 'https://shegerpay.com',
    'source_code_uri' => 'https://github.com/shegerpay/sdk-ruby',
    'documentation_uri' => 'https://api.shegerpay.com/docs'
  }
end
