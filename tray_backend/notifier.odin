package tray_backend

import "base:runtime"
import "core:c"
import "core:dynlib"
import "core:strings"

Gio :: struct {
    __handle: dynlib.Library,
    bus_get_sync: proc "c" (c.int, rawptr, rawptr) -> rawptr,
    bus_watch_name_on_connection: proc "c" (rawptr, cstring, c.int, rawptr, rawptr, rawptr, rawptr) -> u32,
    bus_unwatch_name: proc "c" (u32),
    dbus_node_info_new_for_xml: proc "c" (cstring, rawptr) -> rawptr,
    dbus_node_info_lookup_interface: proc "c" (rawptr, cstring) -> rawptr,
    dbus_node_info_unref: proc "c" (rawptr),
    dbus_connection_register_object: proc "c" (rawptr, cstring, rawptr, ^Notifier_VTable, rawptr, rawptr, rawptr) -> u32,
    dbus_connection_unregister_object: proc "c" (rawptr, u32) -> c.int,
    dbus_connection_get_unique_name: proc "c" (rawptr) -> cstring,
    dbus_connection_call: proc "c" (rawptr, cstring, cstring, cstring, cstring, rawptr, rawptr, c.int, c.int, rawptr, rawptr, rawptr),
    dbus_method_invocation_return_value: proc "c" (rawptr, rawptr),
}
Glib :: struct {
    __handle: dynlib.Library,
    variant_new_string: proc "c" (cstring) -> rawptr,
    variant_new_boolean: proc "c" (c.int) -> rawptr,
    variant_new_uint32: proc "c" (u32) -> rawptr,
    variant_new_tuple: proc "c" ([^]rawptr, c.size_t) -> rawptr,
    variant_new_array: proc "c" (cstring, [^]rawptr, c.size_t) -> rawptr,
    variant_get_child_value: proc "c" (rawptr, c.size_t) -> rawptr,
    variant_get_int32: proc "c" (rawptr) -> i32,
    variant_get_string: proc "c" (rawptr, ^c.size_t) -> cstring,
    variant_unref: proc "c" (rawptr),
}
Notifier_VTable :: struct {
    method_call: proc "c" (rawptr, cstring, cstring, cstring, cstring, rawptr, rawptr, rawptr),
    get_property: proc "c" (rawptr, cstring, cstring, cstring, cstring, rawptr, rawptr) -> rawptr,
    set_property: rawptr,
    padding: [8]rawptr,
}

gio: Gio
glib: Glib
notifier_vtable := Notifier_VTable{method_call = notifier_method, get_property = notifier_property}
NOTIFIER_PATH :: "/StatusNotifierItem"
NOTIFIER_INTERFACE :: "org.kde.StatusNotifierItem"
NOTIFIER_XML :: `<node><interface name="org.kde.StatusNotifierItem">
<property name="Category" type="s" access="read"/>
<property name="Id" type="s" access="read"/>
<property name="Title" type="s" access="read"/>
<property name="Status" type="s" access="read"/>
<property name="WindowId" type="u" access="read"/>
<property name="IconName" type="s" access="read"/>
<property name="IconThemePath" type="s" access="read"/>
<property name="IconPixmap" type="a(iiay)" access="read"/>
<property name="ItemIsMenu" type="b" access="read"/>
<method name="Activate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="ContextMenu"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="SecondaryActivate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="Scroll"><arg type="i" direction="in"/><arg type="s" direction="in"/></method>
<method name="ProvideXdgActivationToken"><arg type="s" direction="in"/></method>
<signal name="NewIcon"/><signal name="NewStatus"><arg type="s"/></signal><signal name="NewToolTip"/>
</interface></node>`

load_notifier_symbols :: proc() -> bool {
    n, _ := dynlib.initialize_symbols(&gio, "libgio-2.0.so.0", "g_")
    if n != int(size_of(Gio)/size_of(rawptr))-1 { return false }
    n, _ = dynlib.initialize_symbols(&glib, "libglib-2.0.so.0", "g_")
    return n == int(size_of(Glib)/size_of(rawptr))-1
}

start_notifier :: proc(tray: ^Tray) -> bool {
    tray.native = gio.bus_get_sync(2, nil, nil) // session bus
    if tray.native == nil { return false }
    node := gio.dbus_node_info_new_for_xml(NOTIFIER_XML, nil)
    if node == nil { objects.object_unref(tray.native); tray.native = nil; return false }
    defer gio.dbus_node_info_unref(node)
    info := gio.dbus_node_info_lookup_interface(node, NOTIFIER_INTERFACE)
    tray.registration = gio.dbus_connection_register_object(tray.native, NOTIFIER_PATH, info, &notifier_vtable, tray, nil, nil)
    if tray.registration == 0 { objects.object_unref(tray.native); tray.native = nil; return false }
    tray.watcher = gio.bus_watch_name_on_connection(tray.native, "org.kde.StatusNotifierWatcher", 0, rawptr(watcher_appeared), nil, tray, nil)
    return true
}

watcher_appeared :: proc "c" (connection: rawptr, name, owner: cstring, userdata: rawptr) {
    context = runtime.default_context()
    tray := cast(^Tray)userdata
    values := [1]rawptr{glib.variant_new_string(gio.dbus_connection_get_unique_name(connection))}
    parameters := glib.variant_new_tuple(raw_data(values[:]), 1)
    gio.dbus_connection_call(connection, name, "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem", parameters, nil, 0, 3000, nil, nil, nil)
}

notifier_property :: proc "c" (connection: rawptr, sender, path, interface_name, property: cstring, error: rawptr, userdata: rawptr) -> rawptr {
    context = runtime.default_context()
    switch string(property) {
    case "Category": return glib.variant_new_string("ApplicationStatus")
    case "Id": return glib.variant_new_string("odin-clipboard-manager")
    case "Title": return glib.variant_new_string("Clipboard Manager")
    case "Status": return glib.variant_new_string("Active")
    case "IconName": return glib.variant_new_string("edit-paste")
    case "IconThemePath": return glib.variant_new_string("")
    case "IconPixmap": return glib.variant_new_array("(iiay)", nil, 0)
    case "WindowId": return glib.variant_new_uint32(0)
    case "ItemIsMenu": return glib.variant_new_boolean(0)
    }
    return nil
}

notifier_method :: proc "c" (connection: rawptr, sender, path, interface_name, method: cstring, parameters, invocation, userdata: rawptr) {
    context = runtime.default_context()
    tray := cast(^Tray)userdata
    switch string(method) {
    case "Activate", "ContextMenu", "SecondaryActivate":
        x := glib.variant_get_child_value(parameters, 0)
        y := glib.variant_get_child_value(parameters, 1)
        tray.open_requested = true
        tray.popup_x, tray.popup_y = glib.variant_get_int32(x), glib.variant_get_int32(y)
        glib.variant_unref(x)
        glib.variant_unref(y)
    case "ProvideXdgActivationToken":
        token := glib.variant_get_child_value(parameters, 0)
        delete(tray.activation_token)
        tray.activation_token = strings.clone(string(glib.variant_get_string(token, nil)))
        glib.variant_unref(token)
    }
    gio.dbus_method_invocation_return_value(invocation, nil)
}

stop_notifier :: proc(tray: ^Tray) {
    if tray.watcher != 0 { gio.bus_unwatch_name(tray.watcher) }
    if tray.registration != 0 { gio.dbus_connection_unregister_object(tray.native, tray.registration) }
    if tray.native != nil { objects.object_unref(tray.native) }
    delete(tray.activation_token)
}
