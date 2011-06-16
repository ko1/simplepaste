=begin
SimplePaste:

=end

require 'cgi'
require 'erb'
require 'yaml/store'

class SimplePaste
  class RedirectNotice < Exception
  end
  class RawTextNotice < Exception
  end

  def initialize erb_dir, store_dir, backup_dir
    @erb_dir = erb_dir
    SimpleStore.store_dir = store_dir
    SimpleStore.backup_dir = backup_dir
    @cgi = CGI.new
  end

  def show type, params = {}
    file = File.read(File.join(@erb_dir, "#{type}.erb"))
    ERB.new(file).result(binding)
  end

  def move_to *args
    raise RedirectNotice.new([script_name, *args.map{|e| e.to_s}].join('/'))
  end

  def redirect_to url
    raise RedirectNotice.new(url)
  end

  def main cmd = nil, *args
    cmd = 'on_' + (cmd || 'info')

    if self.respond_to? cmd
      self.__send__ cmd, *args
    else
      raise "unknown command: #{cmd}"
    end
  end

  def escape str
    CGI.escapeHTML str
  end

  def run
    begin
      @cgi.out{
        main(*(@cgi.path_info || '').split('/')[1..-1])
      }
    rescue RedirectNotice => e
      to = e.message
      @cgi.out("Location"=>to, "status" => "REDIRECT"){
        "<html><body><a href='#{to}'>#{to}</a></body></html>"
      }
    rescue RawTextNotice => e
      @cgi.out('type'=>'text/plain'){
        e.message
      }
    rescue Exception => e
      # $DEBUG = true
      if $DEBUG
        result = ''
        result << "<pre>"
        result << escape("#{e.class}: #{e.to_s}\n---- \n#{e.backtrace.join("\n")}")
        result << "</pre>"
        result << "<pre>"
        ENV.each{|k, v|
          result << escape("#{k}: #{v}\n")
        }
      else
        result = escape("Error: #{e.to_s}")
      end
      @cgi.out{
        result
      }
    end
  end

  # utilities
  def query key
    @cgi.params[key][0]
  end

  alias q query
  
  def queries key
    @cgi.params[key]
  end

  def client_ip_addr
    @cgi.remote_addr
  end

  def script_name
    if /\.cgi/ !~ ENV['REQUEST_URI']
      @cgi.script_name.gsub(/.cgi\Z/, '')
    else
      @cgi.script_name
    end
  end

  def script_url
    "http://#{@cgi.server_name}#{script_name}"
  end

  # Common action
  def on_info
    show :info
  end

  def on_make page_id = nil
    page_id = StoreClass.make_id unless page_id
    show :make, :page_id => page_id
  end

  def on_commit cmd, page_id = nil, *opts
    page_id = q('page_id') unless page_id
    case cmd
    when 'new', 'auto'
      store = StoreClass.make(page_id)
      begin
        commit_new_entry store
        store['ipaddr'] = client_ip_addr
        store['time']   = Time.now
        store['option'] = opts.join("\n")
        store.commit
      rescue Exception
        store.delete!
        raise
      end

      if cmd == 'new'
        move_to 'view', store.id
      else
        "#{script_url}/view/#{store.id}"
      end

    when 'stick'
      store = StoreClass.open(page_id)
      store['stick'] = true
      store.commit
      
      move_to :view, page_id

    when 'delete'
      store = StoreClass.open(page_id)
      store.delete
      move_to :view, page_id
    end
  end

  def on_check cmd, page_id = nil
    case cmd
    when 'newid'
      StoreClass.make_id
    when 'newidurl'
      script_url + '/view/' + StoreClass.make_id
    when 'exist'
      StoreClass.exist?(page_id) ? 'true' : 'false'
    else
      raise "unknown command: #{cmd}"
    end
  end

end

class SimpleStore

  def self.store_dir=(dir)
    SimpleStore.const_set(:STORE_DIR, dir)
  end

  def self.store_dir
    STORE_DIR
  end

  def self.store_path sid, prefix=nil
    "#{STORE_DIR}/#{prefix}s.#{sid}"
  end

  def self.backup_dir=(dir)
    SimpleStore.const_set(:BACKUP_DIR, dir)
  end

  def self.backup_dir
    BACKUP_DIR
  end

  def self.backup_path sid
    "#{BACKUP_DIR}/#{sid}"
  end

  def check_id pid
    raise "invalid id: #{pid}" unless /\A[\dA-Za-z\-_]{1,32}\Z/ =~ pid
  end

  def self.make_place sid
    File.open(store_path(sid), 'wb'){}
  end

  def self.make sid = nil
    self.lock{
      sid = make_id unless sid
      raise "already exists: #{sid}" if exist?(sid)
      make_place sid
      self.new sid
    }
  end

  def self.make_id
    nid = Time.new.to_i.to_s(36).reverse

    lock{
      while exist? nid
        nid = nid.succ
      end
    }

    nid
  end

  def self.lock
    file = store_path('.lock', '.x.')

    File.open(file, 'w'){|f|
      f.flock(File::LOCK_SH)
      yield
    }
  end

  def self.exist? sid
    FileTest.exist?(store_path(sid))
  end

  def self.random_suffix(sid)
    "#{sid}.#{Time.now.to_i}.#{rand(100)}"
  end

  def self.delete sid
    require 'fileutils'
    FileUtils.mv(store_path(sid), File.join(BACKUP_DIR, random_suffix(sid)))
  end

  def self.delete! sid
    require 'fileutils'
    FileUtils.rm(store_path(sid))
  end

  def self.open sid
    self.new sid
  end

  def initialize sid
    @sid = sid
    raise "Not Found: #{sid}" unless SimpleStore.exist? sid

    @db = YAML::Store.new(SimpleStore.store_path(@sid))
    @store = {}

    @db.transaction{
      @db.roots.each{|key|
        @store[key] = @db[key]
      }
    }
  end

  def [](key)
    @store[key]
  end

  def []=(key, value)
    @store[key] = value
  end

  def commit
    @db.transaction{
      @store.each{|k, v|
        @db[k] = v
      }
    }
  end

  def delete
    if SimpleStore.exist?(@sid)
      SimpleStore.delete(@sid)
    end
  end

  def delete!
    if SimpleStore.exist?(@sid)
      SimpleStore.delete!(@sid)
    end
  end

  def id
    @sid
  end
end

class FileSimpleStore < SimpleStore
  def dir_path
    "#{STORE_DIR}/f.#{@sid}"
  end
  
  def attach name, contents
    dir = dir_path
    file = File.join(dir, 'file.' + name)

    Dir.mkdir(dir) unless FileTest.exist? dir

    open(file, 'wb'){|f|
      f.write(contents)
    }

    file
  end

  def attached_files
    Dir.glob(File.join(dir_path, '*')).to_a
  end

  def delete
    require 'fileutils'
    if FileTest.exists? dir_path
      FileUtils.mv(dir_path, File.join(BACKUP_DIR, SimpleStore.random_suffix(@sid)))
    end
    super
  end

  def delete!
    require 'fileutils'
    if FileTest.exists? dir_path
      FileUtils.rm_r(dir_path)
    end
    super
  end
end

if $0 == __FILE__
  SimpleStore.store_dir = 'sp_store'
  SimpleStore.backup_dir = 'sp_backup'

  if SimpleStore.exist? 'foo'
    SimpleStore.delete 'foo'
  end

  store = SimpleStore.make
  store['a'] = 'x'
  store['b'] = 'y'
  store['c'] = 'z'

  p store['a']
  store.commit

  system('ls sp_store')
  SimpleStore.delete store.id
  system('ls sp_store')
end

