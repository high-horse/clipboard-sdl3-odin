package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import sql "sqlite3"


Database :: struct {
	db:          ^sql.Connection,
	data_dir:    string,
	blob_dir:    string,
	db_path:     string,
	initialized: bool,
}

g_db: Database

get_db :: proc() -> (^Database, bool) {
	if !g_db.initialized || g_db.db == nil {
		fmt.println("ERROR: database has not been initialized yet")
		return nil, false
	}
	return &g_db, true
}

database_init :: proc() -> bool {
	data_dir, db_path, blob_dir, ok := init_storage()

	if !ok {
		return false
	}

	fmt.println("Data directory:", data_dir)
	fmt.println("Database:", db_path)
	fmt.println("Blobs:", blob_dir)

	g_db.data_dir = data_dir
	g_db.blob_dir = blob_dir
	g_db.db_path = db_path

	if !connect_db() {
		return false
	}

	if !prepare_table(&g_db) {
		return false
	}
	if !set_default_config(&g_db) {
		return false
	}
	g_db.initialized = true

	return true
}

connect_db :: proc() -> bool {
	db_path_cs := strings.clone_to_cstring(g_db.db_path, context.temp_allocator)
	rc := sql.open(db_path_cs, &g_db.db)

	if rc != nil {
		fmt.printf("ERROR: failed to connect to database: ", rc)
		return false
	}

	fmt.println("Database connected")
	return true
}


prepare_table :: proc(db: ^Database) -> bool {
	query := `
		CREATE TABLE IF NOT EXISTS clipboard_contents (
			id INTEGER PRIMARY KEY,
			content_path TEXT NOT NULL,
			mime TEXT NOT NULL,
			hash TEXT NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
	`
	query_cs := strings.clone_to_cstring(query, context.temp_allocator)

	rc := sql.exec(db.db, query_cs, nil, nil, nil)

	if rc != .Ok {
		fmt.println("Failed to create clipboard_contents table:", rc)
		return false
	}

	fmt.println("Database tables prepared.")

	return true
}

set_db_content_with_blob :: proc(content: ^database_content) -> bool {
	db, ok := get_db()
	if !ok {
		return false
	}

	file_path, err := filepath.join({db.blob_dir, content.hash}, context.temp_allocator)
	if err != nil {
		fmt.printfln("Error joining file path: %s", err)
		return false
	}
	write_err := os.write_entire_file(file_path, content.data)
	if write_err != nil {
		fmt.printfln("Error saving blob file to disk: %s", file_path)
		return false
	}

	query := `
		INSERT INTO clipboard_contents (content_path, hash, mime)
		VALUES (?, ?, ?);
	`
	query_cs := strings.clone_to_cstring(query, context.temp_allocator)

	file_path_cs := strings.clone_to_cstring(file_path, context.temp_allocator)
	hash_cs := strings.clone_to_cstring(content.hash, context.temp_allocator)
	mime_cs := strings.clone_to_cstring(content.mime, context.temp_allocator)

	stmt: ^sql.Statement
	// 	prepare_v2 :: proc "c" (db: ^Connection, sql: cstring, n_bytes: c.int, statement: ^^Statement, tail: ^^cstring) -> Result_Code ---
	if sql.prepare_v2(db.db, query_cs, -1, &stmt, nil) != .Ok {
		fmt.printfln("Failed to prepare statement: %s", sql.errmsg(db.db))
		return false
	}
	defer sql.finalize(stmt)

	if rc := sql.bind_text(
		stmt,
		1,
		file_path_cs,
		c.int(len(file_path_cs)),
		sql.Destructor{behaviour = .Static},
	); rc != .Ok {
		fmt.printfln("Failed to bind content_path: %v", rc)
		return false
	}

	if rc := sql.bind_text(
		stmt,
		2,
		hash_cs,
		c.int(len(hash_cs)),
		sql.Destructor{behaviour = .Static},
	); rc != .Ok {
		fmt.printfln("Failed to bind hash: %v", rc)
		return false
	}

	if rc := sql.bind_text(
		stmt,
		3,
		mime_cs,
		c.int(len(mime_cs)),
		sql.Destructor{behaviour = .Static},
	); rc != .Ok {
		fmt.printfln("Failed to bind mime: %v", rc)
		return false
	}

	if rc := sql.step(stmt); rc != .Done {
		fmt.printfln("Failed to insert clipboard content: %s", sql.errmsg(db.db))
		return false
	}

	fmt.printfln("Successfully stored blob: %s (%d bytes)", file_path, len(content.data))
	return true
}

create_config_table :: proc(db: ^Database) -> bool {
	query := "CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT)"
	query_cs := strings.clone_to_cstring(query, context.temp_allocator);
	stmt: ^sql.Statement
	if sql.prepare_v2(db.db, query_cs, -1, &stmt, nil) != .Ok {
		fmt.printfln("Failed to prepare statement: %s", sql.errmsg(db.db))
		return false
	}
	defer sql.finalize(stmt)

	if rc := sql.step(stmt); rc != .Done {
		fmt.printfln("Failed to create config table: %s", sql.errmsg(db.db))
		return false
	}

	return true
}

set_default_config :: proc(db: ^Database) -> bool {
	if !create_config_table(db) {
		return false
	}
	fmt.printfln("Setting default config")
	
	query := "INSERT OR IGNORE INTO config (key, value) VALUES (?, ?)"
	query_cs := strings.clone_to_cstring(query, context.temp_allocator);
	stmt: ^sql.Statement
	if sql.prepare_v2(db.db, query_cs, -1, &stmt, nil) != .Ok {
		fmt.printfln("Failed to prepare statement: %s", sql.errmsg(db.db))
		return false
	}
	defer sql.finalize(stmt)

	entries_key := "max_entries"
	entries_key_cs := strings.clone_to_cstring(entries_key, context.temp_allocator);
	if rc := sql.bind_text(
		stmt,
		1,
		entries_key_cs,
		c.int(len(entries_key_cs)),
		sql.Destructor{behaviour = .Static},
	); rc != .Ok {
		fmt.printfln("Failed to bind key: %v", rc)
		return false
	}

	entries_value := "5"
	entries_value_cs := strings.clone_to_cstring(entries_value, context.temp_allocator);
	if rc := sql.bind_text(
		stmt,
		2,
		entries_value_cs,
		c.int(len(entries_value_cs)),
		sql.Destructor{behaviour = .Static},
	); rc != .Ok {
		fmt.printfln("Failed to bind value: %v", rc)
		return false
	}

	if rc := sql.step(stmt); rc != .Done {
		fmt.printfln("Failed to set default config: %s", sql.errmsg(db.db))
		return false
	}

	return true
}
