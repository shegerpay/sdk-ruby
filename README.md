<p align="center"><img src="logo.png" alt="ShegerPay" width="200" /></p>

# ShegerPay Ruby SDK

[![Version](https://img.shields.io/badge/version-2.2.0-blue)](https://rubygems.org/gems/shegerpay)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Official Ruby SDK for ShegerPay — verify Ethiopian bank payments (CBE, Telebirr, BOA, Awash).

## Install

```bash
gem install shegerpay
```

Or add to your Gemfile:

```ruby
gem 'shegerpay', '~> 2.2'
```

## Quick Start

```ruby
require 'shegerpay'

client = ShegerPay::Client.new('sk_live_YOUR_API_KEY')

# Verify a payment
result = client.verify('FT26062K7WMY', amount: 1000, provider: 'cbe')
puts result[:verified]  # true/false

# Verify without amount (lookup only)
result2 = client.verify('FT26062K7WMY', provider: 'telebirr')
puts result2[:status]

# Verify from receipt screenshot
image = Base64.encode64(File.read('receipt.png'))
img_result = client.verify_image(image: image, provider: 'cbe')
puts img_result[:verified]

# Create payment link
link = client.create_payment_link(title: 'Order #1234', amount: 1500, currency: 'ETB')
puts link['url']

# Webhook signature check
valid = ShegerPay::Client.verify_webhook_signature(payload, signature, secret)
```

## Supported Providers
`cbe` · `telebirr` · `boa` · `awash` · `ebirr_kaafi` · `ebirr_coop`

## Requirements
- Ruby 2.7+


## Support
- 📚 Docs: https://shegerpay.com/docs
- 💬 Telegram: [@shegerpay_0](https://t.me/shegerpay_0)
- 📧 Email: support@shegerpay.com
