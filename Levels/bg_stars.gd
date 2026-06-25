extends Node2D

const STAR_COUNT = 150
const SCREEN_SIZE = Vector2(1280, 720) # match your project size

var stars = []

func _ready():
	for i in STAR_COUNT:
		stars.append({
			"pos": Vector2(randf() * SCREEN_SIZE.x, randf() * SCREEN_SIZE.y),
			"speed": randf_range(8.0, 25.0),
			"size": randf_range(1.0, 2.5),
			"color": Color(randf_range(0.7, 1.0), randf_range(0.7, 1.0), randf_range(0.8, 1.0), randf_range(0.4, 1.0))
		})

func _process(delta):
	for star in stars:
		star.pos.x += star.speed * delta
		if star.pos.x > SCREEN_SIZE.x:
			star.pos.x = 0
			star.pos.y = randf() * SCREEN_SIZE.y
	queue_redraw()

func _draw():
	for star in stars:
		draw_circle(star.pos, star.size, star.color)
