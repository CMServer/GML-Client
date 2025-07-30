#macro UUIDv4LENGTH 36
#macro TIMEOUT_LENGTH 5
#macro SERVER_IP "127.0.0.1"
#macro SERVER_PORT 5150
#macro PRINT show_debug_message

enum C2S {
	LOGIN = 0x00,
	EVENT,
	PONG,
	BYE
}

enum S2C {
	IDENT = 0x00,
	EVENT,
	PING,
	SYNC,
	BYE
}

enum DisconnectReason {
	NONE = 0x00,
	CERR,
	SERR,
	SEND,
	TIME
}

#region Inlining scripts
// START INLINE
// scr_construct_event
enum FieldType
{
	FourByte = (0 << 0),
	Boolean = (1 << 0),
	CString = (1 << 1),
	EightByte = (1 << 2)
}

function scr_construct_event(event)
{
	if (!variable_instance_exists(id, "ident") || !is_connected())
	{
		throw ("scr_construct_event is missing ident variable!");
		exit;
	}
	var buffer = buffer_create(1 + FIELD_NAME_SIZE + FIELD_DATA_SIZE, buffer_grow, 1);
	buffer_seek(buffer, buffer_seek_start, 0); // pretty useless but just in case.
	buffer_write(buffer, buffer_u8, C2S.EVENT);
	buffer_write(buffer, buffer_string, event.name);
	buffer_write(buffer, buffer_u32, array_length(event.fields) + 1);
	buffer_write(buffer, buffer_string, "uuid");
	buffer_write(buffer, buffer_u8, FieldType.CString);
	buffer_write(buffer, buffer_string, ident);
	for (var i = 0; i < array_length(event.fields); i++)
	{
		var field = event.fields[i];
		
		buffer_write(buffer, buffer_string, field.name);
		switch (typeof(field.value))
		{
			case "bool":
			{
				buffer_write(buffer, buffer_u8, FieldType.Boolean);
				buffer_write(buffer, buffer_u8, field.value);
			}
			break;
			case "string":
			{
				buffer_write(buffer, buffer_u8, FieldType.CString);
				buffer_write(buffer, buffer_string, field.value);
			}
			break;
			case "number": // Now, you'd think this would be an int32, but no, all reals in GML are doubles.
			{
				buffer_write(buffer, buffer_u8, FieldType.EightByte); // so we write a double
				buffer_write(buffer, buffer_f64, field.value);
			}
			break;
			default:
			{
				buffer_write(buffer, buffer_u8, FieldType.FourByte);
				buffer_write(buffer, buffer_u32, field.value);
			}
			break;
		}
	}
	return buffer;
}

// scr_event_constructor
function Field(name, value) constructor
{
	self.name = name;
	self.value = value;
}

function Event(name, fields = []) constructor
{
	self.name = name;
	self.fields = fields;
	
	static find_field = function (name) {
		for (var i = 0; i < array_length(self.fields); i++) {
			var field = self.fields[i];
			if (field.name == name)
				return field;
		}
		return noone;
	}
}

// scr_parse_event
#macro FIELD_NAME_SIZE 16
#macro FIELD_DATA_SIZE 4

// I'm sorry.
function scr_parse_event(data)
{
	var event = [];
	array_copy(event, 0, data, 1, array_length(data) - 1);

	var name = scr_parse_string(event, 0, 0);
	var fields = [];
	var buffer = scr_simple_buffer(event, buffer_fixed);
	buffer_seek(buffer, buffer_seek_start, FIELD_NAME_SIZE);
	var field_count = buffer_read(buffer, buffer_u32);

	PRINT("Event name: " + string(name) + " Field count: " + string(field_count));

	var pos = FIELD_NAME_SIZE + FIELD_DATA_SIZE;

	for (var i = 0; i < field_count; i++)
	{
		if (pos + FIELD_NAME_SIZE > array_length(event))
		{
			PRINT("ERROR: Command failed decode! field name overflow. Ignoring");
			break;
		}

		var field_name = scr_parse_string(event, pos, 0);
		PRINT("Reading field (off. " + string(pos) + "): " + field_name);
		pos += FIELD_NAME_SIZE;

		if (pos + 1 > array_length(event))
		{
			PRINT("ERROR: Field failed decode! field flags. Ignoring");
			continue;
		}

		var flags = event[pos];
		pos += 1;

		var is_val_bool = (flags & (1 << 0)) != 0;
		var is_val_string = (flags & (1 << 1)) != 0;
		var is_val_large_int = (flags & (1 << 2)) != 0;

		var value = undefined;

		if (is_val_bool)
		{
			if (pos + 1 > array_length(event))
			{
				PRINT("ERROR: Field failed decode! field value. Ignoring");
			}
			else
			{
				value = (event[pos] != 0);
				pos += 1;
				PRINT("Bool value: " + string(value));
			}
		}
		else if (is_val_large_int)
		{
			if (pos + 8 > array_length(event))
			{
				PRINT("ERROR: Field failed decode! field value. Ignoring");
			}
			else
			{
				buffer_seek(buffer, buffer_seek_start, pos);
				value = buffer_read(buffer, buffer_f64);
				pos += 8;
				PRINT("Real value: " + string(value));
			}
		}
		else if (is_val_string)
		{
			var str = "", 
			overflow = false, 
			byte;
			do
			{
				if (pos >= array_length(event))
				{
					PRINT("ERROR: String failed decode! overflow. Ignoring");
					str = undefined;
					overflow = true;
					break;
				}

				byte = event[pos];
				pos += 1;

				if (byte != 0)
				{
					str += chr(byte);
				}
			}
			until (byte == 0);

			if (!overflow)
			{
				value = str;
				PRINT("String value: " + value);
			}
		}
		else if (flags == 0)
		{
			if (pos + FIELD_DATA_SIZE > array_length(event))
			{
				PRINT("ERROR: Field failed decode! field value. Ignoring");
			}
			else
			{
				var val = 0;
				for (var j = 0; j < FIELD_DATA_SIZE; j++)
				{
					val += event[pos + j] << (8 * j);
				}
				value = val;
				pos += FIELD_DATA_SIZE;
				PRINT("uint32_t value: " + string(value));
			}
		}
		else
		{
			PRINT("Can't understand unknown flag bits");
		}
		array_push(fields, new Field(field_name, value));
	}
	buffer_delete(buffer);

	return new Event(name, fields);
}

