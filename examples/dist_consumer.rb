#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'English'
require 'gosim'

require 'producer_consumer'

if __FILE__ == $PROGRAM_NAME
  puts "Beginning distributed consumer..."
  GoSim::Simulation.start_client 'localhost'
  puts "Simulation complete..."
end
