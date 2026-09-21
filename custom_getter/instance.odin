package main

import "core:fmt"
import "core:os"
import "core:strings"
import linux "core:sys/linux"
import sdl "vendor:sdl3"

App_Instance :: struct {
	lock: ^os.File,
	request_path, processing_path: string,
}

// The lock is held for the application's lifetime and released by the kernel on exit.
// Launches from the desktop, shortcut, or terminal all share the same instance.
start_instance :: proc(directory: string, background: bool, token: string) -> (instance: App_Instance, primary, ok: bool) {
	if err := os.make_directory(directory, os.perm(0o700)); err != nil && err != .Exist {
		fmt.eprintln("Could not create application runtime directory:", err)
		return
	}
	lock_path := fmt.aprintf("%s/instance.lock", directory)
	defer delete(lock_path)
	lock, err := os.open(lock_path, {.Read, .Write, .Create}, os.perm(0o600))
	if err != nil { return }
	request := fmt.aprintf("%s/show", directory)
	lock_err := linux.flock(linux.Fd(os.fd(lock)), {.EX, .NB})
	if lock_err != nil {
		defer os.close(lock)
		defer delete(request)
		if lock_err != .EWOULDBLOCK {
			fmt.eprintln("Could not lock clipboard manager:", lock_err)
			return
		}
		if background { return {}, false, true }
		// Atomic replacement prevents the UI from reading a partially written token.
		temporary := fmt.aprintf("%s/show-%d", directory, linux.getpid())
		defer delete(temporary)
		if write_err := os.write_entire_file(temporary, transmute([]u8)token); write_err != nil { return }
		if rename_err := os.rename(temporary, request); rename_err != nil {
			os.remove(temporary)
			return
		}
		return {}, false, true
	}
	return {lock, request, fmt.aprintf("%s/show-processing", directory)}, true, true
}

close_instance :: proc(instance: ^App_Instance) {
	os.close(instance.lock)
	delete(instance.request_path)
	delete(instance.processing_path)
}

poll_show_request :: proc(app: ^AppState) {
	instance := &app.instance
	if os.rename(instance.request_path, instance.processing_path) != nil { return }
	data, err := os.read_entire_file(instance.processing_path, context.allocator)
	os.remove(instance.processing_path)
	if err != nil { return }
	defer delete(data)
	if len(data) > 0 {
		token := strings.clone_to_cstring(string(data))
		defer delete(token)
		// SDL consumes the compositor's activation token when mapping the window.
		_ = sdl.setenv_unsafe("XDG_ACTIVATION_TOKEN", token, true)
		if app.show_window { set_window_visible(app, false) }
	}
	set_window_visible(app, true)
	if len(app.clipboard_items) > 0 { navigate_items(app, .HOME) }
}
