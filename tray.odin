package main

import "base:runtime"
import "core:fmt"
import "core:os"
import sdl "vendor:sdl3"

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
    home := os.get_env("HOME", context.allocator)
    if home == "" {
        home = "/temp"
    }

    xdg_config := os.get_env("XDG_CONFIG_HOME", context.allocator)
    if xdg_config != "" {
        return fmt.aprintf("%s/autostart/sdl3-odin-clipboard-manager.desktop", xdg_config)
    }

    return fmt.aprintf("%s/.config/autostart/sdl3-odin-clipboard-manager.desktop", home)
}


autostart_path_ :: proc() -> string {
	home := os.get_env("HOME", context.allocator)
	if home == "" {
		home = "/temp"
	}

	xdg_config := os.get_env("XDG_CONFIG_HOME", context.allocator)
	if xdg_config != "" {
		return fmt.aprintf("%s/autostart/sdl3-odin-clipboard-manager.desktop", xdg_config)
	}
	return fmt.aprintf("%s/.config/autostart/sdl3-odin-clipboard-manager.desktop", home)
}

autostart_enabled :: proc() -> bool {
	path := autostart_path()
	defer delete(path)

	return os.exists(path)
}

get_executable_path :: proc() -> string {
    data, err := os.read_entire_file("/proc/self/exe", context.allocator)
    if err != nil {
        return ""
    }

    return string(data)
}


tray_toggle_autostart :: proc "c" (userdata: rawptr, entry: ^sdl.TrayEntry) {
	context = runtime.default_context()

	_ = userdata

	path := autostart_path()
	defer delete(path)

	// if os.exists(path) {
	// 	if err := os.remove(path); err != nil {
	// 		fmt.eprintfln("Failed to disable autostart: %v", err)
	// 		return
	// 	}

	// 	sdl.SetTrayEntryChecked(entry, false)
	// 	fmt.println("Autostart disabled")
	// 	return
	// }

	// Create ~/.config/autostart/
	parent := os.dir(path)

	if !os.exists(parent) {
		if err := os.make_directory_all(parent); err != nil {
			fmt.eprintfln("Failed to create autostart directory: %v", err)
			return
		}
	}

	exe := get_executable_path()
	if exe == "" {
		fmt.eprintln("Could not determine executable path")
		return
	}
	defer delete(exe)

	file, err := os.create(path)
	if err != nil {
		fmt.eprintfln("Failed to create autostart file: %v", err)
		return
	}
	defer os.close(file)

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

	_, err = os.write(file, transmute([]u8)content)
	if err != nil {
		fmt.eprintfln("Failed to write autostart file: %v", err)
		return
	}

	sdl.SetTrayEntryChecked(entry, true)

	fmt.println("Autostart enabled")
}


create_app_tray :: proc(app: ^AppState) -> ^sdl.Tray {
	// Draw a clipboard icon without requiring an external image file.
	icon := sdl.CreateSurface(32, 32, .RGBA32)
	if icon == nil {
		fmt.eprintfln("Could not create tray icon: %s", sdl.GetError())
		return nil
	}
	defer sdl.DestroySurface(icon)
	_ = sdl.FillSurfaceRect(icon, nil, sdl.MapSurfaceRGBA(icon, 0, 0, 0, 0))
	ink := sdl.MapSurfaceRGBA(icon, 235, 240, 250, 255)
	blue := sdl.MapSurfaceRGBA(icon, 40, 100, 170, 255)
	board := sdl.Rect{5, 5, 22, 25}
	paper := sdl.Rect{8, 8, 16, 19}
	clip := sdl.Rect{11, 2, 10, 7}
	_ = sdl.FillSurfaceRect(icon, &board, ink)
	_ = sdl.FillSurfaceRect(icon, &paper, blue)
	_ = sdl.FillSurfaceRect(icon, &clip, ink)
	for y: i32 = 12; y <= 22; y += 5 {
		line := sdl.Rect{11, y, 10, 2}
		_ = sdl.FillSurfaceRect(icon, &line, ink)
	}
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
	show := sdl.InsertTrayEntryAt(menu, -1, "Show Clipboard Manager", {.BUTTON})
	hide := sdl.InsertTrayEntryAt(menu, -1, "Hide window", {.BUTTON})
	quit := sdl.InsertTrayEntryAt(menu, -1, "Quit", {.BUTTON})
	autostart := sdl.InsertTrayEntryAt(menu, -1, "Start at Login", {.CHECKBOX})
	if show == nil || hide == nil || quit == nil || autostart == nil {
		sdl.DestroyTray(tray)
		return nil
	}
	sdl.SetTrayEntryCallback(show, tray_show, app)
	sdl.SetTrayEntryCallback(hide, tray_hide, app)
	sdl.SetTrayEntryCallback(autostart, tray_toggle_autostart, app)
	sdl.SetTrayEntryCallback(quit, tray_quit, app)
	fmt.println("Clipboard Manager tray icon created")
	return tray
}
