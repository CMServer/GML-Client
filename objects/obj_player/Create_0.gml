positions = {}

function custom_connect_listener() {
	obj_network.send_event("login", true);
}

function custom_event_listener(parsed_event) {
	var name = parsed_event.name;
	switch (name) {
		case "pos":
		{
			var _x = parsed_event.find_field("x");
			var _y = parsed_event.find_field("y");
			var _id = parsed_event.find_field("id");
			if (_x == noone || _y == noone || _id == noone)
				break;
					
			positions[$ _id.value] = [_x.value, _y.value]
		}
		break;
	}
}