extends RefCounted

const Spells = preload("res://scripts/spells.gd")
const ORIGIN := Vector2(0, 3.0)
const LIMIT := Rect2(-10.0, -22.0, 20.0, 27.0)
const MAX_PROJECTILES := 160
var slots: Array = Spells.PRESETS[2].slots.duplicate()
var max_mana := 60.0
var regen := 15.0
var mana := 60.0
var cursor := 0
var active_slot := -1
var waiting := false
var cooldown := 0.0
var clock := 0.0
var shots := 0
var hits := 0
var damage := 0
var bounces := 0
var splits := 0
var payloads := 0
var serial := 0
var jobs: Array = []
var projectiles: Array = []
var events: Array = []
var history: Array[String] = []
var walls: Array[Rect2] = [Rect2(-7.0, -11.5, 0.4, 10.0), Rect2(6.6, -11.5, 0.4, 10.0), Rect2(-4.7, -17, 3.0, 0.4), Rect2(2.0, -17, 3.0, 0.4)]
var targets: Array[Vector2] = [Vector2(-3.5, -8), Vector2(0, -12), Vector2(3.5, -8), Vector2(-4.6, -14.8), Vector2(4.8, -14.8)]

func reset() -> void:
	mana = max_mana
	cursor = 0
	active_slot = -1
	waiting = false
	cooldown = 0
	clock = 0
	shots = 0
	hits = 0
	damage = 0
	bounces = 0
	splits = 0
	payloads = 0
	jobs.clear()
	projectiles.clear()
	events.clear()
	history.clear()

func log_event(message: String) -> void:
	history.push_front(message)
	if history.size() > 5:
		history.pop_back()

func tick(delta: float, firing: bool, aim: Vector2) -> void:
	clock += delta
	mana = minf(max_mana, mana + regen * delta)
	cooldown -= delta
	_move_projectiles(delta)
	if jobs.is_empty() and firing and cooldown <= 0:
		var result := Spells.parse_next(slots, cursor)
		if result.node.is_empty():
			cursor = 0
			cooldown = 0.45
			active_slot = -1
		else:
			cursor = result.next
			jobs.append({"node": result.node, "pos": ORIGIN, "dir": (aim - ORIGIN).normalized(), "flags": {}, "ready": clock})
			cooldown = 0.30
	waiting = false
	# A sequence can pause at any instruction without replaying previous ones.
	var budget := 32
	while not jobs.is_empty() and budget > 0:
		budget -= 1
		var job: Dictionary = jobs[0]
		if job.ready > clock:
			break
		var node: Dictionary = job.node
		active_slot = node.slot
		var cost: float = Spells.DATA[node.id].cost
		if mana + 0.0001 < cost:
			waiting = true
			break
		mana -= cost
		jobs.pop_front()
		_execute(job)

func _execute(job: Dictionary) -> void:
	var node: Dictionary = job.node
	var id: String = node.id
	var flags: Dictionary = job.flags.duplicate()
	if id in ["bounce", "split", "double"]:
		if id == "bounce":
			flags["bounce"] = int(flags.get("bounce", 0)) + 3
		if id == "split":
			flags["split"] = true
		for i in range(node.children.size() - 1, -1, -1):
			var direction: Vector2 = job.dir
			if id == "double":
				direction = direction.rotated((i - (node.children.size() - 1) * 0.5) * 0.16)
			jobs.push_front({"node": node.children[i], "pos": job.pos, "dir": direction, "flags": flags.duplicate(), "ready": clock})
		if node.children.is_empty():
			log_event("연결할 후속 주문 없음")
		return
	var payload: Dictionary = {}
	if id in ["trigger", "timer"] and not node.children.is_empty():
		payload = node.children[0]
	_spawn(job.pos, job.dir, id, flags, payload)
	shots += 1
	log_event("%02d  %s 발사" % [node.slot + 1, Spells.DATA[id].name])

func _spawn(pos: Vector2, direction: Vector2, id: String, flags: Dictionary, payload: Dictionary) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		return
	serial += 1
	projectiles.append({"key": serial, "pos": pos, "prev": pos, "dir": direction, "id": id, "speed": 24.0 if id == "spark" else 15.0, "age": 0.0, "bounce": flags.get("bounce", 0), "split": flags.get("split", false), "payload": payload, "dead": false})
	events.append({"type": "cast", "pos": pos, "color": Spells.DATA[id].color})

func _payload(p: Dictionary) -> void:
	if p.payload.is_empty():
		return
	jobs.append({"node": p.payload, "pos": p.pos + p.dir * 0.85, "dir": p.dir, "flags": {}, "ready": clock})
	payloads += 1
	log_event("후속 주문 발동")
	p.payload = {}

func _move_projectiles(delta: float) -> void:
	# Bound step length so even the fastest projectile cannot tunnel through walls.
	var steps := maxi(1, int(ceil(delta / 0.008)))
	var step := delta / steps
	for _s in range(steps):
		var current := projectiles.duplicate()
		for p in current:
			if p.dead:
				continue
			p.age += step
			p.prev = p.pos
			p.pos += p.dir * p.speed * step
			if p.id == "timer" and p.age >= 0.65:
				_payload(p)
				p.dead = true
				continue
			if p.split and p.age >= 0.35:
				for angle in [-0.30, 0.0, 0.30]:
					_spawn(p.pos, p.dir.rotated(angle), p.id, {"bounce": p.bounce}, p.payload.duplicate(true))
				p.dead = true
				splits += 1
				log_event("투사체 → 3갈래 분열")
				continue
			var normal := Vector2.ZERO
			for wall in walls:
				if wall.grow(0.12).has_point(p.pos):
					if p.prev.x < wall.position.x or p.prev.x > wall.end.x:
						normal = Vector2.RIGHT
					else:
						normal = Vector2.DOWN
					break
			if not LIMIT.has_point(p.pos):
				normal = Vector2.RIGHT if p.pos.x < LIMIT.position.x or p.pos.x >= LIMIT.end.x else Vector2.DOWN
			if normal != Vector2.ZERO:
				events.append({"type": "impact", "pos": p.prev, "color": "f3cb86"})
				if p.id == "trigger":
					p.pos = p.prev
					_payload(p)
				if p.bounce > 0:
					p.dir = p.dir.bounce(normal)
					p.pos = p.prev + p.dir * 0.05
					p.bounce -= 1
					bounces += 1
					log_event("벽 반사")
				else:
					p.dead = true
				continue
			for target in targets:
				if p.pos.distance_to(target) < 0.65:
					hits += 1
					damage += 24 if p.id == "spark" else 12
					events.append({"type": "hit", "pos": target, "color": Spells.DATA[p.id].color})
					if p.id == "trigger":
						_payload(p)
					p.dead = true
					break
			if p.age > 4.0:
				p.dead = true
		projectiles = projectiles.filter(func(p): return not p.dead)
	# Rendering consumes events; bound storage for headless callers as well.
	if events.size() > 300:
		events = events.slice(-300)
