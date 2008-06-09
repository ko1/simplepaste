#!/usr/bin/ruby
#
# SimplePaste
#
###################################################


$FILE_SIZE_LIMIT  = (1024 * 1024) # 1MB
$FILE_TYPE_LIMIT  = true # image file only
$FILE_COUNT_LIMIT = 5

PASSWORD_FILE     = 'fp.passwd'

BASE_DIR       =  File.dirname(__FILE__)
ERB_DIR        = 'fp_erb'
STORE_DIR      = 'fp_store'
BACKUP_DIR     = 'fp_backup'

###################################################
require File.join(BASE_DIR, 'simplepaste')
require 'uri'

StoreClass = FileSimpleStore
PASSWORD = {}

# Password File
if File.exist?(passwdfile = File.join(BASE_DIR, PASSWORD_FILE))
  File.read(passwdfile).split(/\n/).each{|line|
    line = line.sub(/\#.+/, '').strip
    next if line.empty?
    if /(.+)\s+:\s+(.+)/ =~ line
      PASSWORD[$1] = $2
    else
      raise "Password File: Invalid format (#{line})"
    end
  }
end

class FileSimplePaste < SimplePaste
  def initialize *args
    @query_cache = {}
    super
  end

  def on_view page_id, *args
    move_to :make, page_id unless StoreClass.exist? page_id
    store = StoreClass.open(page_id)
    file_info = store['file_info']

    #
    # fi[0]: original filename
    # fi[1]: store path
    # fi[2]: thumbnail path
    #
    base = File.dirname(script_name)
    text = ''


    text << '<h1>Pasted Files</h1>'
    text << '<ul>'
    text << file_info.map{|fi|
      e  = "<li>"
      e << "<a  href='#{File.join(base, fi[1])}'>"
      e << "<img src='#{File.join(base, fi[2])}' /><br />" if fi[2]
      e << "#{escape(fi[0])}</a>"
      e << "</li>"
      e
    }.join("\n")
    text << '</ul>'

    store['name']    = escape(store['user_name'] || 'unknown')
    store['comment'] = escape(store['user_comment'] || '-')
    store['body']    = "#{text}"
    store['page_id'] = page_id
    store['header']  = ''
    store['v_url']   = "#{script_url}/view/#{page_id}"
    store['hooter']
    show :view, store
  end

  def query key
    return @query_cache[key] if @query_cache.has_key? key

    v = @cgi.params[key][0]
    v = v ? ((v = v.read; v.empty?) ? nil : v) : nil
    @query_cache[key] = v
  end

  alias q query

  def commit_auth store, auth_id, auth_passwd, auth_name
    # ID/Password
    raise "ID is specified, but Password is null (#{auth_id})" unless auth_passwd
    raise "Password is specified, but ID is null" unless auth_id

    auth_name = q('auth_name') || "Please enter your ID and password for #{store.id}"
    auth_name.gsub(/[^a-zA-Z0-9. ]/, '.')

    open(File.join(store.dir_path, '.htaccess'), 'w'){|f|
      f.puts "AuthUserFile #{store.dir_path}/.htpasswd"
      f.puts "AuthGroupFile /dev/null"
      f.puts "AuthName \"#{auth_name}\""
      f.puts 'AuthType Basic'
      f.puts 'require valid-user'
    }

    salt = [rand(64),rand(64)].pack("C*").tr("\x00-\x3f","A-Za-z0-9./")

    open(File.join(store.dir_path, '.htpasswd'), 'w'){|f|
      f.puts "#{auth_id}:#{auth_passwd.crypt(salt)}"
    }
  end

  def commit_new_entry store
    if q('user_password') == PASSWORD[q('user_name')]
      $FILE_SIZE_LIMIT  = $FILE_TYPE_LIMIT  = $FILE_COUNT_LIMIT = nil
    end

    i = 0
    store['file_info'] = file_info = []
    store['user_name'] = q('user_name')
    store['user_comment'] = q('user_comment')

    files = queries('paste_body').map{|f|
      contents = f.read
      length = contents.length
      next if length == 0

      if $FILE_SIZE_LIMIT && length > $FILE_SIZE_LIMIT
        raise "Too large data: #{length} > #{$FILE_SIZE_LIMIT}"
      end

      orig_file  = File.basename(URI.encode(f.original_filename))
      saved_path = store.attach(orig_file, contents)
      saved_file = saved_path.sub(BASE_DIR + '/', '')
      thumb_file = nil

      if /\Aimage/ !~ `file -ib #{saved_path} 2> /dev/null`
        if $FILE_TYPE_LIMIT && $FILE_TYPE_LIMIT
          raise "File is not image: #{f.original_filename}"
        end
      else
        thumb_path = "#{saved_path}.thumbnail.jpg"
        thumb_file = thumb_path.sub(BASE_DIR + '/', '')
        system("/usr/bin/convert -geometry 160 #{saved_path} #{thumb_path}")
      end

      file_info << [orig_file, saved_file, thumb_file]

      if $FILE_COUNT_LIMIT && file_info.length > $FILE_COUNT_LIMIT
        raise "Too many files: #{file_info.length} > #{$FILE_COUNT_LIMIT}"
      end
    }

    raise "No file is uploaded." if file_info.empty?

    auth_id = q('auth_id')
    auth_passwd = q('auth_passwd')
    if auth_id || auth_passwd
      commit_auth store, auth_id, auth_passwd, q('auth_name')
    end
  end
end

FileSimplePaste.new(
  File.join(BASE_DIR, ERB_DIR),
  File.join(BASE_DIR, STORE_DIR),
  File.join(BASE_DIR, BACKUP_DIR)).run

