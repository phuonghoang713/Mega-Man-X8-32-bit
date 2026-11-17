extends Reference

# Loads Zeno's sprites from an Aseprite sprite-sheet export, if one is present:
#   res://src/Actors/Player/zeno_sprites/zeno.json  (Aseprite JSON, Hash or Array)
#   res://src/Actors/Player/zeno_sprites/zeno.png   (the sheet the JSON points to)
# Each Aseprite frame tag becomes an animation with the same name. Animations
# the game plays but the sheet lacks are filled from the closest drawn one, so
# Zeno never turns invisible; they are listed in the log so you know what to
# draw next. See zeno_sprites/README.md for the expected names.

const FOLDER := "res://src/Actors/Player/zeno_sprites/"
const DATA_FILE := "zeno.json"
const SHEET_FILE := "zeno.png"
const CONFIG_FILE := "zeno.cfg"

# Zeno-only animations used by the saber (ZSaber.gd). Optional.
const SABER_ANIMATIONS := ["saber_1", "saber_2", "saber_3", "saber_air", "saber_dash"]

# What to show for a missing animation, tried in order before "idle".
const FALLBACKS := {
	"walk_start": ["walk"], "stop": ["idle"], "stop_end": ["idle"], "turn": ["idle"],
	"jump": ["fall"], "fall": ["jump"], "walljump": ["jump", "fall"], "slide": ["fall"],
	"airdash": ["dash"], "boost": ["dash"], "boost_start": ["dash"], "boost_end": ["dash"],
	"damage_resist": ["damage"], "weak": ["damage"], "recover": ["idle"],
	"shot": ["saber_1"], "shot_strong": ["saber_2"], "counter": ["saber_3"],
	"crouch_talk": ["talk"], "stairs_start": ["stairs"], "stairs_end": ["stairs"],
	"wheelie_end": ["wheelie"], "break_end": ["break"],
}

# Returns {} when no custom sprites exist. Otherwise:
#   frames:  SpriteFrames with every animation `reference` has
#   offset:  sprite offset that puts Zeno's feet where X's are
#   missing: animation names that were filled with a fallback
static func build(reference: SpriteFrames, folder := FOLDER) -> Dictionary:
	var file := File.new()
	var data_path: String = folder.plus_file(DATA_FILE)
	if not file.file_exists(data_path):
		return {}
	if file.open(data_path, File.READ) != OK:
		push_error("Zeno sprites: cannot open " + data_path)
		return {}
	var parsed := JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or not parsed.result is Dictionary:
		push_error("Zeno sprites: %s line %d: %s" % [data_path, parsed.error_line, parsed.error_string])
		return {}
	var data: Dictionary = parsed.result

	var sheet_name := SHEET_FILE
	var meta: Dictionary = data.get("meta", {})
	if meta.get("image", "") != "":
		sheet_name = String(meta.image).get_file()
	var sheet := load_sheet(folder.plus_file(sheet_name))
	if not sheet:
		push_error("Zeno sprites: cannot load sheet " + folder.plus_file(sheet_name))
		return {}

	var frame_list := []
	var raw_frames = data.get("frames", [])
	if raw_frames is Array:
		frame_list = raw_frames
	elif raw_frames is Dictionary:
		for key in raw_frames:
			frame_list.append(raw_frames[key])
	if frame_list.empty():
		push_error("Zeno sprites: no frames in " + data_path)
		return {}

	var textures := []
	var durations := []
	var canvas := Vector2.ZERO
	for f in frame_list:
		var r: Dictionary = f.frame
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(r.x, r.y, r.w, r.h)
		var source := Vector2(r.w, r.h)
		if f.get("trimmed", false):
			var s: Dictionary = f.spriteSourceSize
			source = Vector2(f.sourceSize.w, f.sourceSize.h)
			atlas.margin = Rect2(s.x, s.y, source.x - r.w, source.y - r.h)
		elif f.has("sourceSize"):
			source = Vector2(f.sourceSize.w, f.sourceSize.h)
		canvas.x = max(canvas.x, source.x)
		canvas.y = max(canvas.y, source.y)
		textures.append(atlas)
		durations.append(max(1.0, float(f.get("duration", 100))))

	var frames := SpriteFrames.new()
	var tags: Array = meta.get("frameTags", [])
	if tags.empty():
		tags = [{"name": "idle", "from": 0, "to": frame_list.size() - 1, "direction": "forward"}]
	for tag in tags:
		var anim_name := String(tag.name)
		var order := tag_order(int(tag.from), int(tag.to), String(tag.get("direction", "forward")))
		if anim_name == "" or order.empty():
			continue
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		var total_ms := 0.0
		for i in order:
			if i >= 0 and i < textures.size():
				frames.add_frame(anim_name, textures[i])
				total_ms += durations[i]
		frames.set_animation_speed(anim_name, 1000.0 * order.size() / max(total_ms, 1.0))
		var loops := false
		if reference.has_animation(anim_name):
			loops = reference.get_animation_loop(anim_name)
		frames.set_animation_loop(anim_name, loops)

	var drawn := Array(frames.get_animation_names())
	drawn.erase("default")
	if drawn.empty():
		push_error("Zeno sprites: no usable animations in " + data_path)
		return {}
	if frames.has_animation("default") and frames.get_frame_count("default") == 0:
		frames.remove_animation("default")

	var missing := []
	for anim_name in reference.get_animation_names():
		if frames.has_animation(anim_name):
			continue
		var source_anim := pick_fallback(anim_name, frames, drawn)
		frames.add_animation(anim_name)
		for i in frames.get_frame_count(source_anim):
			frames.add_frame(anim_name, frames.get_frame(source_anim, i))
		frames.set_animation_speed(anim_name, frames.get_animation_speed(source_anim))
		frames.set_animation_loop(anim_name, reference.get_animation_loop(anim_name))
		missing.append(anim_name)

	# Put Zeno's feet where X's are. Both sprites are centered, so compare how
	# far below the frame center the lowest solid pixel of "idle" sits.
	var offset := Vector2.ZERO
	var zeno_feet := feet_below_center(frames.get_frame("idle", 0)) if frames.has_animation("idle") else NAN
	var x_feet := NAN
	if reference.has_animation("idle") and reference.get_frame_count("idle") > 0:
		x_feet = feet_below_center(reference.get_frame("idle", 0))
	if not is_nan(zeno_feet) and not is_nan(x_feet):
		offset.y = round(x_feet - zeno_feet)
	var config := load_config(folder)
	offset += config.get_value("sprite", "offset", Vector2.ZERO)

	var missing_saber := []
	for anim_name in SABER_ANIMATIONS:
		if not frames.has_animation(anim_name):
			missing_saber.append(anim_name)
	print("Zeno sprites: loaded %d animations from %s (canvas %dx%d)." % [drawn.size(), data_path, canvas.x, canvas.y])
	if not missing.empty():
		print("Zeno sprites: not drawn yet, using a stand-in: " + PoolStringArray(missing).join(", "))
	if not missing_saber.empty():
		print("Zeno sprites: optional saber animations not drawn: " + PoolStringArray(missing_saber).join(", "))

	return {"frames": frames, "offset": offset, "missing": missing}

