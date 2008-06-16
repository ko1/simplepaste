require File.join(File.dirname(__FILE__), 'simplepaste')

StoreClass = SimpleStore

class TextSimplePaste < SimplePaste
  def edit_line_number text
    i = 0
    text.split(/\n/).map{|line|
      "#{'%04d' % (i+=1)}: #{line}"
    }.join("\n")
  end

  EDIT_COMMANDS = ['line_number']

  def on_view page_id, *args
    move_to :make, page_id unless StoreClass.exist? page_id
    store = StoreClass.open(page_id)
    text = store['body']

    args.each{|option|
      edit_command = "edit_#{option}"
      if respond_to? edit_command
        text = __send__(edit_coomand, text)
      end
    }

    store['body']    = escape(text)
    store['page_id'] = page_id
    store['header']  = '...'
    store['v_url']   = "#{script_url}/view/#{page_id}"
    store['ro_url']  = "#{script_url}/readonly/#{page_id}"
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
    store['body']   = q('paste_body')
  end
end

TextSimplePaste.new(
  File.join(BASE_DIR, ERB_DIR),
  File.join(BASE_DIR, STORE_DIR),
  File.join(BASE_DIR, BACKUP_DIR)).run

