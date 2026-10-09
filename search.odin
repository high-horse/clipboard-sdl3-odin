package main

import "base:runtime"
import "core:fmt"
import "core:c"
import "core:strings"
import sdl "vendor:sdl3"
import tray_api "tray_backend"
import ttf "vendor:sdl3/ttf"

search_item_matches :: proc(item: database_content, normalized_query: string) -> bool {
    if normalized_query == "" { return true }
    mime := strings.to_lower(item.mime)
    defer delete(mime)
    if strings.contains(mime, normalized_query) { return true }
    if strings.has_prefix(item.mime, "text/") {
        text := strings.to_lower(transmute(string)item.data)
        defer delete(text)
        return strings.contains(text, normalized_query)
    }
    label := preview_text(item)
    defer delete(label)
    lower := strings.to_lower(label)
    defer delete(lower)
    return strings.contains(lower, normalized_query)
}

collect_search_matches :: proc(items: []database_content, query: string, result: ^[dynamic]int) {
    clear(result)
    normalized := strings.to_lower(strings.trim_space(query))
    defer delete(normalized)
    for i := len(items)-1; i >= 0; i -= 1 {
        if search_item_matches(items[i], normalized) { append(result, i) }
    }
}

refresh_search_results :: proc(app: ^AppState) {
    if app.search_query == "" { clear(&app.search_indices); return }
    collect_search_matches(app.clipboard_items[:], app.search_query, &app.search_indices)
    if visible_offset_of(app, app.selected_index) < 0 { app.selected_index = -1 }
}
visible_item_count :: proc(app: ^AppState) -> int {
    if app.search_query == "" { return len(app.clipboard_items) }
    return len(app.search_indices)
}
visible_item_index :: proc(app: ^AppState, offset: int) -> int {
    if offset < 0 || offset >= visible_item_count(app) { return -1 }
    if app.search_query == "" { return len(app.clipboard_items)-1-offset }
    return app.search_indices[offset]
}
visible_offset_of :: proc(app: ^AppState, index: int) -> int {
    if index < 0 || index >= len(app.clipboard_items) { return -1 }
    if app.search_query == "" { return len(app.clipboard_items)-1-index }
    for candidate, offset in app.search_indices { if candidate == index { return offset } }
    return -1
}

set_window_search :: proc(app: ^AppState, query: string) {
    replacement := strings.clone(truncate_utf8(query, 1024))
    delete(app.search_query)
    app.search_query = replacement
    app.search_select_all = false
    app.scroll = 0
    app.selected_index, app.pressed_index = -1, -1
    refresh_search_results(app)
}
append_window_search :: proc(app: ^AppState, text: string) {
    old := app.search_query
    if app.search_select_all { old = "" }
    joined := fmt.aprintf("%s%s", old, text)
    defer delete(joined)
    set_window_search(app, joined)
}
backspace_window_search :: proc(app: ^AppState) {
    if app.search_select_all { set_window_search(app, ""); return }
    end := len(app.search_query)
    if end == 0 { return }
    end -= 1
    for end > 0 && (app.search_query[end]&0xc0) == 0x80 { end -= 1 }
    set_window_search(app, app.search_query[:end])
}

window_search_rect :: proc(app: ^AppState) -> sdl.FRect {
    layout := list_layout(app)
    return {layout.x, 79, layout.width, 34}
}
window_search_at :: proc(app: ^AppState, x, y: f32) -> bool {
    r := window_search_rect(app)
    return x >= r.x && x < r.x+r.w && y >= r.y && y < r.y+r.h
}
window_search_clear_at :: proc(app: ^AppState, x, y: f32) -> bool {
    r := window_search_rect(app)
    return app.search_query != "" && window_search_at(app, x, y) && x >= r.x+r.w-30
}
focus_window_search :: proc(app: ^AppState, focused: bool) {
    app.search_focused = focused
    if focused {
        _ = sdl.StartTextInput(app.window)
        r := window_search_rect(app)
        area := sdl.Rect{i32(r.x), i32(r.y), i32(r.w), i32(r.h)}
        _ = sdl.SetTextInputArea(app.window, &area, 0)
    } else { _ = sdl.StopTextInput(app.window); app.search_select_all = false }
}

