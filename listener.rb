#!/bin/env ruby

require 'rubygems'
require 'redis'
require 'json'
require 'xmpp4r'
require 'xmpp4r/roster'
require 'crack'
require 'yaml'

CONFIG_FILE = File.join(File.dirname(File.expand_path(__FILE__)), "config.yaml")

class QuoteBot

    include Jabber

    def initialize
      
        # Configuration from yaml file
        @config = YAML.load_file(CONFIG_FILE)

        # XMPP Configuation
        @jid = @config['xmpp']['jid']
        @password = @config['xmpp']['password']
        @buddies = @config['allowed_buddies']
        @presence = @config['xmpp']['presence']
        @xmpp_debug = @config['xmpp']['debug']
        @xmpp_client = Client.new(@jid)
        
        # Redis Configuration
        @redis_in_key = @config['redis']['queue_in_key']
        @redis_out_key = @config['redis']['queue_out_key']
        @redis_host = @config['redis']['hostname']
        @redis_port = @config['redis']['port']
        @redis_db = @config['redis']['db_number']    
        
        # We use two Redis clients, the "out" client is going to block on 
        # a background thread so it must be separate. 
        @redis_client = Redis.new(:host => @redis_host, 
            :port => @redis_port,  :db => @redis_db)
        @out_redis_client = Redis.new(:host => @redis_host, 
            :port => @redis_port, :db => @redis_db)

        Jabber::debug = @xmpp_debug
        connect
    end

    # Handles the connection to the XMPP server and gets ready to accept messages 
    # and process anything received on the queue to be sent back out.
    def connect
        @xmpp_client.connect
        @xmpp_client.auth(@password)
        @xmpp_client.send(Presence.new.set_type(:available))
        @xmpp_client.send(Presence.new.set_status(@presence))

        # Process the messages we receive
        start_message_callback

        # Handle any subscription/presence requests
        listen_for_subscription_requests

        # When the backend application has done its job, it tells the listener
        # via the "listener" message queue.
        process_queue
    end
    
    # Handles subscription/presence requests. It's configured to only allow 
    # whitelisted buddies (from the config) file to be authorized.
    def listen_for_subscription_requests
        @roster = Jabber::Roster::Helper.new(@xmpp_client)
        @roster.add_subscription_request_callback do |item, pres|
            # Only accept subscription requests from whitelisted JIDs
            if @buddies.include? pres.from.strip.to_s
                @roster.accept_subscription(pres.from)
            end            
        end
    end

    # Whatever we receive, we send it to our backend message queue. No processing of the 
    # message happens here except to see if the message comes from an approved buddy. It's 
    # the backend's job to do grunt work, this just merely accepts and passes on.
    def start_message_callback
        @xmpp_client.add_message_callback do |m|
            # Only process messages from people on our approved list
            if @buddies.include? m.from.strip.to_s
                # Only process chat messages with a body
                if m.type == :chat && !m.body.nil?
                    json_msg = {:from => m.from, :body => m.body}.to_json
                    # By pushing onto the the list, we effectively queue up 
                    # something for the backend to process.
                    @redis_client.lpush(@redis_in_key, json_msg)
                end
            end
        end
    end

    # The backend application talks to this XMPP interface via Redis. This method starts a 
    # thread that sits around and waits for items to show up on the outgoing queue. Our backend
    # is responsible for figuring out what should be sent, this portion should only have to worry 
    # about sending out what it is told to.
    def process_queue
        th = Thread.new do
            Thread.current.abort_on_exception = true
            loop do
                # Blocking pop operation will sit here until something shows up.
                # Expects the message on the queue to be of the format:
                # {"from": "<jid>", "body": "<message to send>"}
                # Todo: Needs better error handling here to validate the 
                # format of the message.
                key, raw_msg = @out_redis_client.blpop(@redis_out_key, 0)
                json_msg = Crack::JSON.parse(raw_msg)
                msg = Message::new(json_msg['from'])
                msg.type = :chat
                msg.body = json_msg['body']
                # Send the message
                @xmpp_client.send(msg)
            end
        end
    end

end

QuoteBot.new
Thread.stop