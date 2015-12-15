#!/usr/bin/env ruby

require 'openssl'
require 'Base64'

key = ENV['AWS_SECRET_ACCESS_KEY']
message = 'SendRawEmail'
version = "\x02"
digest = OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), key, message)
puts Base64.encode64("#{version}#{digest}").strip()
