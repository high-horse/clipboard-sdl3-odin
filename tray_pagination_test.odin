package main

import "core:testing"

@(test)
tray_reopening_starts_on_first_page :: proc(t: ^testing.T) {
    app := AppState{tray_page = 2, tray_page_delta = 1, tray_search_query = "saved search"}
    tray_popup_opened(&app)
    start, end, _ := tray_page_bounds(&app, 35)
    testing.expect(t, app.tray_page == 0 && app.tray_page_delta == 0 && start == 0 && end == 10)
    testing.expect(t, app.tray_search_query == "saved search")
}

@(test)
tray_pages_contain_at_most_ten_items :: proc(t: ^testing.T) {
    app: AppState
    for count in ([]int{0, 1, 10, 11, 20, 21, 101}) {
        visited := 0
        pages := max(1, (count+9)/10)
        for page in 0..<pages {
            app.tray_page = page
            start, end, total := tray_page_bounds(&app, count)
            testing.expect(t, total == pages && start == visited)
            testing.expect(t, end >= start && end-start <= 10 && end <= count)
            visited += end-start
        }
        testing.expect(t, visited == count)
    }
}

@(test)
tray_page_clamps_after_deletion_and_resets_on_search :: proc(t: ^testing.T) {
    app := AppState{tray_page = 2}
    defer delete(app.tray_search_query)
    start, end, pages := tray_page_bounds(&app, 20)
    testing.expect(t, app.tray_page == 1 && start == 10 && end == 20 && pages == 2)
    app.tray_page = -1
    start, end, pages = tray_page_bounds(&app, 21)
    testing.expect(t, app.tray_page == 0 && start == 0 && end == 10 && pages == 3)
    app.tray_page = 4
    app.tray_page_delta = 1
    set_tray_search(&app, "older item")
    testing.expect(t, app.tray_page == 0 && app.tray_page_delta == 0 && app.tray_search_dirty)
    start, end, pages = tray_page_bounds(&app, 0)
    testing.expect(t, start == 0 && end == 0 && pages == 1)
}
