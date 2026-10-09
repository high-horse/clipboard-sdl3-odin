package main

import "core:fmt"
import "core:os"
import "core:sync/chan"
import "core:thread"

import sdl "vendor:sdl3"
import tray_api "tray_backend"

import "clipboard"

HEIGHT :: 560
WIDTH :: 680
APP_NAME :: "SDL3 odin Clipboard Manager"
APP_ID :: "com.example.odinsdl3clipboardmanager"
BLOB_DIR_NAME :: "blobs"
DB_FILE_NAME :: "cd.slm"
CONFIG_FILE_NAME :: "cfg.jsn"
APP_DATA_DIR :: "sdl3-clipboard-manager"


AppState :: struct {
	window:               ^sdl.Window,
	renderer:             ^sdl.Renderer,
	pointer_cursor:       ^sdl.Cursor,
	default_cursor:       ^sdl.Cursor,
	instance:             App_Instance,
	running:              bool,
	show_window:          bool,
	resources:            Resource_Usage,
	image_previews:        [dynamic]Image_Preview,
	height, width:        int,
	clipboard_items:      [dynamic]database_content,
	copied_index:         int,
	copied_until:         u64,
	scroll:               f32,
	selected_index:       int,
	pressed_index:        int,
	copy_failed:          bool,
	clear_pressed:        bool,
	pressed_action:       Card_Action,
	history_generation:   u64,
	history_status:       string,
	history_status_until: u64,

	tray:                 ^tray_api.Tray,
	tray_history_menu:    ^tray_api.TrayMenu,
	tray_visibility_entry: ^tray_api.TrayEntry,
	tray_history_data:    [dynamic]^Tray_Item_Data,
	tray_delete_hash:     string,
	search_query:         string,
	search_indices:       [dynamic]int,
	search_focused, search_select_all: bool,
	tray_search_query:    string,
	tray_search_dirty:    bool,
	tray_page, tray_page_delta: int,
}


Worker_Data :: struct {
	ch:      chan.Chan(database_content),
	running: ^bool,
}

init_storage :: proc() -> (data_dir, db_path, blob_dir, config_file_name: string, ok: bool) {
	data_dir = get_data_dir()

	if !os.exists(data_dir) {
		if err := os.make_directory_all(data_dir); err != nil {
			fmt.eprintfln("failed to create data dir: %v", err)
			return "", "", "", "", false
		}
	}

	blob_dir = fmt.aprintf("%s/%s", data_dir, BLOB_DIR_NAME)

	if !os.exists(blob_dir) {
		if err := os.make_directory_all(blob_dir); err != nil {
			fmt.eprintfln("failed to create blob directory: %v", err)
			return "", "", "", "", false
		}
	}

	db_path = fmt.aprintf("%s/%s", data_dir, DB_FILE_NAME)

	return data_dir, db_path, blob_dir, CONFIG_FILE_NAME, true
}


get_data_dir :: proc() -> string {
	xdg := os.get_env("XDG_DATA_HOME", context.allocator)
	if xdg != "" {
		return fmt.aprintf("%s/%s", xdg, APP_DATA_DIR)
	}

	home := os.get_env("HOME", context.allocator)
	if home == "" {
		home = "/tmp"
	}
	return fmt.aprintf("%s/.local/share/%s", home, APP_DATA_DIR)
}

