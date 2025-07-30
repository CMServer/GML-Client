if (!is_connected()) {
	draw_set_color(c_white);
	draw_text(0, 0, "Waiting for auth...");
	exit;
}

if (frames_since_last_update / fps > TIMEOUT_LENGTH) {
	draw_set_color(c_red);
	draw_text(0, 0, "Lacking server updates for " + string(frames_since_last_update / fps) + " seconds.");
} else {
	draw_set_color(c_white);
	draw_text(0, 0, "server tick: " + string(tick_count) + "\nclient tick: " + string(client_ticks));
}