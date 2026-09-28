package main

import "core:fmt"
import "core:os"
import "core:strings"

import sdl3 "vendor:sdl3"
import ttf "vendor:sdl3/ttf"


Font_Set :: struct {
	primary:    ^ttf.Font,
	arabic:     ^ttf.Font,
	devanagari: ^ttf.Font,
	tc:         ^ttf.Font,
	emoji:      ^ttf.Font,
	small:      ^ttf.Font,
	title:      ^ttf.Font,
}


font_set: Font_Set

FONT_SIZE :: cast(f32)15
FONT_SMALL :: cast(f32)10
FONT_BIG :: cast(f32)25

FONT_LATIN :: "noto_sans_collection/Noto_Sans/static/NotoSans-Regular.ttf"
FONT_ARABIC :: "noto_sans_collection/Noto_Sans_Arabic/static/NotoSansArabic-Regular.ttf"
FONT_DEVANAGARI :: "noto_sans_collection/Noto_Sans_Devanagari/static/NotoSansDevanagari-Regular.ttf"
FONT_TC :: "noto_sans_collection/Noto_Sans_TC/static/NotoSansTC-Regular.ttf"
FONT_EMOJI :: "noto_sans_collection/Noto_Emoji/static/NotoEmoji-Regular.ttf"


get_executable_dir :: proc() -> string {
	exe, err := os.read_link("/proc/self/exe", context.allocator)
	if err != nil {
		return ""
	}
	defer delete(exe)

	if idx := strings.last_index_byte(exe, '/'); idx >= 0 {
		return strings.clone(exe[:idx])
	}

	return "."
}


resource_path :: proc(relative: string) -> string {
	exe_dir := get_executable_dir()

	if exe_dir == "" {
		return strings.clone(relative)
	}
	defer delete(exe_dir)

	return fmt.aprintf("%s/%s", exe_dir, relative)
}


open_font :: proc(path: string, size: f32) -> ^ttf.Font {
	font := ttf.OpenFont(strings.clone_to_cstring(path, context.temp_allocator), size)
	if font == nil {
		fmt.eprintfln("Failed to load font: %s", path)
	}
	return font
}


add_fallback :: proc(primary: ^ttf.Font, fallback: ^ttf.Font, name: string) -> bool {
	if primary == nil {
		return false
	}

	if fallback == nil {
		fmt.eprintfln("Skipping unavailable fallback font: %s", name)
		return false
	}

	ttf.AddFallbackFont(primary, fallback)
	fmt.eprintfln("Added fallback font: %s", name)
	return true
}


init_fonts :: proc() -> bool {
	if !ttf.Init() {
		fmt.eprintln("TTF_Init failed")
		return false
	}

	latin_path := resource_path(FONT_LATIN)
	defer delete(latin_path)

	arabic_path := resource_path(FONT_ARABIC)
	defer delete(arabic_path)

	devanagari_path := resource_path(FONT_DEVANAGARI)
	defer delete(devanagari_path)

	tc_path := resource_path(FONT_TC)
	defer delete(tc_path)

	emoji_path := resource_path(FONT_EMOJI)
	defer delete(emoji_path)


	font_set.primary = open_font(latin_path, FONT_SIZE)
	if font_set.primary == nil {
		fmt.eprintln("Failed to load primary Noto Sans font")
		ttf.Quit()
		return false
	}

	font_set.arabic = open_font(arabic_path, FONT_SIZE)
	add_fallback(font_set.primary, font_set.arabic, "Noto Sans Arabic")

	font_set.devanagari = open_font(devanagari_path, FONT_SIZE)
	add_fallback(font_set.primary, font_set.devanagari, "Noto Sans Devanagari")


	font_set.tc = open_font(tc_path, FONT_SIZE)
	add_fallback(font_set.primary, font_set.tc, "Noto Sans TC")

	font_set.emoji = open_font(emoji_path, FONT_SIZE)
	add_fallback(font_set.primary, font_set.emoji, "Noto Color Emoji")

	font_set.small = open_font(latin_path, FONT_SMALL)
	add_fallback(font_set.primary, font_set.small, "Latin small font")


	font_set.title = open_font(latin_path, FONT_BIG)
	add_fallback(font_set.primary, font_set.title, "Latin title font")

	return true
}


destroy_fonts :: proc() {

	if font_set.arabic != nil {
		ttf.CloseFont(font_set.arabic)
		font_set.arabic = nil
	}

	if font_set.devanagari != nil {
		ttf.CloseFont(font_set.devanagari)
		font_set.devanagari = nil
	}

	if font_set.tc != nil {
		ttf.CloseFont(font_set.tc)
		font_set.tc = nil
	}

	if font_set.emoji != nil {
		ttf.CloseFont(font_set.emoji)
		font_set.emoji = nil
	}

	if font_set.small != nil {
		ttf.CloseFont(font_set.small)
		font_set.small = nil
	}

	if font_set.title != nil {
		ttf.CloseFont(font_set.title)
		font_set.title = nil
	}

	if font_set.primary != nil {
		ttf.CloseFont(font_set.primary)
		font_set.primary = nil
	}

	ttf.Quit()
}
