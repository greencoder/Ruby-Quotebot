#!/bin/env ruby

require 'rubygems'
require 'redis'
require 'json'
require 'crack'
require 'yaml'

CONFIG_FILE = File.join(File.dirname(File.expand_path(__FILE__)), "config.yaml")
QUOTE_FILE = File.join(File.dirname(File.expand_path(__FILE__)), "simpsons.txt")

class QuoteBackend

    def initialize
        @config = YAML.load_file(CONFIG_FILE)
        
        # Configure the Redis stuff from the configuration file
        @redis_in_key = @config['redis']['queue_in_key']
        @redis_out_key = @config['redis']['queue_out_key']
        @redis_host = @config['redis']['hostname']
        @redis_port = @config['redis']['port']
        @redis_db = @config['redis']['db_number']

        # Read all the quotes from the file
        @quotes = read_quotes
    end
    
    # We use run so that we can instantiate the class without running the 
    # redis connection and threads. This may be helpful for daemonizing things.
    def run
        # Connect to Redis
        @redis_client = Redis.new(:host => @redis_host, :port => @redis_port, 
            :db => @redis_db)
        # Start listening for items that show up on the queue.
        process_queue
    end

    # Just a wrapper method to read in a bunch of lines from a text file and return 
    # them as an array.
    def read_quotes
        tmp_quotes = []
        f = File.open(QUOTE_FILE, 'r')
        f.each_line do |line|
            tmp_quotes << line
        end
        f.close
        return tmp_quotes
    end

    # This method spawns a thread that will watch the queue for arriving messages. This 
    # is a blocking operation so it happens in a thread.
    def process_queue
        puts "Waiting for new messages"
        th = Thread.new do
            Thread.current.abort_on_exception = true
            loop do
                # This will sit around and wait forever.
                key, raw_msg = @redis_client.blpop(@redis_in_key, 0)
                json_msg = Crack::JSON.parse(raw_msg)
                # Send back a random quote
                random_quote = @quotes[rand(@quotes.size)]
                out_msg = {:from => json_msg['from'], :body => random_quote}.to_json
                # Pusing onto the "out" list queues up something for the listener to process
                @redis_client.lpush(@redis_out_key, out_msg)
            end
        end 
    end

end

QuoteBackend.new.run
Thread.stop