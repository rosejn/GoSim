#include "ruby.h"
#include "stdio.h"

/*
    def schedule_event(event_id, dest_id, time, data)
      #log "#{dest_id} is scheduling #{event_id} for #{@time + time}"
      event_id = ("handle_" + event_id.to_s).to_sym
      @event_queue.push(Event.new(event_id, dest_id, @time + time, data))
    end
*/


static ID event_q_id = Qnil;
static ID time_id		 = Qnil;
static ID new_id	   = Qnil;
static ID push_id		 = Qnil;

static VALUE schedule_event(VALUE self, 
		VALUE event_id, 
		VALUE dest_id, 
		VALUE time, 
		VALUE data)
{
	VALUE event_sym;
	VALUE event;
	VALUE event_q;
	
	event_sym = rb_str_intern(rb_str_concat(rb_str_new2("handle_"), event_id));
	event_q = rb_ivar_get(self, event_q_id);

	event = rb_funcall(event_class, new_id, 4, 
			event_sym, 
			dest_id, 
			rb_funcall(time, rb_ivar_get(self, event_q_id)),
			data);

	rb_funcall(event_q, push_id, 1, event);

	return event_q;
}

static VALUE test(VALUE self, VALUE num)
{
	//return rb_funcall(num, rb_intern("+"), 1, INT2FIX(10));
	return rb_
}

void Init_gosim_guts()
{
	VALUE rb_guts;

	event_q_id = rb_intern("@event_queue");
	time_id = rb_intern("@time");
	new_id = rb_intern("new");
	push_id = rb_intern("push");

	rb_guts = rb_define_module("Guts");
	rb_define_module_function(rb_guts, "schedule_event", schedule_event, 4);
	rb_define_module_function(rb_guts, "test", test, 1);
}
