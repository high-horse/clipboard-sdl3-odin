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
    tray_toggle_window(&app, nil)
    testing.expect(t, app.running && app.show_window)
    testing.expect(t, string(tray_visibility_label(&app)) == "Hide window")
    tray_toggle_window(&app, nil)
    testing.expect(t, app.running && !app.show_window)
    testing.expect(t, string(tray_visibility_label(&app)) == "Show Clipboard Manager")
    tray_quit(&app, nil)
    testing.expect(t, !app.running)

    // Filtering must map card and icon hit targets to the original saved item.
    app.clipboard_items = make([dynamic]database_content)
    defer delete(app.clipboard_items)
    defer delete(app.search_query)
    defer delete(app.search_indices)
    append(&app.clipboard_items, database_content{mime = "image/png"}, database_content{mime = "text/plain"}, database_content{mime = "image/jpeg"})
    set_window_search(&app, "png")
    layout := list_layout(&app)
    testing.expect(t, clipboard_item_at(&app, layout.x+10, LIST_TOP+10) == 0)
    trash := card_action_rect(&app, 0, .Delete)
    testing.expect(t, card_action_at(&app, trash.x+5, trash.y+5) == .Delete)
    set_window_search(&app, "no match")
    testing.expect(t, clipboard_item_at(&app, layout.x+10, LIST_TOP+10) == -1)

    // Keep a usable exit path on desktops where no tray can be created.
    app.tray = nil
    app.running = true
    configure_window_close_behavior(&app)
    testing.expect(t, sdl.GetHintBoolean(sdl.HINT_QUIT_ON_LAST_WINDOW_CLOSE, false))
    close_main_window(&app)
    testing.expect(t, !app.running)
}
