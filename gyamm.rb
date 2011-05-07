# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'
require 'fileutils'

require 'gyamm/mime'
require 'gyamm/config'
require 'gyamm/delete'
require 'gyamm/lib'
require 'gyamm/lock'

helpers do
  #
  # Basic認証のためのヘルパー
  # (ヘルパーにする必要があるのか不明)
  #
  def protected!(name)
    unless authorized?(name)
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized.\n"])
    end
  end

  def authorized?(name)
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    lock = Lock.new(name)
    return true unless lock.locked?
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [lock.addr, lock.password]
  end
end

get %r{/([0-9a-f]{32})$} do |link| # e.g. http://gyamm.com/e2cf57e59b4aa5eebc9ecd21b92bd86e
  link_html(link)
end

get '/:name' do |name|
  protected!(name)
  list_html(name) # in gyamm/lib.rb
end

get '/:name/' do |name|
  protected!(name)
  list_html(name)
end

get '/:name/recover' do |name|
  protected!(name)
  listfile = "#{datadir(name)}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.recover
  redirect "/#{name}"
end

get '/:name/sort' do |name|
  protected!(name)
  touch_all(name)
  redirect "/#{name}"
end

get %r{/(\S+)/([0-9]{14})$} do |name,id|
  protected!(name)
  message_html(name,id)
end

get %r{/(\S+)/([0-9]{14})/$} do |name,id|
  protected!(name)
  message_html(name,id)
end

get %r{/(\S+)/([0-9]{14})/delete$} do |name,id|
  protected!(name)
  listfile = "#{datadir(name)}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.delete(id)
  redirect "/#{name}"
end

get %r{/(\S+)/([0-9]{14})/text$} do |name,id|
  protected!(name)
  file = datafile(name,id)
  @name = name
  @id = id
  @text = (File.exists?(file) ? File.read(file) : '')
  @text.gsub!(/</,'&lt;')
  erb :text
end

get %r{/(\S+)/([0-9]{14})/top$} do |name,id|
  protected!(name)
  file = datafile(name,id)
  FileUtils.touch(file)
  redirect "/#{name}"
end

