package godin

import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
GRID_CENTER_X :: SCREEN_WIDTH / 2
GRID_CENTER_Y :: SCREEN_HEIGHT / 2
STONE_RADIUS :: 28
GRID_SPACING :: 60
TOP_GRID_Y :: GRID_CENTER_Y - (BOARD_SIZE / 2) * GRID_SPACING
BOTTOM_GRID_Y :: GRID_CENTER_Y + (BOARD_SIZE / 2) * GRID_SPACING
LEFT_GRID_X :: GRID_CENTER_X - (BOARD_SIZE / 2) * GRID_SPACING
RIGHT_GRID_X :: GRID_CENTER_X + (BOARD_SIZE / 2) * GRID_SPACING

mouse_to_grid :: proc(m: rl.Vector2) -> (x, y: i32) {
	x = i32((m.x - LEFT_GRID_X + GRID_SPACING / 2) / GRID_SPACING)
	y = i32((m.y - TOP_GRID_Y + GRID_SPACING / 2) / GRID_SPACING)
	return
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) > 0 {
			fmt.printf("=== %v leaks detected ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.printf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.printf("=== %v bad frees detected ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.printf("- %v\n", entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	board := make_board()
	board_t1 := copy_board(&board)
	board_t2 := copy_board(&board)
	defer {
		destroy_board(&board)
		destroy_board(&board_t1)
		destroy_board(&board_t2)
	}

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Godin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	w, h := i32(board.width), i32(board.height)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)

		// Pass turn
		if rl.IsKeyPressed(.SPACE) {
			destroy_board(&board_t2)
			board_t2 = board_t1
			board_t1 = copy_board(&board)
			pass(&board)
		}

		// Over and put stone
		mouse_pos := rl.GetMousePosition()
		mx, my := mouse_to_grid(mouse_pos)
		if (mx >= 0 && mx < w && my >= 0 && my < h) {
			turn_color: rl.Color
			if board.turn == .TurnBlack {
				turn_color = rl.BLACK
			} else {
				turn_color = rl.WHITE
			}
			turn_color.a = 127
			rl.DrawCircle(
				mx * GRID_SPACING + LEFT_GRID_X,
				my * GRID_SPACING + TOP_GRID_Y,
				STONE_RADIUS,
				turn_color,
			)

			if rl.IsMouseButtonPressed(.LEFT) {
				before_put := copy_board(&board)
				ok := put_stone(&board, int(mx), int(my))
				ko := !board_stones_equals(&board, &board_t2)
				if ok && ko {
					destroy_board(&before_put)
					destroy_board(&board_t2)
					board_t2 = board_t1
					board_t1 = copy_board(&board)
				} else {
					destroy_board(&board)
					board = before_put
				}
			}
		}

		// Horizontal lines
		for x: i32 = 0; x < w; x += 1 {
			xx := x * GRID_SPACING + LEFT_GRID_X
			rl.DrawLine(xx, TOP_GRID_Y, xx, BOTTOM_GRID_Y, rl.BLACK)
		}

		// Vertical lines
		for y: i32 = 0; y < h; y += 1 {
			yy := y * GRID_SPACING + TOP_GRID_Y
			rl.DrawLine(LEFT_GRID_X, yy, RIGHT_GRID_X, yy, rl.BLACK)
		}

		// Draw stones
		for x: i32 = 0; x < w; x += 1 {
			for y: i32 = 0; y < h; y += 1 {
				s := get_stone(&board, int(x), int(y))
				if s == .StoneBlack {
					rl.DrawCircle(
						x * GRID_SPACING + LEFT_GRID_X,
						y * GRID_SPACING + TOP_GRID_Y,
						STONE_RADIUS,
						rl.BLACK,
					)
				} else if s == .StoneWhite {
					rl.DrawCircle(
						x * GRID_SPACING + LEFT_GRID_X,
						y * GRID_SPACING + TOP_GRID_Y,
						STONE_RADIUS,
						rl.WHITE,
					)
				}
			}
		}

		// Draw score at top-right (live stone counts)
		black_count, white_count := calculate_score(&board)
		score_c := rl.TextFormat("B: %.1f  W: %.1f", black_count, white_count)
		text_w := rl.MeasureText(score_c, 20)
		rl.DrawText(score_c, SCREEN_WIDTH - text_w - 10, 10, 20, rl.BLACK)

		// Draw current turn at bottom-left (use C string literals)
		if board.turn == .TurnBlack {
			rl.DrawText(cast(cstring)"Turn: Black", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
		} else {
			rl.DrawText(cast(cstring)"Turn: White", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
		}

		rl.EndDrawing()
	}
}
