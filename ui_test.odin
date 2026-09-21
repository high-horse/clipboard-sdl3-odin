package main

import "core:testing"
import "core:os"
import "core:strings"
import sql "sqlite3"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
clipboard_layout_test :: proc(t: ^testing.T) {
	if !testing.expect(t, sdl.Init({.VIDEO}), "SDL video must initialize (use SDL_VIDEO_DRIVER=dummy)") { return }
	defer sdl.Quit()
	if !testing.expect(t, ttf.Init()) { return }
	defer ttf.Quit()
	app := AppState{selected_index = -1, pressed_index = -1, copied_index = -1}
	app.window = sdl.CreateWindow("Layout test", 680, 560, {.HIDDEN, .RESIZABLE})
	if !testing.expect(t, app.window != nil) { return }
	defer sdl.DestroyWindow(app.window)
	app.renderer = sdl.CreateRenderer(app.window, "software")
	if !testing.expect(t, app.renderer != nil) { return }
	defer sdl.DestroyRenderer(app.renderer)
	app.font = ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 18)
	app.small_font = ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 13)
	app.title_font = ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 26)
	if !testing.expect(t, app.font != nil && app.small_font != nil && app.title_font != nil) { return }
	defer ttf.CloseFont(app.font)
	defer ttf.CloseFont(app.small_font)
	defer ttf.CloseFont(app.title_font)
	app.clipboard_items = make([dynamic]database_content)
	defer delete(app.clipboard_items)
	testing.expect(t, clipboard_item_at(&app, 40, 110) == -1, "Empty state is not clickable")
	button := clear_button_rect(&app)
	testing.expect(t, !clear_button_at(&app, button.x + 10, button.y + 10), "Clear is disabled for an empty list")
	render_clipboard_ui(&app)
	texts := []string{
		"A short note for later.",
		"https://example.com/design/clipboard",
		"First line\nSecond line\nThird line should stay inside the card.",
		"A longer clipboard entry wraps to the available width. The full content is preserved when you copy it.",
	}
	for text in texts {
		append(&app.clipboard_items, database_content{mime = "text/plain", data = transmute([]u8)strings.clone(text)})
	}
	defer for item in app.clipboard_items { delete(item.data) }
	layout := list_layout(&app)
	testing.expect(t, clipboard_item_at(&app, layout.x + 10, LIST_TOP + 10) == 3, "Newest item comes first")
	testing.expect(t, clipboard_item_at(&app, layout.x + 10, LIST_TOP + CARD_HEIGHT + 2) == -1, "Card gaps are not clickable")
	testing.expect(t, clipboard_item_at(&app, layout.x - 1, LIST_TOP + 10) == -1, "Margins are not clickable")
	testing.expect(t, clipboard_item_at(&app, layout.x + 10, LIST_TOP - 1) == -1, "Header is not clickable")
	navigate_items(&app, .END)
	testing.expect(t, app.selected_index == 0 && app.scroll > 0, "End reveals oldest item")
	navigate_items(&app, .HOME)
	testing.expect(t, app.selected_index == 3 && app.scroll == 0, "Home returns to newest item")
	sizes := [][2]i32{{680, 560}, {320, 280}, {1200, 800}}
	for size in sizes {
		_ = sdl.SetWindowSize(app.window, size[0], size[1])
		clamp_scroll(&app)
		layout = list_layout(&app)
		button = clear_button_rect(&app)
		testing.expect(t, button.x >= layout.x && button.x + button.w <= layout.x + layout.width, "Clear button fits window")
		testing.expect(t, clear_button_at(&app, button.x + 10, button.y + 10), "Clear button is clickable with items")
		testing.expect(t, layout.x >= 0 && layout.x + layout.width <= f32(size[0]), "Cards fit resized window")
		app.scroll = 100000
		clamp_scroll(&app)
		testing.expect(t, app.scroll == layout.max_scroll, "Scroll stops at content end")
		testing.expect(t, clipboard_item_at(&app, layout.x + 10, layout.bottom) == -1, "Footer is not clickable")
		app.scroll = 0
		render_clipboard_ui(&app)
		when #config(UI_SCREENSHOTS, false) {
			surface := sdl.RenderReadPixels(app.renderer, nil)
			if testing.expect(t, surface != nil) {
				path: cstring = "/tmp/clipboard-ui-wide.png"
				if size[0] == 320 { path = "/tmp/clipboard-ui-narrow.png" }
				if size[0] == 680 { path = "/tmp/clipboard-ui-default.png" }
				testing.expect(t, sdl.SavePNG(surface, path))
				sdl.DestroySurface(surface)
			}
		}
	}
	// Exercise clearing with an isolated database and temporary blob directory.
	previous_db := g_db
	previous_generation := history_generation
	defer { g_db = previous_db; history_generation = previous_generation }
	dir, err := os.make_directory_temp("/tmp", "clipboard-clear-test-", context.allocator)
	if !testing.expect(t, err == nil) { return }
	defer delete(dir)
	defer os.remove(dir)
	g_db = Database{blob_dir = dir, initialized = true}
	if !testing.expect(t, sql.open(":memory:", &g_db.db) == nil) { return }
	defer sql.close(g_db.db)
	if !testing.expect(t, prepare_table(&g_db)) { return }
	item := database_content{mime = "text/plain", data = transmute([]u8)string("test"), hash = "test-blob", generation = history_generation}
	testing.expect(t, set_db_content_with_blob(&item))
	testing.expect(t, set_db_content_with_blob(&item), "Repeated copies can share a blob")
	path := strings.concatenate({dir, "/test-blob"})
	defer delete(path)
	defer if os.exists(path) { os.remove(path) }
	testing.expect(t, os.exists(path))
	clear_history(&app)
	testing.expect(t, len(app.clipboard_items) == 0 && app.scroll == 0 && app.selected_index == -1, "Clear resets list and selection")
	testing.expect(t, !os.exists(path), "Clear deletes saved blobs")
	testing.expect(t, app.history_generation == previous_generation + 1, "Queued old items are invalidated")
	testing.expect(t, !set_db_content_with_blob(&item), "In-flight old captures cannot restore cleared data")
	stmt: ^sql.Statement
	if testing.expect(t, sql.prepare_v2(g_db.db, "SELECT count(*) FROM clipboard_contents", -1, &stmt, nil) == .Ok) {
		defer sql.finalize(stmt)
		testing.expect(t, sql.step(stmt) == .Row && sql.column_int(stmt, 0) == 0, "Saved history is empty")
	}
	instance, primary, instance_ok := start_instance(dir, true, "")
	if !testing.expect(t, instance_ok && primary, "First launch owns the instance lock") { return }
	app.instance = instance
	defer close_instance(&instance)
	lock_path := strings.concatenate({dir, "/instance.lock"})
	defer delete(lock_path)
	defer os.remove(lock_path)
	_, second_primary, second_ok := start_instance(dir, true, "")
	testing.expect(t, second_ok && !second_primary && !os.exists(instance.request_path), "Background relaunch does not create another window")
	_, second_primary, second_ok = start_instance(dir, false, "test-activation-token")
	testing.expect(t, second_ok && !second_primary && os.exists(instance.request_path), "Shortcut relaunch requests the existing window")
	set_window_visible(&app, false)
	poll_show_request(&app)
	testing.expect(t, app.show_window && !os.exists(instance.request_path), "Activation request shows the window and is consumed")
	_ = sdl.unsetenv_unsafe("XDG_ACTIVATION_TOKEN")
}
