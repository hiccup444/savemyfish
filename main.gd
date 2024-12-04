extends Node

var previous_fish_data = {}
const SAVE_FILE_PATH = "user://caught_fish.json"
const FISH_CATEGORIES = ["lake", "ocean", "rain"]

func _ready():
	if PlayerData.has_signal("_journal_update"):
		PlayerData.connect("_journal_update", self, "_poll_journal_data")
	
	_load_caught_fish()

func _poll_journal_data():
	for category in FISH_CATEGORIES:
		if PlayerData.journal_logs.has(category):
			var current_fish_data = PlayerData.journal_logs[category]

			for fish_id in current_fish_data.keys():
				if current_fish_data[fish_id]["count"] > 0:
					if not previous_fish_data.has(fish_id) or current_fish_data[fish_id]["count"] > previous_fish_data[fish_id]["count"]:
						previous_fish_data[fish_id] = current_fish_data[fish_id]
						save_caught_fish()

func save_caught_fish():
	var file = File.new()
	if file.open(SAVE_FILE_PATH, File.WRITE) == OK:
		var filtered_data = {}
		for fish_id in previous_fish_data.keys():
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

func _get_fish_category(fish_id):
	if Globals.item_data.has(fish_id):
		return Globals.item_data[fish_id]["file"].loot_table
	return null
