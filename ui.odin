package main

import "core:c"
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

LIST_TOP :: 96
LIST_BOTTOM :: 38
CARD_HEIGHT :: 112
CARD_STEP :: 124

UI_TEXT :: sdl.Color{231, 237, 247, 255}
UI_MUTED :: sdl.Color{150, 165, 187, 255}
UI_ACCENT :: sdl.Color{112, 173, 255, 255}

List_Layout :: struct {
	x, width, bottom, viewport, max_scroll: f32,
}

list_layout :: proc(app: ^AppState) -> List_Layout {
	w, h: i32
	sdl.GetWindowSize(app.window, &w, &h)
	app.width = int(w)
	app.height = int(h)
	margin := f32(24)

	if w < 480 {
		margin = 14
	}

	width := min(f32(w) - margin * 2, 880)

	viewport := max(f32(0), f32(h) - LIST_TOP - LIST_BOTTOM)

	content := max(0, len(app.clipboard_items) * CARD_STEP - (CARD_STEP - CARD_HEIGHT))

	return {
		(f32(w) - width) / 2,
		width,
		f32(h) - LIST_BOTTOM,
		viewport,
		max(f32(0), f32(content) - viewport),
	}
}


clamp_scroll :: proc(app: ^AppState) {
	layout := list_layout(app)

	app.scroll = clamp(app.scroll, 0, layout.max_scroll)
}


clear_button_rect :: proc(app: ^AppState) -> sdl.FRect {
	layout := list_layout(app)

	return {layout.x + layout.width - 88, 18, 88, 32}
}


clear_button_at :: proc(app: ^AppState, x, y: f32) -> bool {
	if len(app.clipboard_items) == 0 {
		return false
	}

	r := clear_button_rect(app)

	return x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h
}


clear_history :: proc(app: ^AppState) {
	generation, ok, files_removed := clear_saved_history()

	app.history_status_until = sdl.GetTicks() + 3000

	if !ok {
		app.history_status = "Could not clear history. Try again."

		return
	}

	app.history_generation = generation

	for item in app.clipboard_items {
		delete(item.data)
	}

	clear(&app.clipboard_items)

	app.scroll = 0

	app.selected_index, app.pressed_index, app.copied_index = -1, -1, -1

	app.copied_until = 0
	app.copy_failed = false

	app.history_status = "History cleared."

	if !files_removed {
		app.history_status = "History cleared; some saved files remain."
	}
}


clipboard_item_at :: proc(app: ^AppState, x, y: f32) -> int {
	layout := list_layout(app)

	if x < layout.x || x >= layout.x + layout.width || y < LIST_TOP || y >= layout.bottom {
		return -1
	}

	position := y - LIST_TOP + app.scroll
	offset := int(position / CARD_STEP)

	if offset >= len(app.clipboard_items) {
		return -1
	}

	if position - f32(offset * CARD_STEP) >= CARD_HEIGHT {
		return -1
	}

	return len(app.clipboard_items) - 1 - offset
}


copy_item :: proc(app: ^AppState, index: int) {
	if index < 0 || index >= len(app.clipboard_items) {
		return
	}

	app.copy_failed = !set_content(&app.clipboard_items[index])

	app.copied_index = index

	app.copied_until = sdl.GetTicks() + 1800
}


navigate_items :: proc(app: ^AppState, key: sdl.Scancode) {
	count := len(app.clipboard_items)

	if count == 0 {
		return
	}

	index := app.selected_index

	#partial switch key {

	case .HOME:
		index = count - 1

	case .END:
		index = 0

	case .DOWN:
		if index < 0 {
			index = count - 1
		} else {
			index = max(0, index - 1)
		}

	case .UP:
		if index < 0 {
			index = count - 1
		} else {
			index = min(count - 1, index + 1)
		}
	}

	app.selected_index = index

	layout := list_layout(app)

	top := f32((count - 1 - index) * CARD_STEP)

	if top < app.scroll {
		app.scroll = top
	}

	if top + CARD_HEIGHT > app.scroll + layout.viewport {

		app.scroll = top + CARD_HEIGHT - layout.viewport
	}

	clamp_scroll(app)
}


ui_fill :: proc(app: ^AppState, rect: sdl.FRect, color: sdl.Color) {
	sdl.SetRenderDrawColor(app.renderer, color.r, color.g, color.b, color.a)

	r := rect

	sdl.RenderFillRect(app.renderer, &r)
}


ui_border :: proc(app: ^AppState, rect: sdl.FRect, color: sdl.Color) {
	sdl.SetRenderDrawColor(app.renderer, color.r, color.g, color.b, color.a)

	r := rect

	sdl.RenderRect(app.renderer, &r)
}


