# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'

# Extracting Games from Eneba
class RemoteExtract
  # ENEBA_URL_PATTERN = 'https://www.eneba.com/store/xbox-games?drms[]=xbox&page=%d&regions[]=argentina&regions[]=latam&regions[]=turkey&types[]=game'
  ENEBA_URL_PATTERN = 'https://www.eneba.com/store/xbox-games?drms[]=xbox&page=%d&regions[]=argentina&regions[]=latam&regions[]=turkey&sortBy=ALPHABETICALLY_ASC&types[]=game'

  Game = Struct.new('Game', :name, :platform, :region, :price)

  # Accessors
  attr_reader :game_list

  # Constructor
  def initialize
    @game_list = []
    @number_of_pages = 1
  end

  # Extract Game list from an Eneba page
  #
  # @param page [Integer] The page index to extract
  #
  # @return [Array<Game>] The game list
  def games_from_page(page)
    url         = format(ENEBA_URL_PATTERN, page)
    content     = Nokogiri::HTML(URI.parse(url).open)
    name_list   = games_name(content)
    region_list = games_region(content)
    price_list  = games_price(content)

    merge_name_price(name_list, region_list, price_list)
  end

  # Extract all games from all pages
  # Fill @game_list
  #
  # @note Long Process Execution
  def all_games
    @number_of_pages = init_number_of_pages
    (1..@number_of_pages).each do |page|
      loading_percentage = (page.to_f / @number_of_pages) * 100.0
      warn(format('Page: %<page>d Percentage: %<percentage>.2f%%', page: page, percentage: loading_percentage))
      page_game_list = games_from_page(page)
      redo if page_game_list.empty?
      page_game_list.each do |game|
        @game_list << game
      end
    end
  end

  # Print @game_list in markdown array format
  def print_markdown
    puts('| Game | Platform | Region | Price |')
    puts('| ---- | -------- | ------ | ----- |')
    @game_list.each do |game|
      puts("| #{game.name.gsub(/\|/, '\|')} | #{game.platform} | #{game.region} | #{game.price} |")
    end
  end

  private

  # Extract The total number of pages
  #
  # @return [Integer] Total number of pages
  def init_number_of_pages
    url     = format(ENEBA_URL_PATTERN, 1)
    content = Nokogiri::HTML(URI.parse(url).open)

    # Extract the total number of result
    total_result = content.css('span.qOhwsO').text

    (total_result.to_f / 20.0).ceil
  end

  # Extract all game's name from html_content
  #
  # @param html_content [Nokogiri::HTML4::Document] The HTML content of the page you want to extract
  #
  # @return [Array<String>] The list of all game's name present on html_content
  def games_name(html_content)
    name_list = []
    # CSS class for Title of the game "YLosEL"
    html_content.css('span.YLosEL').each do |game_name|
      name_list << game_name.content
    end

    name_list
  end

  # Extract all game's price from html_content
  #
  # @param html_content [Nokogiri::HTML4::Document] The HTML content of the page you want to extract
  #
  # @return [Array<String>] The list of all game's price present on html_content
  def games_price(html_content)
    price_list = []

    html_content.css('span.L5ErLT').each do |game_price|
      price_list << game_price.content.gsub(/€(.*)/, '\1€')
    end

    price_list
  end

  # Extract all game's region from html_content
  #
  # @param html_content [Nokogiri::HTML4::Document] The HTML content of the page you want to extract
  #
  # @return [Array<String>] The list of all game's region present on html_content
  def games_region(html_content)
    region_list = []

    html_content.css('div.Pm6lW1').each do |game_region|
      region_list << game_region.content
    end

    region_list
  end

  # Clean the raw price, if the price is empty return 'Sold Out'
  #
  # @param raw_price [String] The extracted price
  #
  # @return [String] the price or 'Sold Out'
  def fetch_price(raw_price)
    raw_price.nil? ? 'Sold Out' : raw_price
  end

  # Extract name and platform from the raw_name
  # If the extract fail, it use default values
  #
  # @param raw_name [String] The name extracted from the web page
  #
  # @return [String, String] The name and the platform
  def fetch_name_and_platform(raw_name)
    # rubocop:disable Lint/MixedRegexpCaptureTypes
    filter = (raw_name.match %r{(?<name>.*)\s\(?(?<plat>(PC|Xbox)[A-Z /|\\]+)\)? Key(|(?<region> [A-Z]*))}i)
    # rubocop:enable Lint/MixedRegexpCaptureTypes
    if filter.nil?
      warn("NO MATCH for: #{raw_name}")
      name     = raw_name
      platform = 'XBOX LIVE'
    else
      name     = filter[:name].strip.gsub(/ for$/, '')
      platform = filter[:plat].upcase
    end
    [name, platform]
  end

  # Merge game's name and price
  #
  # @param name_list [Array of String] The game's name list
  # @param region_list [Array of String] The game's region list
  # @param price_list [Array of String] The game's price list
  #
  # @return [Array<Game>] A Game list structure
  def merge_name_price(name_list, region_list, price_list)
    page_game_list = []
    name_list.each_with_index do |name, index|
      price = fetch_price(price_list[index])
      name_clean, platform = fetch_name_and_platform(name)
      page_game_list << Game.new(name_clean, platform, region_list[index], price)
    end
    page_game_list
  end
end
