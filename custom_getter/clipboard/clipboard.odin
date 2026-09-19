package clipboard

import "core:os"
import sdl "vendor:sdl3"

Backend :: enum {
	None,
	X11,
	Wayland,
}

Clipboard :: struct {
	backend: Backend,
}

Clipboard_Data :: struct {
	// Examples:
	//   text/plain
	//   text/uri-list
	//   image/png
	//   image/jpeg
	mime: string,

	// Raw data for the MIME type.
	//
	// IMPORTANT:
	// The caller owns this memory and must delete(data)
	// when finished with it.
	data: []u8,
}


create :: proc() -> (Clipboard, bool) {
	_, wayland_found := os.lookup_env_alloc("WAYLAND_DISPLAY", context.allocator)

	if wayland_found {
		if _, ok := wayland_create(); ok {
			return Clipboard{backend = .Wayland}, true
		}
	}

	_, x11_found := os.lookup_env_alloc("DISPLAY", context.allocator)

	if x11_found {
		if _, ok := x11_create(); ok {
			return Clipboard{backend = .X11}, true
		}
	}

	return Clipboard{}, false
}


set_text :: proc(cb: ^Clipboard, text: string) -> bool {
	switch cb.backend {
	case .Wayland:
		return wayland_set_text(text)

	case .X11:
		return x11_set_text(text)

	case .None:
		return false
	}

	return false
}


// get_text specifically asks the backend for text.
//
// It does not care whether the clipboard currently contains
// a file, image, etc.
get_text :: proc(cb: ^Clipboard) -> (string, bool) {
	switch cb.backend {
	case .Wayland:
		return wayland_get_text()

	case .X11:
		return x11_get_text()

	case .None:
		return "", false
	}

	return "", false
}


// get returns the best available clipboard representation.
//
// The returned data is allocated with context.allocator and
// belongs to the caller.
get :: proc(cb: ^Clipboard) -> (Clipboard_Data, bool) {
	switch cb.backend {
	case .Wayland:
		return wayland_get()

	case .X11:
		return x11_get()

	case .None:
		return {}, false
	}

	return {}, false
}


destroy :: proc(cb: ^Clipboard) {
	cb.backend = .None
}


backend_name :: proc(cb: ^Clipboard) -> string {
	switch cb.backend {
	case .Wayland:
		return "Wayland"

	case .X11:
		return "X11"

	case .None:
		return "None"
	}

	return "Unknown"
}

// set_sdl_clipboard_content :: proc(data: []u8, mime: string) -> bool {
// 	sdl.SetClipboardData()
// }

// set_content :: proc(cb: ^Clipboard, content: Clipboard_Data) -> bool {
// 	switch cb.backend {
// 	case .Wayland:
// 		return wayland_set_content(content)

// 	case .X11:
// 		return x11_set_content(content)

// 	case .None:
// 		return false
// 	}

// 	return false
// }


