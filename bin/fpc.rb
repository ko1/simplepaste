#!/usr/bin/ruby
# fpc.rb

FilePasteURL = 'http://www.atdot.net/fp/commit/auto'

#####################################################################
require 'optparse'
require 'net/http'
require 'uri'

auth_id = nil
auth_passwd = nil
passwd = nil
comment = nil
name = ENV['USER']

opt = OptionParser.new{|o|
  o.banner = "Usage: #{$0} [options] files..."
  o.separator ''

  o.on('--set-auth [ID:Password]', "Specify Download ID and Passowrd."){|a|
    auth_id, auth_passwd = a.split(/:/)
  }
  o.on('--name [NAME]', "Uploader name."){|n|
    name = n
  }
  o.on('--comment [COMMENT]', "Comment of Files."){|c|
    comment = c
  }
  o.on('--password [Password]', "Upload password."){|pass|
    passwd = pass
  }
  o.on('-h', '--help', 'Show this help.'){
    puts o
    exit
  }
}

opt.parse!(ARGV)
if ARGV.empty?
  puts opt
  exit 1
end

Net::HTTP.version_1_2

def upload uri, files, rest = {}
  uri      = URI.parse(uri)

  if block_given?
    boundary = yield
  else
    boundary = '--------------------------' +
    Time.now.to_i.to_s(36) + '--' + rand(10000).to_s(36)
  end

  data = []

  files.each{|file|
    data << '--' + boundary
    data << %Q(content-disposition: form-data; name="paste_body"; filename="#{file}")
    data << 'content-type: application/octet-stream'
    data << ''
    data << open(file, 'rb'){|f| f.read}
    data << "--#{boundary}"
  }

  #  data.pop
  rest.each{|k, v|
    next unless v
    data << "content-disposition: form-data; name=\"#{k}\""
    data << ''
    data << v
    data << "--#{boundary}"
  }

  data.last << '--' #

  #puts data.join("\n")
  #exit
  Net::HTTP.start(uri.host){|http|
    header = {
      'content-type' => "multipart/form-data; boundary=#{boundary}"
    }
    res = http.post(uri.path, data.join("\r\n"), header)
    res.body
  }
end

uri  = upload(FilePasteURL, ARGV, {
  :auth_id => auth_id,
  :auth_passwd => auth_passwd,
  :user_name => name,
  :user_comment => comment,
  :user_password => passwd,
})

# for Windows
if uri
  if uri.map.size > 1
    puts uri
  else
    puts uri
    system "cmd /c start #{uri}"
  end
end



