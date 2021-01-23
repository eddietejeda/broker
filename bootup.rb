# encoding: utf-8

# Set up environment
require 'active_support/all'
require "sqlite3"
require 'smarter_csv'
require 'net/http'
require 'roo'
require 'json'
require 'net/http'
require 'uri'
require 'bigdecimal'
require 'bigdecimal/util'
require 'dotenv/load'
require 'byebug'
require 'ap'

load "./helpers.rb"
load "./app.rb"