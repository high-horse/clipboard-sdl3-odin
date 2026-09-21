package main

import "clipboard"


set_content :: proc(db_content: ^database_content) -> bool {
	content := clipboard.Clipboard_Data{data = db_content.data, mime = db_content.mime}
	return clipboard.set_content(&content)
}
