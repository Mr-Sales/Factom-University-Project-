extends Reference

const DIRS = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const TURN_COST = 0.4

# Retorna a lista de células de start até goal (inclusive), ou [] se não houver caminho.
# 'blocked' é um Dictionary com as células ocupadas.
static func find_path(start, goal, blocked, margin = 12):
	var lo = Vector2(min(start.x, goal.x), min(start.y, goal.y)) - Vector2(margin, margin)
	var hi = Vector2(max(start.x, goal.x), max(start.y, goal.y)) + Vector2(margin, margin)

	var start_state = Vector3(start.x, start.y, -1)
	var best = {}
	best[start_state] = 0.0
	var came = {}
	var heap = []
	_push(heap, [_h(start, goal), start_state, 0.0])

	while not heap.empty():
		var top = _pop(heap)
		var state = top[1]
		if top[2] > best[state]:
			continue   # entrada velha da fila
		var cell = Vector2(state.x, state.y)
		if cell == goal:
			return _rebuild(came, state)
		for d in range(4):
			var n = cell + DIRS[d]
			if n.x < lo.x or n.x > hi.x or n.y < lo.y or n.y > hi.y:
				continue
			if n != goal and blocked.has(n):
				continue
			var g = top[2] + 1.0
			if state.z >= 0 and int(state.z) != d:
				g += TURN_COST
			var ns = Vector3(n.x, n.y, d)
			if not best.has(ns) or g < best[ns]:
				best[ns] = g
				came[ns] = state
				_push(heap, [g + _h(n, goal), ns, g])
	return []

static func _h(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)

static func _rebuild(came, state):
	var path = [Vector2(state.x, state.y)]
	while came.has(state):
		state = came[state]
		path.push_front(Vector2(state.x, state.y))
	return path

# --- fila de prioridade (heap binário) ---
static func _push(heap, item):
	heap.append(item)
	var i = heap.size() - 1
	while i > 0:
		var p = (i - 1) >> 1
		if heap[p][0] <= heap[i][0]:
			break
		var tmp = heap[p]
		heap[p] = heap[i]
		heap[i] = tmp
		i = p

static func _pop(heap):
	var top = heap[0]
	var last = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var i = 0
		while true:
			var l = 2 * i + 1
			var r = l + 1
			var m = i
			if l < heap.size() and heap[l][0] < heap[m][0]:
				m = l
			if r < heap.size() and heap[r][0] < heap[m][0]:
				m = r
			if m == i:
				break
			var tmp = heap[m]
			heap[m] = heap[i]
			heap[i] = tmp
			i = m
	return top
