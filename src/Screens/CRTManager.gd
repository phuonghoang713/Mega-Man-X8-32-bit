extends Node

const crt = preload("res://src/Screens/CRT.tscn")
# Smoothing sits on layer 0, after the game world but below the HUD (layer 1+)
# and menus, so text and UI stay crisp.
const smooth_layer = preload("res://src/Screens/SmoothLayer.tscn")

var fullscreen := false

var light
var strong
var smooth
var crt_shader : CanvasLayer
var smooth_canvas : CanvasLayer

func _ready() -> void:
	crt_shader = crt.instance()
	get_parent().call_deferred("add_child",crt_shader)
	smooth_canvas = smooth_layer.instance()
	get_parent().call_deferred("add_child",smooth_canvas)
	Tools.timer(0.1,"late_initialization",self)


func late_initialization():
	light = crt_shader.get_node("Light")
	strong = crt_shader.get_node("Strong")
	smooth = smooth_canvas.get_node("Smooth")
	Configurations.listen("value_changed",self,"on_value_change")
	crt_changed()
	smooth_changed()


func on_value_change(key):
	if key == "CRT":
		crt_changed()
	elif key == "SMOOTH":
		smooth_changed()

# Smooth Colors is on unless the player turned it off.
func smooth_changed() -> void:
	smooth.visible = Configurations.get("SMOOTH") != false

func crt_changed() -> void:
	strong.visible = false
	light.visible = false
	match Configurations.get("CRT"):
		null:
			pass
		0:
			pass
		1:
			light.visible = true
		2:
			strong.visible = true

		
