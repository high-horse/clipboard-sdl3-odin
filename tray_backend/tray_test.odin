package tray_backend

import "core:dynlib"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
thumbnail_pixels_survive_source_cleanup :: proc(t: ^testing.T) {
    // These libraries require no display; exercise real GdkPixbuf ownership.
    n, _ := dynlib.initialize_symbols(&objects, "libgobject-2.0.so.0", "g_")
    if !testing.expect(t, n == 3) { return }
    n, _ = dynlib.initialize_symbols(&pixbuf, "libgdk_pixbuf-2.0.so.0", "gdk_pixbuf_")
    if !testing.expect(t, n == 2) { return }
    lib, ok := dynlib.load_library("libgdk_pixbuf-2.0.so.0")
    if !testing.expect(t, ok) { return }
    defer dynlib.unload_library(lib)
    pixels_ptr, found := dynlib.symbol_address(lib, "gdk_pixbuf_get_pixels")
    if !testing.expect(t, found) { return }
    get_pixels := cast(proc "c" (rawptr) -> [^]u8)pixels_ptr
    surface := sdl.CreateSurface(8, 4, .RGBA32)
    if !testing.expect(t, surface != nil) { return }
    sdl.FillSurfaceRect(surface, nil, sdl.MapSurfaceRGBA(surface, 25, 100, 200, 128))
    copy := surface_pixbuf(surface)
    sdl.DestroySurface(surface)
    if !testing.expect(t, copy != nil) { return }
    defer objects.object_unref(copy)
    pixels := get_pixels(copy)
    testing.expect(t, pixels[0] == 25 && pixels[1] == 100 && pixels[2] == 200 && pixels[3] == 128)
    testing.expect(t, surface_pixbuf(nil) == nil)
}
