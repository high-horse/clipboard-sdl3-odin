package clipboard

import "core:os"
import "core:strings"


wayland_create :: proc() -> (Clipboard, bool) {
	return Clipboard{backend = .Wayland}, true
}


wayland_set_text :: proc(text: string) -> bool {
	read_pipe, write_pipe, err := os.pipe()

	if err != os.ERROR_NONE {
		return false
	}

	desc := os.Process_Desc {
		command = []string{"wl-copy"},
		stdin   = read_pipe,
	}

	process, start_err := os.process_start(desc)

	_ = os.close(read_pipe)

	if start_err != os.ERROR_NONE {
		_ = os.close(write_pipe)
		return false
	}

	data := transmute([]u8)text

	_, write_err := os.write(write_pipe, data)

	_ = os.close(write_pipe)

	if write_err != os.ERROR_NONE {
		_ = os.process_terminate(process)

		_, wait_err := os.process_wait(process)
		_ = wait_err

		return false
	}

	state, wait_err := os.process_wait(process)

	if wait_err != os.ERROR_NONE {
		return false
	}

	return state.success
}


wayland_get_text :: proc() -> (string, bool) {
	data, ok := wayland_get_mime("text/plain")

	if !ok {
		return "", false
	}

	return transmute(string)data, true
}


// Get arbitrary MIME type
wayland_get_mime :: proc(mime: string) -> ([]u8, bool) {
	desc := os.Process_Desc {
		command = []string{"wl-paste", "--no-newline", "--type", mime},
	}

	state, stdout, stderr, err := os.process_exec(desc, context.allocator)

	delete(stderr)

	if err != os.ERROR_NONE {
		delete(stdout)
		return nil, false
	}

	if !state.success {
		delete(stdout)
		return nil, false
	}

	result := make([]u8, len(stdout), context.allocator)
	copy(result, stdout)

	delete(stdout)

	return result, true
}


// Available MIME types
wayland_get_types :: proc() -> ([]string, bool) {
	desc := os.Process_Desc {
		command = []string{"wl-paste", "--list-types"},
	}

	state, stdout, stderr, err := os.process_exec(desc, context.allocator)

	delete(stderr)

	if err != os.ERROR_NONE {
		delete(stdout)
		return nil, false
	}

	if !state.success {
		delete(stdout)
		return nil, false
	}

	types := make([dynamic]string, 0, context.allocator)

	output := transmute(string)stdout

	start := 0

	for i := 0; i <= len(output); i += 1 {
		if i == len(output) || output[i] == '\n' {
			line := output[start:i]

			// Remove CR for CRLF output.
			line = strings.trim_right(line, "\r")

			if len(line) > 0 {
				type_copy := strings.clone(line, context.allocator)
				append(&types, type_copy)
			}

			start = i + 1
		}
	}

	delete(stdout)

	return types[:], true
}


wayland_has_type :: proc(types: []string, wanted: string) -> bool {
	for type in types {
		if type == wanted {
			return true
		}
	}

	return false
}


// Generic clipboard retrieval
wayland_get :: proc() -> (Clipboard_Data, bool) {
	types, ok := wayland_get_types()

	if !ok {
		return {}, false
	}

	defer {
		for type in types {
			delete(type)
		}

		delete(types)
	}

	// Files
	if wayland_has_type(types, "text/uri-list") {
		data, ok := wayland_get_mime("text/uri-list")

		if ok {
			return Clipboard_Data{mime = "text/uri-list", data = data}, true
		}
	}

	// Text — prefer explicit UTF-8.
	if wayland_has_type(types, "text/plain;charset=utf-8") {
		data, ok := wayland_get_mime("text/plain;charset=utf-8")

		if ok {
			return Clipboard_Data{
				mime = "text/plain;charset=utf-8",
				data = data,
			}, true
		}
	}

	if wayland_has_type(types, "UTF8_STRING") {
		data, ok := wayland_get_mime("UTF8_STRING")
		if ok {
			return Clipboard_Data{
				mime = "text/plain",
				data = data,
			}, true
		}
	}

	if wayland_has_type(types, "text/plain") {
		data, ok := wayland_get_mime("text/plain")

		if ok {
			return Clipboard_Data{
				mime = "text/plain",
				data = data,
			}, true
		}
	}


	// Images
	if wayland_has_type(types, "image/png") {
		data, ok := wayland_get_mime("image/png")

		if ok {
			return Clipboard_Data{mime = "image/png", data = data}, true
		}
	}

	if wayland_has_type(types, "image/jpeg") {
		data, ok := wayland_get_mime("image/jpeg")

		if ok {
			return Clipboard_Data{mime = "image/jpeg", data = data}, true
		}
	}

	return {}, false
}


wayland_set :: proc(item: ^Clipboard_Data) -> bool {
	read_pipe, write_pipe, err := os.pipe()

	if err != os.ERROR_NONE {
		return false
	}

	desc := os.Process_Desc {
		command = []string{"wl-copy", "--type", item.mime},
		stdin   = read_pipe,
	}

	process, start_err := os.process_start(desc)

	_ = os.close(read_pipe)

	if start_err != os.ERROR_NONE {
		_ = os.close(write_pipe)
		return false
	}

	_, write_err := os.write(write_pipe, item.data)

	_ = os.close(write_pipe)

	if write_err != os.ERROR_NONE {
		_ = os.process_terminate(process)

		_, wait_err := os.process_wait(process)
		_ = wait_err

		return false
	}

	state, wait_err := os.process_wait(process)

	if wait_err != os.ERROR_NONE {
		return false
	}

	return state.success
}
