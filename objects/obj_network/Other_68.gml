var type = ds_map_find_value(async_load, "type");
var socket = ds_map_find_value(async_load, "id");
if (socket != socket_reliable && socket != socket_unreliable)
{
	PRINT($"Got event for unknown socket! ID: {socket}");
	exit;
}
var is_reliable = socket == socket_reliable;
PRINT($"Got networking event for reliable? {is_reliable} socket ID {socket}");

switch (type)
{
	case network_type_non_blocking_connect:
	{
		if (!is_reliable)
			break;
		
		if (!ds_map_find_value(async_load, "succeeded")) // !success
		{
			PRINT("Failed to connect!");
			break;
		}
		PRINT("Connected! Sending AUTH packet...");
		var buf = scr_simple_buffer([C2S.LOGIN]);
		network_send_raw(socket, buf, buffer_tell(buf));
		buffer_delete(buf);
	}
	break;
	case network_type_data:
	{
		var buffer = ds_map_find_value(async_load, "buffer");
		var size = ds_map_find_value(async_load, "size");
		buffer_seek(buffer, buffer_seek_start, 0);
		var data = array_create(size, 0);
		for (var i = 0; i < size; i++)
		{
			data[i] = buffer_read(buffer, buffer_u8);
		}
		on_get_data(data);
	}
	break;
}