package main

import "core:c"
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

Image_Preview :: struct {
    hash: string,
    texture: ^sdl.Texture,
    surface: ^sdl.Surface,
    width, height: i32,
    used_at: u64,
}

IMAGE_PREVIEW_CACHE_LIMIT :: 32

free_image_preview :: proc(preview: ^Image_Preview) {
    if preview.texture != nil { sdl.DestroyTexture(preview.texture) }
    if preview.surface != nil { sdl.DestroySurface(preview.surface) }
    delete(preview.hash)
}

clear_image_previews :: proc(app: ^AppState) {
    for &preview in app.image_previews { free_image_preview(&preview) }
    delete(app.image_previews)
    app.image_previews = nil
}

remove_image_preview :: proc(app: ^AppState, hash: string) {
    for &preview, i in app.image_previews {
        if preview.hash == hash {
            free_image_preview(&preview)
            ordered_remove(&app.image_previews, i)
            return
        }
    }
}

image_preview :: proc(app: ^AppState, item: database_content) -> Image_Preview {
    for &preview in app.image_previews {
        if preview.hash == item.hash {
            preview.used_at = sdl.GetTicks()
            return preview
        }
    }
    preview := Image_Preview{hash = strings.clone(item.hash), used_at = sdl.GetTicks()}
    // Cache failures too, so invalid clipboard images are not decoded every frame.
    if len(item.data) > 0 && len(item.data) <= 64*1024*1024 {
        w, h, channels: c.int
        if stbi.info_from_memory(raw_data(item.data), c.int(len(item.data)), &w, &h, &channels) != 0 && w > 0 && h > 0 && i64(w)*i64(h) <= 32*1024*1024 {
            pixels := stbi.load_from_memory(raw_data(item.data), c.int(len(item.data)), &w, &h, &channels, 4)
            if pixels != nil {
                defer stbi.image_free(pixels)
                surface := sdl.CreateSurfaceFrom(w, h, .RGBA32, pixels, w*4)
                if surface != nil {
                    defer sdl.DestroySurface(surface)
                    // Store only a small texture; release full-size decoded pixels immediately.
                    scale := min(f32(1), min(f32(320)/f32(w), f32(96)/f32(h)))
                    thumb := sdl.ScaleSurface(surface, max(1, c.int(f32(w)*scale)), max(1, c.int(f32(h)*scale)), .LINEAR)
                    if thumb != nil {
                        preview.surface = thumb
                        preview.texture = sdl.CreateTextureFromSurface(app.renderer, thumb)
                        if preview.texture != nil {
                            preview.width, preview.height = i32(w), i32(h)
                            sdl.SetTextureBlendMode(preview.texture, sdl.BLENDMODE_BLEND)
                            sdl.SetTextureScaleMode(preview.texture, .LINEAR)
                        }
                    }
                }
            }
        }
    }
    if len(app.image_previews) >= IMAGE_PREVIEW_CACHE_LIMIT {
        oldest := 0
        for cached, i in app.image_previews {
            if cached.used_at < app.image_previews[oldest].used_at { oldest = i }
        }
        free_image_preview(&app.image_previews[oldest])
        ordered_remove(&app.image_previews, oldest)
    }
    append(&app.image_previews, preview)
    return preview
}

image_fit_rect :: proc(width, height: i32, bounds: sdl.FRect) -> sdl.FRect {
    if width <= 0 || height <= 0 || bounds.w <= 0 || bounds.h <= 0 { return {} }
    scale := min(f32(1), min(bounds.w/f32(width), bounds.h/f32(height)))
    return {bounds.x, bounds.y+(bounds.h-f32(height)*scale)/2, f32(width)*scale, f32(height)*scale}
}

render_image_preview :: proc(app: ^AppState, item: database_content, bounds: sdl.FRect) {
    preview := image_preview(app, item)
    if preview.texture == nil {
        ui_text(app, "Image preview unavailable", bounds.x, bounds.y+12, UI_MUTED)
        return
    }
    // Checkerboard makes transparent regions visible.
    dst := image_fit_rect(preview.width, preview.height, bounds)
    ui_fill(app, dst, {47, 57, 72, 255})
    for y := dst.y; y < dst.y+dst.h; y += 8 {
        for x := dst.x; x < dst.x+dst.w; x += 8 {
            if (int((x-dst.x)/8)+int((y-dst.y)/8))%2 == 0 {
                ui_fill(app, {x, y, min(f32(8), dst.x+dst.w-x), min(f32(8), dst.y+dst.h-y)}, {66, 77, 94, 255})
            }
        }
    }
    sdl.RenderTexture(app.renderer, preview.texture, nil, &dst)
    label := fmt.tprintf("%d x %d", preview.width, preview.height)
    if bounds.w-dst.w > 100 {
        ui_text_with_font(app, font_set.small, label, dst.x+dst.w+12, bounds.y+8, UI_MUTED)
    }
}
