extends Node2D
## 轻量特效：漂浮文字 / 字符碎片 / 扩散圆环

var kind := "text"
var text := ""
var color := Color.WHITE
var fsize := 16
var vel := Vector2.ZERO
var ttl := 0.6
var age := 0.0
var r0 := 0.0
var r1 := 0.0
var line_to := Vector2.ZERO
var bolt_points := PackedVector2Array()

func setup_line(a: Vector2, b: Vector2, c: Color) -> void:
	kind = "line"
	position = a
	line_to = b - a
	color = c
	ttl = 0.18
	# 折线闪电：中间随机两个拐点
	var mid1 := line_to * 0.33 + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
	var mid2 := line_to * 0.66 + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
	bolt_points = PackedVector2Array([Vector2.ZERO, mid1, mid2, line_to])

func draw_line_path(col: Color) -> void:
	for i in bolt_points.size() - 1:
		draw_line(bolt_points[i], bolt_points[i + 1], col, 3.0)
		draw_line(bolt_points[i], bolt_points[i + 1], Color(1, 1, 1, col.a * 0.7), 1.2)

func setup_text(p: Vector2, t: String, c: Color, s: int) -> void:
	kind = "text"
	position = p
	text = t
	color = c
	fsize = s
	ttl = 0.8

func setup_shard(p: Vector2, c: Color) -> void:
	kind = "shard"
	position = p
	color = c
	text = ["░", "▒", "▓"][randi() % 3]
	fsize = 10 + randi() % 8
	vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
	ttl = 0.45

func setup_dust(p: Vector2) -> void:
	kind = "shard"
	position = p
	color = Color(0.55, 0.78, 0.58, 0.55)
	text = "·"
	fsize = 13
	vel = Vector2(randf_range(-16.0, 16.0), randf_range(-40.0, -20.0))
	ttl = 0.55

func setup_ring(p: Vector2, c: Color, from_r: float, to_r: float) -> void:
	kind = "ring"
	position = p
	color = c
	r0 = from_r
	r1 = to_r
	ttl = 0.22

func _process(delta: float) -> void:
	age += delta
	if age >= ttl:
		queue_free()
		return
	if kind == "shard":
		position += vel * delta
		vel *= maxf(1.0 - delta * 4.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var k := age / ttl
	var col := Color(color, 1.0 - k)
	if kind == "text":
		KP.draw_center(self, Vector2(0.0, -k * 34.0), text, fsize, col)
	elif kind == "shard":
		KP.draw_center(self, Vector2.ZERO, text, fsize, col)
	elif kind == "ring":
		draw_arc(Vector2.ZERO, lerpf(r0, r1, k), 0.0, TAU, 40, col, 2.0)
	elif kind == "line":
		draw_line_path(col)
