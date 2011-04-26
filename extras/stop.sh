#!/bin/bash
export RUBYOPT=rubygems
d=`dirname $0`
ruby $d/backend_bot.rb stop
ruby $d/listener_bot.rb stop
