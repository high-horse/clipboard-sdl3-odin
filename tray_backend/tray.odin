package tray_backend

import "base:runtime"
import "core:c"
import "core:dynlib"
import "core:strings"
import sdl "vendor:sdl3"

TrayEntryFlags :: sdl.TrayEntryFlags
TrayCallback :: #type proc "c" (userdata: rawptr, entry: ^TrayEntry)
Tray :: struct {
    native: rawptr,
    fallback: ^sdl.Tray,
    menu: ^TrayMenu,
    registration, watcher: u32,
    open_requested: bool,
    popup_x, popup_y: i32,
    activation_token: string,
}
TrayMenu :: struct {
    native, popup, scroller: rawptr,
    fallback: ^sdl.TrayMenu,
    entries: [dynamic]^TrayEntry,
    visible: bool,
}
TrayEntry :: struct {
    native, button, image_slot, trash: rawptr,
    fallback: ^sdl.TrayEntry,
    menu: ^TrayMenu,
    callback, delete_callback: TrayCallback,
    userdata: rawptr,
    updating: bool,
}
Gtk :: struct {
    __handle: dynlib.Library,
    init_check: proc "c" (^c.int, rawptr) -> c.int,
    window_new: proc "c" (c.int) -> rawptr,
    window_set_decorated: proc "c" (rawptr, c.int),
    window_set_resizable: proc "c" (rawptr, c.int),
    window_set_keep_above: proc "c" (rawptr, c.int),
    window_set_skip_taskbar_hint: proc "c" (rawptr, c.int),
    window_set_skip_pager_hint: proc "c" (rawptr, c.int),
    window_set_type_hint: proc "c" (rawptr, c.int),
    window_set_title: proc "c" (rawptr, cstring),
    window_set_startup_id: proc "c" (rawptr, cstring),
    window_move: proc "c" (rawptr, c.int, c.int),
    window_present: proc "c" (rawptr),
    box_new: proc "c" (c.int, c.int) -> rawptr,
    box_pack_start: proc "c" (rawptr, rawptr, c.int, c.int, c.uint),
    container_add: proc "c" (rawptr, rawptr),
    container_set_border_width: proc "c" (rawptr, c.uint),
    button_new: proc "c" () -> rawptr,
    button_set_image: proc "c" (rawptr, rawptr),
    button_set_relief: proc "c" (rawptr, c.int),
    check_button_new_with_label: proc "c" (cstring) -> rawptr,
    toggle_button_set_active: proc "c" (rawptr, c.int),
    label_new: proc "c" (cstring) -> rawptr,
    label_set_xalign: proc "c" (rawptr, f32),
    label_set_ellipsize: proc "c" (rawptr, c.int),
    scrolled_window_new: proc "c" (rawptr, rawptr) -> rawptr,
    scrolled_window_set_policy: proc "c" (rawptr, c.int, c.int),
    widget_set_size_request: proc "c" (rawptr, c.int, c.int),
    widget_set_tooltip_text: proc "c" (rawptr, cstring),
    widget_show_all: proc "c" (rawptr),
    widget_hide: proc "c" (rawptr),
    widget_destroy: proc "c" (rawptr),
    widget_set_sensitive: proc "c" (rawptr, c.int),
    image_new_from_pixbuf: proc "c" (rawptr) -> rawptr,
    image_new_from_icon_name: proc "c" (cstring, c.int) -> rawptr,
    events_pending: proc "c" () -> c.int,
    main_iteration_do: proc "c" (c.int) -> c.int,
}
Gdk_Rect :: struct { x, y, width, height: c.int }
Gdk :: struct {
    __handle: dynlib.Library,
    set_allowed_backends: proc "c" (cstring),
    event_get_keyval: proc "c" (rawptr, ^c.uint) -> c.int,
    display_get_default: proc "c" () -> rawptr,
    display_get_default_seat: proc "c" (rawptr) -> rawptr,
    seat_get_pointer: proc "c" (rawptr) -> rawptr,
    device_get_position: proc "c" (rawptr, rawptr, ^c.int, ^c.int),
    display_get_monitor_at_point: proc "c" (rawptr, c.int, c.int) -> rawptr,
    monitor_get_workarea: proc "c" (rawptr, ^Gdk_Rect),
}
Objects :: struct {
    __handle: dynlib.Library,
    object_ref_sink: proc "c" (rawptr) -> rawptr,
    object_unref: proc "c" (rawptr),
    signal_connect_data: proc "c" (rawptr, cstring, rawptr, rawptr, rawptr, c.int) -> c.ulong,
}
Pixbuf :: struct {
    __handle: dynlib.Library,
    new_from_data: proc "c" ([^]u8, c.int, c.int, c.int, c.int, c.int, c.int, rawptr, rawptr) -> rawptr,
    copy: proc "c" (rawptr) -> rawptr,
}

