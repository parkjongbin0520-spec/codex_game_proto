extends Node3D

const Spells = preload("res://scripts/spells.gd")
const Simulation = preload("res://scripts/simulation.gd")
const SlotButton = preload("res://scripts/slot_button.gd")
const INK := Color("0c1222")
const PANEL := Color("111b2beF")
const LINE := Color("2b3b4c")
const MINT := Color("9ff5da")
const MUTED := Color("8395ab")
const WHITE := Color("e9f0f5")
var sim = Simulation.new()
var camera: Camera3D
var mage: Node3D
var wand_tip: MeshInstance3D
var aim_ring: MeshInstance3D
var ui: Control
var font: Font
var slot_buttons: Array[Button] = []
var projectile_visuals: Dictionary = {}
var effects: Array = []
var target_nodes: Array[Node3D] = []
var mana_bar: ProgressBar
var mana_text: Label
var status_label: Label
var stats_label: Label
var log_label: Label
var hint_label: Label
var expression_label: Label
var selected_label: Label
var pitch_label: Label
var toast_label: Label
var crosshair: Label
var selected := 0
var camera_pitch := 38.0
var aim := Vector2(0, -12)
var firing := false
var paused := false
var clock := 0.0
var trail_clock := 0.0
var toast_time := 0.0
var hover_arena := false
var last_slot := -2
var last_waiting := false
var debug_clock := 0.0
var layout_nodes: Dictionary = {}

func _ready() -> void:
	font = load("res://assets/ui-font.otf")
	_build_world()
	_build_ui()
	_apply_preset(2)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, glow)
	node.position = pos
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = _material(color, glow)
	node.position = pos
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)
	return node

func _ring(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.025
	mesh.outer_radius = radius + 0.025
	mesh.rings = 48
	mesh.ring_segments = 6
	node.mesh = mesh
	node.material_override = _material(color, true)
	node.position = pos
	parent.add_child(node)
	return node

func _build_world() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("080f1e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a7b5da")
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -25, 0)
	light.light_color = Color("c8d3ff")
	light.light_energy = 1.4
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5, 1)
	fill.light_color = MINT
	fill.light_energy = 4
	fill.omni_range = 15
	add_child(fill)
	_box(self, Vector3(0, -0.28, -8), Vector3(22, 0.5, 30), Color("162233"))
	for x in range(-10, 11, 2):
		_box(self, Vector3(x, 0.005, -8), Vector3(0.018, 0.01, 28), Color("263b4b"), true)
	for z in range(-22, 7, 2):
		_box(self, Vector3(0, 0.006, z), Vector3(20, 0.01, 0.018), Color("263b4b"), true)
	for x in [-10.0, 10.0]:
		_box(self, Vector3(x, 0.04, -8), Vector3(0.045, 0.05, 28), MINT.darkened(0.55), true)
	for z in [-22.0, 6.0]:
		_box(self, Vector3(0, 0.04, z), Vector3(20, 0.05, 0.045), MINT.darkened(0.55), true)
	_ring(self, Vector3(0, 0.03, -9), 4.1, Color("355367"))
	_ring(self, Vector3(0, 0.03, -9), 4.4, Color("2c4658"))
	for wall in sim.walls:
		var center: Vector2 = wall.get_center()
		_box(self, Vector3(center.x, 0.42, center.y), Vector3(wall.size.x, 0.84, wall.size.y), Color("35404b"))
		_box(self, Vector3(center.x, 0.87, center.y), Vector3(wall.size.x + 0.04, 0.06, wall.size.y + 0.04), Color("dcb982"), true)
		for z in range(int(wall.position.y), int(wall.end.y), 2):
			_box(self, Vector3(center.x, 0.2, z), Vector3(wall.size.x + 0.06, 0.12, 0.2), Color("947f61"), true)
	for i in range(sim.targets.size()):
		var p: Vector2 = sim.targets[i]
		var target := Node3D.new()
		target.position = Vector3(p.x, 0, p.y)
		add_child(target)
		_cylinder(target, Vector3(0, 0.14, 0), 0.7, 0.7, 0.26, Color("29384b"))
		_ring(target, Vector3(0, 0.3, 0), 0.57, Color("b5a1f1"))
		var crystal := _box(target, Vector3(0, 1.25, 0), Vector3(0.7, 1.2, 0.7), Color("aca0e5"))
		crystal.rotation_degrees = Vector3(0, 45, 30)
		_sphere(target, Vector3(0, 1.2, 0), 0.15, Color("efe8ff"), true)
		var label := Label3D.new()
		label.text = "0%d  /  SENTINEL" % (i + 1)
		label.font_size = 32
		label.pixel_size = 0.008
		label.position.y = 2.3
		label.modulate = Color("c4c2df")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		target.add_child(label)
		target_nodes.append(target)
	_build_mage()
	aim_ring = _ring(self, Vector3(0, 0.1, -12), 0.45, MINT)
	camera = Camera3D.new()
	camera.fov = 46
	camera.current = true
	add_child(camera)
	_update_camera()

