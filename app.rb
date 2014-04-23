require 'sinatra'
require 'sinatra/base'
require 'json'
require 'torrenter'
require "net/http"

$data_dump = 'thrones.torrent-data'

$thread = Thread.new { Torrenter::Torrent.new.start("thrones.torrent") }.run

get '/' do
  erb :index
end

post '/' do
  erb :index
end

get '/filer' do
  erb :index
end

post '/filer' do
  JSON.generate({ master_index: $update})
end