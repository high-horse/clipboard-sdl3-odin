package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"

TRAY_HISTORY_LIMIT :: 30
FIXED_TRAY_ENTRIES :: 4 // 5 // Show, Hide, Quit, Start at Login, Separator

Tray_Item_Data :: struct {
	app:   ^AppState,
	index: int,
}

set_window_visible :: proc(app: ^AppState, visible: bool) {
	if visible {
		if sdl.ShowWindow(app.window) {
			app.show_window = true
			_ = sdl.RaiseWindow(app.window)
		}
	} else if sdl.HideWindow(app.window) {
		app.show_window = false
	}
}

tray_show :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	set_window_visible(cast(^AppState)userdata, true)
}

tray_hide :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	set_window_visible(cast(^AppState)userdata, false)
}

tray_quit :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()
	app := cast(^AppState)userdata
	app.running = false
}

autostart_path :: proc() -> string {
	xdg_config := os.get_env("XDG_CONFIG_HOME", context.allocator)
	if xdg_config != "" {
		defer delete(xdg_config)
		return fmt.aprintf("%s/autostart/sdl3-odin-clipboard-manager.desktop", xdg_config)
	}
	delete(xdg_config)

	home := os.get_env("HOME", context.allocator)
	if home == "" {
		delete(home)
		return fmt.aprintf("/tmp/.config/autostart/sdl3-odin-clipboard-manager.desktop")
	}
	defer delete(home)
	return fmt.aprintf("%s/.config/autostart/sdl3-odin-clipboard-manager.desktop", home)
}

autostart_enabled :: proc() -> bool {
	path := autostart_path()
	defer delete(path)
	return os.exists(path)
}

// Resolves the symlink /proc/self/exe to the real executable path.
get_executable_path :: proc() -> string {
	exe, err := os.read_link("/proc/self/exe", context.allocator)
	if err != nil {
		return ""
	}
	return exe
}


tray_toggle_autostart :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()

	path := autostart_path()
	defer delete(path)

	// Already enabled -> disable.
	if os.exists(path) {
		if err := os.remove(path); err != nil {
			fmt.eprintfln("Failed to disable autostart: %v", err)
			return
		}
		sdl.SetTrayEntryChecked(entry, false)
		fmt.println("Autostart disabled")
		return
	}

	// Ensure the parent directory exists (slice up to last '/', no allocation).
	if idx := strings.last_index_byte(path, '/'); idx > 0 {
		parent := path[:idx]
		if !os.exists(parent) {
			if err := os.make_directory_all(parent); err != nil {
				fmt.eprintfln("Failed to create autostart directory: %v", err)
				return
			}
		}
	}

	exe := get_executable_path()
	if exe == "" {
		fmt.eprintln("Could not determine executable path")
		return
	}
	defer delete(exe)

	content := fmt.aprintf(
		"[Desktop Entry]\n" +
		"Type=Application\n" +
		"Name=%s\n" +
		"Exec=%s --background\n" +
		"X-GNOME-Autostart-enabled=true\n" +
		"NoDisplay=false\n",
		APP_NAME,
		exe,
	)
	defer delete(content)

	file, err := os.create(path)
	if err != nil {
		fmt.eprintfln("Failed to create autostart file: %v", err)
		return
	}
	defer os.close(file)

	_, werr := os.write(file, transmute([]u8)content)
	if werr != nil {
		fmt.eprintfln("Failed to write autostart file: %v", werr)
		return
	}

	sdl.SetTrayEntryChecked(entry, true)
	fmt.println("Autostart enabled ", path)
}