gtk: Gtk
gdk: Gdk
objects: Objects
pixbuf: Pixbuf
attempted, native_ready: bool
active_tray: ^Tray

init_native :: proc() -> bool {
    if attempted { return native_ready }
    attempted = true
    n, _ := dynlib.initialize_symbols(&gtk, "libgtk-3.so.0", "gtk_")
    if n != int(size_of(Gtk)/size_of(rawptr))-1 { return false }
    n, _ = dynlib.initialize_symbols(&gdk, "libgdk-3.so.0", "gdk_")
    if n != int(size_of(Gdk)/size_of(rawptr))-1 { return false }
    n, _ = dynlib.initialize_symbols(&objects, "libgobject-2.0.so.0", "g_")
    if n != 3 { return false }
    n, _ = dynlib.initialize_symbols(&pixbuf, "libgdk_pixbuf-2.0.so.0", "gdk_pixbuf_")
    if n != 2 || !load_notifier_symbols() { return false }
    // XWayland lets the popup use the panel's global position; fall back to Wayland.
    gdk.set_allowed_backends("x11,wayland")
    native_ready = gtk.init_check(nil, nil) != 0
    return native_ready
}

CreateTray :: proc(icon: ^sdl.Surface, tooltip: cstring) -> ^Tray {
    tray := new(Tray)
    if init_native() && start_notifier(tray) {
        active_tray = tray
        return tray
    }
    tray.fallback = sdl.CreateTray(icon, tooltip)
    if tray.fallback == nil { free(tray); return nil }
    return tray
}

CreateTrayMenu :: proc(tray: ^Tray) -> ^TrayMenu {
    menu := new(TrayMenu)
    if tray.native != nil {
        menu.popup = gtk.window_new(0)
        menu.native = gtk.box_new(1, 2)
        menu.scroller = gtk.scrolled_window_new(nil, nil)
        gtk.window_set_title(menu.popup, "Clipboard history")
        gtk.window_set_decorated(menu.popup, 0)
        gtk.window_set_resizable(menu.popup, 0)
        gtk.window_set_keep_above(menu.popup, 1)
        gtk.window_set_skip_taskbar_hint(menu.popup, 1)
        gtk.window_set_skip_pager_hint(menu.popup, 1)
        gtk.window_set_type_hint(menu.popup, 9) // GDK_WINDOW_TYPE_HINT_POPUP_MENU
        gtk.container_set_border_width(menu.native, 6)
        gtk.scrolled_window_set_policy(menu.scroller, 2, 1) // never horizontal / automatic vertical
        gtk.container_add(menu.scroller, menu.native)
        gtk.container_add(menu.popup, menu.scroller)
        objects.signal_connect_data(menu.popup, "focus-out-event", rawptr(popup_dismiss), menu, nil, 0)
        objects.signal_connect_data(menu.popup, "delete-event", rawptr(popup_dismiss), menu, nil, 0)
        objects.signal_connect_data(menu.popup, "key-press-event", rawptr(popup_key), menu, nil, 0)
    } else { menu.fallback = sdl.CreateTrayMenu(tray.fallback) }
    if menu.native == nil && menu.fallback == nil { free(menu); return nil }
    tray.menu = menu
    return menu
}

hide_popup :: proc(menu: ^TrayMenu) {
    if menu.popup != nil { gtk.widget_hide(menu.popup) }
    menu.visible = false
}
popup_dismiss :: proc "c" (widget, event, userdata: rawptr) -> c.int {
    context = runtime.default_context()
    hide_popup(cast(^TrayMenu)userdata)
    return 1
}
popup_key :: proc "c" (widget, event, userdata: rawptr) -> c.int {
    context = runtime.default_context()
    key: c.uint
    if gdk.event_get_keyval(event, &key) != 0 && key == 0xff1b {
        hide_popup(cast(^TrayMenu)userdata)
        return 1
    }
    return 0
}

