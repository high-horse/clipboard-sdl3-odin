package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import linux "core:sys/linux"
import sdl "vendor:sdl3"

Resource_Usage :: struct {
    sampled: bool,
    next_sample: u64,
    cpu_total, cpu_idle: u64,
    cpu, ram, gpu, disk: f64,
    cpu_ok, ram_ok, gpu_ok, disk_ok: bool,
    ram_used, ram_total, disk_used, disk_total: f64,
}

resource_sidebar_width :: proc(app: ^AppState) -> f32 {
    if app.width < 640 || app.height < 440 { return 0 }
    return 180
}

resource_file :: proc(path: string) -> string {
    data, err := os.read_entire_file(path, context.temp_allocator)
    if err != nil { return "" }
    return transmute(string)data
}

sample_resources :: proc(r: ^Resource_Usage) {
    now := sdl.GetTicks()
    if r.sampled && now < r.next_sample { return }
    r.sampled = true
    r.next_sample = now + 1000
    r.cpu_ok, r.ram_ok, r.gpu_ok, r.disk_ok = false, false, false, false

    stat := resource_file("/proc/stat")
    line, _ := strings.split_by_byte_iterator(&stat, '\n')
    fields := strings.fields(line, context.temp_allocator)
    if len(fields) >= 5 && fields[0] == "cpu" {
        total, idle: u64
        valid := true
        // guest times are already included in user/nice.
        for i := 1; i < min(len(fields), 9); i += 1 {
            value, ok := strconv.parse_u64(fields[i])
            valid = valid && ok
            total += value
            if i == 4 || i == 5 { idle += value }
        }
        if valid {
            if r.cpu_total > 0 && total > r.cpu_total && idle >= r.cpu_idle {
                r.cpu = clamp(100 * (1 - f64(idle-r.cpu_idle)/f64(total-r.cpu_total)), 0, 100)
                r.cpu_ok = true
            }
            r.cpu_total, r.cpu_idle = total, idle
        }
    }

    memory := resource_file("/proc/meminfo")
    total, available: u64
    have_total, have_available: bool
    for line in strings.split_lines(memory, context.temp_allocator) {
        values := strings.fields(line, context.temp_allocator)
        if len(values) < 2 { continue }
        if values[0] == "MemTotal:" { total, have_total = strconv.parse_u64(values[1]) }
        if values[0] == "MemAvailable:" { available, have_available = strconv.parse_u64(values[1]) }
    }
    if have_total && have_available && total > 0 && available <= total {
        r.ram_total = f64(total) / (1024*1024)
        r.ram_used = f64(total-available) / (1024*1024)
        r.ram = 100*r.ram_used/r.ram_total
        r.ram_ok = true
    }

    // Drivers exposing DRM busy counters (e.g. AMD); unsupported GPUs show N/A.
    for card in 0..<16 {
        path := fmt.tprintf("/sys/class/drm/card%d/device/gpu_busy_percent", card)
        value, ok := strconv.parse_f64(strings.trim_space(resource_file(path)))
        if ok && value >= 0 && value <= 100 {
            r.gpu, r.gpu_ok = value, true
            break
        }
    }

    path := get_data_dir()
    defer delete(path)
    fs: linux.Stat_FS
    if linux.statfs(strings.clone_to_cstring(path, context.temp_allocator), &fs) == nil && fs.blocks > 0 {
        r.disk_total = f64(fs.blocks)*f64(fs.bsize)/(1024*1024*1024)
        r.disk_used = f64(fs.blocks-fs.bfree)*f64(fs.bsize)/(1024*1024*1024)
        r.disk = 100*r.disk_used/r.disk_total
        r.disk_ok = true
    }
}

render_resources :: proc(app: ^AppState, layout: List_Layout) {
    width := resource_sidebar_width(app)
    if width == 0 { return }
    r := &app.resources
    sample_resources(r)
    panel_x := layout.x + layout.width + 20
    panel_y := f32(LIST_TOP)
    ui_fill(app, {panel_x, panel_y, width, 336}, {23, 31, 45, 255})
    ui_text(app, "Resources", panel_x+12, panel_y+12, UI_TEXT)
    ui_text_with_font(app, font_set.small, "System / updates every second", panel_x+12, panel_y+35, UI_MUTED)
    labels := [4]string{"CPU", "RAM", "GPU", "Disk"}
    values := [4]f64{r.cpu, r.ram, r.gpu, r.disk}
    valid := [4]bool{r.cpu_ok, r.ram_ok, r.gpu_ok, r.disk_ok}
    for label, i in labels {
        x := panel_x+12
        y := panel_y+34+f32(i)*68
        text := fmt.tprintf("%s  N/A", label)
        if valid[i] { text = fmt.tprintf("%s  %.0f%%", label, values[i]) }
        ui_text(app, text, x, y+25, UI_TEXT)
        ui_fill(app, {x, y+49, width-24, 3}, {44, 55, 73, 255})
        if valid[i] { ui_fill(app, {x, y+49, (width-24)*f32(values[i]/100), 3}, UI_ACCENT) }
        detail := "System load"
        switch i {
        case 1: detail = "Memory used"
            if r.ram_ok { detail = fmt.tprintf("%.1f / %.1f GiB", r.ram_used, r.ram_total) }
        case 2: detail = "Driver unavailable"
            if r.gpu_ok { detail = "GPU busy" }
        case 3: detail = "Data filesystem"
            if r.disk_ok { detail = fmt.tprintf("%.0f / %.0f GiB", r.disk_used, r.disk_total) }
        }
        ui_text_with_font(app, font_set.small, detail, x, y+61, UI_MUTED)
    }
}
