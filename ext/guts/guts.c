#include <ruby.h>
#include <intern.h>
#include <stdio.h>

/*
 * This is probably the most called method, and it's easy so it's a good one to
 * start with... :-)
    def schedule_event(event_id, dest_id, time, data)
      @event_queue.push(Event.new(event_id, dest_id, @time + time, data))
    end
*/

static ID event_q_id = Qnil;
static ID time_id		 = Qnil;
static ID new_id	   = Qnil;
static ID push_id		 = Qnil;
static ID event_class = Qnil;

static VALUE schedule_event(
		VALUE self, 
		VALUE event_sym, 
		VALUE dest_id, 
		VALUE time, 
		VALUE data)
{
	VALUE event;
	VALUE event_q;

	event_q = rb_ivar_get(self, event_q_id);

	event = rb_funcall(event_class, new_id, 4, 
			event_sym, 
			dest_id, 
			rb_funcall(time, rb_ivar_get(self, event_q_id), 0),
			data);

	printf("Inside schedule_event!");
	rb_funcall(event_q, push_id, 1, event);

	return event_q;
}

void Init_gosim_guts()
{
	VALUE rb_gosim;
	VALUE rb_simulation;

	rb_gosim = rb_const_get(rb_cObject, rb_intern("GoSim"));
//	rb_simulation = rb_const_get(rb_gosim, rb_intern("Simulation"));
	rb_simulation = rb_define_class_under(rb_gosim, "Simulation", rb_cObject);

	event_class = rb_const_get(rb_gosim, rb_intern("Event"));
	event_q_id = rb_intern("@event_queue");
	time_id = rb_intern("@time");
	new_id = rb_intern("initialize");
	push_id = rb_intern("push");

	rb_define_method(rb_simulation, "schedule_event", schedule_event, 4);
}
