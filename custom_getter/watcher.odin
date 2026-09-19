package main

import "core:crypto/hash"
import "core:fmt"
import "core:strings"
import "core:time"

import "clipboard"

import sdl "vendor:sdl3"

watch_clipboard :: proc() {
	cb, ok := clipboard.create()

	if !ok {
		fmt.println("Could not initialize clipboard.")
		return
	}

	defer clipboard.destroy(&cb)

	fmt.printf("Clipboard backend: %s\n", clipboard.backend_name(&cb))

	last_text := ""

	for {
		text, ok := clipboard.get_text(&cb)

		if ok && text != last_text {
			fmt.printf("Clipboard changed: %s\n", text)
			last_text = text
		}

		time.sleep(100 * time.Millisecond)
	}
}

watch_clipboard_get_generic :: proc(wd: ^Worker_Data) {
	cb, ok := clipboard.create()

	if !ok {
		fmt.println("Could not initialize clipboard.")
		return
	}

	defer clipboard.destroy(&cb)

	fmt.printf("Clipboard backend: %s\n", clipboard.backend_name(&cb))

	last_mime := ""
	last_data: []u8 = nil

	defer {
		if last_data != nil {
			delete(last_data)
		}
	}

	for wd.running^ {
		data, ok := clipboard.get(&cb)

		if ok {
			changed := data.mime != last_mime

			if !changed {
				if len(data.data) != len(last_data) {
					changed = true
				} else {
					for i in 0 ..< len(data.data) {
						if data.data[i] != last_data[i] {
							changed = true
							break
						}
					}
				}
			}

			if changed {
				fmt.printf(
					"Clipboard changed: mime=%s, size=%d bytes\n",
					data.mime,
					len(data.data),
				)

				switch data.mime {
				case "text/plain":
					text := transmute(string)data.data
					fmt.printf("Text: %s\n", text)

				case "text/uri-list":
					fmt.printf("Files/URIs:\n%s\n", transmute(string)data.data)

				case "image/png":
					fmt.println("Clipboard contains PNG data.")

				case "image/jpeg":
					fmt.println("Clipboard contains JPEG data.")

				case:
					fmt.printf("Clipboard contains unsupported MIME type: %s\n", data.mime)
				}

				// Replace our previous snapshot.
				if last_data != nil {
					delete(last_data)
				}

				last_mime = data.mime

				last_data = make([]u8, len(data.data), context.allocator)

				copy(last_data, data.data)
			}

			// get() allocated this data for us.
			delete(data.data)
		}
		time.sleep(100 * time.Millisecond)
	}
	if (!wd.running^) {
		fmt.println("exiting ...")
	}
}

watch_clipboard_get_generic_hashed :: proc(wd: ^Worker_Data) {
	cb, ok := clipboard.create()
	if !ok {
		fmt.println("failed to create clipboard")
		return
	}
	defer clipboard.destroy(&cb)

	fmt.printfln("clipboard backend %s", cb.backend)

	last_hash: [32]byte
	has_last_hash := false

	for wd.running^ {
		data, ok := clipboard.get(&cb)
		if ok {
			defer delete(data.data)

			ctx: hash.Context
			hash.init(&ctx, .SHA256)
			hash.update(&ctx, transmute([]u8)data.mime)
			hash.update(&ctx, data.data)

			current_hash: [32]byte
			hash.final(&ctx, current_hash[:])

			changed := !has_last_hash || (current_hash != last_hash)
			if changed {
				last_hash = current_hash
				has_last_hash = true

				fmt.printf(
					"Clipboard changed: mime=%s, size=%d bytes\n",
					data.mime,
					len(data.data),
				)
				switch data.mime {
				case "text/plain":
					text := transmute(string)data.data
					fmt.printf("Text: %s\n", text)

				case "text/uri-list":
					fmt.printf("Files/URIs:\n%s\n", transmute(string)data.data)

				case "image/png":
					fmt.println("Clipboard contains PNG data.")

				case "image/jpeg":
					fmt.println("Clipboard contains JPEG data.")

				case:
					fmt.printf("Clipboard contains unsupported MIME type: %s\n", data.mime)
				}
			}

		}
	}
	if !wd.running^ {
		fmt.println("exiting ...")
	}

}


sdl_board :: proc(wd: ^Worker_Data) {
	data := sdl.GetClipboardText()
	fmt.println("clipboard content changed")
}


sdl_clipboard_worker :: proc(wd: ^Worker_Data) {
	previous := ""
	for wd.running^ {
		raw := sdl.GetClipboardText()
		current := strings.clone(string(cstring(raw)))
		if current != previous {
			previous = current
			fmt.println("content changed")
		}
		time.sleep(100 * time.Millisecond)
	}
	if (!wd.running^) {
		fmt.println("exiting goodbye...")
	}
}
