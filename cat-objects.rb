#!/usr/bin/ruby
require 'find'

Find.find(".git/objects") do |path|
  if FileTest.file?(path)
    dirname = File.dirname(path)
    hash_prefix = File.basename(dirname)
    hash = hash_prefix + File.basename(path)
    puts "Hash: " + hash
    puts "Type: " + `git cat-file -t #{hash}`
    puts `git cat-file -p #{hash}`
    puts
  end
end