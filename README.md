Overview
================================
Quotebot is a Ruby XMPP bot that separates the receiving, processing, and sending of messages. It is meant as a starting point for others and uses a simple example of sending back a cartoon quote to any message received.

I have included some files to daemonize the processes - if someone knows a better way to do this, please let me know. Feedback appreciated!


Requirements
================================
This project requires a Jabber/XMPP account (GTalk works fine) and a Redis server. I haven't tested it with RedisToGo, but it should work. Also required are the Crack gem for JSON processing, XMPP4r, and Redis gems.



Configuration
================================
Rename the config.yaml.sample file to config.yaml and fill in your XMPP information. The default values for Redis should work fine but you may have to tweak them to work with existing Redis installations. 

There is a whitelist of allowed JIDs - add any that you would like to be able to use the bot. (I haven't considered making it wide open, but if that would be useful to people, let me know and I'll incorporate it)


Usage
================================
To run it without daemonizing:

    $ redis-server (in terminal 1)
    $ ruby backend.rb (in terminal 2)
    $ ruby listener.rb (in terminal 3)

To daemonize, move in the appropriate files from the extras/ folder:

    $ redis-server (in terminal 1)
    $ ruby backend_bot.rb start (in terminal 2)
    $ ruby listener_bot.rb start (in terminal 2)

I've included the shell scripts to start/stop.


Feedback
================================

Feedback is welcome and appreciated! Extra points for helping me improve my Ruby style.


Future Enhancements
================================
Instead of daemonize, I might want to use God to run this. I haven't used it before, so if someone wants to help with that, I'll add it.