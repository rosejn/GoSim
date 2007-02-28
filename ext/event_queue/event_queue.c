#include <ruby.h>
#include <intern.h>
#include <stdio.h>

#include "fib.h"

typedef struct Event {
	VALUE event_id;
	VALUE dest_id;
	VALUE data;
	long time;
} Event;

int compare_events(void *x, void *y)
{
	long a, b;
	a = ((Event*)x)->time;
	b = ((Event*)y)->time;

	if (a < b)
		return -1;
	if (a == b)
		return 0;
	return 1;
}

static struct fibheap *event_queue = NULL;
static ID time_id		 = Qnil;
static ID send_id		 = Qnil;

static VALUE reset_event_queue(
		VALUE self)
{
	if(event_queue != NULL)
		fh_deleteheap(event_queue);

	event_queue = fh_makeheap();
	fh_setcmp(event_queue, compare_events);

	return Qnil;
}

static VALUE schedule_event(
		VALUE self, 
		VALUE event_id, 
		VALUE dest_id, 
		VALUE time, 
		VALUE data)
{
	Event *event;

	event = malloc(sizeof(Event));
	event->event_id = event_id;
	event->dest_id = dest_id;
	event->data = data;

	event->time = NUM2LONG(time) + NUM2LONG(rb_ivar_get(self, time_id));
	fh_insert(event_queue, (void *)event);

	return Qnil;
}

static VALUE run_main_loop(
		VALUE self,
		VALUE end_time)
{
	VALUE running = rb_ivar_get(self, rb_intern("@running"));
	VALUE entities = rb_ivar_get(self, rb_intern("@entities"));

	Event *cur_event = fh_min(event_queue);
	long end = NUM2LONG(end_time);

	while((running == Qtrue) && (cur_event != NULL) && (cur_event->time <= end))
	{
		cur_event = fh_extractmin(event_queue);
		rb_ivar_set(self, time_id, LONG2NUM(cur_event->time));

		rb_funcall(rb_hash_aref(entities, cur_event->dest_id), send_id, 2,
				cur_event->event_id, cur_event->data);

		cur_event = fh_min(event_queue);
	}

	return Qnil;
}

static VALUE queue_size(
		VALUE self)
{
	return INT2NUM(fh_size(event_queue));
}

void Init_event_queue()
{
	VALUE rb_gosim;
	VALUE rb_simulation;

	//rb_gosim = rb_const_get(rb_cObject, rb_intern("GoSim"));
	//rb_simulation = rb_const_get(rb_gosim, rb_intern("Simulation"));
	rb_gosim = rb_define_module("GoSim");
	rb_simulation = rb_define_class_under(rb_gosim, "Simulation", rb_cObject);

	time_id = rb_intern("@time");
	send_id = rb_intern("send");

	rb_define_method(rb_simulation, "schedule_event", schedule_event, 4);
	rb_define_method(rb_simulation, "reset_event_queue", reset_event_queue, 0);
	rb_define_method(rb_simulation, "run_main_loop", run_main_loop, 1);
	rb_define_method(rb_simulation, "queue_size", queue_size, 0);
}
