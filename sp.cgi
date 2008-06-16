#!/usr/bin/ruby
#
# SimplePaste CGI
# Copy this file to your CGI directory
#
###################################################

BASE_DIR   = File.dirname(__FILE__)
ERB_DIR    = 'sp_erb'
STORE_DIR  = 'sp_store'
BACKUP_DIR = 'sp_backup'

###################################################
require File.join(BASE_DIR, 'sp_base')