func _build_mage() -> void:
	mage = Node3D.new()
	mage.position = Vector3(0, 0, 3)
	add_child(mage)
	_ring(mage, Vector3(0, 0.03, 0), 1.05, MINT.darkened(0.3))
	_ring(mage, Vector3(0, 0.03, 0), 1.19, MINT.darkened(0.65))
	# Original low-poly apprentice, viewed from behind: robe, hair, hat, wand.
	_cylinder(mage, Vector3(0, 0.95, 0), 0.7, 0.32, 1.7, Color("44436c"))
	_cylinder(mage, Vector3(0, 0.17, 0), 0.72, 0.67, 0.13, Color("c8b286"))
	_sphere(mage, Vector3(0, 2.0, 0), 0.35, Color("d4b8ae"))
	_sphere(mage, Vector3(0, 2.04, 0.12), 0.39, Color("d8d3e6"))
	_box(mage, Vector3(0, 1.75, 0.32), Vector3(0.5, 0.65, 0.2), Color("c7c1dd"))
	_cylinder(mage, Vector3(0, 2.29, 0), 0.85, 0.85, 0.09, Color("403f65"))
	var hat := _cylinder(mage, Vector3(0.03, 2.68, 0), 0.48, 0.02, 0.8, Color("4f4c7b"))
	hat.rotation.z = -0.14
	_cylinder(mage, Vector3(0, 2.36, 0), 0.47, 0.44, 0.14, Color("d2ba88"))
	var arm := _box(mage, Vector3(0.48, 1.4, -0.22), Vector3(0.35, 0.4, 0.85), Color("5f5982"))
	arm.rotation.x = -0.1
	_box(mage, Vector3(0.57, 1.43, -0.95), Vector3(0.08, 0.08, 1.0), Color("bea47b"))
	wand_tip = _sphere(mage, Vector3(0.57, 1.43, -1.48), 0.13, MINT, true)
	for i in range(3):
		_box(mage, Vector3(0, 0.8 + i * 0.28, 0.49 - i * 0.08), Vector3(0.04, 0.17, 0.04), Color("ccb686"), true)

func _update_camera() -> void:
	var center := Vector3(0, 0, -6)
	var pitch := deg_to_rad(camera_pitch)
	camera.position = center + Vector3(0, sin(pitch) * 36, cos(pitch) * 36)
	camera.look_at(center)

