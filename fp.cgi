#!/usr/bin/ruby
#
# FileSimplePaste
# Copy this file to your CGI directory
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
require File.join(BASE_DIR, 'fp_base')
