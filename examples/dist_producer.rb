#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'English'
require 'gosim'

require 'producer_consumer'

if __FILE__ == $PROGRAM_NAME
  num_clients = ARGV[0] || 1

  puts "Beginning distributed producer..."
  GoSim::Simulation.start_server num_clients

  consumer = Consumer.new
  producer = Producer.new(consumer.sid)

  GoSim::Simulation.run
  puts "Simulation complete..."
end
