#!/usr/bin/ruby

TextPasteURL = 'http://www.atdot.net/fp/commit/auto'

####################################################

require 'uri'
require 'cgi'
require 'net/http'
Net::HTTP.version_1_2

def paste str
  body = CGI.escape(str)
  uri = URI.parse(TextPasteURL)

  Net::HTTP.start(uri.host, uri.port) {|http|
    response = http.post(uri.path, 'paste_body=' + body)
    puts response.body
  }
end

if ARGV.empty?
  paste ARGF.read
else
  ARGV.each{|file|
    paste File.read(file)
  }
end
