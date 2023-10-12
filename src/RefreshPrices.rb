#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'Utils/data_helper'

file_to_read = ARGV[0]

new_file = []

File.readlines(file_to_read).each do |line|
  if line.match?(/^\| \d+/)
    match = line.match(/^\| (\d+)/)
    id = match[1]
    game = DataHelper.actual_price_for_id(id)
    result = if game.nil?
               line
             else
               "| #{game.id} | #{game.name.gsub(/\|/,
                                                '\|')} | #{DataHelper.best_price?(id) ? 'X' : '-'} | #{game.price}€ |\n"
             end
  else
    result = line
  end
  new_file << result
end

File.write("#{ARGV[0][0..-4]}_new.md", new_file.join)
