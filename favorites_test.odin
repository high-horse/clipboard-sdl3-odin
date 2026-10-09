package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:testing"
import "core:sync"
import sql "sqlite3"

@(test)
favorites_persistence_and_retention :: proc(t: ^testing.T) {
    sync.mutex_lock(&database_test_mutex)
    defer sync.mutex_unlock(&database_test_mutex)
    saved := g_db
    defer g_db = saved
    conn: ^sql.Connection
    if !testing.expect(t, sql.open(":memory:", &conn) == .Ok) { return }
    defer sql.close(conn)
    // Simulate a database created before favorites existed.
    testing.expect(t, sql.exec(conn, "CREATE TABLE clipboard_contents(id INTEGER PRIMARY KEY, content_path TEXT NOT NULL, mime TEXT NOT NULL, hash TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)", nil, nil, nil) == .Ok)
    dir, err := os.make_directory_temp("/tmp", "clipboard-favorites-*", context.allocator)
    if !testing.expect(t, err == nil) { return }
    defer delete(dir)
    defer os.remove(dir)
    defer {
        for hash in ([]string{"favorite", "old", "new"}) {
            os.remove(fmt.tprintf("%s/%s", dir, hash))
        }
    }
    g_db = Database{db = conn, initialized = true, blob_dir = dir, config = Config{max_entries = 1}}
    testing.expect(t, prepare_table(&g_db))
    testing.expect(t, prepare_table(&g_db))
    for hash in ([]string{"favorite", "old", "new"}) {
        path := fmt.aprintf("%s/%s", dir, hash)
        defer delete(path)
        testing.expect(t, os.write_entire_file(path, hash) == nil)
        query := fmt.tprintf("INSERT INTO clipboard_contents(content_path,mime,hash) VALUES('%s','text/plain','%s')", path, hash)
        testing.expect(t, sql.exec(conn, strings.clone_to_cstring(query, context.temp_allocator), nil, nil, nil) == .Ok)
    }
    testing.expect(t, save_pin("favorite", true))
    testing.expect(t, trim_dataset(&g_db))
    testing.expect(t, database_has_hash("favorite") && database_has_hash("new") && !database_has_hash("old"))
    testing.expect(t, os.exists(fmt.tprintf("%s/favorite", dir)) && !os.exists(fmt.tprintf("%s/old", dir)))
    items, ok := load_all_contents()
    testing.expect(t, ok && len(items) == 2)
    defer {
        for item in items {
            delete(item.data)
            delete(item.mime)
            delete(item.hash)
            delete(item.content_path)
        }
        delete(items)
    }
    if len(items) == 2 {
        testing.expect(t, items[1].hash == "favorite" && items[1].pinned)
        testing.expect(t, items[0].hash == "new" && !items[0].pinned)
    }
    testing.expect(t, save_pin("favorite", false))
    testing.expect(t, trim_dataset(&g_db))
    testing.expect(t, !database_has_hash("favorite") && database_has_hash("new"))
}

@(test)
favorites_order_and_selection :: proc(t: ^testing.T) {
    app: AppState
    app.clipboard_items = make([dynamic]database_content)
    defer delete(app.clipboard_items)
    append(&app.clipboard_items,
        database_content{hash = "pinned", pinned = true},
        database_content{hash = "old"},
        database_content{hash = "recent"},
        database_content{hash = "pinned-recent", pinned = true},
    )
    app.selected_index, app.copied_index = 1, 0
    arrange_favorites(&app)
    testing.expect(t, app.clipboard_items[0].hash == "old" && app.clipboard_items[1].hash == "recent")
    testing.expect(t, app.clipboard_items[2].hash == "pinned" && app.clipboard_items[3].hash == "pinned-recent")
    testing.expect(t, app.selected_index == 0 && app.copied_index == 2)
}
