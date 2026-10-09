package main

import "core:c"
import "core:strings"
import "core:sync"
import sql "sqlite3"
import sdl "vendor:sdl3"

save_pin :: proc(hash: string, pinned: bool) -> bool {
    sync.mutex_lock(&history_mutex)
    defer sync.mutex_unlock(&history_mutex)
    db, ok := get_db()
    if !ok { return false }
    stmt: ^sql.Statement
    if sql.prepare_v2(db.db, "UPDATE clipboard_contents SET pinned = ? WHERE hash = ?", -1, &stmt, nil) != .Ok { return false }
    defer sql.finalize(stmt)
    if sql.bind_int(stmt, 1, c.int(pinned)) != .Ok { return false }
    if sql.bind_text(stmt, 2, strings.clone_to_cstring(hash, context.temp_allocator), c.int(len(hash)), sql.Destructor{behaviour = .Static}) != .Ok { return false }
    return sql.step(stmt) == .Done
}

// Keep favorites at the end of the array (the top of the displayed history).
// Preserve recency within both groups and keep selection attached to its item.
arrange_favorites :: proc(app: ^AppState) {
    selected, copied: string
    if app.selected_index >= 0 && app.selected_index < len(app.clipboard_items) { selected = app.clipboard_items[app.selected_index].hash }
    if app.copied_index >= 0 && app.copied_index < len(app.clipboard_items) { copied = app.clipboard_items[app.copied_index].hash }
    ordered := make([]database_content, len(app.clipboard_items), context.temp_allocator)
    n := 0
    for item in app.clipboard_items { if !item.pinned { ordered[n] = item; n += 1 } }
    for item in app.clipboard_items { if item.pinned { ordered[n] = item; n += 1 } }
    copy(app.clipboard_items[:], ordered)
    app.selected_index, app.copied_index = -1, -1
    for item, i in app.clipboard_items {
        if selected != "" && item.hash == selected { app.selected_index = i }
        if copied != "" && item.hash == copied { app.copied_index = i }
    }
}

toggle_pin :: proc(app: ^AppState, index: int) {
    if index < 0 || index >= len(app.clipboard_items) { return }
    pinned := !app.clipboard_items[index].pinned
    app.history_status_until = sdl.GetTicks()+2500
    if !save_pin(app.clipboard_items[index].hash, pinned) {
        app.history_status = "Could not update favorite. Try again."
        return
    }
    app.clipboard_items[index].pinned = pinned
    arrange_favorites(app)
    app.scroll = 0
    update_tray_history(app)
    app.history_status = "Pinned to favorites."
    if !pinned { app.history_status = "Unpinned from favorites." }
}

Card_Action :: enum { Copy, Pin, Delete }

card_action_rect :: proc(app: ^AppState, index: int, action: Card_Action) -> sdl.FRect {
    layout := list_layout(app)
    y := f32(LIST_TOP+visible_offset_of(app, index)*CARD_STEP)-app.scroll
    return {layout.x+layout.width-104+f32(int(action))*30, y+5, 26, 26}
}

card_action_at :: proc(app: ^AppState, x, y: f32) -> Card_Action {
    index := clipboard_item_at(app, x, y)
    if index >= 0 {
        for action in Card_Action {
            r := card_action_rect(app, index, action)
            if x >= r.x && x < r.x+r.w && y >= r.y && y < r.y+r.h { return action }
        }
    }
    return .Copy
}

// Draw icons with SDL lines so they work regardless of font glyph coverage.
card_icon :: proc(app: ^AppState, rect: sdl.FRect, action: Card_Action, color: sdl.Color, pinned: bool) {
    x, y := rect.x+5, rect.y+5
    sdl.SetRenderDrawColor(app.renderer, color.r, color.g, color.b, color.a)
    switch action {
    case .Copy:
        ui_border(app, {x+3, y+3, 11, 13}, color)
        ui_fill(app, {x+6, y+1, 5, 4}, color)
        sdl.RenderLine(app.renderer, x+6, y+8, x+11, y+8)
        sdl.RenderLine(app.renderer, x+6, y+11, x+11, y+11)
    case .Delete:
        sdl.RenderLine(app.renderer, x+1, y+4, x+15, y+4)
        ui_border(app, {x+4, y+4, 9, 12}, color)
        ui_border(app, {x+6, y+1, 5, 3}, color)
        sdl.RenderLine(app.renderer, x+7, y+7, x+7, y+13)
        sdl.RenderLine(app.renderer, x+10, y+7, x+10, y+13)
    case .Pin:
        ui_border(app, {x+5, y+1, 7, 7}, color)
        if pinned { ui_fill(app, {x+6, y+2, 5, 5}, color) }
        sdl.RenderLine(app.renderer, x+5, y+8, x+2, y+11)
        sdl.RenderLine(app.renderer, x+12, y+8, x+15, y+11)
        sdl.RenderLine(app.renderer, x+2, y+11, x+15, y+11)
        sdl.RenderLine(app.renderer, x+8, y+11, x+8, y+17)
    }
}
