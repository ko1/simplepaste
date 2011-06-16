require File.join(File.dirname(__FILE__), 'simplepaste')
require File.join(File.dirname(__FILE__), 'syntax_highlighter') if SYNTAX_HIGHLIGHTER_PATH

StoreClass = SimpleStore

class TextSimplePaste < SimplePaste
  def edit_lineno text
    i = 0
    text.split(/\n/).map{|line|
      "#{'%5d ' % (i+=1)}| #{line}"
    }.join("\n")
  end

  def edit_reverse text
    text.split(/\n/).reverse.join("\n")
  end

  def edit_statistics text

    stat = []
    stat << "#{text.size} bytes"
    stat << "#{text.split(//u).size} characters"
    stat << "#{text.count("\n")} lines"

=begin
    chars = Hash.new{0}
    text.split(//u).each{|c| chars[c] += 1}
    stat << "Characters: "
    stat << chars.sort.map{|k, v| 
              "  #{k.inspect}: #{v}"
            }
=end
    stat << ''
    stat << ''
    stat.join("\n") + text
  end

  def edit_randomize text
    text.split(//u).sort_by{rand}.join
  end

  def edit_readonly text
    
  end

  EDIT_COMMANDS = %w(readonly lineno reverse randomize statistics)
  LANGUAGES = %w(plain ruby c javascript)

  def on_view page_id, *args
    move_to :make, page_id unless StoreClass.exist? page_id
    store = StoreClass.open(page_id)

    title = store['title'] || ''
    body = store['body']

    lang = q('lang') || store['language']
    store['language'] = lang

    cmds = EDIT_COMMANDS.map{|cmd|
      if args.include? cmd
        case cmd
        when 'readonly'
          store['readonly'] = true; nil
        else
          edit_command = "edit_#{cmd}"
          if respond_to? edit_command
            body = __send__(edit_command, body)
          end
          "no #{cmd}"
        end
      else
        cmd
      end
    }.compact

    v_url = "#{script_url}/view/#{page_id}/#{args.join('/')}"
    store['title']   = title.length > 0 ? escape(title) : nil
    store['body']    = escape(body)
    store['page_id'] = page_id
    store['v_url']   = v_url
    store['ro_url']  = "#{script_url}/readonly/#{page_id}"
    store['raw_url'] = "#{script_url}/raw/#{page_id}"
    store['class']   = lang ? "class='brush: #{lang}'" : nil
    store['header']  = "<a href='#{store['raw_url']}'>[raw]</a>"
    cmds.each{|cmd|
      if /\Ano (.+)/ =~ cmd
        store['header'] += " <a href='#{v_url.sub(/#{$1}\/?/, '')}'>[#{cmd}]</a>"
      else
        store['header'] += " <a href='#{File.join(v_url, cmd)}'>[#{cmd}]</a>"
      end
    }
    show :view, store
  end

  def on_readonly page_id
    store = StoreClass.open(page_id)
    show :readonly, 'body' => escape(store['body'])
  end

  def on_raw page_id
    raise "You can't view raw page with MSIE" if @cgi.user_agent =~ /MSIE/
    store = StoreClass.open(page_id)
    raise RawTextNotice.new(store['body'])
  end

  def commit_new_entry store
    store['body']   = body = q('paste_body')
    store['title']  = q('title')
    lang = q('language')

    # easy lang detection
    unless lang
      if /^--- .+?\n\+\+\+ .+?\n@@ -\d+,\d+ +\+\d+,\d+ @@.*\n/m =~ body
        lang = 'diff'
      end
    end
    store['language'] = lang 
  end
end

TextSimplePaste.new(
  File.join(BASE_DIR, ERB_DIR),
  File.join(BASE_DIR, STORE_DIR),
  File.join(BASE_DIR, BACKUP_DIR)).run

