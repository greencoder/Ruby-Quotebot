#!/bin/bash
export RUBYOPT=rubygems
d=`dirname $0`
ruby $d/backend_bot.rb start
ruby $d/listener_bot.rb start
