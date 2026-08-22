# frozen_string_literal: true

# ShegerPay Ruby SDK
# Official Ruby SDK for ShegerPay Payment Verification Gateway
#
# @author ShegerPay <support@shegerpay.com>
# @version 2.2.1

require 'net/http'
require 'uri'
require 'json'
require 'openssl'

module ShegerPay
  VERSION = '2.2.1'
  
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ValidationError < Error; end
  
  # Verification result
  class VerificationResult
    attr_reader :verified, :valid, :status, :provider, :transaction_id, :amount, :reason, :mode
    
    def initialize(data)
      @verified = data['verified'] || data['valid'] || false
      @valid = data['valid'] || false
      @status = data['status'] || 'unknown'
      @provider = data['provider']
      @transaction_id = data['transaction_id']
      @amount = data['amount']
      @reason = data['reason']
      @mode = data['mode']
    end
    
    def valid?
      @valid
    end
  end
  
  # ShegerPay Payment Verification Client
  class Client
    DEFAULT_BASE_URL = 'https://api.shegerpay.com'
    
    # Create a new ShegerPay client
    #
    # @param api_key [String] Your secret API key (sk_test_xxx or sk_live_xxx)
    # @param options [Hash] Optional configuration
    def initialize(api_key, options = {})
      raise AuthenticationError, 'API key is required' if api_key.nil? || api_key.empty?
      
      unless api_key.start_with?('sk_test_', 'sk_live_')
        raise AuthenticationError, 'Invalid API key format'
      end
      
      @api_key = api_key
      @base_url = (options[:base_url] || DEFAULT_BASE_URL).chomp('/')
      @timeout = options[:timeout] || 30
      @mode = api_key.start_with?('sk_test_') ? 'test' : 'live'
    end
    
    # Verify a payment transaction
    #
    # @param params [Hash] Verification parameters
    # @return [VerificationResult]
    def verify(params)
      transaction_id = params[:transaction_id]
      amount = params[:amount]
      provider = params[:provider]
      merchant_name = params[:merchant_name] || 'ShegerPay Verification'
      sender_account = params[:sender_account]
      
      raise ValidationError, 'transaction_id is required' unless transaction_id
      raise ValidationError, 'amount is required' unless amount
      
      provider ||= transaction_id.downcase.include?('cs.bankofabyssinia.com/slip/?trx=') ? 'boa' : nil
      raise ValidationError, 'provider is required for ambiguous transaction references. Pass provider explicitly or use quick_verify.' unless provider
      
      data = {
        provider: provider,
        transaction_id: transaction_id,
        amount: amount,
        merchant_name: merchant_name
      }
      data[:sub_provider] = params[:sub_provider] if params[:sub_provider]
      data[:sender_account] = sender_account if sender_account
      
      response = request(:post, '/api/v1/verify', data)
      VerificationResult.new(response)
    end
    
    # Quick verification with auto-detected provider
    #
    # @param transaction_id [String] Bank transaction reference
    # @param amount [Float] Expected amount
    # transaction_id may be a typed reference OR a raw scanned-QR payload (decoded server-side).
    # @return [VerificationResult]
    def quick_verify(transaction_id, amount, expected_provider = nil, sender_account = nil)
      payload = {
        transaction_id: transaction_id,
        amount: amount
      }
      payload[:expected_provider] = expected_provider if expected_provider
      payload[:sender_account] = sender_account if sender_account
      response = request(:post, '/api/v1/quick-verify', payload)
      VerificationResult.new(response)
    end
    
    # Get transaction history
    #
    # @param limit [Integer] Maximum number of transactions
    # @return [Array]
    def history(limit = 50)
      request(:get, '/api/v1/history')
    end
    
    # Verify a payment from a receipt image/screenshot (or PDF).
    #
    # Works for ANY supported bank — the backend reads the receipt's QR code
    # (CBE, Telebirr, BOA…) or OCRs the reference and auto-detects the provider.
    # Just pass the image; no need to know the bank or pre-extract the reference.
    #
    # @param screenshot [String, IO] image/PDF bytes, an IO, or a path to a file
    # @param options [Hash] :amount, :provider, :transaction_id, :merchant_name, :sender_account
    # @return [VerificationResult]
    def verify_image(screenshot, options = {})
      if screenshot.respond_to?(:read)
        bytes = screenshot.read
        filename = 'receipt'
      elsif screenshot.is_a?(String) && screenshot.bytesize < 4096 && (File.file?(screenshot) rescue false)
        bytes = File.binread(screenshot)
        filename = File.basename(screenshot)
      else
        bytes = screenshot
        filename = 'receipt.png'
      end

      fields = {}
      [:amount, :provider, :transaction_id, :merchant_name, :sender_account].each do |k|
        fields[k] = options[k] unless options[k].nil?
      end

      data = request_multipart('/api/v1/verify-image', fields, 'screenshot', filename, bytes)
      VerificationResult.new(data)
    end

    # Create a shareable payment link
    #
    # @param title [String] Link title
    # @param amount [Float] Payment amount
    # @param options [Hash] Optional parameters
    # @return [Hash]
    def create_payment_link(title, amount, options = {})
      params = { title: title, amount: amount, currency: 'ETB' }
      params.merge!(options.select { |key, _| [
        :description, :enable_cbe, :enable_telebirr, :expires_in_hours,
        :amount_mode, :amount_options, :min_amount, :max_amount,
        :promo_code_ids, :payment_method_layout, :allow_quantity,
        :max_quantity, :business_name, :merchant_logo_url, :theme_color
      ].include?(key) })
      request_json(:post, '/api/v1/payment-links/', params)
    end

    # List all payment links for the account
    #
    # @return [Array]
    def list_payment_links
      # Trailing slash is required: the FastAPI route is defined as
      # GET /api/v1/payment-links/ and Net::HTTP does not follow the
      # 307 redirect the slash-less form would return.
      request(:get, '/api/v1/payment-links/')
    end

    # Delete a payment link by ID
    #
    # @param link_id [String]
    # @return [Hash]
    def delete_payment_link(link_id)
      request(:delete, "/api/v1/payment-links/#{link_id}")
    end

    def create_promo_code(params)
      request_json(:post, '/api/v1/promo-codes/', promo_payload(params))
    end

    def list_promo_codes
      request(:get, '/api/v1/promo-codes/')
    end

    def update_promo_code(code_id, params)
      request_json(:patch, "/api/v1/promo-codes/#{code_id}", promo_payload(params))
    end

    def delete_promo_code(code_id)
      request(:delete, "/api/v1/promo-codes/#{code_id}")
    end

    def validate_promo_code(params)
      request_json(:post, '/api/v1/promo-codes/validate', {
        code: params[:code],
        amount: params[:amount],
        link_id: params[:link_id],
        provider: params[:provider],
        customer_identifier: params[:customer_identifier]
      })
    end

    def redeem_promo_code(params)
      request_json(:post, '/api/v1/promo-codes/redeem', {
        code: params[:code],
        amount: params[:amount],
        link_id: params[:link_id],
        provider: params[:provider],
        customer_identifier: params[:customer_identifier],
        transaction_id: params[:transaction_id],
        order_id: params[:order_id],
        idempotency_key: params[:idempotency_key]
      })
    end

    def apply_payment_link_coupon(short_code, code, options = {})
      request_json(:post, "/api/v1/payment-links/#{short_code}/apply-coupon", {
        code: code,
        amount: options[:amount],
        quantity: options[:quantity] || 1,
        provider: options[:provider],
        customer_identifier: options[:customer_identifier]
      })
    end

    def get_payment_link_order_status(short_code, order_id)
      request(:get, "/api/v1/payment-links/#{short_code}/orders/#{order_id}/status")
    end

    # ============================================
    # MULTI-CURRENCY WALLET METHODS
    # ============================================

    # Get multi-currency wallet balances
    # @return [Hash]
    def get_wallet_balance
      request(:get, '/api/v1/paypal/wallet/balance')
    end

    # Get wallet transaction history
    # @param currency [String] Filter by currency
    # @param limit [Integer] Limit
    # @return [Array]
    def get_wallet_history(currency = nil, limit = 20)
      url = "/api/v1/wallets/transactions?limit=#{limit}"
      url += "&currency=#{currency}" if currency
      request(:get, url)
    end

    # ============================================
    # REFUND METHODS
    # ============================================

    # Request a refund
    # @param transaction_id [String]
    # @param amount [Float]
    # @param reason [String]
    # @return [Hash]
    def create_refund(transaction_id, amount = nil, reason = nil)
      data = { transaction_id: transaction_id }
      data[:amount] = amount if amount
      data[:reason] = reason if reason
      request(:post, '/api/v1/refunds/request', data)
    end

    # Get refund details
    # @param refund_id [String]
    # @return [Hash]
    def get_refund(refund_id)
      request(:get, "/api/v1/refunds/#{refund_id}")
    end

    # Approve a pending refund
    # @param refund_id [String]
    # @return [Hash]
    def approve_refund(refund_id)
      request(:post, "/api/v1/refunds/#{refund_id}/approve")
    end

    # Reject a pending refund
    # @param refund_id [String]
    # @param reason [String]
    # @return [Hash]
    def reject_refund(refund_id, reason)
      request(:post, "/api/v1/refunds/#{refund_id}/reject", { reason: reason })
    end

    # ============================================
    # DISPUTE METHODS
    # ============================================

    # List disputes
    # @param status [String]
    # @param limit [Integer]
    # @return [Array]
    def list_disputes(status = nil, limit = 20)
      url = "/api/v1/disputes?limit=#{limit}"
      url += "&status=#{status}" if status
      request(:get, url)
    end

    # Get dispute details
    # @param dispute_id [String]
    # @return [Hash]
    def get_dispute(dispute_id)
      request(:get, "/api/v1/disputes/#{dispute_id}")
    end

    # Respond to a dispute
    # @param dispute_id [String]
    # @param message [String]
    # @param evidence [Array]
    # @return [Hash]
    def respond_to_dispute(dispute_id, message, evidence = [])
      request(:post, "/api/v1/disputes/#{dispute_id}/respond", {
        message: message,
        evidence_urls: evidence
      })
    end

    # ============================================
    # ANALYTICS METHODS
    # ============================================

    def get_api_usage
      request(:get, '/api/v1/analytics/api-usage')
    end

    def get_webhook_logs(limit = 20)
      request(:get, "/api/v1/analytics/webhook-logs?limit=#{limit}")
    end

    # Verify webhook signature
    #
    # Constant-time comparison via OpenSSL.secure_compare — no Rack
    # dependency and no timing-unsafe fallback.
    #
    # @param payload [String] Raw request body
    # @param signature [String] X-ShegerPay-Signature header ("sha256=<hex>")
    # @param secret [String] Your webhook secret
    # @return [Boolean]
    def self.verify_webhook_signature(payload, signature, secret)
      expected = 'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
      OpenSSL.secure_compare(expected, signature.to_s)
    end
    
    private

    def promo_payload(params)
      {
        code: params[:code],
        discount_type: params[:discount_type] || 'percent',
        discount_value: params[:discount_value] || params[:discount_percent],
        discount_percent: params[:discount_percent],
        max_discount_amount: params[:max_discount_amount],
        min_order_amount: params[:min_order_amount],
        max_uses: params[:max_uses],
        max_uses_per_customer: params[:max_uses_per_customer],
        starts_at: params[:starts_at],
        expires_at: params[:expires_at],
        active: params[:active],
        applies_to_link_ids: params[:applies_to_link_ids],
        allowed_providers: params[:allowed_providers],
        metadata: params[:metadata]
      }.reject { |_, value| value.nil? }
    end

    def request_json(method, path, data = nil)
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      request = case method
                when :post then Net::HTTP::Post.new(uri)
                when :patch then Net::HTTP::Patch.new(uri)
                when :put then Net::HTTP::Put.new(uri)
                else Net::HTTP::Post.new(uri)
                end
      request.body = JSON.generate(data || {})
      request['Content-Type'] = 'application/json'
      request['X-API-Key'] = @api_key
      request['User-Agent'] = "ShegerPay-Ruby-SDK/#{VERSION}"
      response = http.request(request)
      case response.code.to_i
      when 401
        raise AuthenticationError, 'Invalid API key'
      when 400
        error = JSON.parse(response.body) rescue {}
        raise ValidationError, error['detail'] || 'Validation error'
      end
      JSON.parse(response.body) rescue {}
    end
    
    def request_multipart(path, fields, file_field, filename, file_bytes)
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      req = Net::HTTP::Post.new(uri)
      req['X-API-Key'] = @api_key
      req['User-Agent'] = "ShegerPay-Ruby-SDK/#{VERSION}"

      parts = fields.map { |k, v| [k.to_s, v.to_s] }
      parts << [file_field, file_bytes, { filename: filename, content_type: 'application/octet-stream' }]
      req.set_form(parts, 'multipart/form-data')

      response = http.request(req)
      case response.code.to_i
      when 401
        raise AuthenticationError, 'Invalid API key'
      when 400
        error = JSON.parse(response.body) rescue {}
        raise ValidationError, error['detail'] || 'Validation error'
      end
      JSON.parse(response.body) rescue {}
    end

    def request(method, path, data = nil)
      uri = URI.parse("#{@base_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      
      case method
      when :get
        request = Net::HTTP::Get.new(uri)
      when :post
        request = Net::HTTP::Post.new(uri)
        request.body = URI.encode_www_form(data) if data
        request['Content-Type'] = 'application/x-www-form-urlencoded'
      when :delete
        request = Net::HTTP::Delete.new(uri)
      end
      
      request['X-API-Key'] = @api_key
      request['User-Agent'] = "ShegerPay-Ruby-SDK/#{VERSION}"
      
      response = http.request(request)
      
      case response.code.to_i
      when 401
        raise AuthenticationError, 'Invalid API key'
      when 400
        error = JSON.parse(response.body) rescue {}
        raise ValidationError, error['detail'] || 'Validation error'
      end
      
      JSON.parse(response.body) rescue {}
    end
  end
end
