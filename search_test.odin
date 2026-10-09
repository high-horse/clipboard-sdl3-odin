package main

import "core:strings"
import "core:testing"

@(test)
search_full_text_unicode_and_mime :: proc(t: ^testing.T) {
    long_text := strings.repeat("before ", 100)
    defer delete(long_text)
    full := strings.concatenate({long_text, "HiddenNeedle"})
    defer delete(full)
    first := string("Hello WORLD")
    unicode_text := string("CAFÉ नमस्ते")
    items := []database_content{
        {mime = "text/plain", data = transmute([]byte)first},
        {mime = "text/plain", data = transmute([]byte)full},
        {mime = "image/png"},
        {mime = "text/plain", data = transmute([]byte)unicode_text},
    }
    matches := make([dynamic]int)
    defer delete(matches)
    collect_search_matches(items, "world", &matches)
    testing.expect(t, len(matches) == 1 && matches[0] == 0)
    collect_search_matches(items, "hiddenneedle", &matches)
    testing.expect(t, len(matches) == 1 && matches[0] == 1)
    collect_search_matches(items, " café ", &matches)
    testing.expect(t, len(matches) == 1 && matches[0] == 3)
    collect_search_matches(items, "नमस्ते", &matches)
    testing.expect(t, len(matches) == 1 && matches[0] == 3)
    collect_search_matches(items, "PNG", &matches)
    testing.expect(t, len(matches) == 1 && matches[0] == 2)
    collect_search_matches(items, "not found", &matches)
    testing.expect(t, len(matches) == 0)
    collect_search_matches(items, "", &matches)
    testing.expect(t, len(matches) == 4 && matches[0] == 3 && matches[3] == 0)
}

@(test)
search_navigation_uses_matching_item_indices :: proc(t: ^testing.T) {
    app := AppState{selected_index = -1}
    app.clipboard_items = make([dynamic]database_content)
    append(&app.clipboard_items, database_content{mime = "image/png"}, database_content{mime = "text/plain"}, database_content{mime = "image/png"})
    defer delete(app.clipboard_items)
    defer delete(app.search_query)
    defer delete(app.search_indices)
    set_window_search(&app, "png")
    testing.expect(t, visible_item_count(&app) == 2)
    testing.expect(t, visible_item_index(&app, 0) == 2 && visible_item_index(&app, 1) == 0)
    testing.expect(t, visible_offset_of(&app, 1) == -1)
    navigate_items(&app, .DOWN)
    testing.expect(t, app.selected_index == 2)
    navigate_items(&app, .DOWN)
    testing.expect(t, app.selected_index == 0)
    navigate_items(&app, .UP)
    testing.expect(t, app.selected_index == 2)
    set_window_search(&app, "missing")
    testing.expect(t, visible_item_count(&app) == 0 && app.selected_index == -1)
    set_window_search(&app, "")
    testing.expect(t, visible_item_count(&app) == 3)
}

@(test)
search_editing_and_independent_tray_query :: proc(t: ^testing.T) {
    app: AppState
    defer delete(app.search_query)
    defer delete(app.tray_search_query)
    defer delete(app.search_indices)
    set_window_search(&app, "café")
    backspace_window_search(&app)
    testing.expect(t, app.search_query == "caf")
    append_window_search(&app, "é")
    testing.expect(t, app.search_query == "café")
    app.search_select_all = true
    append_window_search(&app, "hello")
    testing.expect(t, app.search_query == "hello")
    set_tray_search(&app, "png")
    testing.expect(t, app.search_query == "hello" && app.tray_search_query == "png" && app.tray_search_dirty)
    testing.expect(t, handle_search_key(&app, .ESCAPE, false) && app.search_query == "")
    testing.expect(t, app.tray_search_query == "png")
}
