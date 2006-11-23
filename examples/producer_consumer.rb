#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__) + '/../lib')

# Uncomment this line to print out profiling information for the simulation.
#require 'profile'
require 'English'

require 'gosim'

NewProduct = Struct.new(:name)

class Producer < GoSim::Entity
  NUM_SHIPMENTS = 10
  PRODUCTS = ["Prosciutto", "Salami", "Formaggio", "Pomodori"]

  def initialize(neighbor)
    super()
    @neighbor = neighbor 

    # Schedule a bunch of new product events.
    NUM_SHIPMENTS.times do |t|
      evt = NewProduct.new(PRODUCTS[rand(PRODUCTS.size)])
      @sim.schedule_event(@sid, t * 10, evt)
    end
  end

  def handle_new_product(event)
    @sim.schedule_event(@neighbor, 5, event)
  end
end

class Consumer < GoSim::Entity
  def handle_new_product(event)
    puts "Received a new product: #{event.name} at #{@sim.time}"
  end
end

if __FILE__ == $PROGRAM_NAME
  consumer = Consumer.new
  producer = Producer.new(consumer.sid)

  puts "Beginning simulation..."
  GoSim::Simulation.run
  puts "Simulation complete..."
end
