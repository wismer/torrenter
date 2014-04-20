# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'torrenter/version'

Gem::Specification.new do |spec|
  spec.name    = "torrenter"
  spec.version = Torrenter::VERSION
  spec.authors = ["wismer"] 
  spec.email   = ["matthewhl@gmail.com"]
  spec.description = "BitTorrent Client written in Ruby"
  spec.homepage = "http://wismer.github.io"
  spec.license = "MIT"
  spec.files = Dir["lib/**/*"]
  spec.executables << 'torrenter'
  spec.require_paths = ["lib"]
  spec.summary = 'Load by typing the torrent file name after torrenter'
end
