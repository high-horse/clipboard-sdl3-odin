package main

import "core:fmt"
import "core:sync/chan"
import "core:thread"

import sdl "vendor:sdl3"

import "clipboard"

HEIGHT :: 400;
WIDTH :: 600;

AppState :: struct {
    window:        ^sdl.Window,
	renderer:      ^sdl.Renderer,
	running:       bool,
	show_window:   bool,
	height, width: int,
}


Worker_Data :: struct {
	ch: chan.Chan(clipboard.Clipboard_Data),
	running: ^bool,
}

main :: proc() {
    if !sdl.Init({.VIDEO}) {
        fmt.eprintfln("failed to init sdl : %s", sdl.GetError());
        return
    }
    defer sdl.Quit()

    app := AppState {
        height = HEIGHT,
        width = WIDTH,
        show_window = true,
        running = true,
    }

    app.window = sdl.CreateWindow("clipboaed", cast(i32)app.width, cast(i32)app.height, {.RESIZABLE});
    if app.window == nil {
        fmt.eprintfln("Failed to init window: %s", sdl.GetError());
        return;
    }
    defer sdl.DestroyWindow(app.window)

    app.renderer = sdl.CreateRenderer(app.window, nil);
    if app.renderer == nil {
        fmt.eprintfln("Failed to init renderer: %s", sdl.GetError());
        return
    }
    defer sdl.DestroyRenderer(app.renderer);

    ch, err := chan.create_buffered(chan.Chan(clipboard.Clipboard_Data), 16, context.allocator);
    assert(err == .None);
    defer chan.destroy(ch)

    data := new(Worker_Data);
    data.ch = ch
    data.running = &app.running;
    defer free(data);

    worker := thread.create_and_start_with_data(data, clipboard_worker_thred);

    mainloop(&app, ch);
    thread.join(worker);
}


mainloop :: proc(app: ^AppState, ch: chan.Chan(clipboard.Clipboard_Data)) {
	for app.running {
		event: sdl.Event

		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				app.running = false;

			case .KEY_DOWN:
				if event.key.scancode == .ESCAPE {
					app.running = false;
				}
			}
			
		}

		for {
			text, ok := chan.try_recv(ch);
			if !ok {
				break;
			}
			fmt.println("clipboard content changed:", text);
		}
		sdl.SetRenderDrawColor(app.renderer, 30, 40, 60, 255)
		sdl.RenderClear(app.renderer)
		sdl.RenderPresent(app.renderer)
	}
}


clipboard_worker_thred :: proc(data: rawptr){
	wd := cast(^Worker_Data)data
    // sdl_clipboard_worker(wd);
	watch_clipboard_get_generic(wd);
    fmt.println("worker returned");
}