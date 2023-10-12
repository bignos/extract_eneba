# frozen_string_literal: true

require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'database.db')

# Create the games table in the database
class CreateGameTable < ActiveRecord::Migration[7.0]
  def change
    create_table :games do |table|
      table.string  :name
      table.string  :platform
      table.string  :region
      table.timestamps
      table.index %i[name platform region], unique: true
    end
  end
end

CreateGameTable.migrate(:down) if ActiveRecord::Base.connection.table_exists? 'games'
CreateGameTable.migrate(:up)
