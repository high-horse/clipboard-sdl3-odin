package tray_backend

import "core:dynlib"
import "core:testing"

Popup_Callback_Counts :: struct { copies, deletions: int }
popup_test_copy :: proc "c" (userdata: rawptr, entry: ^TrayEntry) {
    counts := cast(^Popup_Callback_Counts)userdata
    counts.copies += 1
}
popup_test_delete :: proc "c" (userdata: rawptr, entry: ^TrayEntry) {
    counts := cast(^Popup_Callback_Counts)userdata
    counts.deletions += 1
}

@(test)
popup_copy_closes_and_trash_only_deletes :: proc(t: ^testing.T) {
    menu := TrayMenu{visible = true}
    counts: Popup_Callback_Counts
    entry := TrayEntry{menu = &menu, callback = popup_test_copy, delete_callback = popup_test_delete, userdata = &counts}
    native_delete(nil, &entry)
    testing.expect(t, counts.deletions == 1 && counts.copies == 0 && menu.visible)
    native_activate(nil, &entry)
    testing.expect(t, counts.deletions == 1 && counts.copies == 1 && !menu.visible)
    entry.updating = true
    native_activate(nil, &entry)
    testing.expect(t, counts.copies == 1)
}

@(test)
popup_runtime_symbols_available :: proc(t: ^testing.T) {
    // Resolve required APIs without initializing GTK or connecting to a display.
    gtk_symbols: Gtk
    gdk_symbols: Gdk
    n, _ := dynlib.initialize_symbols(&gtk_symbols, "libgtk-3.so.0", "gtk_")
    testing.expect(t, n == int(size_of(Gtk)/size_of(rawptr))-1)
    if gtk_symbols.__handle != nil { dynlib.unload_library(gtk_symbols.__handle) }
    n, _ = dynlib.initialize_symbols(&gdk_symbols, "libgdk-3.so.0", "gdk_")
    testing.expect(t, n == int(size_of(Gdk)/size_of(rawptr))-1)
    if gdk_symbols.__handle != nil { dynlib.unload_library(gdk_symbols.__handle) }
}