create_app_tray :: proc(app: ^AppState) -> ^sdl.Tray {
	icon := sdl.CreateSurface(32, 32, .RGBA32)
	if icon == nil {
		fmt.eprintfln("Could not create tray icon: %s", sdl.GetError())
		return nil
	}
	defer sdl.DestroySurface(icon)

	transparent := sdl.MapSurfaceRGBA(icon, 0, 0, 0, 0)
	_ = sdl.FillSurfaceRect(icon, nil, transparent)

	black := sdl.MapSurfaceRGBA(icon, 20, 22, 25, 255)
	white := sdl.MapSurfaceRGBA(icon, 245, 247, 250, 255)

	// Clipboard body
	board := sdl.Rect{6, 5, 20, 24}
	_ = sdl.FillSurfaceRect(icon, &board, white)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{6, 5, 2, 24}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{24, 5, 2, 24}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{6, 5, 20, 2}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{6, 27, 20, 2}, black)

	// Clip
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 2, 12, 7}, white)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 2, 12, 2}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 7, 12, 2}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 2, 2, 7}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{20, 2, 2, 7}, black)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{13, 3, 6, 3}, black)

	// Paper lines
	line_color := sdl.MapSurfaceRGBA(icon, 60, 63, 68, 255)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 12, 12, 1}, line_color)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 16, 12, 1}, line_color)
	_ = sdl.FillSurfaceRect(icon, &sdl.Rect{10, 20, 9, 1}, line_color)

	tray := sdl.CreateTray(icon, "Clipboard Manager")
	if tray == nil {
		fmt.eprintfln("Tray unavailable: %s", sdl.GetError())
		return nil
	}

	menu := sdl.CreateTrayMenu(tray)
	if menu == nil {
		sdl.DestroyTray(tray)
		return nil
	}
	app.tray_history_menu = menu

	// NOTE: these 4 entries must match FIXED_TRAY_ENTRIES and stay first.
	show := sdl.InsertTrayEntryAt(menu, -1, "Show Clipboard Manager", {.BUTTON})
	hide := sdl.InsertTrayEntryAt(menu, -1, "Hide window", {.BUTTON})

	// quit := sdl.InsertTrayEntryAt(menu, -1, "Quit", {.BUTTON})
	autostart := sdl.InsertTrayEntryAt(menu, -1, "Start at Login", {.CHECKBOX})

	separator := sdl.InsertTrayEntryAt(
		menu,
		-1,
		"──────────────────────────",
		{.BUTTON, .DISABLED},
	)


	if show == nil || hide == nil || 
	// quit == nil ||
	autostart == nil || separator == nil {
		sdl.DestroyTray(tray)
		return nil
	}

	sdl.SetTrayEntryCallback(show, tray_show, app)
	sdl.SetTrayEntryCallback(hide, tray_hide, app)
	// sdl.SetTrayEntryCallback(quit, tray_quit, app)
	sdl.SetTrayEntryCallback(autostart, tray_toggle_autostart, app)
	sdl.SetTrayEntryChecked(autostart, autostart_enabled())

	fmt.println("Clipboard Manager tray icon created")
	return tray
}

// Removes only the dynamic history entries, keeping the fixed ones.
// Re-fetches the entry array each iteration because SDL mutates/reallocs it
// on every removal, so a cached pointer/count goes stale.
clear_tray_history_menu :: proc(menu: ^sdl.TrayMenu) {
	if menu == nil {return}

	for {
		count: c.int = 0
		entries := sdl.GetTrayEntries(menu, &count)
		if entries == nil || int(count) <= FIXED_TRAY_ENTRIES {
			break
		}
		sdl.RemoveTrayEntry(entries[count - 1])
	}
}

tray_history_click :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()

	data := cast(^Tray_Item_Data)userdata
	if data == nil || data.app == nil {
		return
	}

	app := data.app
	if data.index < 0 || data.index >= len(app.clipboard_items) {
		return
	}

	copy_item(app, data.index)
}

clear_tray_history_data :: proc(app: ^AppState) {
	if app == nil {
		return
	}

	for data in app.tray_history_data {
		if data != nil {
			free(data)
		}
	}

	clear(&app.tray_history_data)
}

// Truncates to at most `max_bytes` without splitting a UTF-8 sequence.
truncate_utf8 :: proc(s: string, max_bytes: int) -> string {
	if len(s) <= max_bytes {
		return s
	}
	n := max_bytes
	for n > 0 && (s[n] & 0xC0) == 0x80 {
		n -= 1
	}
	return s[:n]
}

update_tray_history :: proc(app: ^AppState) {
	if app == nil || app.tray_history_menu == nil {
		return
	}

	// Remove menu entries FIRST, then free the userdata they pointed to.
	clear_tray_history_menu(app.tray_history_menu)
	clear_tray_history_data(app)

	count := min(len(app.clipboard_items), TRAY_HISTORY_LIMIT)

	if count == 0 {
		_ = sdl.InsertTrayEntryAt(
			app.tray_history_menu,
			-1,
			"No clipboard history",
			{.BUTTON, .DISABLED},
		)
		return
	}

	for offset := 0; offset < count; offset += 1 {
		index := len(app.clipboard_items) - 1 - offset
		item := app.clipboard_items[index]

		// label := truncate_utf8(preview_text(item), 30)
		label := strings.trim_space(truncate_utf8(preview_text(item), 30))


		// SDL copies the label, so we can free it right after inserting.
		label_cs := strings.clone_to_cstring(label, context.allocator)
		entry := sdl.InsertTrayEntryAt(app.tray_history_menu, -1, label_cs, {.BUTTON})
		delete(label_cs)

		if entry == nil {
			continue
		}

		data := new(Tray_Item_Data)
		data.app = app
		data.index = index
		append(&app.tray_history_data, data)

		sdl.SetTrayEntryCallback(entry, tray_history_click, data)
	}
}
