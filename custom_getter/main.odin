package main

import "core:fmt"
import "core:sync/chan"
import "core:thread"
import "core:os"

import sdl "vendor:sdl3"

import "clipboard"

HEIGHT :: 400
WIDTH :: 600
APP_NAME :: "SDL3 odin Clipboard Manager"
APP_ID :: "com.example.odinsdl3clipboardmanager"
BLOB_DIR_NAME :: "blobs"
DB_FILE_NAME :: "clipboard.db"
APP_DATA_DIR :: "sdl3-clipboard-manager"



AppState :: struct {
	window:        ^sdl.Window,
	renderer:      ^sdl.Renderer,
	running:       bool,
	show_window:   bool,
	height, width: int,
}


Worker_Data :: struct {
	ch:      chan.Chan(clipboard.Clipboard_Data),
	running: ^bool,
}

init_storage :: proc() -> (data_dir, db_path, blob_dir: string, ok: bool) {
	data_dir = get_data_dir()

	if !os.exists(data_dir) {
		if err := os.make_directory_all(data_dir); err != nil {
			fmt.eprintfln("failed to create data dir: %v", err)
			return "", "", "", false
		}
	}

	blob_dir = fmt.aprintf("%s/%s", data_dir, BLOB_DIR_NAME)

	if !os.exists(blob_dir) {
		if err := os.make_directory_all(blob_dir); err != nil {
			fmt.eprintfln("failed to create blob directory: %v", err)
			return "", "", "", false
		}
	}

	db_path = fmt.aprintf("%s/%s", data_dir, DB_FILE_NAME)

	return data_dir, db_path, blob_dir, true
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
	
	database, ok := database_init()
    if !ok {
    	fmt.eprintfln("failed to init database")
        return
    }

	app := AppState {
		height      = HEIGHT,
		width       = WIDTH,
		show_window = true,
		running     = true,
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

	ch, err := chan.create_buffered(chan.Chan(clipboard.Clipboard_Data), 16, context.allocator)
	assert(err == .None)
	defer chan.destroy(ch)

	data := new(Worker_Data)
	data.ch = ch
	data.running = &app.running
	defer free(data)

	worker := thread.create_and_start_with_data(data, clipboard_worker_thred)

	mainloop(&app, ch)
	thread.join(worker)
}


mainloop :: proc(app: ^AppState, ch: chan.Chan(clipboard.Clipboard_Data)) {
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
			text, ok := chan.try_recv(ch)
			if !ok {
				break
			}
			fmt.println("clipboard content changed:", text)
		}
		sdl.SetRenderDrawColor(app.renderer, 30, 40, 60, 255)
		sdl.RenderClear(app.renderer)
		sdl.RenderPresent(app.renderer)
	}
}


clipboard_worker_thred :: proc(data: rawptr) {
	wd := cast(^Worker_Data)data
	// sdl_clipboard_worker(wd);
	watch_clipboard_get_generic_hashed(wd)
	// watch_clipboard_get_generic(wd);
	fmt.println("worker returned")
}
