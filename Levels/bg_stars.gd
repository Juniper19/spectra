extends Node2D

const SCREEN_SIZE = Vector2(1280, 720)
const COLS = 8
const ROWS = 5

var stars = []
var camera: Camera2D
var _redraw_accum: float = 0.0
const REDRAW_INTERVAL: float = 1.0 / 30.0

func _ready():
	camera = get_tree().get_first_node_in_group("camera")
	_generate_stars()

func _generate_stars():
	stars.clear()
	var cell_w = SCREEN_SIZE.x / COLS
	var cell_h = SCREEN_SIZE.y / ROWS
	for i in COLS:
		for j in ROWS:
			var bright = false ## CHANGE IF U WANT BIG ONES AGAIN
			var tinted = not bright and randf() > 0.55
			var angle = randf() * TAU
			stars.append({
				"cell": Vector2(i, j),
				"offset": Vector2(
					randf() * cell_w * 0.8 + cell_w * 0.1,
					randf() * cell_h * 0.8 + cell_h * 0.1
				),
				"drift": Vector2(cos(angle), sin(angle)) * randf_range(4.0, 12.0),
				"drift_offset": Vector2.ZERO,
				"size": randf_range(8.0, 18.0) if bright else randf_range(3.0, 7.0) if tinted else randf_range(1.0, 2.5),
				"rotation": randf() * PI,
				"bright": bright,
				"tinted": tinted,
				"hue": randf(),
				"twinkle_offset": randf() * TAU,
				"twinkle_speed": randf_range(0.5, 2.0),
				"fade": 1.0,
				"fading_out": false,
			})

func _process(delta):
	for star in stars:
		star.drift_offset += star.drift * delta

		if star.drift_offset.length() > 80.0 and not star.fading_out:
			star.fading_out = true

		if star.fading_out:
			star.fade -= delta * 1.5
			if star.fade <= 0.0:
				star.drift_offset = Vector2.ZERO
				star.fading_out = false
				star.fade = 0.0
		else:
			star.fade = min(star.fade + delta * 1.5, 1.0)

	_redraw_accum += delta
	if _redraw_accum >= REDRAW_INTERVAL:
		_redraw_accum -= REDRAW_INTERVAL
		queue_redraw()

func soft_glow(pos: Vector2, radius: float, color: Color, layers: int = 4):
	# white hot center bleeding outward into color
	for i in layers:
		var t = float(i) / float(layers)
		var r = radius * t
		# inner layers are near-white, outer layers are full color, edges transparent
		var white_mix = 1.0 - t
		var c = Color(
			lerpf(1.0, color.r, t),
			lerpf(1.0, color.g, t),
			lerpf(1.0, color.b, t),
			color.a * (1.0 - t) * (1.0 - t) * 0.4
		)
		draw_circle(pos, r, c)

func draw_spike_star(pos: Vector2, size: float, rot: float, color: Color, spikes: int = 4):
	var points = []
	for i in spikes * 2:
		var angle = rot + (i * PI / spikes)
		var r = size if i % 2 == 0 else size * 0.08
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
	for i in points.size():
		draw_line(points[i], pos, color, 1.2, true)
		draw_line(points[(i + 1) % points.size()], pos, color, 0.6, true)

func _draw():
	var t = Time.get_ticks_msec() / 1000.0
	var cam_pos = Vector2.ZERO
	if camera:
		cam_pos = camera.get_screen_center_position()

	var cell_w = SCREEN_SIZE.x / COLS
	var cell_h = SCREEN_SIZE.y / ROWS
	var tile_x = floor(cam_pos.x / SCREEN_SIZE.x)
	var tile_y = floor(cam_pos.y / SCREEN_SIZE.y)

	for tx in range(tile_x - 1, tile_x + 2):
		for ty in range(tile_y - 1, tile_y + 2):
			var world_offset = Vector2(tx * SCREEN_SIZE.x, ty * SCREEN_SIZE.y)
			for star in stars:
				var world_pos = world_offset + star.cell * Vector2(cell_w, cell_h) + star.offset + star.drift_offset
				var draw_pos = world_pos - cam_pos * 0.15 + SCREEN_SIZE * 0.5

				if draw_pos.x < -100 or draw_pos.x > SCREEN_SIZE.x + 100:
					continue
				if draw_pos.y < -100 or draw_pos.y > SCREEN_SIZE.y + 100:
					continue

				var twinkle = (0.7 + 0.3 * sin(t * star.twinkle_speed + star.twinkle_offset)) * star.fade

				if star.bright:
					var h = star.hue
					var core = Color.from_hsv(h, 0.4, 1.0)

					soft_glow(draw_pos, star.size * 5.0, Color(core.r, core.g, core.b, 0.5 * twinkle))
					soft_glow(draw_pos, star.size * 3.0, Color(core.r, core.g, core.b, 0.7 * twinkle))
					soft_glow(draw_pos, star.size * 1.5, Color(1.0, 1.0, 1.0, 0.9 * twinkle), 4)

					for j in 4:
						var spike_hue = fmod(h + j * 0.08, 1.0)
						var spike_color = Color.from_hsv(spike_hue, 1.0, 1.0, 0.6 * twinkle)
						var spike_rot = star.rotation + j * (PI / 4.0)
						draw_spike_star(draw_pos, star.size * 1.8, spike_rot, spike_color)

					draw_spike_star(draw_pos, star.size, star.rotation, Color(1, 1, 1, twinkle))
					soft_glow(draw_pos, star.size * 0.6, Color(1.0, 1.0, 1.0, twinkle), 4)

				elif star.tinted:
					var h = star.hue
					var c = Color.from_hsv(h, 0.6, 0.8)
					soft_glow(draw_pos, star.size * 2.5, Color(c.r, c.g, c.b, 0.2 * twinkle), 3)
					soft_glow(draw_pos, star.size * 1.2, Color(1.0, 1.0, 1.0, 0.15 * twinkle), 2)

				else:
					var col = Color(0.8, 0.85, 1.0, 0.4 * twinkle)
					draw_spike_star(draw_pos, star.size, star.rotation, col)
