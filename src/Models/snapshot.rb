# frozen_string_literal: true

require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'database.db')

class Snapshot < ActiveRecord::Base
end
