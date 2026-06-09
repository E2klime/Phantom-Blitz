extends Control
## Server browser — join a saved server, direct-connect, or host a game.
## The list is local (see autoload/servers.gd); plug in a master server by
## implementing an HTTP fetch and calling Servers.add_server() per entry.

@onready var server_list: ItemList = %ServerList
@onready var status_label: Label = %StatusLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_edit: LineEdit = %PortEdit
@onready var host_port_edit: LineEdit = %HostPortEdit
@onready var host_name_edit: LineEdit = %HostNameEdit
@onready var join_button: Button = %JoinButton
@onready var host_config_label: Label = %HostConfigLabel

var _connecting: bool = false


func _ready() -> void:
	Servers.list_changed.connect(_refresh_list)
	Net.connection_succeeded.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	_refresh_list()
	host_config_label.text = "Will host: %s on %s (change in main menu)" % [
		str(Game.mode_info()["name"]), str(MapDB.get_map(Game.map_id)["name"])
	]
	if OS.has_feature("web"):
		%HostBox.hide()
		status_label.text = "Web build: join servers started with --websocket."


func _refresh_list() -> void:
	server_list.clear()
	for entry: Dictionary in Servers.entries:
		server_list.add_item("%s  —  %s:%d" % [entry["name"], entry["address"], int(entry["port"])])


func _set_status(text: String) -> void:
	status_label.text = text


# ------------------------------------------------------------------ joining

func _on_join_pressed() -> void:
	var selected := server_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a server first.")
		return
	var entry: Dictionary = Servers.entries[selected[0]]
	_join(str(entry["address"]), int(entry["port"]))


func _on_direct_connect_pressed() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		_set_status("Enter an address to connect to.")
		return
	_join(address, _port_from(port_edit))


func _join(address: String, port: int) -> void:
	if _connecting:
		return
	var err := Net.join_game(address, port)
	if not err.is_empty():
		_set_status(err)
		return
	_connecting = true
	join_button.disabled = true
	_set_status("Connecting to %s:%d ..." % [address, port])


func _on_connected() -> void:
	# The server replies with Game._sync_match_config, which moves us into the
	# arena once we know the mode and map. Just report progress here.
	_set_status("Connected — waiting for match info...")


func _on_connection_failed(reason: String) -> void:
	_connecting = false
	join_button.disabled = false
	_set_status(reason)


# ------------------------------------------------------------- list editing

func _on_add_pressed() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		_set_status("Enter an address to save.")
		return
	Servers.add_server(name_edit.text, address, _port_from(port_edit))
	_set_status("Server saved.")


func _on_remove_pressed() -> void:
	var selected := server_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a server to remove.")
		return
	Servers.remove_server(selected[0])


# ------------------------------------------------------------------ hosting

func _on_host_pressed() -> void:
	var err := Net.host_game(_port_from(host_port_edit), false, host_name_edit.text.strip_edges())
	if not err.is_empty():
		_set_status(err)
		return
	Game.start_match()


func _port_from(edit: LineEdit) -> int:
	var port := edit.text.strip_edges().to_int()
	return port if port > 0 and port < 65536 else Net.DEFAULT_PORT


func _on_back_pressed() -> void:
	Game.goto_scene("res://scenes/ui/main_menu.tscn")
