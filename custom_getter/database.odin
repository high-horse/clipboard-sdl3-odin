package main

import "core:fmt"
import "core:strings"
import sql "sqlite3"


Database :: struct {
	db:       ^sql.Connection,
	data_dir: string,
	blob_dir: string,
	db_path:  string,
}


database_init :: proc() -> (Database, bool) {
	data_dir, db_path, blob_dir, ok := init_storage()

	if !ok {
		return {}, false
	}

	fmt.println("Data directory:", data_dir)
	fmt.println("Database:", db_path)
	fmt.println("Blobs:", blob_dir)

	database := Database{
		data_dir = data_dir,
		blob_dir  = blob_dir,
		db_path   = db_path,
	}

	if !connect(&database) {
		return {}, false
	}

	if !prepare_table(&database) {
		return {}, false
	}

	return database, true
}


connect :: proc(db: ^Database) -> bool {
	db_path_cs := strings.clone_to_cstring(db.db_path, context.temp_allocator)
	rc := sql.open(db_path_cs, &db.db)

	if rc != .Ok {
		fmt.println("Failed to connect to database:", rc)
		return false
	}

	fmt.println("Database connected.")

	return true
}


prepare_table :: proc(db: ^Database) -> bool {
	query := `
		CREATE TABLE IF NOT EXISTS clipboard_contents (
			id INTEGER PRIMARY KEY,
			content_path TEXT NOT NULL,
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
