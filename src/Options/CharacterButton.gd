extends X8OptionButton

# Chooses the playable character (X or Zeno). Read by Player.gd when a stage
# loads, so changing it mid-stage takes effect on the next stage.

func _ready() -> void:
	Event.connect("translation_updated",self,"display")

func setup() -> void:
	display()

func increase_value() -> void: #override
	toggle()

func decrease_value() -> void: #override
	toggle()

func toggle() -> void:
	if is_zeno():
		Configurations.set("CHARACTER", "X")
	else:
		Configurations.set("CHARACTER", "ZENO")
	display()

func is_zeno() -> bool:
	return Configurations.get("CHARACTER") == "ZENO"

func display():
	if is_zeno():
		display_value("ZENO_VALUE")
	else:
		display_value("X_VALUE")
