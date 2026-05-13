    # ============================================
    # MULTI-CURRENCY WALLET METHODS
    # ============================================

    # Get multi-currency wallet balances
    # @return [Hash]
    def get_wallet_balance
      request(:get, '/api/v1/paypal/wallet/balance')
    end

    # Convert currency within wallet
    # @param from_currency [String] Source currency code
    # @param to_currency [String] Target currency code
    # @param amount [Float] Amount to convert
    # @return [Hash]
    def convert_currency(from_currency, to_currency, amount)
      raise 'Currency conversion is private/assisted and is not exposed in the public SDK.'
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
