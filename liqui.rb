#!/usr/bin/env ruby

require 'openssl'
require 'net/http'
require 'uri'
require 'json'
require 'yaml'
require 'bigdecimal'
require 'date'

def abort msg
  STDERR.puts msg
  exit 1
end

unless File.exist?("liqui.yml") then
  File.open("liqui.yml", "w") do |file|
    file.write "---\nkey:\nsecret\n"
  end
  abort "Please configure liqui.yml with your API key first"
end
config = YAML.load( File.read( "liqui.yml" ))

secret  = config["secret"]
key     = config["key"]
urlpost = "https://api.liqui.io/tapi"
urlget  = "https://api.liqui.io/api/3/"

uri     = URI.parse( urlpost )
content = { "method"       => "TradeHistory",
            "nonce"        => Time.now.to_i.to_s }
body    = URI.encode_www_form content
digest  = OpenSSL::Digest.new "sha512"
sign    = ( OpenSSL::HMAC.digest digest, secret, body ).unpack("H*").first
headers = { "Key"          => key, 
            "Sign"         => sign, 
            "Content-Type" => "application/x-www-form-urlencoded" }


puts "----------------"
puts "POST HTTP/1.1 #{uri}"
headers.each do |h, v|
  puts "#{h}: #{v}"
end
puts ""
puts "#{body}"
puts "----------------"
response = nil

Net::HTTP.start( uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
  request      = Net::HTTP::Post.new( uri.request_uri )
  request.body = body
  headers.each { |h, v| request[ h ] = v }

  response     = http.request request # Net::HTTPResponse object
end

puts "#{response.code} #{response.msg}"
response.each_header do |h, v|
  puts "#{h}: #{v}"
end
puts ""
body = response.body

File.open( "liqui.csv", "w" ) do |file| 
  file.write "isotime,exchange,txn_id,currency1,adjustment1,currency2,adjustment2,order_id,rate\n"
  entries = JSON.parse( body )
  entries[ "return" ].each do |txn_id, txn_info|
    pair          = txn_info["pair"]
    type          = txn_info["type"]
    amount        = txn_info["amount"]
    rate          = txn_info["rate"]
    order_id      = txn_info["order_id"]
    is_your_order = txn_info["is_your_order"]
    timestamp     = txn_info["timestamp"]
 
    currencies    = pair.split("_", 2).collect {|x| x.upcase }
    adjustment1   = BigDecimal(amount.to_s)
    adjustment1   = BigDecimal("0.0") - adjustment1 if type == "sell"
    adjustment1   = adjustment1.truncate(8).to_f.to_s
    adjustment2   = (BigDecimal("0.0") - (BigDecimal(amount.to_s) * BigDecimal(rate.to_s))).truncate(8).to_f.to_s

    isotime       = DateTime.strptime(timestamp.to_s, "%s").to_s

    file.write "#{isotime},liqui.io,#{txn_id},#{currencies.first},#{adjustment1},#{currencies.last},#{adjustment2},#{order_id},#{rate}\n"
  end
end

puts "Result written to liqui.csv"

#{
#  "success": 1,
#  "return": {
#    "11230496": {
#      "pair": "omg_eth",
#      "type": "buy",
#      "amount": 32.51075379,
#      "rate": 0.00397325,
#      "order_id": 28134476,
#      "is_your_order": true,
#      "timestamp": 1500044957
#    },