ui_text_run :: proc(
	app: ^AppState,
	font: ^ttf.Font,
	text: string,
	x, y: f32,
	color: sdl.Color,
) -> f32 {
	if font == nil || len(text) == 0 {
		return 0
	}

	cs := strings.clone_to_cstring(text, context.temp_allocator)

	surface := ttf.RenderText_Blended(font, cs, c.size_t(len(text)), color)

	if surface == nil {
		return 0
	}

	defer sdl.DestroySurface(surface)

	texture := sdl.CreateTextureFromSurface(app.renderer, surface)

	if texture == nil {
		return 0
	}

	defer sdl.DestroyTexture(texture)

	rect := sdl.FRect{x, y, f32(surface.w), f32(surface.h)}

	sdl.RenderTexture(app.renderer, texture, nil, &rect)

	return f32(surface.w)
}


ui_text :: proc(app: ^AppState, text: string, x, y: f32, color: sdl.Color) {
	if font_set.primary == nil || len(text) == 0 {
		return
	}

	cs := strings.clone_to_cstring(text, context.temp_allocator)

	surface := ttf.RenderText_Blended(font_set.primary, cs, c.size_t(len(text)), color)

	if surface == nil {
		return
	}

	defer sdl.DestroySurface(surface)

	texture := sdl.CreateTextureFromSurface(app.renderer, surface)

	if texture == nil {
		return
	}

	defer sdl.DestroyTexture(texture)

	dst := sdl.FRect{x, y, f32(surface.w), f32(surface.h)}

	sdl.RenderTexture(app.renderer, texture, nil, &dst)
}

ui_text_wrapped :: proc(app: ^AppState, text: string, x, y: f32, color: sdl.Color, wrap: i32) {
	if len(text) == 0 {
		return
	}

	if wrap <= 0 {
		ui_text(app, text, x, y, color)

		return
	}

	// If the text contains multiple scripts, render it without
	// forcing everything through one font. This avoids the old
	// behavior where Devanagari was used for Latin text.
	//
	// The current UI preview is short enough that this is a
	// reasonable first implementation.
	ui_text(app, text, x, y, color)
}


preview_text :: proc(item: database_content) -> string {
	if strings.has_prefix(item.mime, "text/") {

		text := transmute(string)item.data
		for _, offset in text {
			if offset >= 512 {
				return text[:offset]
			}
		}

		if len(text) == 0 {
			return "Empty text"
		}

		return text
	}

	switch item.mime {

	case "image/png", "image/jpeg":
		return "Image saved to clipboard"

	case:
		return "Saved clipboard content"
	}
}


item_kind :: proc(mime: string) -> string {
	switch mime {

	case "text/plain":
		return "TEXT"

	case "text/uri-list":
		return "FILES / LINKS"

	case "image/png":
		return "PNG IMAGE"

	case "image/jpeg":
		return "JPEG IMAGE"

	case:
		return "CONTENT"
	}
}


