extends Button

var slot_index := 0
var on_drop: Callable

func _get_drag_data(_pos: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	preview.add_theme_color_override("font_color", Color("9ff5da"))
	set_drag_preview(preview)
	return {"slot": slot_index}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("slot")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	on_drop.call(int(data.slot), slot_index)
