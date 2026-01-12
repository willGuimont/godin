package godin

import "core:fmt"
import "core:mem"
import "core:slice"
Stone :: enum {
	StoneEmpty,
	StoneBlack,
	StoneWhite,
}

Turn :: enum {
	TurnBlack,
	TurnWhite,
}

GameState :: enum {
	GamePlaying,
	GameRemove,
	GameTerritory,
}

@(private = "file")
stone_to_turn :: proc(stone: Stone) -> Turn {
	if stone == .StoneBlack {
		return .TurnBlack
	} else {
		return .TurnWhite
	}
}

@(private = "file")
turn_to_stone :: proc(turn: Turn) -> Stone {
	if turn == .TurnBlack {
		return .StoneBlack
	} else {
		return .StoneWhite
	}
}

@(private = "file")
turn_opposite :: proc(turn: Turn) -> Turn {
	if turn == .TurnBlack {
		return .TurnWhite
	} else {
		return .TurnBlack
	}
}

Board :: struct {
	graph:     Graph(Stone),
	width:     int,
	height:    int,
	turn:      Turn,
	num_pass:  int,
	score:     [Turn]f32,
	state:     GameState,
	to_remove: []bool,
}

BOARD_SIZE :: 9
NUM_STONES :: BOARD_SIZE * BOARD_SIZE

@(private = "file")
get_board_idx :: proc(x, y: int) -> int {
	return y * BOARD_SIZE + x
}

@(private = "file")
get_board_coords :: proc(idx: int) -> [2]int {
	return {idx % BOARD_SIZE, idx / BOARD_SIZE}
}

make_board :: proc() -> Board {
	stones := make([]Stone, NUM_STONES)
	adjacency := make([][dynamic]int, NUM_STONES)

	for i := 0; i < BOARD_SIZE; i += 1 {
		for j := 0; j < BOARD_SIZE; j += 1 {
			on_left := i == 0
			on_top := j == 0
			on_right := i == BOARD_SIZE - 1
			on_bottom := j == BOARD_SIZE - 1

			idx := get_board_idx(i, j)
			adjacency[idx] = make([dynamic]int, 0, 4)

			if (!on_top) {
				append(&adjacency[idx], get_board_idx(i, j - 1))
			}
			if (!on_bottom) {
				append(&adjacency[idx], get_board_idx(i, j + 1))
			}
			if (!on_left) {
				append(&adjacency[idx], get_board_idx(i - 1, j))
			}
			if (!on_right) {
				append(&adjacency[idx], get_board_idx(i + 1, j))
			}
		}
	}

	g := Graph(Stone) {
		values    = stones[:],
		adjacency = adjacency,
	}
	return Board {
		graph = g,
		width = BOARD_SIZE,
		height = BOARD_SIZE,
		turn = .TurnBlack,
		num_pass = 0,
		score = [Turn]f32{.TurnBlack = 0, .TurnWhite = 6.5},
		state = .GamePlaying,
		to_remove = nil,
	}

}


destroy_board :: proc(board: ^Board) {
	graph_destroy(&board.graph)
	if board.to_remove != nil {
		delete(board.to_remove)
	}
}

pass :: proc(board: ^Board) {
	board.turn = turn_opposite(board.turn)
	board.num_pass += 1
	if board.num_pass >= 2 {
		board.state = .GameRemove
		if board.to_remove == nil {
			board.to_remove = make([]bool, NUM_STONES)
		}
		slice.fill(board.to_remove, false)
	}
}

get_stone :: proc(board: ^Board, x, y: int) -> Stone {
	idx := get_board_idx(x, y)
	return board.graph.values[idx]
}

get_stone_removal :: proc(board: ^Board, x, y: int) -> bool {
	if board.to_remove == nil {
		return false
	}
	idx := get_board_idx(x, y)
	return board.to_remove[idx]
}

put_stone :: proc(board: ^Board, x, y: int) -> (ok: bool) {
	idx := get_board_idx(x, y)
	fmt.println(board.graph.values[idx])
	if board.graph.values[idx] != .StoneEmpty {
		return
	}

	fmt.println(turn_to_stone(board.turn))
	board.graph.values[idx] = turn_to_stone(board.turn)
	board.turn = turn_opposite(board.turn)
	board.num_pass = 0

	if x != 0 {
		kill_if_dead(board, x - 1, y)
	}
	if y != 0 {
		kill_if_dead(board, x, y - 1)
	}
	if x != board.width - 1 {
		kill_if_dead(board, x + 1, y)
	}
	if y != board.height - 1 {
		kill_if_dead(board, x, y + 1)
	}

	group, liberties := get_group(board, x, y)
	defer delete(group)
	if liberties == 0 {
		// if put stone has no liberties after kill, revert to previous state
	} else {
		ok = true
	}
	return
}

