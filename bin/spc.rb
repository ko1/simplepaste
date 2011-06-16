#!/usr/bin/ruby

TextPasteURL = 'http://www.atdot.net/sp/commit/auto'

####################################################

require 'uri'
require 'cgi'
require 'net/http'
require 'optparse'
require 'kconv'
Net::HTTP.version_1_2

def paste title, lang, body
  uri = URI.parse(TextPasteURL)
  proxy = URI.parse(ENV["http_proxy"] || "")

  post_body = "paste_body=#{CGI.escape(body.toutf8)}"
  post_body += "&title=#{CGI.escape(title.toutf8)}" if title
  post_body += "&language=#{CGI.escape(lang.toutf8)}" if lang

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
opt.on("-l [LANGUAGE]"){|v|
  case v
  when 'C'
    v = 'cpp'
  when /Lisp/
    v = nil
  end
  OPTS[:language] = v if v
}
opt.parse!(ARGV)

if ARGV.empty?
  data = ''
  while line = ARGF.gets
    break if /\x00/ =~ line
    data << line
  end
  paste OPTS[:title], OPTS[:language], data
else
  ARGV.each{|file|
    lang = OPTS[:language]
    case file
    when /\.rb\z/
      lang = 'rb'
    when /\.c\z/
      lang = 'c'
    when /\.py\z/
      lang = 'py'
    when /\.pl\z/
      lang = 'pl'
    when /\.php\z/
      lang = 'php'
    end
    paste OPTS[:title], OPTS[:language], File.read(file)
  }
end
