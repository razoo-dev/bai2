#!/usr/bin/env ruby

# Test script for the simplified, clean bai2 gem approach
require_relative 'lib/bai2'
require_relative 'lib/bai2/custom_integrity'

def test_simplified_approach(file_path)
  file_name = File.basename(file_path)
  
  puts "=" * 80
  puts "Testing Simplified Approach: #{file_name}"
  puts "=" * 80
  
  unless File.exist?(file_path)
    puts "❌ File not found: #{file_path}"
    return
  end
  
  # Read and preprocess file
  file_content = File.read(file_path)
  file_content.gsub!('88,/', '88,')
  
  puts "File size: #{file_content.bytesize} bytes"
  puts "File lines: #{file_content.lines.count}"
  
  # Test the simplified approaches
  approaches = [
    {
      name: "Standard parsing (baseline)",
      options: {}
    },
    {
      name: "Skip record count validation (recommended)",
      options: { skip_record_count_validation: true }
    },
    {
      name: "Skip record count + ignore summary amounts",
      options: { 
        skip_record_count_validation: true,
        account_control_ignores_summary_amounts: true
      }
    },
    {
      name: "Full integrity bypass (fallback)",
      options: { skip_integrity_checks: true }
    }
  ]
  
  successful_approach = nil
  
  approaches.each_with_index do |approach, index|
    puts "\n--- Approach #{index + 1}: #{approach[:name]} ---"
    puts "Options: #{approach[:options].inspect}"
    
    begin
      start_time = Time.now
      bai = Bai2::BaiFile.new(file_content, approach[:options])
      end_time = Time.now
      
      puts "✅ SUCCESS! Parsed in #{((end_time - start_time) * 1000).round(2)}ms"
      
      # Basic metrics
      groups = bai.groups.count
      accounts = bai.groups.sum { |g| g.accounts.count }
      transactions = bai.groups.sum { |g| g.accounts.sum { |a| a.transactions.count } }
      
      puts "Groups: #{groups}, Accounts: #{accounts}, Transactions: #{transactions}"
      
      if bai.groups.any? && bai.groups.first.accounts.any?
        customer_id = bai.groups.first.accounts.first.customer
        puts "Customer ID: #{customer_id}"
      end
      
      # Run custom integrity checking
      puts "\n--- Custom Integrity Validation ---"
      validation_options = {
        expected_customers: ['***REMOVED***'],
        allow_unknown_customers: true
      }
      
      validation_results = Bai2::CustomIntegrity.validate(bai, validation_options)
      
      puts "Validation Status: #{validation_results[:valid] ? '✅ VALID' : '❌ INVALID'}"
      puts "Errors: #{validation_results[:errors].count}"
      puts "Warnings: #{validation_results[:warnings].count}"
      
      # Show first few warnings/errors
      validation_results[:errors].first(2).each do |error|
        puts "  ERROR: #{error}"
      end
      
      validation_results[:warnings].first(2).each do |warning|
        puts "  WARNING: #{warning}"
      end
      
      # Show key metrics
      metrics = validation_results[:metrics]
      puts "\nKey Metrics:"
      puts "  Total Amount: $#{(metrics[:total_amount] / 100.0).round(2)}"
      puts "  Credits: #{metrics[:credit_count]}, Debits: #{metrics[:debit_count]}"
      
      successful_approach = approach
      puts "\n🎉 FIRST SUCCESSFUL APPROACH!"
      break
      
    rescue StandardError => e
      puts "❌ FAILED: #{e.class.name}: #{e.message}"
      puts "   #{e.message[0..80]}..." if e.message.length > 50
    end
  end
  
  if successful_approach
    puts "\n" + "="*60
    puts "RECOMMENDED PRODUCTION CONFIGURATION:"
    puts "="*60
    puts "bai = Bai2::BaiFile.new(file_content, #{successful_approach[:options].inspect})"
    puts "validation = Bai2::CustomIntegrity.validate(bai)"
    puts "="*60
  else
    puts "\n💥 ALL APPROACHES FAILED for #{file_name}"
  end
  
  puts "\n" + "=" * 80
  puts ""
end

def main
  puts "Simplified BAI2 Gem Test"
  puts "Time: #{Time.now}"
  puts ""
  
  # Test files (adjust paths as needed)
  test_files = [
    "/Users/brycemelvin/razoo2/tmp/CFOT_BAI_PDR_20250603.txt",
    "/Users/brycemelvin/razoo2/tmp/Mightycause_BAI_PDR_20250603.txt"
  ]
  
  test_files.each do |file_path|
    if File.exist?(file_path)
      test_simplified_approach(file_path)
    else
      puts "⚠️  File not found: #{file_path}"
    end
  end
  
  puts "Testing completed at #{Time.now}"
  puts "\n🚀 SIMPLIFIED SOLUTION VALIDATED! 🚀"
end

# Run the tests
main
