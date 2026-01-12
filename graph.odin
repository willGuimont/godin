package godin

import "core:container/queue"

Graph :: struct($T: typeid) {
	values:    []T,
	adjacency: [][dynamic]int,
}

graph_destroy :: proc(g: ^Graph($T)) {
	delete(g.values)
	for i := 0; i < len(g.adjacency); i += 1 {
		delete(g.adjacency[i])
	}
	delete(g.adjacency)
}

graph_bfs :: proc(
	g: ^Graph($T),
	start: int,
	allocator := context.allocator,
) -> (
	output: [dynamic]int,
	seen: [dynamic]int,
) {
	always_true :: proc(x: $T) -> bool {
		return true
	}
	return graph_bfs_predicate(g, start, proc(s: Stone) -> bool {return true}, allocator)
}

graph_bfs_predicate :: proc(
	g: ^Graph($T),
	start: int,
	can_visit: proc(_: T) -> bool,
	allocator := context.allocator,
) -> (
	output: [dynamic]int,
	seen: [dynamic]int,
) {
	q: queue.Queue(int)
	defer queue.destroy(&q)
	queue.init(&q)
	queue.enqueue(&q, start)

	visited := make([]bool, len(g.values))
	defer delete(visited)

	output = make([dynamic]int, 0)
	seen = make([dynamic]int, 0)

	visited[start] = true

	for queue.len(q) > 0 {
		current := queue.dequeue(&q)
		append(&output, current)

		for neighbor in g.adjacency[current] {
			append(&seen, neighbor)
			if !visited[neighbor] && can_visit(g.values[neighbor]) {
				visited[neighbor] = true
				queue.enqueue(&q, neighbor)
			}
		}
	}
	return
}