static func load_config(folder := FOLDER) -> ConfigFile:
	var config := ConfigFile.new()
	var path: String = folder.plus_file(CONFIG_FILE)
	if File.new().file_exists(path) and config.load(path) != OK:
		push_error("Zeno sprites: cannot parse " + path)
	return config

static func load_sheet(path: String) -> Texture:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var imported = load(path)
		if imported is Texture:
			imported.flags = 0 # pixel art: no filtering, mipmaps or repeat
			return imported
	# Not imported by the editor yet: read the PNG directly.
	var image := Image.new()
	var real_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if image.load(real_path) != OK:
		return null
	var texture := ImageTexture.new()
	texture.create_from_image(image, 0)
	return texture

# Distance from the frame's center down to just below its lowest solid pixel,
# or NAN if it cannot be measured.
static func feet_below_center(texture: Texture) -> float:
	if not texture:
		return NAN
	var source: Texture = texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	var margin := Rect2()
	if texture is AtlasTexture:
		source = texture.atlas
		region = texture.region
		margin = texture.margin
	if not source:
		return NAN
	var image: Image = source.get_data()
	if not image or image.is_empty():
		return NAN
	var canvas_height := region.size.y + margin.size.y
	image.lock()
	var feet := -1
	var y := int(region.end.y) - 1
	while y >= int(region.position.y) and feet < 0:
		for x in range(int(region.position.x), int(region.end.x)):
			if image.get_pixel(x, y).a > 0.5:
				feet = y - int(region.position.y) + int(margin.position.y) + 1
				break
		y -= 1
	image.unlock()
	if feet < 0:
		return NAN
	return feet - canvas_height / 2.0

static func tag_order(from: int, to: int, direction: String) -> Array:
	var forward := range(from, to + 1)
	var backward := range(to, from - 1, -1)
	match direction:
		"reverse":
			return backward
		"pingpong":
			return forward + range(to - 1, from, -1)
		"pingpong_reverse":
			return backward + range(from + 1, to)
		_:
			return forward

static func pick_fallback(anim_name: String, frames: SpriteFrames, drawn: Array) -> String:
	for candidate in FALLBACKS.get(anim_name, []):
		if frames.has_animation(candidate) and candidate in drawn:
			return candidate
	if "idle" in drawn:
		return "idle"
	return drawn[0]