native_activate :: proc "c" (widget: rawptr, userdata: rawptr) {
    context = runtime.default_context()
    entry := cast(^TrayEntry)userdata
    if entry.updating { return }
    // Hide before copying so clipboard ownership is handed back to the user's app.
    hide_popup(entry.menu)
    if entry.callback != nil { entry.callback(entry.userdata, entry) }
}
native_delete :: proc "c" (widget: rawptr, userdata: rawptr) {
    context = runtime.default_context()
    entry := cast(^TrayEntry)userdata
    if entry.delete_callback != nil { entry.delete_callback(entry.userdata, entry) }
}
fallback_activate :: proc "c" (userdata: rawptr, original: ^sdl.TrayEntry) {
    context = runtime.default_context()
    entry := cast(^TrayEntry)userdata
    if entry.callback != nil { entry.callback(entry.userdata, entry) }
}

InsertTrayEntryAt :: proc(menu: ^TrayMenu, pos: c.int, label: cstring, flags: TrayEntryFlags) -> ^TrayEntry {
    entry := new(TrayEntry)
    entry.menu = menu
    if menu.native != nil {
        entry.native = gtk.box_new(0, 4)
        if .CHECKBOX in flags {
            entry.button = gtk.check_button_new_with_label(label)
            gtk.toggle_button_set_active(entry.button, c.int(.CHECKED in flags))
        } else {
            entry.button = gtk.button_new()
            gtk.button_set_relief(entry.button, 2)
            content := gtk.box_new(0, 8)
            entry.image_slot = gtk.box_new(0, 0)
            text := gtk.label_new(label)
            gtk.label_set_xalign(text, 0)
            gtk.label_set_ellipsize(text, 3) // PANGO_ELLIPSIZE_END
            gtk.box_pack_start(content, entry.image_slot, 0, 0, 0)
            gtk.box_pack_start(content, text, 1, 1, 0)
            gtk.container_add(entry.button, content)
        }
        gtk.widget_set_sensitive(entry.button, c.int(!(.DISABLED in flags)))
        gtk.box_pack_start(entry.native, entry.button, 1, 1, 0)
        gtk.box_pack_start(menu.native, entry.native, 0, 0, 0)
        objects.signal_connect_data(entry.button, "clicked", rawptr(native_activate), entry, nil, 0)
        gtk.widget_show_all(entry.native)
    } else {
        entry.fallback = sdl.InsertTrayEntryAt(menu.fallback, pos, label, flags)
        if entry.fallback != nil { sdl.SetTrayEntryCallback(entry.fallback, fallback_activate, entry) }
    }
    if entry.native == nil && entry.fallback == nil { free(entry); return nil }
    append(&menu.entries, entry)
    return entry
}

GetTrayEntries :: proc(menu: ^TrayMenu, count: ^c.int) -> [^]^TrayEntry {
    count^ = c.int(len(menu.entries))
    return raw_data(menu.entries)
}
RemoveTrayEntry :: proc(entry: ^TrayEntry) {
    menu := entry.menu
    if entry.native != nil { gtk.widget_destroy(entry.native) }
    else { sdl.RemoveTrayEntry(entry.fallback) }
    for candidate, i in menu.entries {
        if candidate == entry { ordered_remove(&menu.entries, i); break }
    }
    free(entry)
}
SetTrayEntryCallback :: proc(entry: ^TrayEntry, callback: TrayCallback, userdata: rawptr) {
    entry.callback, entry.userdata = callback, userdata
}
SetTrayEntryInlineDelete :: proc(entry: ^TrayEntry, callback: TrayCallback) {
    entry.delete_callback = callback
    if entry.native == nil { return }
    entry.trash = gtk.button_new()
    gtk.button_set_relief(entry.trash, 2)
    gtk.button_set_image(entry.trash, gtk.image_new_from_icon_name("user-trash", 1))
    gtk.widget_set_tooltip_text(entry.trash, "Delete item")
    gtk.widget_set_size_request(entry.trash, 32, 32)
    gtk.box_pack_start(entry.native, entry.trash, 0, 0, 0)
    objects.signal_connect_data(entry.trash, "clicked", rawptr(native_delete), entry, nil, 0)
    gtk.widget_show_all(entry.native)
}
SetTrayEntryChecked :: proc(entry: ^TrayEntry, checked: bool) {
    entry.updating = true
    defer entry.updating = false
    if entry.native != nil { gtk.toggle_button_set_active(entry.button, c.int(checked)) }
    else { sdl.SetTrayEntryChecked(entry.fallback, checked) }
}

