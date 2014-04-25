require 'sinatra'
require 'sinatra/base'
require 'json'
require 'torrenter'
require "net/http"

$data_dump = 'thrones.torrent-data'


get '/' do
  erb :index
end

post '/' do
  erb :index
end

get '/filer' do
  $thread = Thread.new { Torrenter::Torrent.new.start(params[:torrent]) }.run
  erb :index
end

post '/filer' do
  JSON.generate({ master_index: $update[:index], peer_count: $update[:peer_count]}) if $update
end