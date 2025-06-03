module Bai2
  # Custom integrity checking module for production use
  # Provides business-level validation beyond basic parsing
  module CustomIntegrity
    
    class ValidationError < StandardError; end
    
    # Performs comprehensive business-level validation on a parsed BAI file
    #
    # @param bai [Bai2::BaiFile] The parsed BAI file
    # @param options [Hash] Validation options
    # @return [Hash] Validation results with warnings and errors
    def self.validate(bai, options = {})
      results = {
        valid: true,
        errors: [],
        warnings: [],
        metrics: {},
        recommendations: []
      }
      
      begin
        # Basic structure validation
        validate_structure(bai, results)
        
        # Business logic validation
        validate_business_rules(bai, results, options)
        
        # Data quality checks
        validate_data_quality(bai, results)
        
        # Performance metrics
        collect_metrics(bai, results)
        
        # Generate recommendations
        generate_recommendations(bai, results, options)
        
      rescue StandardError => e
        results[:valid] = false
        results[:errors] << "Validation failed: #{e.message}"
      end
      
      results[:valid] = results[:errors].empty?
      results
    end
    
    private
    
    # Validates basic file structure
    def self.validate_structure(bai, results)
      # Check for required elements
      if bai.groups.empty?
        results[:errors] << "File contains no groups"
        return
      end
      
      bai.groups.each_with_index do |group, group_index|
        if group.accounts.empty?
          results[:errors] << "Group #{group_index + 1} contains no accounts"
          next
        end
        
        # Validate account structure
        group.accounts.each_with_index do |account, account_index|
          validate_account_structure(account, group_index + 1, account_index + 1, results)
        end
      end
    end
    
    # Validates individual account structure
    def self.validate_account_structure(account, group_num, account_num, results)
      # Check customer ID format
      customer_id = account.customer
      if customer_id.nil? || customer_id.strip.empty?
        results[:errors] << "Group #{group_num}, Account #{account_num}: Missing customer ID"
      elsif customer_id.length < 5
        results[:warnings] << "Group #{group_num}, Account #{account_num}: Customer ID '#{customer_id}' seems unusually short"
      end
      
      # Check for reasonable transaction counts
      transaction_count = account.transactions.count
      if transaction_count == 0
        results[:warnings] << "Group #{group_num}, Account #{account_num}: No transactions found"
      elsif transaction_count > 10000
        results[:warnings] << "Group #{group_num}, Account #{account_num}: Unusually high transaction count (#{transaction_count})"
      end
      
      # Check summary vs transaction consistency
      summary_count = account.summaries.count
      if summary_count == 0
        results[:warnings] << "Group #{group_num}, Account #{account_num}: No account summaries found"
      end
    end
    
    # Validates business rules specific to your application
    def self.validate_business_rules(bai, results, options)
      expected_customers = options[:expected_customers] || ['0005157748558']
      
      bai.groups.each_with_index do |group, group_index|
        group.accounts.each_with_index do |account, account_index|
          customer_id = account.customer
          
          # Validate expected customer IDs
          unless expected_customers.include?(customer_id) || options[:allow_unknown_customers]
            results[:warnings] << "Group #{group_index + 1}, Account #{account_index + 1}: Unknown customer ID '#{customer_id}'"
          end
          
          # Validate transaction amounts
          account.transactions.each_with_index do |transaction, tx_index|
            amount = transaction.amount
            
            # Check for zero amounts
            if amount == 0
              results[:warnings] << "Group #{group_index + 1}, Account #{account_index + 1}, Transaction #{tx_index + 1}: Zero amount transaction"
            end
            
            # Check for unusually large amounts (over $1M)
            if amount.abs > 100_000_000 # $1M in cents
              results[:warnings] << "Group #{group_index + 1}, Account #{account_index + 1}, Transaction #{tx_index + 1}: Large amount transaction ($#{amount / 100.0})"
            end
          end
        end
      end
    end
    
    # Validates data quality
    def self.validate_data_quality(bai, results)
      bai.groups.each_with_index do |group, group_index|
        group.accounts.each_with_index do |account, account_index|
          # Check for duplicate transactions (same amount, same type, same day)
          transactions_by_key = account.transactions.group_by do |tx|
            [tx.amount, tx.type[:code], tx.type[:transaction]]
          end
          
          transactions_by_key.each do |key, transactions|
            if transactions.count > 1
              results[:warnings] << "Group #{group_index + 1}, Account #{account_index + 1}: #{transactions.count} potentially duplicate transactions (amount: $#{key[0] / 100.0}, type: #{key[1]})"
            end
          end
          
          # Check for missing transaction details
          account.transactions.each_with_index do |transaction, tx_index|
            if transaction.text.nil? || transaction.text.strip.empty?
              results[:warnings] << "Group #{group_index + 1}, Account #{account_index + 1}, Transaction #{tx_index + 1}: Missing transaction description"
            end
          end
        end
      end
    end
    
    # Collects performance and quality metrics
    def self.collect_metrics(bai, results)
      results[:metrics] = {
        groups: bai.groups.count,
        accounts: bai.groups.sum { |g| g.accounts.count },
        transactions: bai.groups.sum { |g| g.accounts.sum { |a| a.transactions.count } },
        summaries: bai.groups.sum { |g| g.accounts.sum { |a| a.summaries.count } },
        total_amount: bai.groups.sum { |g| g.accounts.sum { |a| a.transactions.sum(&:amount) } },
        credit_count: bai.groups.sum { |g| g.accounts.sum { |a| a.transactions.count(&:credit?) } },
        debit_count: bai.groups.sum { |g| g.accounts.sum { |a| a.transactions.count(&:debit?) } }
      }
      
      # Calculate averages
      if results[:metrics][:transactions] > 0
        results[:metrics][:avg_transaction_amount] = results[:metrics][:total_amount] / results[:metrics][:transactions]
      end
    end
    
    # Generates recommendations based on validation results
    def self.generate_recommendations(bai, results, options)
      # Recommend specific parsing options based on file characteristics
      if results[:warnings].any? { |w| w.include?("Customer ID") }
        results[:recommendations] << "Consider updating expected customer ID list or enabling allow_unknown_customers option"
      end
      
      if results[:metrics][:transactions] == 0
        results[:recommendations] << "File contains no transactions - verify this is expected"
      end
      
      if results[:warnings].count > results[:metrics][:transactions] * 0.1
        results[:recommendations] << "High warning rate (#{results[:warnings].count} warnings for #{results[:metrics][:transactions]} transactions) - consider reviewing data quality"
      end
      
      # Bank-specific recommendations
      customer_ids = bai.groups.flat_map { |g| g.accounts.map(&:customer) }.uniq
      if customer_ids.any? { |id| id.start_with?('144') }
        results[:recommendations] << "CFOT customer detected - ensure proper processing entity configuration"
      end
      
      if customer_ids.include?('0005157748558')
        results[:recommendations] << "MCF customer detected - standard processing applies"
      end
    end
  end
end
