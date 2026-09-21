package main

import "base:runtime"
import "core:fmt"
import sdl "vendor:sdl3"

set_window_visible :: proc(app: ^AppState, visible: bool) {
	if visible {
		if sdl.ShowWindow(app.window) {
			app.show_window = true
			_ = sdl.RaiseWindow(app.window)
		}
	} else if sdl.HideWindow(app.window) {
		app.show_window = false
	}
}

tray_show :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	set_window_visible(cast(^AppState)userdata, true)
}

tray_hide :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	set_window_visible(cast(^AppState)userdata, false)
}

tray_quit :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	app := cast(^AppState)userdata
	app.running = false
}

create_app_tray :: proc(app: ^AppState) -> ^sdl.Tray {
	// Draw a clipboard icon without requiring an external image file.
	icon := sdl.CreateSurface(32, 32, .RGBA32)
	if icon == nil {
		fmt.eprintfln("Could not create tray icon: %s", sdl.GetError())
		return nil
	}
	defer sdl.DestroySurface(icon)
	_ = sdl.FillSurfaceRect(icon, nil, sdl.MapSurfaceRGBA(icon, 0, 0, 0, 0))
	ink := sdl.MapSurfaceRGBA(icon, 235, 240, 250, 255)
	blue := sdl.MapSurfaceRGBA(icon, 40, 100, 170, 255)
	board := sdl.Rect{5, 5, 22, 25}
	paper := sdl.Rect{8, 8, 16, 19}
	clip := sdl.Rect{11, 2, 10, 7}
	_ = sdl.FillSurfaceRect(icon, &board, ink)
	_ = sdl.FillSurfaceRect(icon, &paper, blue)
	_ = sdl.FillSurfaceRect(icon, &clip, ink)
	for y: i32 = 12; y <= 22; y += 5 {
		line := sdl.Rect{11, y, 10, 2}
		_ = sdl.FillSurfaceRect(icon, &line, ink)
	}
	tray := sdl.CreateTray(icon, "Clipboard Manager")
	if tray == nil {
		fmt.eprintfln("Tray unavailable: %s", sdl.GetError())
		return nil
	}
	menu := sdl.CreateTrayMenu(tray)
	if menu == nil {
		sdl.DestroyTray(tray)
		return nil
	}
	show := sdl.InsertTrayEntryAt(menu, -1, "Show Clipboard Manager", {.BUTTON})
	hide := sdl.InsertTrayEntryAt(menu, -1, "Hide window", {.BUTTON})
	quit := sdl.InsertTrayEntryAt(menu, -1, "Quit", {.BUTTON})
	if show == nil || hide == nil || quit == nil {
		sdl.DestroyTray(tray)
		return nil
	}
	sdl.SetTrayEntryCallback(show, tray_show, app)
	sdl.SetTrayEntryCallback(hide, tray_hide, app)
	sdl.SetTrayEntryCallback(quit, tray_quit, app)
	fmt.println("Clipboard Manager tray icon created")
	return tray
}
