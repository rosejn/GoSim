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

      @space_map = SpaceMap.new(@main_window)
      @glade['map_scroller'].add(@space_map)

      @sim = Simulation.instance
      @sim_manager = SimManager.new(self)

      @reset_handlers = []

      @ticks_per_sec = 1
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

    def run
      Gtk.main
    end

    def on_quit
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
      puts "open trace file dialog..."
    end

    def on_open_live_sim
      puts "open sim file dialog..."
    end

    def on_time_forward
      @forwarding = true

      @sim.run(@sim.time + @ticks_per_sec)
      @cur_time.text = @sim.time.to_s
      Gtk.main_iteration while Gtk.events_pending?

      @forwarding = false
    end

    def on_time_back
      puts "time backward?"
    end

    def on_time_play
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
      @cur_time.text = @sim.time.to_s

      @reset_handlers.each {|h| h.call }
    end

    def add_reset_handler(&block)
      @reset_handlers << block
    end

=begin
      file_selection.ok_button.signal_connect('clicked') {
        filename = file_selection.filename
        $logger.log(DEBUG, "Open tracefile #{filename}")

        open_sim(filename)
        file_selection.hide()
      }

      file_selection.cancel_button.signal_connect('clicked') {
        file_selection.hide()
      }

      open_trace_item.signal_connect('activate') {
        file_selection.show()
      }

      # TODO: This might be an easier way to deal with dialogs, rather than
      # crowding the glade file etc...
      open_live_sim.signal_connect('activate') {
        fs = Gtk::FileSelection.new("Please select a live sim file.")

        fs.ok_button.signal_connect("clicked") do
          puts "Selected filename: #{fs.filename}"
          fs.hide
        end

        fs.cancel_button.signal_connect("clicked") do
          fs.hide
        end
        fs.show
      }

      file_selection.signal_connect('delete_event') {
        file_selection.hide()
        true
      }

      file_selection.signal_connect('delete_event') {
        file_selection.hide()
        true
      }

      @root_window = @widgets["main_window"]
      @root_window.signal_connect('destroy') { | x | quit() }

      scroll_window = @widgets["map_scroller"]
      @space_map = SimSpace.new(scroll_window)
      scroll_window.add(@space_map)

      @root_window.show_all()

      open_sim(filename) if not filename.nil?
