# frozen_string_literal: true

require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'database.db')

# ORM Class Game
class Game < ActiveRecord::Base
  has_many :snapshots
end
