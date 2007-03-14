require 'gtk2'
require 'libglade2'
require 'gnomecanvas2'

require 'gosim'

module GoSim
  class View
    include Singleton

    GLADE_FILE = File.expand_path(File.join(File.dirname(__FILE__), 
                                            'view.glade'))
    attr_reader :space_map, :controls, :data, :log

    def initialize
      Gtk.init

      @glade = GladeXML.new(GLADE_FILE) {|handler| method(handler)}
      @main_window = @glade['main_window']
      @about_dialog = @glade['about_dialog']
      @cur_time = @glade['current_time']

      @controls = @glade['controls']
      @data = @glade['data']
      @log = @glade['log']
      @file_selection = @glade['file_selection']

      @space_map = SpaceMap.new(@glade["map_scroller"])
      @glade['map_scroller'].add(@space_map)

      @sim = Simulation.instance
      @virt_time = 0
      @live = false   # ie, from a trace file

      @reset_handlers = []

      @ticks_per_sec = 2000
      @glade["ticks_per_sec"].value = @ticks_per_sec
      @glade["ticks_per_sec"].signal_connect("value-changed") do | item, event |
        @ticks_per_sec = item.value_as_int
      end

      @zoom_factor = 1.0
      @glade["zoom_factor"].signal_connect("value-changed") do | item, event |
        @zoom_factor = item.value_as_int
      end

      @forwarding = false
      @playing = false
      @play_stop_lbl = @glade["play_stop"]
    end

    def live=(arg)
      @live = arg  if @sim.time == 0
    end

    def run
      Gtk.main
    end

    def on_quit
      GoSim::Data::DataSetWriter::instance.flush_all
      Gtk.main_quit
    end

    def on_help_about
      @about_dialog.show
    end

    def on_about_ok
      @about_dialog.hide
    end

    def on_delete(widget)
    end

    def on_open_trace
      file = get_file_dialog("Open trace...")
      if(!file.nil?)
        puts "opening #{file}"
        @trace_events = GoSim::Data::DataSetReader.new(file)
      end
    end

    def on_open_live_sim
      show_error("Opening of simulations not currently supported from GUI.\nUse the command line.")
    end

    def on_time_forward
      @forwarding = true

      if !@live
        if @trace_events.nil?
          show_error("No trace has been opened.") 
          return
        else
          @trace_events.queue_to(@virt_time + @ticks_per_sec)
        end
      end

      Thread.new do
        @sim.run(@virt_time + @ticks_per_sec) 
      end

      @virt_time += @ticks_per_sec
      @cur_time.text = @virt_time.to_s
      Gtk.main_iteration while Gtk.events_pending?

      @forwarding = false
    end

    def on_time_back
      puts "time backward?"
    end

    def on_time_play
#      print "play button\n"

      @playing = !@playing
      if @playing
        @play_stop_lbl.text = "Stop"

        @play_timer = Gtk::timeout_add(1000) do
          if @playing
            on_time_forward unless @forwarding 
          end

          # TODO: This should stop automatically of the sim is over...
          true
        end
      else
        @play_stop_lbl.text = "Play"
        Gtk.timeout_remove(@play_timer)
        @sim.stop
        @cur_time.text = @sim.time.to_s
        Gtk.main_iteration while Gtk.events_pending?
      end
    end

    def on_time_reset
      on_time_play if @playing

      @sim.reset
      @virt_time = 0
      @cur_time.text = @virt_time.to_s

      @reset_handlers.each {|h| h.call }
    end

    def add_reset_handler(&block)
      @reset_handlers << block
    end

    def show_message(mesg, title = "Message")
      # Create the dialog
      dialog = Gtk::Dialog.new(title, @main_window,
                               Gtk::Dialog::DESTROY_WITH_PARENT,
                               [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE ])

      # Ensure that the dialog box is destroyed when the user responds.
      dialog.signal_connect('response') { dialog.destroy }

      # Add the message in a label, and show everything we've added to the dialog.
      
      dialog.vbox.add(Gtk::Label.new(("\n" + mesg + "\n").gsub("\n", "   \n   ")))
      #dialog.run
      dialog.show_all
    end

    def show_error(mesg, title = "Error")
      show_message(mesg, title)
    end

    def get_file_dialog(dialog_name = "Open...")
      file = nil
      fs = Gtk::FileChooserDialog.new(dialog_name, @main_window,
                                      Gtk::FileChooser::ACTION_OPEN, nil,
                                      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                      [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      if fs.run == Gtk::Dialog::RESPONSE_ACCEPT
        file = fs.filename
      end
      fs.destroy

      return file
    end
  end

  class SpaceMap < Gnome::Canvas
    DEFAULT_SIZE = 640
    BACKGROUND_COLOR = 'black'

    WITH_AA = true

    attr_reader :x, :y

    def initialize(parent)
      super(WITH_AA)

      @parent = parent

      # Do UI stuff
      @background = Gnome::CanvasRect.new(self.root, 
                                          :x1 => 0.0, :y1 => 0.0,
                                          :x2 => DEFAULT_SIZE, :y2 => DEFAULT_SIZE,
                                          :fill_color => BACKGROUND_COLOR)
      resize(DEFAULT_SIZE, DEFAULT_SIZE)
      self.show_all()
      @x, @y = DEFAULT_SIZE, DEFAULT_SIZE

      @background.signal_connect("event") do |item, event|
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 2
          @drag_x = event.x
          @drag_y = event.y
        elsif event.event_type == Gdk::Event::BUTTON_RELEASE && event.button == 2
          @drag_x = @drag_y = nil
        elsif event.event_type == Gdk::Event::MOTION_NOTIFY && @drag_x
          @parent.hadjustment.value += (event.x - @drag_x) * 0.5
          @parent.vadjustment.value += (event.y - @drag_y) * 0.5

          # This is horribly slow, but fine for now
          if @parent.hadjustment.value > 0 || @parent.vadjustment.value > 0
            resize(@parent.hadjustment.value + @x, @parent.vadjustment.value + @y)
          end

          @drag_x = event.x
          @drag_y = event.y
        end
      end
    end

    def resize(x, y)
      set_size_request(x, y)
      set_scroll_region(0, 0, x, y)
      @background.set({ :x2 => x, :y2 => y })
    end
  end

=begin
  class Log
    def initialize(buffer)
      @buffer = buffer
    end

    def log(text)
      @buffer.insert_at_cursor(text.strip + "\n")
      mark = @buffer.create_mark("end", @buffer.end_iter, false)
      scroll_to_mark(mark, 0.0, true, 0.0, 0.0)
      buffer.delete_mark(mark)
    end
  end
=end


end
