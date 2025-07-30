if (!instance_exists(obj_network)) {
	draw_text(0, 0, "Press enter to connect to the remote server.");
	exit;
}

draw_set_color(c_green);
draw_circle(x, y, 10, false);

if (!obj_network.is_connected())
	exit;
	
var names = struct_get_names(positions);
for (var i = 0; i < array_length(names); i++)
{
	var name = names[i];
	var pos_data = positions[$ name];
	var _x = pos_data[0];
	var _y = pos_data[1];
	draw_set_color(c_red);
	draw_text(_x, _y - 30, name);
	draw_circle(_x, _y, 15, false);
}