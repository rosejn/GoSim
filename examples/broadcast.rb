#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'English'

require 'gosim'

NUM_NODES = 10

Message = Struct.new(:htl)

class MyNode < GoSim::Net::Node
  def handle_message(msg)
    puts "Node #{@sid} got message..."
    msg.htl -= 1
    send_packet(@neighbor_ids, msg) unless msg.htl == 0
  end
end

nodes = []
NUM_NODES.times { nodes << MyNode.new }

# Create a circle of nodes.
nodes.each_with_index {|n,i| n.link(nodes[i-1].sid) }

# Only execute if we are run stand alone
if __FILE__ == $PROGRAM_NAME
  
  # Kick off one message that should travel around the circle
  nodes.first.handle_message(Message.new(NUM_NODES + 5))

  puts "Beginning simulation..."
  GoSim::Simulation.run
  puts "Simulation complete..."

end