func _style(bg: Color, border := LINE, radius := 10, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, separation := 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, size := 14, color := WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 36
	button.add_theme_stylebox_override("normal", _style(Color("213b39") if accent else Color("192436"), Color("527668") if accent else LINE, 7, 8))
	button.add_theme_stylebox_override("hover", _style(Color("2c3d4c"), MINT, 7, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("34554e"), MINT, 7, 8))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", MINT if accent else WHITE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _rule(parent: Node) -> void:
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _style(LINE, LINE, 0, 0))
	parent.add_child(rule)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	ui.theme = theme
	var header := _panel(ui)
	header.add_theme_stylebox_override("panel", _style(Color("0d1522f5"), LINE, 0, 20))
	layout_nodes.header = header
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	header.add_child(row)
	_label(row, "◆", 34, MINT)
	var title := _vbox(row, 0)
	_label(title, "L U M E N", 25)
	_label(title, "W A N D   A T E L I E R", 9, MUTED)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_label(row, "01  /  마법 실험장", 15, MINT)
	_label(row, "     FIELD RESEARCH     /     PROTOTYPE 0.1", 11, MUTED)
	_button(row, "실험 초기화  R", _reset)
	var left := _panel(ui)
	layout_nodes.left = left
	var lib := _vbox(left, 10)
	_label(lib, "SPELL ARCHIVE", 10, MINT)
	_label(lib, "주문 보관함", 21)
	_label(lib, "선택한 슬롯에 주문을 넣으세요", 11, MUTED)
	_rule(lib)
	for id in Spells.DATA:
		var data: Dictionary = Spells.DATA[id]
		var button := _button(lib, "%s   %s     %d" % [data.symbol, data.name, data.cost], func(): _equip(id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 45
		button.add_theme_color_override("font_color", Color(data.color))
		button.tooltip_text = data.desc + "\n마나 %d · 클릭해서 선택 슬롯에 장착" % data.cost
	_rule(lib)
	_label(lib, "7 SPELLS  /  자유롭게 실험", 10, MUTED)
	var right := _panel(ui)
	layout_nodes.right = right
	var inspector := _vbox(right, 11)
	_label(inspector, "LIVE TELEMETRY", 10, MINT)
	_label(inspector, "완드 상태", 21)
	status_label = _label(inspector, "●  시전 준비", 13, MINT)
	_rule(inspector)
	_label(inspector, "MANA RESERVOIR", 10, MUTED)
	mana_text = _label(inspector, "60 / 60", 25)
	mana_bar = ProgressBar.new()
	mana_bar.show_percentage = false
	mana_bar.custom_minimum_size.y = 7
	mana_bar.add_theme_stylebox_override("background", _style(Color("223044"), Color("223044"), 3, 0))
	mana_bar.add_theme_stylebox_override("fill", _style(MINT, MINT, 3, 0))
	inspector.add_child(mana_bar)
	_label(inspector, "최대 60  ·  회복 15 / 초", 11, MUTED)
	_rule(inspector)
	stats_label = _label(inspector, "", 13)
	_rule(inspector)
	_label(inspector, "EXECUTION LOG", 10, MUTED)
	log_label = _label(inspector, "조준 후 마우스를 누르세요", 11, MUTED)
	log_label.custom_minimum_size.y = 100
	var presets := _panel(ui)
	layout_nodes.presets = presets
	var pbox := _vbox(presets, 9)
	_label(pbox, "EXPERIMENT RECIPES", 10, MUTED)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 7)
	pbox.add_child(prow)
	for i in range(Spells.PRESETS.size()):
		_button(prow, "%02d  %s" % [i + 1, Spells.PRESETS[i].name], func(): _apply_preset(i))
	hint_label = _label(pbox, "", 12, MINT)
	var camera_panel := _panel(ui)
	layout_nodes.camera = camera_panel
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 12)
	camera_panel.add_child(crow)
	_label(crow, "시점", 12, MUTED)
	var slider := HSlider.new()
	slider.min_value = 30
	slider.max_value = 72
	slider.step = 1
	slider.value = camera_pitch
	slider.custom_minimum_size.x = 150
	slider.value_changed.connect(func(value): camera_pitch = value; _update_camera(); pitch_label.text = "%d°" % value)
	crow.add_child(slider)
	pitch_label = _label(crow, "38°", 13, MINT)
	var bottom := _panel(ui)
	layout_nodes.bottom = bottom
	var wandbox := _vbox(bottom, 9)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	wandbox.add_child(heading)
	_label(heading, "YOUR WAND", 10, MINT)
	_label(heading, "견습생의 완드", 18)
	selected_label = _label(heading, "", 12, MUTED)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(gap)
	_button(heading, "← 이동", func(): _move_selected(-1))
	_button(heading, "이동 →", func(): _move_selected(1))
	_button(heading, "슬롯 비우기", _clear_slot)
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 9)
	wandbox.add_child(slots_row)
	for i in range(6):
		var button = SlotButton.new()
		button.slot_index = i
		button.on_drop = _swap_slots
		button.custom_minimum_size = Vector2(130, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("hover", _style(Color("243548"), MINT, 8, 10))
		button.add_theme_stylebox_override("pressed", _style(Color("34554e"), MINT, 8, 10))
		button.pressed.connect(func(): selected = i; _refresh_slots())
		slots_row.add_child(button)
		slot_buttons.append(button)
	expression_label = _label(wandbox, "", 12, MUTED)
	expression_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var footer := _label(ui, "LMB 유지  시전     ·     1–6  슬롯 선택     ·     드래그  순서 변경     ·     SPACE  일시정지     ·     R  초기화", 12, MUTED)
	layout_nodes.footer = footer
	toast_label = _label(ui, "", 14, MINT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout_nodes.toast = toast_label
	crosshair = _label(ui, "+", 34, MINT)
	crosshair.visible = false

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	layout_nodes.header.position = Vector2.ZERO
	layout_nodes.header.size = Vector2(size.x, 86)
	layout_nodes.left.position = Vector2(24, 111)
	layout_nodes.left.size = Vector2(221, 0)
	layout_nodes.right.position = Vector2(size.x - 234, 111)
	layout_nodes.right.size = Vector2(210, 0)
	layout_nodes.presets.position = Vector2(265, 111)
	layout_nodes.presets.size = Vector2(size.x - 519, 0)
	layout_nodes.camera.position = Vector2(size.x - 505, size.y - 265)
	layout_nodes.camera.size = Vector2(271, 45)
	layout_nodes.bottom.position = Vector2(24, size.y - 208)
	layout_nodes.bottom.size = Vector2(size.x - 48, 170)
	layout_nodes.footer.position = Vector2(28, size.y - 26)
	layout_nodes.toast.position = Vector2(265, size.y - 250)
	layout_nodes.toast.size = Vector2(size.x - 790, 28)

func _toast(message: String) -> void:
	toast_label.text = message
	toast_time = 2.5

func _clear_visuals() -> void:
	for visual in projectile_visuals.values():
		visual.queue_free()
	projectile_visuals.clear()
	for effect in effects:
		effect.node.queue_free()
	effects.clear()

func _reset() -> void:
	firing = false
	sim.reset()
	_clear_visuals()
	_refresh_slots()
	_toast("마나와 실험 기록을 초기화했습니다")

func _apply_preset(index: int) -> void:
	sim.slots = Spells.PRESETS[index].slots.duplicate()
	selected = 0
	_reset()
	hint_label.text = Spells.PRESETS[index].hint
	_toast(Spells.PRESETS[index].name + " 장착")

func _equip(id: String) -> void:
	sim.slots[selected] = id
	_reset()
	_toast("슬롯 %d · %s 장착" % [selected + 1, Spells.DATA[id].name])

func _clear_slot() -> void:
	sim.slots[selected] = ""
	_reset()

func _move_selected(direction: int) -> void:
	_swap_slots(selected, clampi(selected + direction, 0, 5))

func _swap_slots(from: int, to: int) -> void:
	var previous: String = sim.slots[to]
	sim.slots[to] = sim.slots[from]
	sim.slots[from] = previous
	selected = to
	_reset()
	_toast("실행 순서를 변경했습니다")

func _refresh_slots() -> void:
	for i in range(slot_buttons.size()):
		var id: String = sim.slots[i]
		var button: Button = slot_buttons[i]
		var border := LINE
		var bg := Color("182235")
		if i == selected:
			border = Color("718e9b")
		if i == sim.active_slot:
			border = Color("f3cb86") if sim.waiting else MINT
			bg = Color("353022") if sim.waiting else Color("203e3b")
		button.add_theme_stylebox_override("normal", _style(bg, border, 8, 10))
		if id == "":
			button.text = "%02d     +\n빈 슬롯" % (i + 1)
			button.add_theme_color_override("font_color", MUTED)
			button.tooltip_text = "선택 후 보관함에서 스펠을 클릭하세요"
		else:
			button.text = "%02d   %s   %d MP\n%s" % [i + 1, Spells.DATA[id].symbol, Spells.DATA[id].cost, Spells.DATA[id].name]
			button.add_theme_color_override("font_color", Color(Spells.DATA[id].color))
			button.tooltip_text = Spells.DATA[id].desc
	selected_label.text = "6 SLOTS  /  %02d 선택" % (selected + 1)
	var result := Spells.parse_next(sim.slots, 0)
	expression_label.text = "실행 구조   " + Spells.describe(result.node) + "     /     왼쪽 → 오른쪽 · 빈 슬롯 건너뜀"
	last_slot = sim.active_slot
	last_waiting = sim.waiting

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		firing = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			selected = event.keycode - KEY_1
			_refresh_slots()
		elif event.keycode == KEY_R:
			_reset()
		elif event.keycode == KEY_SPACE:
			paused = not paused
			firing = false
			_toast("일시정지" if paused else "실험 재개")
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_clear_slot()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		firing = event.pressed and _is_arena(event.position) and not paused
		if firing:
			_aim_at(event.position)
			# Register even a press/release shorter than one rendered frame.
			sim.tick(0.0, true, aim)

func _is_arena(mouse: Vector2) -> bool:
	var size := get_viewport().get_visible_rect().size
	return mouse.x > 249 and mouse.x < size.x - 238 and mouse.y > 220 and mouse.y < size.y - 270

func _aim_at(mouse: Vector2) -> void:
	var plane := Plane(Vector3.UP, 0.85)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit != null:
		aim = Vector2(clampf(hit.x, -9.8, 9.8), clampf(hit.z, -21.8, 2.0))
		var direction: Vector2 = aim - Simulation.ORIGIN
		mage.rotation.y = atan2(-direction.x, -direction.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		firing = false

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	clock += dt
	var mouse := get_viewport().get_mouse_position()
	hover_arena = _is_arena(mouse)
	crosshair.visible = hover_arena
	crosshair.position = mouse - Vector2(14, 25)
	if hover_arena:
		_aim_at(mouse)
	aim_ring.position = Vector3(aim.x, 0.06, aim.y)
	if not paused:
		sim.tick(dt, firing and hover_arena, aim)
		_render_projectiles(dt)
		_update_effects(dt)
		for i in range(target_nodes.size()):
			var crystal := target_nodes[i].get_child(2) as Node3D
			crystal.rotation.y += dt * 0.45
			crystal.position.y = 1.25 + sin(clock * 1.8 + i) * 0.12
	wand_tip.scale = Vector3.ONE * (1.0 + sin(clock * 5) * 0.12)
	mana_bar.max_value = sim.max_mana
	mana_bar.value = sim.mana
	mana_text.text = "%02d / %d" % [sim.mana, sim.max_mana]
	status_label.text = "Ⅱ  일시정지" if paused else ("●  마나 회복 대기" if sim.waiting else ("●  시전 중" if firing else "●  시전 준비"))
	status_label.add_theme_color_override("font_color", Color("f3cb86") if sim.waiting else MINT)
	stats_label.text = "발사                 %03d\n적중                 %03d\n누적 피해            %04d\n벽 반사              %03d\n분열                 %03d" % [sim.shots, sim.hits, sim.damage, sim.bounces, sim.splits]
	log_label.text = "\n".join(sim.history) if not sim.history.is_empty() else "조준 후 마우스를 누르세요"
	if sim.active_slot != last_slot or sim.waiting != last_waiting:
		_refresh_slots()
	toast_time -= dt
	toast_label.modulate.a = clampf(toast_time, 0, 1)
	debug_clock += dt
	if OS.has_feature("web") and debug_clock >= 0.2:
		debug_clock = 0
		var target_positions: Array = []
		for target in sim.targets:
			var screen := camera.unproject_position(Vector3(target.x, 0.85, target.y))
			target_positions.append({"x": screen.x, "y": screen.y})
		# Read-only diagnostics for browser verification; no alternate game logic.
		var state := {"shots": sim.shots, "hits": sim.hits, "mana": sim.mana, "waiting": sim.waiting, "active_slot": sim.active_slot, "slots": sim.slots, "selected": selected, "paused": paused, "bounces": sim.bounces, "splits": sim.splits, "payloads": sim.payloads, "pitch": camera_pitch, "targets": target_positions}
		JavaScriptBridge.eval("window.__wandAtelier = " + JSON.stringify(state) + ";")

func _render_projectiles(dt: float) -> void:
	var live: Dictionary = {}
	trail_clock += dt
	var draw_trail := trail_clock > 0.035
	if draw_trail:
		trail_clock = 0
	for p in sim.projectiles:
		live[p.key] = true
		var color := Color(Spells.DATA[p.id].color)
		if not projectile_visuals.has(p.key):
			var visual := Node3D.new()
			add_child(visual)
			_sphere(visual, Vector3.ZERO, 0.12 if p.id == "spark" else 0.18, color, true)
			_sphere(visual, Vector3.ZERO, 0.065, Color.WHITE, true)
			projectile_visuals[p.key] = visual
		projectile_visuals[p.key].position = Vector3(p.pos.x, 0.85, p.pos.y)
		if draw_trail and effects.size() < 220:
			var trail := _sphere(self, Vector3(p.pos.x, 0.85, p.pos.y), 0.10, color, true)
			effects.append({"node": trail, "life": 0.22, "max": 0.22, "grow": false})
	for key in projectile_visuals.keys():
		if not live.has(key):
			projectile_visuals[key].queue_free()
			projectile_visuals.erase(key)
	for event in sim.events:
		if effects.size() >= 250:
			break
		var p: Vector2 = event.pos
		var ring := _ring(self, Vector3(p.x, 0.12, p.y), 0.27, Color(event.color))
		effects.append({"node": ring, "life": 0.4, "max": 0.4, "grow": true})
		if event.type == "hit":
			var burst := _sphere(self, Vector3(p.x, 1.1, p.y), 0.38, Color(event.color), true)
			effects.append({"node": burst, "life": 0.20, "max": 0.20, "grow": false})
	sim.events.clear()

func _update_effects(dt: float) -> void:
	for effect in effects:
		effect.life -= dt
		var fraction: float = maxf(0.001, effect.life / effect.max)
		effect.node.scale = Vector3.ONE * ((1.0 - fraction) * 3.0 + 0.2 if effect.grow else fraction)
		if effect.life <= 0:
			effect.node.queue_free()
	effects = effects.filter(func(effect): return effect.life > 0)