render_window_search :: proc(app: ^AppState) {
    r := window_search_rect(app)
    border := UI_MUTED
    if app.search_focused { border = UI_ACCENT }
    ui_fill(app, r, {25, 34, 49, 255})
    ui_border(app, r, border)
    clip := sdl.Rect{i32(r.x+10), i32(r.y+1), i32(r.w-44), i32(r.h-2)}
    sdl.SetRenderClipRect(app.renderer, &clip)
    text := app.search_query
    color := UI_TEXT
    if text == "" { text = "Search clipboard...  Ctrl+F"; color = UI_MUTED }
    if app.search_select_all { ui_fill(app, {r.x+8, r.y+5, r.w-16, r.h-10}, {46, 72, 105, 255}) }
    text_width: c.int
    if font_set.primary != nil {
        ttf.GetStringSize(font_set.primary, strings.clone_to_cstring(text, context.temp_allocator), c.size_t(len(text)), &text_width, nil)
    }
    x := r.x+10
    if app.search_query != "" { x -= max(f32(0), f32(text_width)-(r.w-52)) }
    ui_text(app, text, x, r.y+7, color)
    if app.search_focused && !app.search_select_all && app.search_query != "" && (sdl.GetTicks()/500)%2 == 0 {
        ui_fill(app, {x+f32(text_width)+1, r.y+7, 1, 20}, UI_TEXT)
    }
    sdl.SetRenderClipRect(app.renderer, nil)
    if app.search_query != "" {
        x := r.x+r.w-20
        sdl.SetRenderDrawColor(app.renderer, UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, UI_MUTED.a)
        sdl.RenderLine(app.renderer, x-4, r.y+13, x+4, r.y+21)
        sdl.RenderLine(app.renderer, x+4, r.y+13, x-4, r.y+21)
    }
}

tray_search_changed :: proc "c" (userdata: rawptr, text: cstring) {
    context = runtime.default_context()
    app := cast(^AppState)userdata
    set_tray_search(app, string(text))
}
set_tray_search :: proc(app: ^AppState, query: string) {
    replacement := strings.clone(query)
    delete(app.tray_search_query)
    app.tray_search_query = replacement
    app.tray_page, app.tray_page_delta = 0, 0
    app.tray_search_dirty = true
}

empty_hint :: proc(app: ^AppState) -> string {
    if app.search_query != "" { return "Try another search or clear the search field." }
    return "Copy text, a link or an image to get started."
}

handle_search_key :: proc(app: ^AppState, key: sdl.Scancode, ctrl: bool) -> bool {
    #partial switch key {
    case .BACKSPACE:
        backspace_window_search(app)
        return true
    case .DELETE:
        if app.search_select_all { set_window_search(app, "") }
        return true
    case .A:
        if ctrl { app.search_select_all = true; return true }
    case .U:
        if ctrl { set_window_search(app, ""); return true }
    case .V:
        if ctrl {
            text := sdl.GetClipboardText()
            if text != nil {
                append_window_search(app, string(cast(cstring)text))
                sdl.free(text)
            }
            return true
        }
    case .ESCAPE:
        if app.search_query != "" { set_window_search(app, ""); return true }
    case .HOME, .END:
        if !ctrl { return true }
    case .RETURN:
        if app.selected_index < 0 { app.selected_index = visible_item_index(app, 0) }
    case .SPACE:
        return true
    }
    return false
}

copy_first_tray_match :: proc(app: ^AppState) {
    matches := make([dynamic]int)
    defer delete(matches)
    collect_search_matches(app.clipboard_items[:], app.tray_search_query, &matches)
    start, end, _ := tray_page_bounds(app, len(matches))
    if end > start {
        copy_item(app, matches[start])
        if app.tray_history_menu != nil { tray_api.CloseTrayPopup(app.tray_history_menu) }
    }
}