@(private = "file")
remove_stone :: proc {
	remove_stone_xy,
	remove_stone_i,
}

@(private = "file")
remove_stone_xy :: proc(board: ^Board, x, y: int) {
	idx := get_board_idx(x, y)
	board.graph.values[idx] = .StoneEmpty
}

@(private = "file")
remove_stone_i :: proc(board: ^Board, idx: int) {
	board.graph.values[idx] = .StoneEmpty
}

@(private = "file")
get_group :: proc(board: ^Board, x, y: int) -> (group: [dynamic][2]int, liberties: int) {
	group = make([dynamic][2]int, 0, 4)

	idx := get_board_idx(x, y)
	color := board.graph.values[idx]

	visited: [dynamic]int
	seen: [dynamic]int
	switch color {
	case .StoneBlack:
		visited, seen = graph_bfs_predicate(&board.graph, idx, is_black)
	case .StoneWhite:
		visited, seen = graph_bfs_predicate(&board.graph, idx, is_white)
	case .StoneEmpty:
		return
	}
	defer {
		if visited != nil {
			delete(visited)
		}
		if seen != nil {
			delete(seen)
		}
	}

	for v in visited {
		append(&group, get_board_coords(v))
	}

	for s in seen {
		if board.graph.values[s] == .StoneEmpty {
			liberties += 1
		}
	}

	return
}

@(private = "file")
is_black :: proc(s: Stone) -> bool {
	return s == .StoneBlack
}

@(private = "file")
is_white :: proc(s: Stone) -> bool {
	return s == .StoneWhite
}

@(private = "file")
kill_if_dead :: proc(board: ^Board, x, y: int) {
	idx := get_board_idx(x, y)
	color := board.graph.values[idx]

	if color == .StoneEmpty {
		return
	}

	group, liberties := get_group(board, x, y)
	defer delete(group)

	if liberties == 0 {
		t := stone_to_turn(color)
		for s in group {
			remove_stone(board, s.x, s.y)
			board.score[t] += 1
		}
	}
}

copy_board :: proc(board: ^Board) -> Board {
	values_copy := make([]Stone, NUM_STONES)
	for i := 0; i < NUM_STONES; i += 1 {
		values_copy[i] = board.graph.values[i]
	}

	adjacency_copy := make([][dynamic]int, len(board.graph.adjacency))
	for i := 0; i < len(board.graph.adjacency); i += 1 {
		adjacency_copy[i] = make([dynamic]int, 0, len(board.graph.adjacency[i]))
		for n in board.graph.adjacency[i] {
			append(&adjacency_copy[i], n)
		}
	}

	g := Graph(Stone) {
		values    = values_copy[:],
		adjacency = adjacency_copy,
	}

	to_remove_copy: []bool
	if board.to_remove != nil && len(board.to_remove) == NUM_STONES {
		mem.copy(&to_remove_copy, &board.to_remove, NUM_STONES)
	}

	return Board {
		graph = g,
		width = board.width,
		height = board.height,
		turn = board.turn,
		num_pass = board.num_pass,
		score = board.score,
		to_remove = to_remove_copy,
	}
}

toggle_remove :: proc(board: ^Board, x, y: int) {
	idx := get_board_idx(x, y)
	if board.graph.values[idx] == .StoneEmpty {
		return
	}
	board.to_remove[idx] = !board.to_remove[idx]
}

confirm_removal :: proc(board: ^Board) {
	if board.to_remove == nil {
		board.state = .GameTerritory
		return
	}
	for i := 0; i < NUM_STONES; i += 1 {
		if board.to_remove[i] {
			s := board.graph.values[i]
			if s != .StoneEmpty {
				opp := turn_opposite(stone_to_turn(s))
				board.score[opp] += 1
				remove_stone_i(board, i)
			}
			board.to_remove[i] = false
		}
	}
	board.state = .GameTerritory
}

calculate_score :: proc(board: ^Board) -> (black: f32, white: f32) {
	// TODO count areas
	black = board.score[.TurnBlack]
	white = board.score[.TurnWhite]
	return
}

board_stones_equals :: proc(a: ^Board, b: ^Board) -> bool {
	if a.width != b.width || a.height != b.height {
		return false
	}

	if len(a.graph.values) != len(b.graph.values) {
		return false
	}
	for i := 0; i < len(a.graph.values); i += 1 {
		if a.graph.values[i] != b.graph.values[i] {
			return false
		}
	}

	return true
}
