extends Node

func get_data_to_save(player_ref) -> Dictionary:
	
	if player_ref == null:
		push_warning("No player found.")
		return {}
	
	var data_dict = {
		"Level": player_ref.Level,
		"Gold": player_ref.Gold,
		"XP": player_ref.XP
		}
	
	return data_dict

func save_file(data):
	var file = FileAccess.open("user://game_data.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_data():
	var data
	var default_data = {}
	
	if !FileAccess.file_exists("user://game_data.save"):
		save_file(default_data)
	else:
		var file = FileAccess.open("user://game_data.save", FileAccess.READ)
		data = JSON.parse_string(file.get_as_text())
		file.close()
	
	if data.is_empty():
		push_warning("No data received.")
		return
