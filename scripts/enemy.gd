extends Node2D
## 敌对进程：追逐玩家 + 正弦游走 + 简单群体分离（particle-life 风味）

const TYPES := {
	"glitch": {"glyph": "▓", "color": Color(1.0, 0.36, 0.36), "hp": 18.0, "speed": 95.0, "dmg": 8.0, "radius": 13.0, "size": 22, "xp": 1, "hop": 5.0},
	"runner": {"glyph": "◆", "color": Color(1.0, 0.72, 0.25), "hp": 10.0, "speed": 175.0, "dmg": 6.0, "radius": 10.0, "size": 19, "xp": 1, "hop": 10.0},
	"tank": {"glyph": "█", "color": Color(0.95, 0.3, 0.85), "hp": 75.0, "speed": 52.0, "dmg": 16.0, "radius": 19.0, "size": 32, "xp": 3, "hop": 3.5},
	"elite": {"glyph": "★", "color": Color(0.95, 1.0, 0.95), "hp": 170.0, "speed": 78.0, "dmg": 20.0, "radius": 22.0, "size": 36, "xp": 6, "hop": 7.0},
}

var main
var gtype := "glitch"
var glyph := "?"
var color := Color.WHITE
var hp := 10.0
var max_hp := 10.0
var speed := 100.0
var dmg := 8.0
var radius := 12.0
var size := 20
var xp_value := 1
var pid := 0
var dead := false
var flash := 0.0
var t := 0.0
var sep := Vector2.ZERO
var sep_phase := 0
var hop_phase := 0.0
var hop_height := 5.0
var facing := 1.0
var orbit_cd := 0.0
var is_boss := false
var tex: Texture2D = null

func setup(m, type: String, hp_mult: float) -> void:
	main = m
	gtype = type
	var c: Dictionary = TYPES[type]
	glyph = c["glyph"]
	color = c["color"]
	max_hp = c["hp"] * hp_mult
	hp = max_hp
	speed = c["speed"] * (0.9 + randf() * 0.2)
	dmg = c["dmg"]
	radius = c["radius"]
	size = c["size"]
	xp_value = c["xp"]
	pid = randi_range(1000, 9999)
	sep_phase = randi() % 3
	t = randf() * TAU
	hop_phase = randf() * TAU
	hop_height = c["hop"]
	tex = KP.tex("enemy_" + type)

func _physics_process(delta: float) -> void:
	if dead or main.player == null or not is_instance_valid(main.player):
		return
	t += delta
	var to_p: Vector2 = main.player.global_position - global_position
	var seek := to_p.normalized() * speed
	var wob := to_p.orthogonal().normalized() * sin(t * 3.0 + float(pid)) * 22.0
	if Engine.get_physics_frames() % 3 == sep_phase:
		sep = Vector2.ZERO
		var checked := 0
		var near: Array = main.grid_neighbors(global_position, 30.0)
		for o in near:
			if o == self or not is_instance_valid(o) or o.dead:
				continue
			var d2 := global_position.distance_squared_to(o.global_position)
			if d2 < 810.0 and d2 > 0.01:
				sep += (global_position - o.global_position).normalized() * 26.0 * (1.0 - d2 / 810.0)
				checked += 1
				if checked >= 8:
					break
	position += (seek + wob + sep) * delta
	hop_phase += delta * clampf(speed / 9.0, 3.0, 14.0)
	orbit_cd = maxf(orbit_cd - delta, 0.0)
	if main.player != null and is_instance_valid(main.player):
		var dx: float = main.player.global_position.x - global_position.x
		if absf(dx) > 6.0:
			facing = signf(dx)
	flash = maxf(flash - delta * 6.0, 0.0)
	queue_redraw()

func hit(d: float) -> void:
	if dead:
		return
	hp -= d
	flash = 1.0
	if hp <= 0.0:
		main.kill_enemy(self)
	else:
		main.update_boss_bar(self)

func _draw() -> void:
	var col := color.lerp(Color.WHITE, flash * 0.85)
	if hp < max_hp:
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var bar_pos := Vector2(-14.0, -radius - 12.0)
		draw_rect(Rect2(bar_pos, Vector2(28.0 * frac, 3.0)), col)
		draw_rect(Rect2(bar_pos, Vector2(28.0, 3.0)), Color(1, 1, 1, 0.12), false, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius * 1.1, Color(1, 1, 1, flash * 0.55))
	var hopv := absf(sin(hop_phase))
	var hop := hopv * hop_height
	var squash := 1.0 - (1.0 - hopv) * 0.12
	var wobble := sin(t * 4.0 + float(pid)) * 0.05
	draw_set_transform(Vector2(0.0, -hop), wobble, Vector2(facing * (1.0 + (1.0 - squash) * 0.8), squash))
	if tex != null:
		var sz := radius * 3.4
		draw_texture_rect(tex, Rect2(Vector2(-sz * 0.5, -sz * 0.5), Vector2(sz, sz)), false)
	else:
		KP.draw_center(self, Vector2.ZERO, glyph, size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
