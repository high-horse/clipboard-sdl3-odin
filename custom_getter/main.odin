package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sync/chan"
import "core:thread"

import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

import "clipboard"

HEIGHT :: 400
WIDTH :: 600
APP_NAME :: "SDL3 odin Clipboard Manager"
APP_ID :: "com.example.odinsdl3clipboardmanager"
BLOB_DIR_NAME :: "blobs"
DB_FILE_NAME :: "cd.slm"
CONFIG_FILE_NAME :: "cfg.jsn"
APP_DATA_DIR :: "sdl3-clipboard-manager"


AppState :: struct {
	window:          ^sdl.Window,
	renderer:        ^sdl.Renderer,
	font:            ^ttf.Font,

	running:         bool,
	show_window:     bool,
	height, width:   int,

	clipboard_items: [dynamic]database_content,
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
	if ok := sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_IDENTIFIER_STRING, APP_ID); ok {
		_ = sdl.SetAppMetadataProperty(sdl.PROP_APP_METADATA_NAME_STRING, APP_NAME)
	} else {
		fmt.eprintfln("failed to set app metadata")
		return
	}

	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("failed to init sdl : %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	if !ttf.Init() {
		fmt.eprintfln("Failed to initialize SDL_ttf: %s", sdl.GetError())
		return
	}

	defer ttf.Quit()

	// font := ttf.OpenFont("/usr/share/fonts/liberation/LiberationSans-Regular.ttf", 18)
	font := ttf.OpenFont("/usr/share/fonts/truetype/freefont/FreeSans.ttf", 18)
	
	if font == nil {
		fmt.eprintfln("Failed to load font: %s", sdl.GetError())
		return
	}

	defer ttf.CloseFont(font)


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
		height          = HEIGHT,
		width           = WIDTH,
		show_window     = true,
		running         = true,
		clipboard_items = items,
		font            = font,
	}

	app.window = sdl.CreateWindow(
		"clipboaed",
		cast(i32)app.width,
		cast(i32)app.height,
		{.RESIZABLE},
	)
	if app.window == nil {
		fmt.eprintfln("Failed to init window: %s", sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(app.window)

	app.renderer = sdl.CreateRenderer(app.window, nil)
	if app.renderer == nil {
		fmt.eprintfln("Failed to init renderer: %s", sdl.GetError())
		return
	}
	defer sdl.DestroyRenderer(app.renderer)

	ch, err := chan.create_buffered(chan.Chan(database_content), 16, context.allocator)
	assert(err == .None)
	defer chan.destroy(ch)

	data := new(Worker_Data)
	data.ch = ch
	data.running = &app.running
	defer free(data)


	worker := thread.create_and_start_with_data(data, clipboard_worker_thred)

	ok = clipboard.create()
	if !ok {
		fmt.println("Could not initialize clipboard.")
		return
	}
	defer clipboard.destroy()

	text_to_copy := "sdl.SetClipboardData() is working!"
	// db_content := database_content {
	//     data         = transmute([]u8)(text_to_copy), // Use '=' instead of ':'
	//     mime         = "text/plain",
	//     hash         = "",
	//     content_path = "",
	// }
	// fmt.println("setting contne")
	// set_content(&db_content)
	cb_content := clipboard.Clipboard_Data {
		mime = "text/plain",
		data = transmute([]u8)(text_to_copy),
	}
	fmt.printfln("setting content : '%s'", text_to_copy)
	clipboard.set_content(&cb_content)

	mainloop(&app, ch)
	thread.join(worker)
}

enforce_max_entries :: proc(app: ^AppState) {
	max_entries, ok := get_max_entries()
	if !ok || max_entries <= 0 {
		return
	}

	for len(app.clipboard_items) > max_entries {
		oldest := app.clipboard_items[0]

		ordered_remove(&app.clipboard_items, 0)

		delete(oldest.data)
		delete(oldest.mime)
		delete(oldest.hash)
		delete(oldest.content_path)
	}
}


mainloop :: proc(app: ^AppState, ch: chan.Chan(database_content)) {
	for app.running {
		event: sdl.Event

		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				app.running = false

			case .KEY_DOWN:
				if event.key.scancode == .ESCAPE {
					app.running = false
				}
			}
		}

		for {
			item, ok := chan.try_recv(ch)
			if !ok {
				break
			}
			append(&app.clipboard_items, item)
			enforce_max_entries(app)
			fmt.printfln(
				"clipboard content changed  from mainloop:: mime=%s, bytes=%d",
				item.mime,
				len(item.data),
			)
			fmt.println("clipboard content changed from mainloop:", cast(string)item.data)

			max_entries, has_limit := get_max_entries()
			if has_limit {
				for len(app.clipboard_items) > max_entries {
					oldest := app.clipboard_items[0]
					ordered_remove(&app.clipboard_items, 0)
					delete(oldest.data)
				}
			}
		}
		sdl.SetRenderDrawColor(app.renderer, 30, 40, 60, 255)
		sdl.RenderClear(app.renderer)

		y := f32(20)
		count := len(app.clipboard_items)
		for offset := 0; offset < count; offset += 1 {
			i := count - 1 - offset
			item := app.clipboard_items[i]
			text := clipboard_preview(item)
			draw_text(app, text, 20, y)
			y += 30
		}
		sdl.RenderPresent(app.renderer)
	}

	defer {
		for item in app.clipboard_items {
			delete(item.data)
			delete(item.mime)
			delete(item.hash)
			delete(item.content_path)
		}
		delete(app.clipboard_items)
	}
}

draw_text :: proc(app: ^AppState, text: string, x: f32, y: f32) {

	color := sdl.Color{255, 255, 255, 255}
	text_cs := strings.clone_to_cstring(text, context.allocator)
	surface := ttf.RenderText_Blended(app.font, text_cs, c.size_t(len(text_cs)), color)
	if surface == nil {
		return
	}

	defer sdl.DestroySurface(surface)
	texture := sdl.CreateTextureFromSurface(app.renderer, surface)
	if texture == nil {
		return
	}
	defer sdl.DestroyTexture(texture)

	rect := sdl.FRect {
		x = x,
		y = y,
		w = f32(surface.w),
		h = f32(surface.h),
	}
	sdl.RenderTexture(app.renderer, texture, nil, &rect)

}

clipboard_preview :: proc(item: database_content) -> string {
	switch item.mime {
	case "text/plain":
		return transmute(string)item.data

	case "text/uri-list":
		return "[Files / URLs]"

	case "image/png":
		return "[PNG Image]"

	case "image/jpeg":
		return "[JPEG Image]"

	case:
		return fmt.aprintf("[%s]", item.mime)
	}
}


clipboard_worker_thred :: proc(data: rawptr) {
	wd := cast(^Worker_Data)data
	// sdl_clipboard_worker(wd);
	watch_clipboard_get_generic_hashed(wd)
	// watch_clipboard_get_generic(wd);
	fmt.println("worker returned")
}

