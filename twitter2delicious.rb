#!/usr/bin/env ruby 

require 'rubygems'
require 'cgi'
require 'open-uri'
require 'timeout'

begin
  require 'rdelicious'
  require 'simple-rss'
  require 'hpricot'
rescue Exception
  puts 'Please install the simple-rss, hpricot and rdelicious gems'
  exit
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
  def initialize
    @twitter_username = login_twitter
    @delicious = login_delicious

    links = get_tweets_with_links
    post_links_to_delicious(links)
  end

  def get_tweets_with_links
    search_url = "http://search.twitter.com/search.atom?q=from%3A#{CGI.escape @twitter_username}+filter%3Alinks"
    rss_items =  SimpleRSS.parse(open(search_url)).items
    links = rss_items.collect { |item| item.content.scan(/href=\"([^"]*)"/) }.flatten

    # Try to ignore @ replies
    links.find_all { |url| not url.match("http://twitter.com") }
  end

  def post_links_to_delicious(links)
    links.each do |link|
      title = get_title(link)
      if title
        puts "Posted: #{title}"
        @delicious.add link, title
      else
        puts "Error: Couldn't get a title for: #{link}"
      end
    end
  end

  def get_title(link)
    WebTools.title(link)
  end

  def prompt(text)
    print text
    value = gets
    value.chomp!
  end

  def login(service)
    puts "Logging into: #{service}"
    username = prompt "Enter username: "

    print "Enter password: "
    password = prompt "Enter password: "

    [username, password]
  end

  def login_twitter
    prompt "Enter twitter username: "
  end

  def login_delicious
    username, password = login('delicious')
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

twitter2delicious = Twitter2Delicious.new
