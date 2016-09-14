#!/usr/bin/ruby
require 'zlib'
filename = ARGV[0]
content = File.open(filename, 'rb') { |f| f.read }
unzipped = Zlib::Inflate.inflate(content)
puts unzipped
