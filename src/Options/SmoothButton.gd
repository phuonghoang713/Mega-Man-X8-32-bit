extends X8OptionButton

# Toggles the "Smooth Colors" pixel-art upscaling shader (see CRTManager.gd).

func _ready() -> void:
	Event.connect("translation_updated",self,"display")

func setup() -> void:
	display()

func increase_value() -> void: #override
	toggle()

func decrease_value() -> void: #override
	toggle()

func toggle() -> void:
	Configurations.set("SMOOTH", not is_on())
	display()

func is_on() -> bool:
	return Configurations.get("SMOOTH") != false

func display():
	if is_on():
		display_value("ON_VALUE")
	else:
		display_value("OFF_VALUE")
