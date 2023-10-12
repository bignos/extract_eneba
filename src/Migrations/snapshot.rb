# frozen_string_literal: true

require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'database.db')

# Create the snapshots table in the database
class CreateSnapshotTable < ActiveRecord::Migration[7.0]
  def change
    create_table :snapshots do |table|
      table.belongs_to :game, foreign_key: true
      table.datetime   :snap_date
      table.float      :price
      table.index %i[game_id snap_date price], unique: true
    end
  end
end

CreateSnapshotTable.migrate(:down) if ActiveRecord::Base.connection.table_exists? 'snapshots'
CreateSnapshotTable.migrate(:up)
