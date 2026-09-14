package clipboard

import "core:os"
import "core:strings"
import "vendor:x11/xlib"


x11_create :: proc() -> (Clipboard, bool) {
	display := xlib.OpenDisplay(nil)

	if display == nil {
		return Clipboard{}, false
	}

	xlib.CloseDisplay(display)

	return Clipboard{
		backend = .X11,
	}, true
}


x11_set_text :: proc(text: string) -> bool {
	read_pipe, write_pipe, err := os.pipe()

	if err != os.ERROR_NONE {
		return false
	}

	desc := os.Process_Desc{
		command = []string{
			"xclip",
			"-selection",
			"clipboard",
		},
		stdin = read_pipe,
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


x11_get_target :: proc(target: string) -> ([]u8, bool) {
	desc := os.Process_Desc{
		command = []string{
			"xclip",
			"-selection",
			"clipboard",
			"-o",
			"-t",
			target,
		},
	}

	state, stdout, stderr, err := os.process_exec(
		desc,
		context.allocator,
	)

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


// Text
x11_get_text :: proc() -> (string, bool) {
	data, ok := x11_get_target("UTF8_STRING")

	if ok {
		return transmute(string)data, true
	}

	data, ok = x11_get_target("text/plain")

	if ok {
		return transmute(string)data, true
	}

	data, ok = x11_get_target("STRING")

	if ok {
		return transmute(string)data, true
	}

	return "", false
}


x11_get_targets :: proc() -> ([]string, bool) {
	desc := os.Process_Desc{
		command = []string{
			"xclip",
			"-selection",
			"clipboard",
			"-o",
			"-t",
			"TARGETS",
		},
	}

	state, stdout, stderr, err := os.process_exec(
		desc,
		context.allocator,
	)

	delete(stderr)

	if err != os.ERROR_NONE {
		delete(stdout)
		return nil, false
	}

	if !state.success {
		delete(stdout)
		return nil, false
	}

	targets := make([dynamic]string, 0, context.allocator)

	output := transmute(string)stdout

	start := 0

	for i := 0; i <= len(output); i += 1 {
		if i == len(output) || output[i] == '\n' {
			line := output[start:i]

			line = strings.trim_right(line, "\r")

			if len(line) > 0 {
				target_copy := strings.clone(line, context.allocator)
				append(&targets, target_copy)
			}

			start = i + 1
		}
	}

	delete(stdout)

	return targets[:], true
}


x11_has_target :: proc(targets: []string, wanted: string) -> bool {
	for target in targets {
		if target == wanted {
			return true
		}
	}

	return false
}


// Generic clipboard retrieval
x11_get :: proc() -> (Clipboard_Data, bool) {
	targets, ok := x11_get_targets()

	if !ok {
		return {}, false
	}

	defer {
		for target in targets {
			delete(target)
		}

		delete(targets)
	}

	// Files
	if x11_has_target(targets, "text/uri-list") {
		data, ok := x11_get_target("text/uri-list")

		if ok {
			return Clipboard_Data{
				mime = "text/uri-list",
				data = data,
			}, true
		}
	}

	// UTF-8 text
	if x11_has_target(targets, "UTF8_STRING") {
		data, ok := x11_get_target("UTF8_STRING")

		if ok {
			return Clipboard_Data{
				mime = "text/plain",
				data = data,
			}, true
		}
	}

	// Standard text
	if x11_has_target(targets, "text/plain") {
		data, ok := x11_get_target("text/plain")

		if ok {
			return Clipboard_Data{
				mime = "text/plain",
				data = data,
			}, true
		}
	}

	// Older X11 text
	if x11_has_target(targets, "STRING") {
		data, ok := x11_get_target("STRING")

		if ok {
			return Clipboard_Data{
				mime = "text/plain",
				data = data,
			}, true
		}
	}

	// PNG
	if x11_has_target(targets, "image/png") {
		data, ok := x11_get_target("image/png")

		if ok {
			return Clipboard_Data{
				mime = "image/png",
				data = data,
			}, true
		}
	}

	// JPEG
	if x11_has_target(targets, "image/jpeg") {
		data, ok := x11_get_target("image/jpeg")

		if ok {
			return Clipboard_Data{
				mime = "image/jpeg",
				data = data,
			}, true
		}
	}

	return {}, false
}
