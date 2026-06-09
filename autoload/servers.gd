extends Node
## Servers autoload — the server browser backend.
##
## Stores a local list of saved servers (user://servers.json). The design is
## intentionally pluggable: to use a central master server, implement
## fetch_online_list() against your HTTP endpoint and merge the result —
## see docs/NETWORKING.md ("Master server").

signal list_changed

const SAVE_PATH := "user://servers.json"

const DEFAULT_SERVERS: Array = [
	{"name": "Local Server", "address": "127.0.0.1", "port": Net.DEFAULT_PORT},
]

## Array of {name: String, address: String, port: int}
var entries: Array = []


func _ready() -> void:
	load_list()


func add_server(name_: String, address: String, port: int) -> void:
	name_ = name_.strip_edges()
	address = address.strip_edges()
	if name_.is_empty():
		name_ = address
	if address.is_empty():
		return
	for entry: Dictionary in entries:
		if entry["address"] == address and int(entry["port"]) == port:
			return
	entries.append({"name": name_, "address": address, "port": port})
	save_list()
	list_changed.emit()


func remove_server(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	entries.remove_at(index)
	save_list()
	list_changed.emit()


func save_list() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(entries, "\t"))


func load_list() -> void:
	entries = DEFAULT_SERVERS.duplicate(true)
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty():
				entries = parsed
	list_changed.emit()
