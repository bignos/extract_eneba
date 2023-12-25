# frozen_string_literal: true

require 'selenium-webdriver'

# Extracting Games from Eneba
class RemoteExtract
  ENEBA_URL_PATTERN = 'https://www.eneba.com/store/xbox-games?drms[]=xbox&page=%d&regions[]=argentina&regions[]=latam&regions[]=turkey&sortBy=ALPHABETICALLY_ASC&types[]=game'

  Game = Struct.new('Game', :name, :platform, :region, :price)

  # Accessors
  attr_reader :game_list

  # Constructor
  def initialize
    @scraper = init_scraper
    @game_list = []
  end

  # Return the web scraper instance(Selenium)
  def init_scraper
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')

    Selenium::WebDriver.for(:chrome, options: options)
  end

  # Extract all games from all pages
  # Fill @game_list
  #
  # @note Long Process Execution
  def all_games
    number_of_pages = init_number_of_pages
    (1..number_of_pages).each do |page|
      loading_percentage = (page.to_f / number_of_pages) * 100.0
      warn(format('Page: %<page>d Percentage: %<percentage>.2f%%', page: page, percentage: loading_percentage))
      page_game_list = games_from_page(page)
      redo if page_game_list.empty?
      page_game_list.each do |game|
        @game_list << game
      end
    end
  end

  # Extract Game list from an Eneba page
  #
  # @param page [Integer] The page index to extract
  # @param max_attempt [Integer] The maximum number of attempts to get the page
  # @param attempt_delay [Integer] The delay between attempts in seconds
  #
  # @return [Array<Game>] The game list
  def games_from_page(page, max_attempt = 5, attempt_delay = 30)
    url = format(ENEBA_URL_PATTERN, page)
    get_url_content_from_scraper(url, max_attempt, attempt_delay)
    @scraper.execute_script('window.scrollBy(200,1000)')
    sleep(2)

    extract_game_list_from_scraper
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
    url = format(ENEBA_URL_PATTERN, 1)
    @scraper.get(url)

    # Extract the total number of result
    total_result = @scraper.find_element(class: 'qOhwsO').text

    (total_result.to_f / 20.0).ceil
  end

  # Extract the game list from @scraper(The HTML page content)
  #
  # @return [Array of Game] The game list from the actual @scraper page
  def extract_game_list_from_scraper
    page_game_list = []

    complete_game_elements = @scraper.find_elements(class: 'pFaGHa')
    complete_game_elements.each do |element|
      name, platform = extract_name_and_platform_from_element(element)
      price = extract_price_from_element(element)
      region = extract_region_from_element(element)

      page_game_list << Game.new(name, platform, region, price)
    end

    page_game_list
  end

  # Get the page content from @scraper
  #
  # @param url [String] The url to get the content
  # @param max_attempt [Integer] The maximum number of attempts
  # @param attempt_delay [Integer] The delay between attempts
  def get_url_content_from_scraper(url, max_attempt = 5, attempt_delay = 30)
    attempt = 0
    while attempt < max_attempt
      begin
        @scraper.get(url)
        break
      rescue Net::ReadTimeout
        display_readtimeout_error(max_attempt, attempt_delay)
        attempt += 1
      end
    end
  end

  # Display ReadTimeout error and sleep attempt_delay seconds
  #
  # @param attempt_delay [Integer] The delay between attempts
  def display_readtimeout_error(attempt_delay)
    puts("Net::ReadTimeout. Retrying in #{attempt_delay} seconds") && sleep(attempt_delay)
  end

  # Extract the game name and platform from HTML element
  #
  # @param element [Selenium::WebDriver::Element] the HTML element containing the information to be extracted
  #
  # @return [String, String] The game name and the game platform
  def extract_name_and_platform_from_element(element)
    fetch_name_and_platform(element.find_element(xpath: './/span[@class=\'YLosEL\']').text)
  end

  # Extract the game price from HTML element
  #
  # @param element [Selenium::WebDriver::Element] the HTML element containing the information to be extracted
  #
  # @return [String] The game price
  def extract_price_from_element(element)
    begin
      price = element.find_element(xpath: './/span[@class=\'L5ErLT\']').text.gsub(/€(.*)/, '\1€')
    rescue Selenium::WebDriver::Error::NoSuchElementError
      price = nil
    end
    fetch_price(price)
  end

  # Extract the game region from HTML element
  #
  # @param element [Selenium::WebDriver::Element] the HTML element containing the information to be extracted
  #
  # @return [String] The game region
  def extract_region_from_element(element)
    element.find_element(xpath: './/div[@class=\'Pm6lW1\']').text
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

  # Clean the raw price, if the price is empty return 'Sold Out'
  #
  # @param raw_price [String] The extracted price
  #
  # @return [String] the price or 'Sold Out'
  def fetch_price(raw_price)
    raw_price.nil? ? 'Sold Out' : raw_price
  end
end
