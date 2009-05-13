#!/usr/bin/env ruby 

require 'rubygems'
require 'cgi'
require 'open-uri'
require 'timeout'
require 'optparse'

begin
  require 'rdelicious'
  require 'simple-rss'
  require 'hpricot'
rescue Exception
  puts 'Please install the simple-rss, hpricot and rdelicious gems'
  exit
end

begin
  require 'highline/import'
rescue LoadError
end

module UserInput
  def ask(question, block = nil)
    if Object.const_defined? :HighLine
      Object.ask question, block 
    else
      print question
      STDIN.gets.chomp
    end
  end

  def self.secure_ask(question)
    ask(question) { |q| q.echo = '*' }
  end
end

options = {}

ARGV.clone.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{$0} [options]" 

  opts.separator ""

  opts.on("-d", "--delicious=username", String, "Your Delicious username") { |o| options['delicious'] = o }
  opts.on("-p", "--password=password", String, "Your Delicious password") { |o| options['password'] = o }
  opts.on("-t", "--twitter=username", String, "Your Twitter username") { |o| options['twitter'] = o }
  opts.on("--help", "-H", "This text") { puts opts; exit 0 }

  opts.parse!
end

module WebTools
  def self.title(url)
    (Hpricot(open(url).read(10000))/"head/title").text
  rescue OpenURI::HTTPError => error
    "Error fetching page: #{error.io.status[0]}"
  rescue SocketError
    "Error fetching page: does the server even exist?"
  rescue
    p $!.class.name
    nil 
  end
end

class Twitter2Delicious
  def initialize(options)
    if options.empty?
      puts "Run with --help to see how to use command line options."
      @twitter_username = login_twitter
      @delicious = login_delicious
    else
      @twitter_username = options['twitter']
      @delicious = login_delicious options['delicious'], options['password']
    end

    link_and_tags = get_tweets_with_links
    post_links_to_delicious(link_and_tags)
  end

  def get_tweets_with_links
    search_url = "http://search.twitter.com/search.atom?q=from%3A#{CGI.escape @twitter_username}+filter%3Alinks"
    rss_items =  SimpleRSS.parse(open(search_url)).items

    rss_items.collect do |item, index|
      item_links = item.content.scan(/href=\"([^"]*)"/).flatten

      # Try to ignore @ replies and hash tags
      item_links = item_links.find_all do |url|
        not (url.match('http://twitter.com') or url.match(/\/search\?q=#/) or url.match(/\/search\?q=%23/))
      end

      # Look for hash tags
      hash_tags = item.content.scan(/#(\w*)/).flatten.collect { |tag| tag.sub /\/search\?q=/, '' }.uniq

      [ item_links, hash_tags ] 
    end
  end

  def post_links_to_delicious(links_and_tags)
    links_and_tags.each do |links, tags|
      links.each do |link|
        link = convert_tiny_url_if_required(link)
        title = get_title(link)
        if title
          title.strip!
          result = @delicious.add link, title, nil, tags.join(' ')

          if result.match /code="done"/
            puts "Posted: #{link}"
          else
            if result.match /code="access denied"/
              puts "Incorrect username or password"
              exit
            else
              puts "Error posting: #{link} -- check your password is correct"
              puts "API response:"
              puts result
            end
          end
        else
          puts "Error: Couldn't get a title for: #{link}"
        end
      end
    end
  end

  def convert_tiny_url_if_required(link)
    return link unless link.match 'http://tinyurl.com'

    response = Net::HTTP.get_response(URI.parse(link))
    return response['location']
  end

  def get_title(link)
    WebTools.title(link)
  end

  def login(service)
    puts "Logging into: #{service}"
    username = UserInput.ask "Enter username: "

    print "Enter password: "
    password = UserInput.secure_ask "Enter password: "

    [username, password]
  end

  def login_twitter
    UserInput.ask "Enter twitter username: "
  end

  def login_delicious(username = nil, password = nil)
    username, password = login('delicious') if username.nil? and password.nil?
    delicious = Rdelicious.new(username, password)
    if delicious.is_connected?
      puts "Connected to delicious\n"
      delicious
    else
      puts "Error: Login incorrect"
      login_delicious
    end 
  end
end

twitter2delicious = Twitter2Delicious.new(options)