// GdkPixbuf owns a copy; the SDL source surface may be released immediately.
surface_pixbuf :: proc(surface: ^sdl.Surface) -> rawptr {
    if surface == nil { return nil }
    rgba := sdl.ConvertSurface(surface, .RGBA32)
    if rgba == nil { return nil }
    defer sdl.DestroySurface(rgba)
    borrowed := pixbuf.new_from_data(cast([^]u8)rgba.pixels, 0, 1, 8, rgba.w, rgba.h, rgba.pitch, nil, nil)
    if borrowed == nil { return nil }
    defer objects.object_unref(borrowed)
    return pixbuf.copy(borrowed)
}
SetTrayEntryImage :: proc(entry: ^TrayEntry, surface: ^sdl.Surface) -> bool {
    if entry.image_slot == nil { return false }
    owned := surface_pixbuf(surface)
    if owned == nil { return false }
    defer objects.object_unref(owned)
    image := gtk.image_new_from_pixbuf(owned)
    if image == nil { return false }
    gtk.box_pack_start(entry.image_slot, image, 0, 0, 0)
    gtk.widget_show_all(entry.native)
    return true
}

show_popup :: proc(tray: ^Tray) {
    menu := tray.menu
    if menu == nil || menu.popup == nil { return }
    if menu.visible { hide_popup(menu); return }
    x, y := tray.popup_x, tray.popup_y
    display := gdk.display_get_default()
    if x <= 0 || y <= 0 {
        seat := gdk.display_get_default_seat(display)
        pointer := gdk.seat_get_pointer(seat)
        if pointer != nil { gdk.device_get_position(pointer, nil, &x, &y) }
    }
    width := c.int(420)
    height := min(c.int(520), max(c.int(180), c.int(len(menu.entries))*48+16))
    work: Gdk_Rect
    monitor := gdk.display_get_monitor_at_point(display, x, y)
    if monitor != nil {
        gdk.monitor_get_workarea(monitor, &work)
        width = min(width, work.width)
        height = min(height, work.height)
        x = clamp(x-width/2, work.x, work.x+work.width-width)
        y = clamp(y+4, work.y, work.y+work.height-height)
    }
    gtk.widget_set_size_request(menu.scroller, width, height)
    if tray.activation_token != "" {
        gtk.window_set_startup_id(menu.popup, strings.clone_to_cstring(tray.activation_token, context.temp_allocator))
        delete(tray.activation_token)
        tray.activation_token = ""
    }
    gtk.window_move(menu.popup, x, y)
    gtk.widget_show_all(menu.popup)
    gtk.window_present(menu.popup)
    menu.visible = true
}
UpdateTrays :: proc() {
    if native_ready {
        for i := 0; i < 32 && gtk.events_pending() != 0; i += 1 { gtk.main_iteration_do(0) }
        if active_tray != nil && active_tray.open_requested {
            active_tray.open_requested = false
            show_popup(active_tray)
        }
    }
}
DestroyTray :: proc(tray: ^Tray) {
    if tray == active_tray { active_tray = nil }
    if tray.native != nil { stop_notifier(tray) }
    if tray.menu != nil {
        for len(tray.menu.entries) > 0 { RemoveTrayEntry(tray.menu.entries[len(tray.menu.entries)-1]) }
        delete(tray.menu.entries)
        if tray.menu.popup != nil { gtk.widget_destroy(tray.menu.popup) }
        free(tray.menu)
    }
    if tray.fallback != nil { sdl.DestroyTray(tray.fallback) }
    free(tray)
}