main :: proc() {
	background := false
	for arg in os.args[1:] {
		if arg == "--background" {background = true}
	}
	runtime_dir := os.get_env("XDG_RUNTIME_DIR", context.allocator)
	defer delete(runtime_dir)
	if runtime_dir == "" {
		fmt.eprintln("XDG_RUNTIME_DIR is required; launch from your desktop session.")
		return
	}
	instance_dir := fmt.aprintf("%s/sdl3-clipboard-manager", runtime_dir)
	defer delete(instance_dir)
	token := os.get_env("XDG_ACTIVATION_TOKEN", context.allocator)
	defer delete(token)
	instance, primary, instance_ok := start_instance(instance_dir, background, token)
	if !instance_ok {
		fmt.eprintln("Could not start or activate clipboard manager.")
		return
	}
	if !primary {return}
	defer close_instance(&instance)
	if ok := sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_IDENTIFIER_STRING, APP_ID); ok {
		_ = sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_NAME_STRING, APP_NAME)
	} else {
		fmt.eprintfln("failed to set app metadata")
		return
	}

	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("failed to init SDL: %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	if !init_fonts() {
		fmt.eprintln("Failed to initialize fonts")
		destroy_fonts()
		return
	}

	defer destroy_fonts()

	ok := database_init()
	if !ok {
		fmt.eprintfln("failed to init database")
		return
	}
	items, db_ok := load_all_contents()
	if !db_ok {
		fmt.eprintfln("failed to load clipboard contents")
		return
	}

	app := AppState {
		instance        = instance,
		height          = HEIGHT,
		width           = WIDTH,
		show_window     = true,
		running         = true,
		// clipboard_items = make([dynamic]database_content, 0, context.allocator),
		clipboard_items = items,
		copied_index    = -1,
		selected_index  = -1,
		pressed_index   = -1,
	}

	window_flags := sdl.WindowFlags{.RESIZABLE}
	if background {window_flags += {.HIDDEN}}
	app.window = sdl.CreateWindow(
		"Clipboard Manager",
		cast(i32)app.width,
		cast(i32)app.height,
		window_flags,
	)
	if app.window == nil {
		fmt.eprintfln("Failed to init window: %s", sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(app.window)
	_ = sdl.SetWindowMinimumSize(app.window, 320, 280)

	app.renderer = sdl.CreateRenderer(app.window, nil)
	if app.renderer == nil {
		fmt.eprintfln("Failed to init renderer: %s", sdl.GetError())
		return
	}
	defer sdl.DestroyRenderer(app.renderer)
	defer clear_image_previews(&app)
	defer {
		delete(app.search_query)
		delete(app.search_indices)
		delete(app.tray_search_query)
	}
	focus_window_search(&app, !background)
	app.pointer_cursor = sdl.CreateSystemCursor(.POINTER)
	app.default_cursor = sdl.CreateSystemCursor(.DEFAULT)
	defer if app.pointer_cursor != nil {sdl.DestroyCursor(app.pointer_cursor)}
	defer if app.default_cursor != nil {sdl.DestroyCursor(app.default_cursor)}
	app.tray = create_app_tray(&app)
	configure_window_close_behavior(&app)
	if app.tray != nil {
		update_tray_history(&app)
	}

	if background && app.tray != nil {
		set_window_visible(&app, false)
	} else if background {
		set_window_visible(&app, true)
	}
	defer {
		clear_tray_history_data(&app)

		if app.tray != nil {
			tray_api.DestroyTray(app.tray)
		}
	}
	ch, err := chan.create_buffered(chan.Chan(database_content), 16, context.allocator)
	assert(err == .None)
	defer chan.destroy(ch)

	data := new(Worker_Data)
	data.ch = ch
	data.running = &app.running
	defer free(data)



	ok = clipboard.create()
	if !ok {
		fmt.println("Could not initialize clipboard.")
		return
	}
	defer clipboard.destroy()
	worker := thread.create_and_start_with_data(data, clipboard_worker_thred)


	mainloop(&app, ch)
	thread.join(worker)
}


mainloop :: proc(app: ^AppState, ch: chan.Chan(database_content)) {
	defer delete(app.tray_delete_hash)
	for app.running {
		tray_api.UpdateTrays()
		poll_show_request(app)
		event: sdl.Event

		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				app.running = false
			case .WINDOW_CLOSE_REQUESTED:
				close_main_window(app)

			case .KEY_DOWN:
				ctrl := .LCTRL in event.key.mod || .RCTRL in event.key.mod
				if ctrl && event.key.scancode == .F {
					focus_window_search(app, true)
					app.search_select_all = true
					continue
				}
				if app.search_focused {
					if handle_search_key(app, event.key.scancode, ctrl) { continue }
				}
				#partial switch event.key.scancode {
				case .ESCAPE:
					close_main_window(app)
				case .DOWN, .UP, .HOME, .END:
					navigate_items(app, event.key.scancode)
				case .RETURN, .SPACE:
					if !event.key.repeat {copy_item(app, app.selected_index)}
				case .DELETE:
					if !event.key.repeat {delete_item(app, app.selected_index)}
				case .P:
					if !app.search_focused && !event.key.repeat {toggle_pin(app, app.selected_index)}
				}
			case .TEXT_INPUT:
				if app.search_focused { append_window_search(app, string(event.text.text)) }
			case .MOUSE_WHEEL:
				delta := event.wheel.y
				if event.wheel.direction == .FLIPPED {delta = -delta}
				app.scroll -= delta * 44
				clamp_scroll(app)
			case .WINDOW_RESIZED:
				clamp_scroll(app)
			case .RENDER_DEVICE_RESET:
				clear_image_previews(app)
			case .WINDOW_FOCUS_LOST:
				app.pressed_index = -1
				app.clear_pressed = false
			case .MOUSE_BUTTON_DOWN:
				if app.show_window && event.button.button == sdl.BUTTON_LEFT {
					focus_window_search(app, window_search_at(app, event.button.x, event.button.y))
					if window_search_clear_at(app, event.button.x, event.button.y) { set_window_search(app, "") }
					app.clear_pressed = clear_button_at(app, event.button.x, event.button.y)
					app.pressed_index = clipboard_item_at(app, event.button.x, event.button.y)
					app.pressed_action = card_action_at(app, event.button.x, event.button.y)
				}
			case .MOUSE_BUTTON_UP:
				if app.show_window && event.button.button == sdl.BUTTON_LEFT {
					if app.clear_pressed && clear_button_at(app, event.button.x, event.button.y) {
						clear_history(app)
					}
					app.clear_pressed = false
					index := clipboard_item_at(app, event.button.x, event.button.y)
					if index >= 0 && index == app.pressed_index {
						app.selected_index = index
						if card_action_at(app, event.button.x, event.button.y) == app.pressed_action {
							switch app.pressed_action {
							case .Copy: copy_item(app, index)
							case .Pin: toggle_pin(app, index)
							case .Delete: delete_item(app, index)
							}
						}
					}
					app.pressed_index = -1
				}
			}
		}

		process_tray_delete(app)
		if app.tray_search_dirty || app.tray_page_delta != 0 {
			app.tray_page += app.tray_page_delta
			app.tray_page_delta = 0
			app.tray_search_dirty = false
			update_tray_history(app)
		}
		if tray_api.TakeSearchActivate(app.tray_history_menu) { copy_first_tray_match(app) }
		for {
			item, ok := chan.try_recv(ch)
			if !ok {
				break
			}
			if item.generation != app.history_generation || !database_has_hash(item.hash) {
				delete(item.data)
				delete(item.hash)
				continue
			}
			if item.reorder {
				move_clipboard_item_to_top(app, item.hash)
				delete(item.data)
				delete(item.hash)
				update_tray_history(app)

				app.scroll = 0
				app.selected_index = -1
				continue
			}
			if app.scroll > 0 {
				app.scroll += CARD_STEP
			}

			append(&app.clipboard_items, item)
			arrange_favorites(app)
			enforce_max_entries(app)
			update_tray_history(app)

			fmt.printfln(
				"clipboard content changed from mainloop: mime=%s, bytes=%d",
				item.mime,
				len(item.data),
			)

		}
		if !app.show_window {
			sdl.Delay(30)
			continue
		}
		render_clipboard_ui(app)
		sdl.RenderPresent(app.renderer)
		sdl.Delay(16)
	}

	defer {
		for item in app.clipboard_items {
			delete(item.data)
			delete(item.hash)
		}
		delete(app.clipboard_items)
	}
}

clipboard_worker_thred :: proc(data: rawptr) {
	wd := cast(^Worker_Data)data
	// sdl_clipboard_worker(wd);
	watch_clipboard_get_generic_hashed(wd)
	// watch_clipboard_get_generic(wd);
	fmt.println("worker returned")
}


enforce_max_entries :: proc(app: ^AppState) {
	max_entries, ok := get_max_entries()
	if !ok || max_entries <= 0 {
		return
	}

	unpinned := 0
	for item in app.clipboard_items { if !item.pinned { unpinned += 1 } }
	for unpinned > max_entries {
		unpinned -= 1
		oldest := app.clipboard_items[0]

		ordered_remove(&app.clipboard_items, 0)

		delete(oldest.data)
		delete(oldest.hash)
	}
}
