package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "core:sync"
import sql "sqlite3"

database_test_mutex: sync.Mutex

@(test)
delete_saved_item_test :: proc(t: ^testing.T) {
    sync.mutex_lock(&database_test_mutex)
    defer sync.mutex_unlock(&database_test_mutex)
    saved := g_db
    defer g_db = saved
    conn: ^sql.Connection
    if !testing.expect(t, sql.open(":memory:", &conn) == .Ok) { return }
    defer sql.close(conn)
    dir, err := os.make_directory_temp("/tmp", "clipboard-delete-*", context.allocator)
    if !testing.expect(t, err == nil) { return }
    defer delete(dir)
    defer os.remove(dir)
    target := fmt.aprintf("%s/target", dir)
    keep := fmt.aprintf("%s/keep", dir)
    outside := fmt.aprintf("%s/outside", dir)
    defer delete(target)
    defer delete(keep)
    defer delete(outside)
    defer os.remove(target)
    defer os.remove(keep)
    defer os.remove(outside)
    testing.expect(t, os.write_entire_file(target, "target") == nil)
    testing.expect(t, os.write_entire_file(keep, "keep") == nil)
    testing.expect(t, os.write_entire_file(outside, "outside") == nil)
    g_db = Database{db = conn, initialized = true, blob_dir = dir}
    if !testing.expect(t, prepare_table(&g_db)) { return }
    query := fmt.tprintf("INSERT INTO clipboard_contents(content_path,hash,mime) VALUES ('%s','target','text/plain'),('%s','keep','text/plain'),('%s','outside','text/plain')", target, keep, outside)
    testing.expect(t, sql.exec(conn, strings.clone_to_cstring(query, context.temp_allocator), nil, nil, nil) == .Ok)
    app := AppState{selected_index = -1, copied_index = -1}
    app.clipboard_items = make([dynamic]database_content)
    append(&app.clipboard_items,
        database_content{hash = "target", data = make([]byte, 1)},
        database_content{hash = "keep", data = make([]byte, 1)},
    )
    defer {
        for item in app.clipboard_items { delete(item.data) }
        delete(app.clipboard_items)
        delete(app.tray_delete_hash)
    }
    queue_tray_delete(&app, "target")
    // A menu callback must not mutate storage while the menu is dispatching.
    testing.expect(t, database_has_hash("target") && os.exists(target))
    app.clipboard_items[0], app.clipboard_items[1] = app.clipboard_items[1], app.clipboard_items[0]
    process_tray_delete(&app)
    testing.expect(t, len(app.clipboard_items) == 1 && app.clipboard_items[0].hash == "keep")
    testing.expect(t, !database_has_hash("target") && !os.exists(target))
    testing.expect(t, database_has_hash("keep") && os.exists(keep))
    // A repeated stale request must not delete the replacement at the old index.
    queue_tray_delete(&app, "target")
    process_tray_delete(&app)
    testing.expect(t, len(app.clipboard_items) == 1 && database_has_hash("keep"))

    // A database failure must leave both the entry and its file intact.
    testing.expect(t, sql.exec(conn, "CREATE TRIGGER reject_delete BEFORE DELETE ON clipboard_contents BEGIN SELECT RAISE(ABORT, 'test failure'); END", nil, nil, nil) == .Ok)
    ok, _ := delete_saved_item("keep")
    testing.expect(t, !ok && database_has_hash("keep") && os.exists(keep))
    testing.expect(t, sql.exec(conn, "DROP TRIGGER reject_delete", nil, nil, nil) == .Ok)

    // Untrusted paths must never be removed, even when their row is deleted.
    g_db.blob_dir = "/nonexistent/clipboard-blobs"
    cleaned: bool
    ok, cleaned = delete_saved_item("outside")
    testing.expect(t, ok && !cleaned && os.exists(outside))
    testing.expect(t, !database_has_hash("outside"))
}
