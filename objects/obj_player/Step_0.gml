if (!instance_exists(obj_network)) {
	if (keyboard_check_pressed(vk_enter)) {
		instance_create_depth(0, 0, 0, obj_network);
		obj_network.add_connect_listener(custom_connect_listener);
		obj_network.add_event_listener(custom_event_listener);
	}
	exit;
}

if (!obj_network.is_connected())
	exit;

var move_dir = [0, 0];
move_dir[0] = keyboard_check(vk_right) - keyboard_check(vk_left);
move_dir[1] = keyboard_check(vk_down) - keyboard_check(vk_up);
x += move_dir[0] * 4;
y += move_dir[1] * 4;
if (move_dir[0] != 0 || move_dir[1] != 0)
	obj_network.send_event("move", false, ["x", x], ["y", y]);