extends RefCounted

const DATA = {
	"bolt": {"name": "루멘 볼트", "tag": "PROJECTILE", "symbol": "◆", "cost": 8.0, "color": "9ff5da", "desc": "조준 방향으로 마력탄을 발사합니다."},
	"bounce": {"name": "도탄", "tag": "MODIFIER", "symbol": "↗", "cost": 5.0, "color": "f3cb86", "desc": "다음 투사체가 벽에서 최대 3회 반사됩니다."},
	"split": {"name": "삼중 분열", "tag": "MODIFIER", "symbol": "Ψ", "cost": 12.0, "color": "d0adff", "desc": "다음 투사체가 비행 0.35초 후 세 갈래로 분열합니다."},
	"trigger": {"name": "충돌 볼트", "tag": "TRIGGER", "symbol": "◎", "cost": 14.0, "color": "ffb59c", "desc": "충돌하는 위치에서 뒤의 주문을 실행합니다."},
	"timer": {"name": "시한 볼트", "tag": "TIMER", "symbol": "○", "cost": 12.0, "color": "99caff", "desc": "0.65초 비행 후 그 위치에서 뒤의 주문을 실행합니다."},
	"double": {"name": "동시 시전", "tag": "MULTICAST", "symbol": "Ⅱ", "cost": 4.0, "color": "edb8ed", "desc": "뒤의 두 주문을 같은 시전에 연결합니다. 마나 부족 시 대기합니다."},
	"spark": {"name": "선더 니들", "tag": "PROJECTILE", "symbol": "Z", "cost": 18.0, "color": "a9bfff", "desc": "빠르고 강한 번개탄. 트리거 뒤에 연결해 보세요."},
}

const PRESETS = [
	{"name": "벽의 메아리", "hint": "금빛 벽을 향해 발사해 도탄 경로를 확인하세요.", "slots": ["bounce", "bolt", "", "", "", ""]},
	{"name": "세 갈래 별빛", "hint": "발사된 볼트가 비행 중 세 갈래로 갈라집니다.", "slots": ["split", "bolt", "", "", "", ""]},
	{"name": "충돌의 연쇄", "hint": "수정 표적을 맞히면 충돌 지점에서 두 발의 번개가 나갑니다.", "slots": ["trigger", "double", "spark", "spark", "", ""]},
	{"name": "시간의 정원", "hint": "시한 볼트에서 분열 볼트가 발사되는 중첩 조합입니다.", "slots": ["timer", "split", "bolt", "", "", ""]},
]

# Prefix parser: payloads consume slots, rather than firing again at the root.
# Empty slots are skipped. A missing child is a harmless incomplete expression.
static func parse_next(slots: Array, start: int) -> Dictionary:
	var i := start
	while i < slots.size() and slots[i] == "":
		i += 1
	if i >= slots.size():
		return {"node": {}, "next": i}
	var id: String = slots[i]
	var node := {"id": id, "slot": i, "children": []}
	i += 1
	var count := 0
	if id in ["bounce", "split", "trigger", "timer"]:
		count = 1
	elif id == "double":
		count = 2
	for _child in range(count):
		var result := parse_next(slots, i)
		i = result.next
		if not result.node.is_empty():
			node.children.append(result.node)
	return {"node": node, "next": i}

static func describe(node: Dictionary) -> String:
	if node.is_empty():
		return "주문을 장착해 주세요"
	var names: Array[String] = []
	for child in node.children:
		names.append(describe(child))
	var title: String = DATA[node.id].name
	if not names.is_empty():
		title += " → (" + " + ".join(names) + ")"
	return title
