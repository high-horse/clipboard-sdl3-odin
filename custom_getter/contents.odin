package main

import "core:fmt"
import "clipboard"
import "core:hash"


set_content :: proc(db_content: ^database_content) -> bool {
	fmt.println("set_content", string(db_content.data))
	ok := clipboard.set_custom_clipboard_data(db_content.data, db_content.mime)
	return ok
}
