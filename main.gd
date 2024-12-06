extends Node

var previous_fish_data = {}
const SAVE_FILE_PATH = "user://caught_fish.json"
const FISH_CATEGORIES = ["lake", "ocean", "rain", "water_trash", "deep", "alien", "void"]

enum Quality { NORMAL, SHINING, GLISTENING, OPULENT, RADIANT, ALPHA }

func _ready():
	print("[SAVEMYFISH] SaveMyFish loaded.")
	get_tree().connect("node_added", self, "_on_node_added")
	if PlayerData.has_signal("_journal_update"):
		PlayerData.connect("_journal_update", self, "_poll_journal_data")

func _on_node_added(node: Node) -> void:
	if node.name == "main_menu":
		print("[SAVEMYFISH] Main menu detected. Loading caught fish data.")
		_load_caught_fish()

func _poll_journal_data():
	for category in FISH_CATEGORIES:
		if not PlayerData.journal_logs.has(category):
			continue

		var current_fish_data = PlayerData.journal_logs[category]

		for fish_id in current_fish_data.keys():
			if not _is_fish_id_valid(fish_id):
				continue

			var fish_data = previous_fish_data.get(fish_id, {"count": 0, "qualities": 0, "record": 0.0})
			var is_new_catch = false

			# Update fish count
			var new_count = current_fish_data[fish_id]["count"]
			if new_count > fish_data["count"]:
				fish_data["count"] = new_count
				is_new_catch = true

			# Update the record if the new size is larger
			var new_record = current_fish_data[fish_id].get("record", 0.0)
			if new_record > fish_data["record"]:
				fish_data["record"] = new_record
				is_new_catch = true

			# Update qualities
			var qualities_int = int(fish_data["qualities"])
			for quality in current_fish_data[fish_id].get("quality", []):
				var quality_bit = 1 << int(quality)
				if not (qualities_int & quality_bit):
					qualities_int |= quality_bit
					is_new_catch = true
			fish_data["qualities"] = qualities_int

			# Save updated fish data if new catch detected
			if is_new_catch:
				previous_fish_data[fish_id] = fish_data
				save_caught_fish()



func _load_caught_fish():
	print("[SAVEMYFISH] Loading caught fish data...")
	var file = File.new()
	if file.file_exists(SAVE_FILE_PATH):
		if file.open(SAVE_FILE_PATH, File.READ) == OK:
			var json_result = JSON.parse(file.get_as_text())
			file.close()

			if json_result.error == OK and typeof(json_result.result) == TYPE_DICTIONARY:
				previous_fish_data = json_result.result
				var valid_fish_data = {}
				
				for fish_id in previous_fish_data.keys():
					if not _is_fish_id_valid(fish_id):
						print("[SAVEMYFISH] Invalid fish ID detected and skipped:", fish_id)
						continue

					var fish_data = previous_fish_data[fish_id]

					# Ensure all necessary fields are present
					if not fish_data.has("record"):
						fish_data["record"] = 0.0
					if not fish_data.has("qualities"):
						fish_data["qualities"] = 0
					if not fish_data.has("count"):
						fish_data["count"] = 0

					# Convert qualities array to bitfield if necessary
					if typeof(fish_data["qualities"]) == TYPE_ARRAY:
						var qualities_bitfield = 0
						for quality in fish_data["qualities"]:
							qualities_bitfield |= 1 << int(quality)
						fish_data["qualities"] = int(qualities_bitfield)

					valid_fish_data[fish_id] = fish_data
					_log_fish_to_journal(fish_id)

				previous_fish_data = valid_fish_data
			else:
				previous_fish_data = {}
		else:
			previous_fish_data = {}
	else:
		previous_fish_data = {}

func _log_fish_to_journal(fish_id):
	if not previous_fish_data.has(fish_id):
		print("[SAVEMYFISH] Fish ID not found in previous_fish_data:", fish_id)
		return

	var qualities = _bitfield_to_quality_list(previous_fish_data[fish_id]["qualities"])
	for quality in qualities:
		PlayerData._log_item(fish_id, previous_fish_data[fish_id]["record"], quality, false)

func save_caught_fish():
	var file = File.new()
	if file.open(SAVE_FILE_PATH, File.WRITE) == OK:
		file.store_string(to_json(previous_fish_data))
		file.close()

func _get_fish_category(fish_id):
	if Globals.item_data.has(fish_id):
		var category = Globals.item_data[fish_id]["file"].loot_table
		if category in FISH_CATEGORIES:
			return category
		return "modded"
	return null

func _is_fish_id_valid(fish_id):
	return Globals.item_data.has(fish_id)

func _bitfield_to_quality_list(bitfield):
	bitfield = int(bitfield)
	var qualities = []
	for quality in Quality.values():
		if bitfield & (1 << quality):
			qualities.append(quality)
	return qualities
