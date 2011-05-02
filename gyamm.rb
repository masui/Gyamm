# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'

require 'gyamm/mime'
require 'gyamm/config'
require 'gyamm/delete'
require 'gyamm/lib'

get '/:name' do |name|
  disp_list(name)
end

get '/:name/' do |name|
  disp_list(name)
end

get '/:name/recover' do |name|
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.recover
  redirect "/#{name}"
end

get '/:name/:id' do |name,id|
  disp_message(name,id)
end

get '/:name/:id/' do |name,id|
  disp_message(name,id)
end

get '/:name/:id/delete' do |name,id|
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.delete(id)
  redirect "/#{name}"
end

get '/:name/:id/text' do |name,id|
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @name = name
  @id = id
  @text = (File.exists?(file) ? File.read(file) : '')
  @text.gsub!(/</,'&lt;')
  erb :text
end
