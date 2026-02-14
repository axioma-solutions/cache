extends Control

func _draw():
	var center = size / 2
	var crosshair_size = 10
	var thickness = 2.0
	var color = Color.WHITE
	
	# Horizontal line
	draw_line(Vector2(center.x - crosshair_size, center.y), Vector2(center.x + crosshair_size, center.y), color, thickness)
	# Vertical line
	draw_line(Vector2(center.x, center.y - crosshair_size), Vector2(center.x, center.y + crosshair_size), color, thickness)
