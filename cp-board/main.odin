package main

import "core:time"

import "core:fmt"
import "core:os"
import "core:sync/chan"
import "core:thread"
import "core:strings"

// import "core:context"

import sdl "vendor:sdl3"


HEIGHT :: 400
WIDTH :: 600

AppState :: struct {
	window:        ^sdl.Window,
	renderer:      ^sdl.Renderer,
	running:       bool,
	show_window:   bool,
	height, width: int,
}


MimeType :: enum {
    TEXT,
    IMAGE,
    VIDEO,
    OTHER,
}

ClipBoard :: struct {
    mimetype: MimeType,
    size: int,
    content: string,
}

Worker_Data :: struct {
	ch: chan.Chan(string),
}

main :: proc() {
	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("failed to initialize sdl : %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	app := AppState {
		height      = HEIGHT,
		width       = WIDTH,
		show_window = true,
		running     = true,
	}

	app.window = sdl.CreateWindow("ODIN + SDL3 window ", 800, 600, {.RESIZABLE})
	if app.window == nil {
		fmt.eprintfln("failed to create window: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.DestroyWindow(app.window)

	app.renderer = sdl.CreateRenderer(app.window, nil)
	if app.renderer == nil {
		fmt.eprintfln("failed to init renderer, %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.DestroyRenderer(app.renderer)

	// ch := chan.make(string)
	ch, err := chan.create_buffered(chan.Chan(string), 16, context.allocator)
	assert(err == .None) 
	defer chan.destroy(ch)
	
	data := new(Worker_Data)
	data.ch = ch
	defer free(data)

	worker := thread.create_and_start_with_data(data, clipboard_worker_thred)

	mainloop(&app, ch);

	thread.join(worker);
}

mainloop :: proc(app: ^AppState, ch: chan.Chan(string)) {
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

			case .CLIPBOARD_UPDATE:
				fmt.println("clipboard changed!")

				text := clipboard()
				fmt.println("content:", text.content)
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

clipboard :: proc() -> ClipBoard {
	raw := sdl.GetClipboardText();
	defer sdl.free(raw);

	// fmt.printfln("content received from clipboard: %s", string(cstring(raw)))
    content := strings.clone(string(cstring(raw)))

	return ClipBoard {
		mimetype = MimeType.TEXT,
		size = len(content),
        content = content,
	}
}


clipboard_worker_thred :: proc(data: rawptr){
	wd := cast(^Worker_Data)data
	clipboard_worker(wd.ch)
}

clipboard_worker :: proc(ch: chan.Chan(string)) {
	previous := ""
	for {
		current := clipboard().content;
		if current != previous {
			fmt.printfln("sending changed content to channel : \"%s\"", current);
			chan.send(ch, current);
			previous = current;
		}
		time.sleep(100 * time.Millisecond);
	}
}