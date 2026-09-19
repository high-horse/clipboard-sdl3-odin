package clipboard

import "base:runtime"
import "core:fmt"
import "core:strings"

import sdl "vendor:sdl3"

// Internal structure to hold our heap-allocated payload safely
Clipboard_Payload :: struct {
    data:       []u8,
    c_mime:     cstring,
    // We must store the array of cstrings on the heap too!
    mime_array: []cstring, 
}

// 1. The Data Callback
clipboard_data_cb :: proc "c" (userdata: rawptr, mime_type: cstring, size: ^uint) -> rawptr {
    // Let's add a print so you know when Wayland actually asks for the data!
    context = runtime.default_context()
    fmt.println(">>> SDL/Wayland requested the clipboard data! <<<")
    
    payload := (^Clipboard_Payload)(userdata)
    size^ = uint(len(payload.data))
    return raw_data(payload.data)
}

// 2. The Cleanup Callback
clipboard_cleanup_cb :: proc "c" (userdata: rawptr) {
    context = runtime.default_context()
    fmt.println(">>> SDL is cleaning up our clipboard payload <<<")

    payload := (^Clipboard_Payload)(userdata)
    if payload != nil {
        if payload.data != nil { delete(payload.data) }
        if payload.c_mime != nil { delete(payload.c_mime) }
        if payload.mime_array != nil { delete(payload.mime_array) }
        free(payload)
    }
}

// Simple and direct text clipboard setter
set_custom_clipboard_data :: proc(data: []u8, mime: string) -> bool {
    // If it's text, we can convert bytes to a null-terminated C string
    text_str := string(data)
    c_text := strings.clone_to_cstring(text_str, context.allocator)
    defer delete(c_text)

    // Call SDL's built-in text clipboard function
    success := sdl.SetClipboardText(c_text)
    
    if !success {
        fmt.println("failed to set clipboard text:", sdl.GetError())
    } else {
        fmt.println("Successfully set clipboard text via SDL_SetClipboardText!")
    }

    return success
}

// 3. Generic function to set clipboard content safely
set_custom_clipboard_data_bkp :: proc(data: []u8, mime: string) -> bool {
    // 1. Duplicate the input bytes onto the heap
    owned_data := make([]u8, len(data))
    copy(owned_data, data)

    // 2. Clone the mime string onto the heap
    c_mime := strings.clone_to_cstring(mime, context.allocator)
    
    // 3. Create a HEAP ALLOCATED slice for the mime types array
    mime_array := make([]cstring, 1)
    mime_array[0] = c_mime

    // 4. Store everything in the heap-allocated payload structure
    payload := new(Clipboard_Payload)
    payload^ = Clipboard_Payload {
        data       = owned_data,
        c_mime     = c_mime,
        mime_array = mime_array,
    }

    // 5. Pass the heap-backed array safely to SDL
    success := sdl.SetClipboardData(
        clipboard_data_cb,
        clipboard_cleanup_cb,
        payload,
        raw_data(payload.mime_array), // Safe! This lives on the heap now.
        1,
    )

    if !success {
        fmt.println("failed to set content")
        delete(owned_data)
        delete(c_mime)
        delete(mime_array)
        free(payload)
    }

    return success
}