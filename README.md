# ShegerPay Ruby SDK

[![Version](https://img.shields.io/badge/version-2.2.0-blue)](https://rubygems.org/gems/shegerpay)

Official Ruby SDK for [ShegerPay](https://shegerpay.com) — Ethiopian payment verification.

## Install

```sh
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
result = client.verify('FT26062K7WMY', amount: 1000, provider: 'cbe')
puts result[:verified]
```

## Docs

https://shegerpay.com/docs
