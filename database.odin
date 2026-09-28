package main

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sync"
import sql "sqlite3"


Config :: struct {
	max_entries: int `json:"max_entries"`,
}

Database :: struct {
	db:          ^sql.Connection,
	data_dir:    string,
	blob_dir:    string,
	db_path:     string,
	config_path: string,
	config:      Config,
	initialized: bool,
}

g_db: Database
history_mutex: sync.Mutex
history_generation: u64

current_history_generation :: proc() -> u64 {
	sync.mutex_lock(&history_mutex)
	defer sync.mutex_unlock(&history_mutex)
	return history_generation
}

clear_saved_history :: proc() -> (generation: u64, ok, files_removed: bool) {
	sync.mutex_lock(&history_mutex)
	defer sync.mutex_unlock(&history_mutex)
	generation = history_generation
	db, ready := get_db()
	if !ready { return }
	paths := make([dynamic]string)
	defer {
		for path in paths { delete(path) }
		delete(paths)
	}
	stmt: ^sql.Statement
	if sql.prepare_v2(db.db, "SELECT DISTINCT content_path FROM clipboard_contents", -1, &stmt, nil) != .Ok { return }
	for {
		rc := sql.step(stmt)
		if rc == .Done { break }
		if rc != .Row { sql.finalize(stmt); return }
		append(&paths, strings.clone(string(sql.column_text(stmt, 0))))
	}
	sql.finalize(stmt)
	if sql.exec(db.db, "DELETE FROM clipboard_contents", nil, nil, nil) != .Ok { return }
	history_generation += 1
	generation = history_generation
	ok, files_removed = true, true
	for path in paths {
		// Only remove files belonging to this application's blob directory.
		if filepath.dir(path) != db.blob_dir {
			files_removed = false
			continue
		}
		if os.exists(path) {
			if err := os.remove(path); err != nil { files_removed = false }
		}
	}
	return
}

get_db :: proc() -> (^Database, bool) {
	if !g_db.initialized || g_db.db == nil {
		fmt.println("ERROR: database has not been initialized yet")
		return nil, false
	}
	return &g_db, true
}

database_init :: proc() -> bool {
	data_dir, db_path, blob_dir, config_file_name, ok := init_storage()

	if !ok {
		return false
	}

	fmt.println("Data directory:", data_dir)
	fmt.println("Database:", db_path)
	fmt.println("Blobs:", blob_dir)

	g_db.data_dir = data_dir
	g_db.blob_dir = blob_dir
	g_db.db_path = db_path

	// file_path, err := filepath.join({db.blob_dir, content.hash}, context.temp_allocator)
	config_path, err := filepath.join({g_db.data_dir, config_file_name}, context.temp_allocator)
	if err != nil {
		fmt.printfln("Failed to create config path: %s", err)
		return false
	}
	g_db.config_path = strings.clone(config_path, context.allocator)

	if !connect_db() {
		return false
	}

	if !prepare_table(&g_db) {
		return false
	}
	if !load_config(&g_db) {
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
	sync.mutex_lock(&history_mutex)
	defer sync.mutex_unlock(&history_mutex)
	if content.generation != history_generation { return false }
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


load_config :: proc(db: ^Database) -> bool {
	data, err := os.read_entire_file(db.config_path, context.allocator)
	if err != nil {
		fmt.printfln("failed to read config file: %v", err)
		db.config = Config {
			max_entries = 5,
		}
		return save_config(db)
	}

	unmarshell_err := json.unmarshal(data, &db.config)
	delete(data)
	if unmarshell_err != nil {
		fmt.printfln("Failed to parse config file: %v", unmarshell_err)
		return false
	}
	fmt.println("config loaded")
	return true
}

save_config :: proc(db: ^Database) -> bool {
	data, err := json.marshal(
		db.config,
		json.Marshal_Options{pretty = true, use_spaces = true, spaces = 4},
		context.allocator,
	)
	if err != nil {
		fmt.printfln("Failed to serialize config: %v", err)
		return false
	}
	defer delete(data)

	if write_err := os.write_entire_file(db.config_path, data); write_err != nil {
		fmt.printfln("Failed to write config: %s", write_err)
		return false
	}
	return true
}

set_max_entries :: proc(value: int) -> bool {
	db, ok := get_db()
	if !ok {
		return false
	}

	db.config.max_entries = value
	return save_config(db)
} 

get_max_entries :: proc() -> (int, bool) {
	db, ok := get_db()
	if !ok {
		return -1, false
	}

	return db.config.max_entries, true
}


database_has_hash :: proc(hash: string) -> bool {
	db, ok := get_db()
	if !ok {
		return false
	}

	query := `
		SELECT 1
		FROM clipboard_contents
		WHERE hash = ?
		LIMIT 1;
	`
	query_cs := strings.clone_to_cstring(query, context.temp_allocator)
	hash_cs := strings.clone_to_cstring(hash, context.temp_allocator)

	stmt: ^sql.Statement

	if sql.prepare_v2(db.db, query_cs, -1, &stmt, nil) != nil {
		return false
	}
	defer sql.finalize(stmt)

	if sql.bind_text(stmt, 1, hash_cs, c.int(len(hash_cs)), sql.Destructor{behaviour = .Static}) != .Ok {
		return false
	}
	return sql.step(stmt) == .Row
}