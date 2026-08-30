extends Control
## 经典 DOOM 火焰算法（逐元胞向上传播 + 37 阶调色板），纯代码无资源

const W := 132
const H := 74

var pal := PackedColorArray()
var cells := PackedInt32Array()
var tex: ImageTexture
var img: Image
var acc := 0.0

func _ready() -> void:
	_build_palette()
	cells.resize(W * H)
	img = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ignite()

func ignite() -> void:
	cells.fill(0)
	for x in W:
		cells[(H - 1) * W + x] = 36

func _process(delta: float) -> void:
	if not visible:
		return
	acc += delta
	if acc < 1.0 / 26.0:
		return
	acc = 0.0
	for x in W:
		for y in range(1, H):
			var src := y * W + x
			var v := cells[src]
			if v == 0:
				cells[src - W] = 0
			else:
				var r := randi() % 3
				var dst := clampi(src - W - r + 1, 0, W * H - 1)
				cells[dst] = maxi(v - (r & 1), 0)
	var bytes := PackedByteArray()
	bytes.resize(W * H * 4)
	for i in W * H:
		var c: Color = pal[cells[i]]
		bytes[i * 4] = int(c.r8)
		bytes[i * 4 + 1] = int(c.g8)
		bytes[i * 4 + 2] = int(c.b8)
		bytes[i * 4 + 3] = 255 if cells[i] > 0 else 235
	img.set_data(W, H, false, Image.FORMAT_RGBA8, bytes)
	tex.update(img)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)

func _build_palette() -> void:
	var stops := [
		Color(0.0, 0.0, 0.0), Color(0.12, 0.0, 0.0), Color(0.38, 0.03, 0.0),
		Color(0.62, 0.13, 0.01), Color(0.75, 0.24, 0.01), Color(0.87, 0.38, 0.03),
		Color(0.94, 0.57, 0.07), Color(0.99, 0.75, 0.13), Color(1.0, 0.9, 0.38),
		Color(1.0, 0.98, 0.7), Color(1.0, 1.0, 1.0),
	]
	for i in 37:
		var f := float(i) / 36.0
		var seg := f * float(stops.size() - 1)
		var i0 := int(seg)
		var i1 := mini(i0 + 1, stops.size() - 1)
		pal.push_back(stops[i0].lerp(stops[i1], seg - float(i0)))
