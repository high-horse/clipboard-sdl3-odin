package main

import "core:testing"
import sdl "vendor:sdl3"
import tray_api "tray_backend"

@(test)
window_close_hides_until_tray_quit :: proc(t: ^testing.T) {
    // Use SDL's headless video driver; no desktop window or live tray is needed.
    sdl.SetHint(sdl.HINT_VIDEO_DRIVER, "dummy")
    defer sdl.ResetHint(sdl.HINT_VIDEO_DRIVER)
    if !testing.expect(t, sdl.Init({.VIDEO})) { return }
    defer sdl.QuitSubSystem({.VIDEO})
    window := sdl.CreateWindow("Lifecycle test", 320, 280, {})
    if !testing.expect(t, window != nil) { return }
    defer sdl.DestroyWindow(window)
    marker: tray_api.Tray
    app := AppState{window = window, tray = &marker, running = true, show_window = true}
    configure_window_close_behavior(&app)
    defer sdl.ResetHint(sdl.HINT_QUIT_ON_LAST_WINDOW_CLOSE)
    testing.expect(t, !sdl.GetHintBoolean(sdl.HINT_QUIT_ON_LAST_WINDOW_CLOSE, true))
    close_main_window(&app)
    testing.expect(t, app.running && !app.show_window)
    testing.expect(t, .HIDDEN in sdl.GetWindowFlags(window))
    set_window_visible(&app, true)
    testing.expect(t, app.running && app.show_window)
    tray_quit(&app, nil)
    testing.expect(t, !app.running)

    // Keep a usable exit path on desktops where no tray can be created.
    app.tray = nil
    app.running = true
    configure_window_close_behavior(&app)
    testing.expect(t, sdl.GetHintBoolean(sdl.HINT_QUIT_ON_LAST_WINDOW_CLOSE, false))
    close_main_window(&app)
    testing.expect(t, !app.running)
}