=end
    def _check_nil
      if @sim_manager == nil
        $logger.log(USER, "You must open a trace file!");
        true
      else
        yield
        false
      end
    end

    def _init_handlers
      @glade["goto_time_item"].signal_connect('activate') do | item, event |
        @glade["goto_time_dialog"].show()
      end

      @glade["goto_time_cancel_button"].signal_connect('clicked') \
        do | item, event |
        @glade["goto_time_dialog"].hide()
        end

      @glade["goto_time_apply_button"].signal_connect('clicked') \
        do | item, event |
        _check_nil() {
        new_time = @glade["goto_time_entry"].text.to_i
      if new_time >= @sim_manager.time()
        @sim_manager.forward_to(new_time)
      else
        @sim_manager.internal_reset()
        @sim_manager.forward_to(new_time)
      end
      }
        end

      @glade["goto_time_ok_button"].signal_connect('clicked') \
        do | item, event |
        _check_nil() {
        @glade["goto_time_dialog"].hide()
      new_time = @glade["goto_time_entry"].text.to_i
      if new_time >= @sim_manager.time()
        @sim_manager.forward_to(new_time)
      else
        @sim_manager.internal_reset()
        @sim_manager.forward_to(new_time)
      end
      }
        end

      @glade["ticks_per_sec"].signal_connect("value-changed") \
        do | item, event |
        _check_nil() { @sim_manager.set_ticks_per_sec(item.value_as_int()) }
        end

      @glade["sim_per_view_sec"].signal_connect("value-changed") \
        do | item, event |
        _check_nil() { @sim_manager.set_sim_secs_per_sec(item.value()) }
        end

      @glade["zoom_factor_spin"].signal_connect("value-changed") \
        do | item, event |
        _check_nil() { @sim_manager.sim_window.zoom(item.value()) }
        end

      hndl = lambda { _check_nil() {
        # make sure we are not in play mode
        @glade["pause_play"].active = false
        @sim_manager.internal_reset()
        @sim_manager.forward_to(0)
      }
      }

      @glade["restart"].signal_connect("clicked") do | item, event |
        hndl.call()
      end

      @glade["restart_item"].signal_connect("activate") do | item, event |
        hndl.call()
      end

      hndl = lambda { _check_nil {
        # make sure we are not in play mode
        @glade["pause_play"].active = false
        @sim_manager._restore_state()
      }
      }

      @glade["back"].signal_connect("clicked") do | item, event |
        hndl.call()
      end

      @glade["back_item"].signal_connect("activate") do | item, event |
        hndl.call()
      end

      hndl = lambda { _check_nil {
        @glade["pause_play"].active = false
        @sim_manager._save_state()
        @sim_manager.forward_to(@sim_manager.time + @sim_manager.step_size())
      }
      }

      @glade["forward"].signal_connect("clicked") do | item, event |
        hndl.call()
      end

      @glade["forward_item"].signal_connect("activate") do | item, event |
        hndl.call()
      end

      t_handle = 0    # Keep track of GTK timer state
      @glade["pause_play"].signal_connect("toggled") do | item, event |
        if t_handle == 0
          # This somewhat non-obvious code checks for the untoggle if 
          if @glade["pause_play"].active? && _check_nil {
            t_handle = Gtk::timeout_add(1000) {
            @sim_manager._save_state()
            @sim_manager.forward_to(@sim_manager.time + @sim_manager.step_size())

            if @sim_manager.eof?
              $logger.log(DEBUG, "...end")
              @glade["pause_play"].active = false

              # ret chooses to reset the timer or to stop
              false
            else
              true
            end
          }
          } 
          #else, was nil
          @glade["pause_play"].active = false
          end
        else   #not item.active?
          Gtk.timeout_remove(t_handle)
          t_handle = 0
          $logger.log(DEBUG, "...pause...") if @sim_manager and not @sim_manager.eof?
        end
      end

      @glade["play_item"].signal_connect("activate") do | item, event |
        @glade["pause_play"].active = !@glade["pause_play"].active?
      end
    end
  end

  class Sim
    private

    HISTORY_SIZE = 100

    public

    attr_reader :time

    def initialize(trace, win)
      @root_window = win
      @trace = trace

      internal_init()
    end

    def step_size
      return @ticks_per_sec * @sim_secs_per_sec
    end

    def run_timeouts(t)
      if @timeouts.has_key?(t)
        @timeouts[t].each() do | block |
          block.call()
        end

        @timeouts.delete(t)
      end
    end

    def setup
      forward_to(0)
    end


    def internal_reset
      delete_all_objects()
      internal_init()
      @trace.reset();
    end

    def set_ticks_per_sec(tpsec)
      @ticks_per_sec = tpsec
    end

    def internal_init
      @classes = { }
      @backwards = []
      @time = 0
      @ticks_per_sec = @root_window.widgets["ticks_per_sec"].value_as_int()
      @timeouts = { }
      @sim_secs_per_sec = @root_window.widgets["sim_per_view_sec"].value_as_int()
      forward_to(0)
    end

    def delete_all_objects
      @classes.each() do | key, item |
        arr = key.downcase
      eval(<<-"stop" 
           $#{arr}.each() do | obj |
             obj.destroy()
           end
           $#{arr} = []
           stop
          )
      end
    end

    def _save_state
      state = {}
      @classes.each() do | key, item |
        arr = key.downcase
      type_state = []
      eval(<<-"stop" 
           $#{arr}.each() do | obj |
             type_state << Marshal.dump(obj)
           end
           stop
          )
          state[key] = type_state
      end

      @backwards << state
      @backwards.shift()  if(@backwards.length > HISTORY_SIZE)
    end

    def _restore_state
      if @backwards.length == 0
        new_time = @time - step_size()
        internal_reset()
        forward_to(new_time)
      else
        state = @backwards.pop()
        delete_all_objects()
        @timeouts = { }
        @time = @time - step_size()
        @trace.reset()  # This needs to be a smarter call to save time
        @classes.each() do | key, item |
          arr = key.downcase
        type_state = state[key]
        eval(<<-"stop" 
             type_state.each() do | obj |
               $#{arr} << Marshal.load(obj)
             end
             stop
            )
        end
        @root_window.widgets["cur_time"].text = print_time(@time)
      end
    end

    def forward_to(end_time)
      while(@time <= end_time && !eof?) do
        @trace.each_at_time(@time) do | event |
          eval(event)
        end
        run_timeouts(@time)
        @time = @time + 1
      end

      @root_window.widgets["cur_time"].text = print_time(@time)
    end

    def eof?
      @trace.eof?
    end

    def print_time(t)
      wall_time = t / @ticks_per_sec
      sprintf("%.2d:%.2d.%.3d", wall_time / 60, wall_time % 60, 
              t % @ticks_per_sec)
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
      @x = 0
      @y = 0

      # Do UI stuff
      @background = Gnome::CanvasRect.new(self.root, 
                                          :x1 => 0.0, :y1 => 0.0,
                                          :x2 => DEFAULT_SIZE, :y2 => DEFAULT_SIZE,
                                          :fill_color => BACKGROUND_COLOR)
      resize(DEFAULT_SIZE, DEFAULT_SIZE)
      self.show_all()
=begin
      @background.signal_connect("event") do |item, event|
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 1
          @drag_x = event.x
          @drag_y = event.y

          Selectable::unselect_current()
        elsif event.event_type == Gdk::Event::BUTTON_RELEASE && event.button == 1
          @drag_x = @drag_y = nil

          # TODO: Figure out coordinate scaling so the drag-scroll feels
          # normal.
        elsif event.event_type == Gdk::Event::MOTION_NOTIFY && @drag_x
          @parent.hadjustment.value += (event.x - @drag_x) 
          @parent.vadjustment.value += (event.y - @drag_y) 
          @drag_x = event.x
          @drag_y = event.y
        end
      end
=end
    end

    def resize(x, y)
      self.set_size_request(x, y)
      self.set_scroll_region(0, 0, x, y)
    end
  end

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


  class Selectable
    @@selected = nil

    def draw()
      if self == @@selected  
        draw_selected()
      else
        draw_unselected()
      end
    end

    def set_selected()
      @@selected = self
    end

    def Selectable.selected()
      return @@selected
    end

    def Selectable.unselect_current()
      @@selected.draw_unselected() if not @@selected.nil?
      @@selected = nil
    end
  end

  class SimManager
    attr_accessor :sim_to_real

    def initialize(view)
      @view = view
      @sim_to_real = 1
    end
  end
end
