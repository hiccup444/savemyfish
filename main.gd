extends Node

var previous_fish_data = {}
const SAVE_FILE_PATH = "user://caught_fish.json"
const FISH_CATEGORIES = ["lake", "ocean", "rain"]

func _ready():
	print("[SAVEMYFISH] SaveMyFish loaded.")
	if PlayerData.has_signal("_journal_update"):
		PlayerData.connect("_journal_update", self, "_poll_journal_data")
	
	_load_caught_fish()
	clean_up_save_file()

func _poll_journal_data():
	for category in FISH_CATEGORIES:
		if PlayerData.journal_logs.has(category):
			var current_fish_data = PlayerData.journal_logs[category]

			for fish_id in current_fish_data.keys():
				if not _is_fish_id_valid(fish_id):
					continue
				
				if current_fish_data[fish_id]["count"] > 0:
					var is_new_catch = false

					if not previous_fish_data.has(fish_id) or current_fish_data[fish_id]["count"] > previous_fish_data[fish_id]["count"]:
						previous_fish_data[fish_id] = current_fish_data[fish_id]
						is_new_catch = true

					var current_qualities = current_fish_data[fish_id]["quality"]
					var previous_qualities = previous_fish_data[fish_id].get("quality", [])

					for quality in current_qualities:
						if not _list_has(previous_qualities, quality):
							if not previous_fish_data[fish_id].has("quality"):
								previous_fish_data[fish_id]["quality"] = []
							previous_fish_data[fish_id]["quality"].append(quality)
							is_new_catch = true

					if previous_fish_data[fish_id].has("quality"):
						previous_fish_data[fish_id]["quality"] = _remove_duplicates(previous_fish_data[fish_id]["quality"])

					if is_new_catch:
						save_caught_fish()

func save_caught_fish():
	var file = File.new()
	if file.open(SAVE_FILE_PATH, File.WRITE) == OK:
		var filtered_data = {}
		for fish_id in previous_fish_data.keys():
			if not _is_fish_id_valid(fish_id):
				continue

			if previous_fish_data[fish_id]["count"] > 0:
				filtered_data[fish_id] = previous_fish_data[fish_id]

		file.store_string(to_json(filtered_data))
		file.close()

func _load_caught_fish():
	var file = File.new()
	if file.file_exists(SAVE_FILE_PATH):
		if file.open(SAVE_FILE_PATH, File.READ) == OK:
			var data = file.get_as_text()
			previous_fish_data = parse_json(data)
			file.close()

			yield(get_tree().create_timer(4), "timeout")

			for fish_id in previous_fish_data.keys():
				if not _is_fish_id_valid(fish_id):
					print("[SAVEMYFISH] Skipping invalid fish ID during load:", fish_id)
					continue

				var fish_data = previous_fish_data[fish_id]
				var category = _get_fish_category(fish_id)

				if not category:
					category = "modded"

					if not PlayerData.journal_logs.has(category):
						PlayerData.journal_logs[category] = {}

					if not PlayerData.journal_logs[category].has(fish_id):
						PlayerData.journal_logs[category][fish_id] = {
							"count": 0,
							"record": 0.0,
							"quality": []
						}

				PlayerData._log_item(fish_id, fish_data["record"], 0, true)

				for quality in fish_data["quality"]:
					PlayerData._log_item(fish_id, fish_data["record"], quality, false)

func clean_up_save_file():
	var file = File.new()
	if file.file_exists(SAVE_FILE_PATH):
		if file.open(SAVE_FILE_PATH, File.READ) == OK:
			var data = parse_json(file.get_as_text())
			file.close()

			if data:
				var cleaned_data = {}
				for fish_id in data.keys():
					var fish_data = data[fish_id]
					if fish_data.has("quality"):
						fish_data["quality"] = _remove_duplicates(fish_data["quality"])
					cleaned_data[fish_id] = fish_data

				file.open(SAVE_FILE_PATH, File.WRITE)
				file.store_string(to_json(cleaned_data))
				file.close()
				print("[SAVEMYFISH] Save file cleaned and re-saved:")

func _get_fish_category(fish_id):
	if Globals.item_data.has(fish_id):
		return Globals.item_data[fish_id]["file"].loot_table
	return null

func _is_fish_id_valid(fish_id):
	return Globals.item_data.has(fish_id)

func _list_has(list, value):
	for item in list:
		if item == value:
			return true
	return false

func _remove_duplicates(list):
	var unique_list = []
	for item in list:
		if not _list_has(unique_list, item):
			unique_list.append(item)
	return unique_list
