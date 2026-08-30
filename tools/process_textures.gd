extends SceneTree
## 无头贴图后处理工具（一次性运行）：
##   godot --headless --path kernel-panic --script res://tools/process_textures.gd
## 自适应抠图：自动检测源图背景是深色还是浅色，从边缘洪泛填充把背景抠成透明
##（保留精灵内部同色区域），再对边缘做羽化，最后缩放输出。

const SRC_DIR := "C:/Users/Administrator/.zcode/workspace/default/assets_gen_anime"
const DST_DIR := "C:/Users/Administrator/.zcode/workspace/default/kernel-panic/assets/sprites"

const KEYED := ["player", "enemy_glitch", "enemy_runner", "enemy_tank", "enemy_elite", "bullet", "gem", "logo_mascot"]
const OPAQUE_BGS := ["title_bg", "arena_bg", "gameover_bg"]

const DARK_T := 0.09
const LIGHT_T := 0.90
const LIGHT_SAT_MAX := 0.28
const FEATHER_T := 0.32

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DST_DIR)
	for n in KEYED:
		_process_sprite(n)
	for n in OPAQUE_BGS:
		_process_bg(n)
	print("[PROCESS] all done")
	quit(0)

func _load_src(name: String) -> Image:
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var p := "%s/%s.%s" % [SRC_DIR, name, ext]
		if FileAccess.file_exists(p):
			return Image.load_from_file(p)
	return null

func _process_sprite(name: String) -> void:
	var img := _load_src(name)
	if img == null:
		print("[SKIP] %s: cannot load source" % name)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(256, 256, Image.INTERPOLATE_NEAREST)
	var light_mode := _detect_light_bg(img)
	_flood_key(img, light_mode)
	_feather_edges(img, light_mode)
	var err := img.save_png("%s/%s.png" % [DST_DIR, name])
	print("[OK] %s (light_bg=%s) -> %s" % [name, light_mode, error_string(err)])

func _process_bg(name: String) -> void:
	var img := _load_src(name)
	if img == null:
		print("[SKIP] %s: cannot load source" % name)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var k := 1024.0 / float(maxi(w, h))
	img.resize(int(w * k), int(h * k), Image.INTERPOLATE_LANCZOS)
	var err := img.save_png("%s/%s.png" % [DST_DIR, name])
	print("[OK] %s (%dx%d) -> %s" % [name, img.get_width(), img.get_height(), error_string(err)])

func _detect_light_bg(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var samples := [Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 3), Vector2i(w - 3, h - 3),
			Vector2i(w / 2, 2), Vector2i(w / 2, h - 3), Vector2i(2, h / 2), Vector2i(w - 3, h / 2)]
	var total := 0.0
	for s in samples:
		var c := img.get_pixel(s.x, s.y)
		total += maxf(c.r, maxf(c.g, c.b))
	return total / samples.size() > 0.5

func _is_bg_color(c: Color, light_mode: bool) -> bool:
	var l := maxf(c.r, maxf(c.g, c.b))
	if light_mode:
		var sat := 0.0
		var mx := maxf(c.r, maxf(c.g, c.b))
		var mn := minf(c.r, minf(c.g, c.b))
		if mx > 0.001:
			sat = (mx - mn) / mx
		return l > LIGHT_T and sat < LIGHT_SAT_MAX
	return l < DARK_T

func _flood_key(img: Image, light_mode: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dark := PackedByteArray()
	dark.resize(w * h)
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue := PackedInt32Array()
	var head := 0
	for y in h:
		for x in w:
			if _is_bg_color(img.get_pixel(x, y), light_mode):
				dark[y * w + x] = 1
	for x in w:
		if dark[x] == 1 and visited[x] == 0:
			queue.push_back(x)
			visited[x] = 1
		var i2 := (h - 1) * w + x
		if dark[i2] == 1 and visited[i2] == 0:
			queue.push_back(i2)
			visited[i2] = 1
	for y in h:
		var i3 := y * w
		if dark[i3] == 1 and visited[i3] == 0:
			queue.push_back(i3)
			visited[i3] = 1
		var i4 := y * w + w - 1
		if dark[i4] == 1 and visited[i4] == 0:
			queue.push_back(i4)
			visited[i4] = 1
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
		if x > 0:
			_push(queue, visited, dark, i - 1)
		if x < w - 1:
			_push(queue, visited, dark, i + 1)
		if y > 0:
			_push(queue, visited, dark, i - w)
		if y < h - 1:
			_push(queue, visited, dark, i + w)

func _push(queue: PackedInt32Array, visited: PackedByteArray, dark: PackedByteArray, i: int) -> void:
	if dark[i] == 1 and visited[i] == 0:
		visited[i] = 1
		queue.push_back(i)

func _feather_edges(img: Image, light_mode: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var adjusts: Array = []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l := maxf(c.r, maxf(c.g, c.b))
			var candidate := false
			var alpha := 1.0
			if light_mode:
				if l > 0.62:
					candidate = true
					alpha = clampf((LIGHT_T - 0.06 - l) / 0.22, 0.0, 1.0)
			elif l < FEATHER_T:
				candidate = true
				alpha = clampf((l - DARK_T) / (FEATHER_T - DARK_T), 0.0, 1.0)
			if not candidate or alpha >= 1.0:
				continue
			var near_trans := false
			if x > 0 and img.get_pixel(x - 1, y).a < 0.5:
				near_trans = true
			elif x < w - 1 and img.get_pixel(x + 1, y).a < 0.5:
				near_trans = true
			elif y > 0 and img.get_pixel(x, y - 1).a < 0.5:
				near_trans = true
			elif y < h - 1 and img.get_pixel(x, y + 1).a < 0.5:
				near_trans = true
			if near_trans:
				adjusts.append([x, y, alpha])
	for a in adjusts:
		var c2 := img.get_pixel(a[0], a[1])
		c2.a = a[2]
		img.set_pixel(a[0], a[1], c2)
