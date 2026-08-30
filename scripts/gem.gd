extends Node2D
## 拾取物：经验数据包 / 恢复包 / 磁铁 / 宝箱

var main
var kind := "xp"        # xp | heal | magnet | chest
var value := 1
var t := 0.0
var pulled := false
var force_pull := false
var tex: Texture2D = null

func setup(m, p: Vector2, v: int, k := "xp") -> void:
	main = m
	position = p
	value = v
	kind = k
	t = randf() * TAU
	tex = KP.tex("gem")

func force_magnet() -> void:
	force_pull = true

func _physics_process(delta: float) -> void:
	t += delta
	var pl = main.player
	if pl != null and is_instance_valid(pl):
		var d: float = pl.global_position.distance_to(global_position)
		var magnet_r: float = 400.0 if kind == "chest" else pl.magnet
		if d < magnet_r or force_pull:
			pulled = true
		if pulled:
			global_position = global_position.move_toward(pl.global_position, 540.0 * delta)
			if global_position.distance_to(pl.global_position) < 22.0:
				main.collect_pickup(self)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	match kind:
		"xp":
			if tex != null:
				var s := 17.0 + value * 3.0
				draw_texture_rect(tex, Rect2(Vector2(-s * 0.5, -s * 0.5 + sin(t * 4.0) * 2.0), Vector2(s, s)), false)
			else:
				KP.draw_center(self, Vector2(0.0, sin(t * 4.0) * 2.0), "¤", 14 + value * 2, KP.YELLOW)
		"heal":
			var s := 9.0 + sin(t * 5.0) * 1.2
			draw_rect(Rect2(-s * 0.32, -s, s * 0.64, s * 2.0), Color(0.3, 0.95, 0.5))
			draw_rect(Rect2(-s, -s * 0.32, s * 2.0, s * 0.64), Color(0.3, 0.95, 0.5))
			draw_rect(Rect2(-s * 0.32, -s, s * 0.64, s * 2.0), Color(1, 1, 1, 0.5), false, 1.0)
		"magnet":
			var r := 9.0 + sin(t * 5.0) * 1.5
			draw_arc(Vector2.ZERO, r, PI, TAU, 20, KP.CYAN, 4.0)
			draw_line(Vector2(-r, 0.0), Vector2(-r, r * 0.6), KP.CYAN, 4.0)
			draw_line(Vector2(r, 0.0), Vector2(r, r * 0.6), Color(1, 0.4, 0.4), 4.0)
		"chest":
			var s := 15.0 + sin(t * 4.0) * 1.5
			draw_rect(Rect2(-s, -s * 0.8, s * 2.0, s * 1.6), Color(0.55, 0.36, 0.12))
			draw_rect(Rect2(-s, -s * 0.8, s * 2.0, s * 1.6), KP.GOLD, false, 2.0)
			draw_rect(Rect2(-s, -s * 0.25, s * 2.0, s * 0.5), KP.GOLD)
			draw_rect(Rect2(-3.0, -s * 0.4, 6.0, s * 0.8), Color(0.2, 0.08, 0.0))
			draw_arc(Vector2.ZERO, s * 1.7, 0.0, TAU, 32, Color(KP.GOLD, 0.25 + 0.15 * sin(t * 3.0)), 2.0)
