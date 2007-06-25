#include <ruby.h>
#include <intern.h>
#include <stdio.h>

#include "fib.h"

typedef struct Event {
	VALUE method;
	VALUE receiver;
	VALUE data;
	VALUE id;
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
static ID data_hash_id = Qnil;
static ID entities_id = Qnil;
static ID object_id = Qnil;
VALUE rb_gosim;
VALUE rb_simulation;

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
		VALUE dest_sid, 
		VALUE time, 
		VALUE data)
{
	Event *event;

	VALUE entities = rb_ivar_get(self, entities_id);
	VALUE receiver = rb_hash_aref(entities, dest_sid);
	VALUE data_hash = rb_cvar_get(rb_simulation, data_hash_id);

	if(NIL_P(receiver) || !rb_respond_to(receiver, SYM2ID(event_id)))
	{
		rb_raise(rb_eRuntimeError, 
				"Cannot schedule %s.%s with sid=(%d), invalid method name!", 
				rb_class2name(CLASS_OF(receiver)),
				rb_id2name(SYM2ID(event_id)),
				FIX2INT(dest_sid)); 
	}

	event = malloc(sizeof(Event));
	event->method = SYM2ID(event_id);
	event->receiver = receiver;
	event->data = data;
	event->id = rb_funcall(data, object_id, 0);

	event->time = NUM2LONG(time) + NUM2LONG(rb_ivar_get(self, time_id));
	fh_insert(event_queue, (void *)event);

  // Store a reference to the data in the hash so it doesn't get garbage
	// collected.
	rb_hash_aset(data_hash, event->id, data);

	return Qnil;
}

static VALUE run_main_loop(
		VALUE self,
		VALUE end_time)
{
	VALUE running_var_name = rb_intern("@running");
	VALUE running = rb_ivar_get(self, running_var_name);
	VALUE data_hash = rb_cvar_get(rb_simulation, data_hash_id);

	Event *cur_event = fh_min(event_queue);
	long end = NUM2LONG(end_time);

	while((running == Qtrue) && (cur_event != NULL) && (cur_event->time <= end))
	{
		cur_event = fh_extractmin(event_queue);
		rb_ivar_set(self, time_id, LONG2NUM(cur_event->time));

		/*
		printf("%ld: %s.%s\n", 
				cur_event->time,
				rb_class2name(CLASS_OF(cur_event->receiver)),
				rb_id2name(cur_event->method));
				*/

		//rb_funcall(cur_event->receiver, send_id, 2, cur_event->method, cur_event->data);
		rb_funcall(cur_event->receiver, cur_event->method, 1, cur_event->data);

		rb_hash_delete(data_hash, cur_event->id);
		free(cur_event);

		cur_event = fh_min(event_queue);
		running = rb_ivar_get(self, running_var_name);
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
	rb_gosim = rb_define_module("GoSim");
	rb_simulation = rb_define_class_under(rb_gosim, "Simulation", rb_cObject);

	time_id = rb_intern("@time");
	send_id = rb_intern("send");
	data_hash_id = rb_intern("@data_hash");
	entities_id = rb_intern("@entities");
	object_id = rb_intern("object_id");

	rb_cvar_set(rb_simulation, data_hash_id, rb_hash_new(), Qfalse);

	rb_define_method(rb_simulation, "schedule_event", schedule_event, 4);
	rb_define_method(rb_simulation, "reset_event_queue", reset_event_queue, 0);
	rb_define_method(rb_simulation, "run_main_loop", run_main_loop, 1);
	rb_define_method(rb_simulation, "queue_size", queue_size, 0);
}