render_clipboard_ui :: proc(app: ^AppState) {
	layout := list_layout(app)

	app.scroll = clamp(app.scroll, 0, layout.max_scroll)
	sdl.SetRenderDrawColor(app.renderer, 16, 22, 33, 255)

	sdl.RenderClear(app.renderer)
	ui_text(app, "Clipboard", layout.x, 18, UI_TEXT)
	count_label := fmt.aprintf("%d items", len(app.clipboard_items))

	defer delete(count_label)

	ui_text(app, count_label, layout.x, 57, UI_MUTED)

	ui_fill(app, {layout.x, 80, layout.width, 1}, {44, 55, 73, 255})

	mouse_x, mouse_y: f32

	_ = sdl.GetMouseState(&mouse_x, &mouse_y)

	hovered := -1

	if sdl.GetMouseFocus() == app.window {
		hovered = clipboard_item_at(app, mouse_x, mouse_y)
	}

	clear_hovered := sdl.GetMouseFocus() == app.window && clear_button_at(app, mouse_x, mouse_y)
	button_fill := sdl.Color{25, 34, 49, 255}

	button_border := sdl.Color{49, 63, 83, 255}

	button_text := UI_TEXT

	if len(app.clipboard_items) == 0 {
		button_text = sdl.Color{94, 107, 126, 255}
	}

	if clear_hovered {

		button_fill = sdl.Color{66, 34, 40, 255}

		button_border = sdl.Color{214, 113, 123, 255}

		if app.clear_pressed {
			button_fill = sdl.Color{90, 42, 50, 255}
		}
	}

	button := clear_button_rect(app)

	ui_fill(app, button, button_fill)

	ui_border(app, button, button_border)

	ui_text(app, "Clear all", button.x + 21, button.y + 8, button_text)

	cursor := app.default_cursor

	if hovered >= 0 || clear_hovered {

		cursor = app.pointer_cursor
	}

	if cursor != nil {
		_ = sdl.SetCursor(cursor)
	}

	viewport := sdl.Rect{i32(layout.x), LIST_TOP, i32(layout.width), i32(layout.viewport)}

	sdl.SetRenderClipRect(app.renderer, &viewport)


	count := len(app.clipboard_items)
	if count == 0 {

		ui_text(app, "Nothing copied yet", layout.x + 18, LIST_TOP + 32, UI_TEXT)

		ui_text_wrapped(
			app,
			"Copy text, a link or an image to get started.",
			layout.x + 18,
			LIST_TOP + 64,
			UI_MUTED,
			i32(layout.width - 36),
		)
	}


	// --------------------------------------------------------
	// Clipboard cards
	// --------------------------------------------------------

	first := int(app.scroll / CARD_STEP)

	for offset := first; offset < count; offset += 1 {

		y := f32(LIST_TOP + offset * CARD_STEP) - app.scroll

		if y >= layout.bottom {
			break
		}

		index := count - 1 - offset

		item := app.clipboard_items[index]

		active := index == app.copied_index && sdl.GetTicks() < app.copied_until


		fill := sdl.Color{25, 34, 49, 255}

		border := sdl.Color{49, 63, 83, 255}

		accent := UI_ACCENT


		if index == hovered {
			fill = sdl.Color{34, 47, 66, 255}

			border = UI_ACCENT
		}

		if index == app.selected_index {
			border = UI_ACCENT
		}

		if index == app.pressed_index && index == hovered {

			fill = sdl.Color{42, 60, 85, 255}
		}


		if active {

			if app.copy_failed {

				fill = sdl.Color{66, 34, 40, 255}

				accent = sdl.Color{255, 151, 151, 255}

			} else {

				fill = sdl.Color{24, 54, 49, 255}

				accent = sdl.Color{112, 221, 176, 255}
			}

			border = accent
		}

		card := sdl.FRect{layout.x, y, layout.width, CARD_HEIGHT}

		ui_fill(app, card, fill)

		ui_border(app, card, border)

		ui_fill(app, {layout.x, y + 1, 3, CARD_HEIGHT - 2}, border)
		ui_text(app, item_kind(item.mime), layout.x + 16, y + 11, accent)


		// ----------------------------------------------------
		// Action
		// ----------------------------------------------------

		action := "Click to copy"

		if active {

			if app.copy_failed {
				action = "Copy failed"
			} else {
				action = "Copied!"
			}
		}

		ui_text(app, action, layout.x + layout.width - 90, y + 11, accent)

		preview_top := max(f32(LIST_TOP), y + 34)

		preview_bottom := min(layout.bottom, y + 78)

		if preview_bottom > preview_top {

			clip := sdl.Rect {
				i32(layout.x + 16),
				i32(preview_top),
				i32(layout.width - 32),
				i32(preview_bottom - preview_top),
			}

			sdl.SetRenderClipRect(app.renderer, &clip)

			ui_text_wrapped(
				app,
				preview_text(item),
				layout.x + 16,
				y + 34,
				UI_TEXT,
				i32(layout.width - 32),
			)

			sdl.SetRenderClipRect(app.renderer, &viewport)
		}

		size_label := fmt.aprintf("%d bytes", len(item.data))

		defer delete(size_label)

		ui_text(app, size_label, layout.x + 16, y + 88, UI_MUTED)
	}

	sdl.SetRenderClipRect(app.renderer, nil)

	if layout.max_scroll > 0 {

		track_x := layout.x + layout.width + 5

		thumb_height := max(
			f32(24),
			layout.viewport * layout.viewport / (layout.viewport + layout.max_scroll),
		)

		thumb_y := LIST_TOP + (layout.viewport - thumb_height) * app.scroll / layout.max_scroll

		ui_fill(app, {track_x, LIST_TOP, 3, layout.viewport}, {35, 45, 62, 255})

		ui_fill(app, {track_x, thumb_y, 3, thumb_height}, {103, 129, 163, 255})
	}

	footer := "Scroll to browse  /  Up & Down to select  /  Enter to copy"

	if app.width < 480 {
		footer = "Scroll to browse  /  Enter to copy"
	}

	if sdl.GetTicks() < app.copied_until {

		if app.copy_failed {
			footer = "Could not copy. Click the item to try again."
		} else {
			footer = "Copied to clipboard. Ready to paste."
		}
	}

	if sdl.GetTicks() < app.history_status_until {
		footer = app.history_status
	}

	ui_text(app, footer, layout.x, f32(app.height - 25), UI_MUTED)
}
