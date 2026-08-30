extends Node2D
## 子弹：直线飞行 + 拖尾

var main
var vel := Vector2.ZERO
var damage := 10.0
var pierce := 1
var ttl := 1.2
var pt := 0.0
var tex: Texture2D = null

func setup(m, p: Vector2, v: Vector2, d: float, pc: int) -> void:
	main = m
	position = p
	vel = v
	damage = d
	pierce = pc
	tex = KP.tex("bullet")

func _physics_process(delta: float) -> void:
	position += vel * delta
	ttl -= delta
	pt += delta
	if ttl <= 0.0 or absf(position.x) > main.ARENA_W + 80.0 or absf(position.y) > main.ARENA_H + 80.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(pt * 18.0) * 0.1
	if tex != null and vel.length_squared() > 0.01:
		draw_set_transform(Vector2.ZERO, vel.angle(), Vector2(pulse, pulse))
		draw_texture_rect(tex, Rect2(Vector2(-15.0, -9.0), Vector2(30.0, 18.0)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		if vel.length_squared() > 0.01:
			draw_line(Vector2.ZERO, -vel.normalized() * 11.0, Color(0.3, 1.0, 1.0, 0.35), 2.0)
		KP.draw_center(self, Vector2.ZERO, "•", int(17.0 * pulse), KP.CYAN)
