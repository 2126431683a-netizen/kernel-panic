class_name KP
## 全局工具：终端风配色 + 等宽字体 + 居中绘制 + ASCII 大字

const GREEN := Color(0.24, 1.0, 0.49)
const DIM := Color(0.35, 0.75, 0.5)
const CYAN := Color(0.3, 1.0, 1.0)
const RED := Color(1.0, 0.33, 0.33)
const ORANGE := Color(1.0, 0.72, 0.25)
const MAGENTA := Color(0.95, 0.3, 0.85)
const YELLOW := Color(1.0, 0.85, 0.3)
const UI := Color(0.55, 1.0, 0.7)
const GOLD := Color(1.0, 0.82, 0.35)
const VERMILION := Color(0.92, 0.28, 0.22)
const JADE := Color(0.35, 0.95, 0.62)

static var _mono: SystemFont = null
static var _ui: SystemFont = null
static var _tex_cache := {}

static func ui_font() -> SystemFont:
	if _ui == null:
		_ui = SystemFont.new()
		_ui.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"])
	return _ui

static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := "res://assets/sprites/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[name] = t
	return t

static func font() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	return _mono

static func draw_center(canvas: CanvasItem, pos: Vector2, text: String, fsize: int, col: Color) -> void:
	var f := font()
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	canvas.draw_string(f, pos + Vector2(-sz.x * 0.5, fsize * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

static func figlet(text: String) -> String:
	var g := {
		"K": ["██╗  ██╗", "██║ ██╔╝", "█████╔╝ ", "██╔═██╗ ", "██║  ██╗", "╚═╝  ╚═╝"],
		"E": ["███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝"],
		"R": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║", "╚═╝  ╚═╝"],
		"N": ["███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝"],
		"L": ["██╗     ", "██║     ", "██║     ", "██║     ", "███████╗", "╚══════╝"],
		"P": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔═══╝ ", "██║     ", "╚═╝     "],
		"A": [" █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝"],
		"I": ["██╗", "██║", "██║", "██║", "██║", "╚═╝"],
		"C": [" ██████╗", "██╔════╝", "██║     ", "██║     ", "╚██████╗", " ╚═════╝"],
		" ": ["  ", "  ", "  ", "  ", "  ", "  "],
	}
	var rows := ["", "", "", "", "", ""]
	var first := true
	for ch in text:
		var glyph: Array = g.get(ch, g[" "])
		for r in 6:
			if not first:
				rows[r] += " "
			rows[r] += glyph[r]
		first = false
	return "\n".join(rows)
