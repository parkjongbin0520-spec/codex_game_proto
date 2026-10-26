extends SceneTree

const Spells = preload("res://scripts/spells.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func advance(sim, seconds: float, firing := false, aim := Vector2(0, -12)) -> void:
	for _i in range(int(seconds * 120)):
		sim.tick(1.0 / 120, firing, aim)

func fresh(slots: Array):
	var sim = Sim.new()
	sim.slots = slots
	sim.targets.clear()
	sim.walls.clear()
	return sim

func _initialize() -> void:
	var tree := Spells.parse_next(["trigger", "double", "bolt", "spark", "bolt"], 0)
	check(tree.next == 4 and tree.node.children[0].children.size() == 2, "Trigger owns multicast payload and consumes its slots")
	check(Spells.parse_next(["", "bolt", ""], 0).node.slot == 1, "Empty slots are skipped")
	check(Spells.parse_next(["split"], 0).node.children.is_empty(), "Incomplete modifier parses safely")
	var sim = fresh(["bolt", "spark"])
	sim.tick(0, true, Vector2(0, -12))
	check(sim.shots == 1 and sim.cursor == 1, "One root projectile per cast")
	advance(sim, 0.4)
	check(sim.shots == 1, "Releasing fire does not start another root")
	sim.tick(0, true, Vector2(0, -12))
	check(sim.shots == 2 and sim.active_slot == 1, "Next cast advances left to right")
	sim = fresh(["double", "bolt", "spark"])
	sim.mana = 12
	sim.regen = 10
	sim.tick(0, true, Vector2(0, -12))
	check(sim.shots == 1 and sim.waiting and sim.active_slot == 2, "Mana runs out at the exact instruction, after first child fired")
	advance(sim, 1.9)
	check(sim.shots == 2 and not sim.waiting, "Mana recovery resumes pending child without replaying first child")
	sim = fresh(["bounce", "bolt"])
	sim.tick(0, true, Vector2(10, 3))
	advance(sim, 0.8)
	check(sim.bounces == 1 and sim.projectiles[0].dir.x < 0, "Wall collision reflects velocity")
	sim = fresh(["split", "bolt"])
	sim.tick(0, true, Vector2(0, -12))
	advance(sim, 0.4)
	check(sim.splits == 1 and sim.projectiles.size() == 3, "Split modifier produces three child trajectories")
	sim = fresh(["bolt", "split"])
	sim.tick(0, true, Vector2(0, -12))
	advance(sim, 0.4)
	check(sim.splits == 0, "Reordering modifier after projectile changes behavior")
	sim = fresh(["trigger", "double", "bolt", "spark"])
	sim.targets.append(Vector2(0, -3))
	sim.tick(0, true, Vector2(0, -12))
	check(sim.shots == 1, "Trigger payload does not fire before collision")
	advance(sim, 0.5)
	check(sim.payloads == 1 and sim.shots == 3 and sim.hits >= 1, "Collision activates nested multicast exactly once")
	sim = fresh(["timer", "bolt"])
	sim.tick(0, true, Vector2(0, -12))
	advance(sim, 0.4)
	check(sim.shots == 1, "Timer waits before payload")
	advance(sim, 0.3)
	check(sim.shots == 2 and sim.payloads == 1, "Timer emits payload at delayed world position")
	sim = fresh(["", "", ""])
	advance(sim, 1, true)
	check(sim.shots == 0 and sim.mana == sim.max_mana, "Empty wand neither fires nor spends mana")
	sim = fresh(["split"])
	advance(sim, 1, true)
	check(sim.shots == 0, "Dangling modifier does not invent a projectile")
	sim = fresh(["bolt"])
	advance(sim, 1.8, true)
	check(sim.shots >= 2, "End of wand recharges and cycles to beginning")
	sim.reset()
	check(sim.shots == 0 and sim.projectiles.is_empty() and sim.jobs.is_empty() and sim.mana == sim.max_mana, "Reset clears all pending work and restores mana")
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
