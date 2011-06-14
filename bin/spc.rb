#!/usr/bin/ruby

TextPasteURL = 'http://www.atdot.net/sp/commit/auto'

####################################################

require 'uri'
require 'cgi'
require 'net/http'
require 'optparse'
Net::HTTP.version_1_2

def paste str
  body = CGI.escape(str)
  uri = URI.parse(TextPasteURL)

  Net::HTTP.start(uri.host, uri.port) {|http|
    response = http.post(uri.path, 'paste_body=' + body)
    puts response.body
  }
end

OPTS={}
opt = OptionParser.new
opt.on("-t title"){|v| OPTS[:t] = v+"\n" }
opt.parse!(ARGV)

if ARGV.empty?
  paste OPTS[:t]+ARGF.read
else
  ARGV.each{|file|
    paste OPTS[:t]+File.read(file)
  }
end
