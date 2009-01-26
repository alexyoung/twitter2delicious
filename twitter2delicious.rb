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

    link_and_tags = get_tweets_with_links
    post_links_to_delicious(link_and_tags)
  end

  def get_tweets_with_links
    search_url = "http://search.twitter.com/search.atom?q=from%3A#{CGI.escape @twitter_username}+filter%3Alinks"
    rss_items =  SimpleRSS.parse(open(search_url)).items

    rss_items.collect do |item, index|
      item_links = item.content.scan(/href=\"([^"]*)"/).flatten

      # Try to ignore @ replies and hash tags
      item_links = item_links.find_all { |url| not(url.match('http://twitter.com') or url.match(/\/search\?q=#/)) }

      # Look for hash tags
      hash_tags = item.content.scan(/#(\w*)/).flatten.collect { |tag| tag.sub /\/search\?q=/, '' }.uniq

      [ item_links, hash_tags ] 
    end
  end

  def post_links_to_delicious(links_and_tags)
    links_and_tags.each do |links, tags|
      links.each do |link|
        title = get_title(link)
        if title
          title.strip!
          puts "Posted: #{link}"
          @delicious.add link, title, nil, tags.join(' ')
        else
          puts "Error: Couldn't get a title for: #{link}"
        end
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
