# frozen_string_literal: true

require_relative 'remote_extract'
require_relative '../Models/game'
require_relative '../Models/snapshot'

# Help to extract data from database
# Static Class(NO INSTANTIATION)
class DataHelper
  Game4display = Struct.new('Game4display', :id, :name, :region, :price)

  # -[Class Methods]-
  class << self
    # Extract games from Eneba and save to database
    # When you extract games from Eneba you do a snapshot
    #
    # @note It's a very long process
    def extract_games_from_eneba
      eneba_extract = RemoteExtract.new

      eneba_extract.all_games
      now = DateTime.now.to_fs(:db)
      eneba_extract.game_list.each do |game|
        game_created = Game.find_or_create_by(name: game.name, platform: game.platform, region: game.region)
        Snapshot.create(game_id: game_created.id, snap_date: now, price: game.price.chomp('€'))
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end

    # Search for the more recent snapshot date
    #
    # @return [DateTime] The more recent snapshot date
    def more_recent_snap_date
      Snapshot.maximum(:snap_date)
    end

    # Search for the actual price on a specific game
    # Print all games match with the search patern
    #
    # @param game [String] The game you want to search
    def actual_price_for(game)
      search = Game.arel_table[:name]
      records = Game.includes(:snapshots).where(search.matches("%#{game}%")).order('snapshots.price')
      more_recent_snap_date_var = more_recent_snap_date
      records.where(snapshots: { snap_date: more_recent_snap_date_var }).each do |record|
        puts "#{record.id} #{record.name} [#{record.region}] : #{record.snapshots.first.price}"
      end
    end

    # Search for the actual price on a specific id
    #
    # @param id [Integer] The id of the game you want to search
    #
    # @return [Game4display] The game object corresponding to the id
    def actual_price_for_id(id)
      record = Game.includes(:snapshots).where(id: id, snapshots: { snap_date: more_recent_snap_date }).first
      return nil if record.nil?

      display_record(record)
      Game4display.new(record.id, record.name, record.region, record.snapshots.first.price)
    end

    # Print on STDOUT the record [id, name, region, actual_price]
    def display_record(record)
      puts "#{record.id} #{record.name} [#{record.region}] : #{record.snapshots.first.price}"
    end

    # Return the actual game price
    #
    # @param id [Integer] The id of the game
    #
    # @return [Float] The actual price of the game
    def actual_price_for_game_id(id)
      result = 0.0
      records = Game.includes(:snapshots).where(id: id).order('snapshots.price')
      records.where(snapshots: { snap_date: more_recent_snap_date }).each do |record|
        result = record.snapshots.first.price
      end
      result
    end

    # Check if the game with the id have is actual best price
    #
    # @param id [Integer] The id of the game you want to check
    #
    # @return [Boolean] True if actually the game is at the best price else False
    def best_price?(id)
      records = Game.includes(:snapshots).where(id: id).where.not(snapshots: { price: 0.0 }).order('snapshots.price')
      return false if records.empty?

      records.each do |game|
        best_price = game.snapshots.first.price
        actual_price = actual_price_for_game_id(id)

        return true if actual_price == best_price
      end
      false
    end

    # Display all new games from last snapshot
    def new_games
      more_recent_snap_date_var = more_recent_snap_date
      Game.includes(:snapshots).find_each do |game|
        if Snapshot.where(game_id: game.id).count == 1 && (game.snapshots.first.snap_date = more_recent_snap_date_var)
          puts "#{game.name} [#{game.region}] : #{game.snapshots.first.price}"
        end
      end
    end

    # Display only games with best price
    def actual_best_price
      records = Game.includes(:snapshots).where.not(snapshots: { price: 0.0 }).order('snapshots.price')
      more_recent_snap_date_var = more_recent_snap_date
      records.each do |game|
        # Condition print game if best price and last snapshot game
        best_price = game.snapshots.first.price
        game.snapshots.each do |snap|
          best_price = snap.price if best_price > snap.price
        end
        if game.snapshots.where(snap_date: more_recent_snap_date_var, price: best_price).count == 1
          puts "#{game.id} #{game.name} [#{game.region}] : #{best_price}€"
        end
      end
    end
  end

  # Disable new() method
  def initialize(*)
    raise TypeError, "\'#{self.class}\' cannot be instantiated."
  end
end
