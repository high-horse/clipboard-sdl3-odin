package main

import "core:os"
import "core:math"
import "core:fmt"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
image_previews_decode_cache_and_cleanup :: proc(t: ^testing.T) {
    surface := sdl.CreateSurface(200, 100, .RGBA32)
    if !testing.expect(t, surface != nil) { return }
    defer sdl.DestroySurface(surface)
    app := AppState{renderer = sdl.CreateSoftwareRenderer(surface)}
    if !testing.expect(t, app.renderer != nil) { return }
    defer sdl.DestroyRenderer(app.renderer)
    defer clear_image_previews(&app)
    for path, i in ([]string{"testdata/preview.png", "testdata/preview.jpg"}) {
        data, err := os.read_entire_file(path, context.allocator)
        if !testing.expect(t, err == nil) { return }
        defer delete(data)
        item := database_content{data = data, hash = path}
        preview := image_preview(&app, item)
        testing.expect(t, preview.texture != nil && preview.width == 12 && preview.height == 6)
        cached := image_preview(&app, item)
        testing.expect(t, cached.texture == preview.texture && len(app.image_previews) == i+1)
        render_image_preview(&app, item, {0, 0, 180, 60})
    }
    invalid := database_content{data = []byte{1, 2, 3}, hash = "broken"}
    testing.expect(t, image_preview(&app, invalid).texture == nil)
    testing.expect(t, image_preview(&app, invalid).texture == nil && len(app.image_previews) == 3)
    remove_image_preview(&app, "testdata/preview.png")
    testing.expect(t, len(app.image_previews) == 2)
    for i in 0..<40 {
        image_preview(&app, database_content{hash = fmt.tprintf("invalid-%d", i)})
    }
    testing.expect(t, len(app.image_previews) == IMAGE_PREVIEW_CACHE_LIMIT)
    clear_image_previews(&app)
    testing.expect(t, len(app.image_previews) == 0)
}

@(test)
image_previews_preserve_aspect_ratio :: proc(t: ^testing.T) {
    wide := image_fit_rect(800, 400, {10, 20, 200, 60})
    testing.expect(t, math.abs(wide.w-120) < 0.001 && math.abs(wide.h-60) < 0.001 && wide.x == 10 && math.abs(wide.y-20) < 0.001)
    tall := image_fit_rect(100, 800, {10, 20, 200, 60})
    testing.expect(t, math.abs(tall.w-7.5) < 0.001 && math.abs(tall.h-60) < 0.001)
    small := image_fit_rect(12, 6, {10, 20, 200, 60})
    testing.expect(t, small.w == 12 && small.h == 6 && small.y == 47)
    testing.expect(t, image_fit_rect(0, 0, {0, 0, 100, 60}).w == 0)
}
