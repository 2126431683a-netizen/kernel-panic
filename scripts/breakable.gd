extends Node2D
## 可破坏物：街道灯笼 / 服务器机柜——打爆掉经验或补给

var main
var kind := "lantern"
var hp := 1.0
var radius := 15.0
var dead := false
var t := 0.0

func setup(m, p: Vector2, k: String) -> void:
	main = m
	position = p
	kind = k
	hp = 1.0
	t = randf() * TAU

func hit(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		dead = true
		main.break_breakable(self)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if kind == "lantern":
		var sway := sin(t * 2.2) * 0.08
		draw_set_transform(Vector2.ZERO, sway, Vector2.ONE)
		draw_line(Vector2(0.0, -radius - 8.0), Vector2.ZERO, Color(0.35, 0.2, 0.15), 2.0)
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.25, 0.2, 0.9))
		draw_circle(Vector2.ZERO, radius * 0.62, Color(1.0, 0.62, 0.3, 0.95))
		draw_rect(Rect2(-radius * 0.45, radius * 0.72, radius * 0.9, 4.0), Color(0.75, 0.16, 0.14))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(Rect2(-radius, -radius * 1.3, radius * 2.0, radius * 2.6), Color(0.08, 0.12, 0.1), true)
		draw_rect(Rect2(-radius, -radius * 1.3, radius * 2.0, radius * 2.6), Color(0.2, 0.6, 0.4, 0.8), false, 1.5)
		for i in 3:
			var blink := 0.5 + 0.5 * sin(t * (3.0 + i) + float(i) * 2.1)
			draw_circle(Vector2(-radius * 0.45, -radius * 0.7 + i * 9.0), 2.2, Color(0.3, 1.0, 0.6, blink))
		draw_rect(Rect2(-radius * 0.6, radius * 0.25, radius * 1.2, radius * 0.8), Color(0.05, 0.09, 0.07))
