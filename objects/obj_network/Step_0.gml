if (!is_connected())
	exit;

if (get_timer() % ((1 / 64) * 1_000_000))
	client_ticks++;
frames_since_last_update++;