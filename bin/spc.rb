#!/usr/bin/ruby

TextPasteURL = 'http://www.atdot.net/sp/commit/auto'

####################################################

require 'uri'
require 'cgi'
require 'net/http'
require 'optparse'
Net::HTTP.version_1_2

def paste title, body
  uri = URI.parse(TextPasteURL)
  proxy = URI.parse(ENV["http_proxy"] || "")

  post_body = "paste_body=#{CGI.escape(body)}"
  if title
    puts title
    post_body += "&title=#{CGI.escape(title)}"
  end

  Net::HTTP.start(uri.host, uri.port, proxy.host, proxy.port) {|http|
    response = http.post(uri.path, post_body)
    puts response.body
  }
end

OPTS={}
opt = OptionParser.new
opt.on("-t [TITLE]"){|v|
  OPTS[:title] = v
}
opt.parse!(ARGV)

if ARGV.empty?
  paste OPTS[:title], ARGF.read
else
  ARGV.each{|file|
    paste OPTS[:title], File.read(file)
  }
end
