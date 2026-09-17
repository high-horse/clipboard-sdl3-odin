package main

import "core:fmt"



Database :: struct {
    db:  string     /* sqlite connection type */,
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

    // sqlite open/create here
    // db.db = sqlite.open(db_path)

    // execute CREATE TABLE statements here

    return Database {
        data_dir = data_dir,
        blob_dir = blob_dir,
        db_path = db_path,
    }, true
}