// scr_parse_string
function scr_parse_string(data, start, size)
{
	var str = "";
	if (size == 0) // is terminated
	{
		var cursor = 0x00;
		var i = start;
		do
		{
			cursor = data[i];
			i++;
			str += chr(cursor);
		}
		until (cursor == 0x00);
	}
	else
	{
		for (var i = start; i < start + size; i++)
		{
			str += chr(data[i]);
		}
	}
	return str;
}

// scr_simple_buffer
function scr_simple_buffer(data, type = buffer_fast)
{
	var size = array_length(data);
	var buffer = buffer_create(size, type, 1);
	buffer_seek(buffer, buffer_seek_start, 0); // useless function call?
	for (var i = 0; i < size; i++)
	{
		var byte = data[i];
		buffer_write(buffer, buffer_u8, byte);
	}
	return buffer;
}
#endregion

socket_reliable = network_create_socket(network_socket_tcp);
socket_unreliable = network_create_socket(network_socket_udp);
ident = "";
network_connect_raw_async(socket_reliable, SERVER_IP, SERVER_PORT);

tick_count = 0;
client_ticks = 0;
frames_since_last_update = 0;
event_listeners = [];
connect_listeners = [];

send_event = function(name, reliable)
{
	if (!is_connected()) {
		PRINT($"Tried to send event {name} before we're even identified!");
		exit;
	}
	
	var _ev = new Event(name);
	for (var i = 2; i < argument_count; i++)
	{
		array_push(_ev.fields, new Field(argument[i][0], argument[i][1]));
	}
	
	PRINT($"Sending event {name}: {_ev.fields}");
	var buf = scr_construct_event(_ev);
	if (reliable)
		network_send_raw(socket_reliable, buf, buffer_tell(buf));
	else
		network_send_udp_raw(socket_unreliable, SERVER_IP, SERVER_PORT, buf, buffer_tell(buf));
	buffer_delete(buf);
}

on_get_data = function(data)
{
	var type = data[0];
	switch (type)
	{
		case S2C.IDENT:
		{
			var uuid = scr_parse_string(data, 1, array_length(data) - 1);
			PRINT($"Our identification of size {string_length(uuid)} is: {uuid}");
			ident = uuid;
			PRINT("Identified! Sending unreliable connect event...");
			send_event("connect", false);
			// Custom code here...
			for (var i = 0; i < array_length(connect_listeners); i++) {
				var func = connect_listeners[i];
				func();
			}
		}
		break;
		case S2C.EVENT:
		{
			frames_since_last_update = 0;
			// Custom code here...
			var parsed_event = scr_parse_event(data);
			for (var i = 0; i < array_length(event_listeners); i++) {
				var func = event_listeners[i];
				func(parsed_event);
			}
		}
		break;
		case S2C.PING:
		{
			frames_since_last_update = 0;
			var buf = scr_simple_buffer([C2S.PONG]);
			network_send_udp_raw(socket_unreliable, SERVER_IP, SERVER_PORT, buf, buffer_tell(buf));
			buffer_delete(buf);
		}
		break;
	}
}

is_connected = function() { return string_length(ident) == UUIDv4LENGTH; }

add_connect_listener = function(func) {
	if (array_contains(connect_listeners, func))
		return;
	array_push(connect_listeners, func);
}

add_event_listener = function(func) {
	if (array_contains(event_listeners, func))
		return;
	array_push(event_listeners, func);
}