extends Node

# Brief global slow-down when a saber hit connects. Measured in real time and
# processed even while paused, so the game speed is always restored.

const SLOW_SCALE := 0.05

var end_msec := 0

func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	set_process(false)

func trigger(seconds: float) -> void:
	end_msec = int(max(end_msec, OS.get_ticks_msec() + seconds * 1000.0))
	Engine.time_scale = SLOW_SCALE
	set_process(true)

func _process(_delta: float) -> void:
	if OS.get_ticks_msec() >= end_msec:
		restore()

func restore() -> void:
	Engine.time_scale = 1.0
	set_process(false)

func _exit_tree() -> void:
	if is_processing():
		restore()
