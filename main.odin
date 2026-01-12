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

USE_TRACKING_ALLOCATOR :: false

mouse_to_grid :: proc(m: rl.Vector2) -> (x, y: i32) {
	x = i32((m.x - LEFT_GRID_X + GRID_SPACING / 2) / GRID_SPACING)
	y = i32((m.y - TOP_GRID_Y + GRID_SPACING / 2) / GRID_SPACING)
	return
}

main :: proc() {
	track: mem.Tracking_Allocator
	if USE_TRACKING_ALLOCATOR {
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
	}
	defer {
		if USE_TRACKING_ALLOCATOR {
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
			#partial switch board.state {
			case .GamePlaying, .GameRemove:
				destroy_board(&board_t2)
				board_t2 = board_t1
				board_t1 = copy_board(&board)
				if board.state == .GameRemove {
					confirm_removal(&board)
				} else {
					pass(&board)
				}
			}
		}

		// Over and put stone
		mouse_pos := rl.GetMousePosition()
		mx, my := mouse_to_grid(mouse_pos)
		if (mx >= 0 && mx < w && my >= 0 && my < h) {
			turn_color: rl.Color
			if board.turn == .PlayerBlack {
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
				#partial switch board.state {
				case .GameRemove:
					toggle_remove(&board, int(mx), int(my))
				case .GamePlaying:
					before_put := copy_board(&board)
					ok := put_stone(&board, int(mx), int(my))
					ko := board_stones_equals(&board, &board_t2)
					if ok && !ko {
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

		// Draw stones (with removal transparency if in remove mode)
		for x: i32 = 0; x < w; x += 1 {
			for y: i32 = 0; y < h; y += 1 {
				s := get_stone(&board, int(x), int(y))
				color: rl.Color

				switch s {
				case .StoneEmpty:
					continue
				case .StoneBlack:
					color = rl.BLACK
				case .StoneWhite:
					color = rl.WHITE
				case .TerritoryBlack:
					color = rl.BLACK
					color.a = 127
				case .TerritoryWhite:
					color = rl.WHITE
					color.a = 127
				case .TerritoryNone:
				}

				to_be_removed := get_stone_removal(&board, int(x), int(y))
				if board.state == .GameRemove && to_be_removed {
					color.a = 127
				}

				if s == .StoneBlack || s == .StoneWhite {
					rl.DrawCircle(
						x * GRID_SPACING + LEFT_GRID_X,
						y * GRID_SPACING + TOP_GRID_Y,
						STONE_RADIUS,
						color,
					)
				} else if s == .TerritoryBlack || s == .TerritoryWhite {
					rl.DrawRectangle(
						x * GRID_SPACING + LEFT_GRID_X - STONE_RADIUS / 4,
						y * GRID_SPACING + TOP_GRID_Y - STONE_RADIUS / 4,
						STONE_RADIUS / 2,
						STONE_RADIUS / 2,
						color,
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
		switch board.state {
		case .GameRemove:
			rl.DrawText("Turn: Remove", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
		case .GamePlaying:
			if board.turn == .PlayerBlack {
				rl.DrawText("Turn: Black", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
			} else {
				rl.DrawText("Turn: White", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
			}
		case .GameTerritory:
			rl.DrawText("Territory", 10, SCREEN_HEIGHT - 30, 20, rl.BLACK)
		}

		rl.EndDrawing()
	}
}
