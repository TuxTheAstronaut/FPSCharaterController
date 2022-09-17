extends Node

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("press ESCAPE to show mouse")
	print("press F11 to fullscreen")
	self.process_mode = Node.PROCESS_MODE_ALWAYS # allows this script to still process when game is paused
	DisplayServer.window_set_min_size(Vector2i(1152,648))

# pauses game when user hits escape
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			match Input.get_mouse_mode():
				Input.MOUSE_MODE_VISIBLE:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					get_tree().paused = false
				Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					get_tree().paused = true
		if event.keycode == KEY_F11:
			if DisplayServer.window_get_mode() != 3:
				DisplayServer.window_set_mode(3)
			else:
				DisplayServer.window_set_mode(0)
				DisplayServer.window_set_flag(1, false)
