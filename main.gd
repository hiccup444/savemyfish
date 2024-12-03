extends Node

var previous_fish_data = {}
const SAVE_FILE_PATH = "user://caught_fish.json"
const FISH_CATEGORIES = ["lake", "ocean", "water_trash", "deep", "rain", "alien", "void"]

func _ready():
	print("User directory:", OS.get_user_data_dir()) #debugging

	if PlayerData.has_signal("_journal_update"):
		PlayerData.connect("_journal_update", self, "_poll_journal_data")
		print("Connected to PlayerData._journal_update signal.")
	else:
		print("Warning: PlayerData does not have a _journal_update signal.")
	
	_load_caught_fish()
	print("Previous fish data loaded:", previous_fish_data)

func _poll_journal_data():
	print("Polling journal logs on update...")
	print("Full journal logs structure:", PlayerData.journal_logs)

	for category in FISH_CATEGORIES:
		if PlayerData.journal_logs.has(category):
			print("Category found:", category)
			var current_fish_data = PlayerData.journal_logs[category]
			print("Data for category", category, ":", current_fish_data)

			for fish_id in current_fish_data.keys():
				print("Inspecting fish:", fish_id, "Data:", current_fish_data[fish_id])
				
				# Only save fish that have been caught (count > 0)
				if current_fish_data[fish_id]["count"] > 0:
					if not previous_fish_data.has(fish_id) or current_fish_data[fish_id]["count"] > previous_fish_data[fish_id]["count"]:
						print("New fish caught or updated:", fish_id)
						previous_fish_data[fish_id] = current_fish_data[fish_id]
						save_caught_fish()
				else:
					print("Fish not caught yet, skipping:", fish_id)
		else:
			print("Category not found in journal logs:", category)

func save_caught_fish():
	var file = File.new()
	print("Attempting to save caught fish data...")
	if file.open(SAVE_FILE_PATH, File.WRITE) == OK:
		# Only save entries with count > 0
		var filtered_data = {}
		for fish_id in previous_fish_data.keys():
			if previous_fish_data[fish_id]["count"] > 0:
				filtered_data[fish_id] = previous_fish_data[fish_id]

		file.store_string(to_json(filtered_data))
		file.close()
		print("Caught fish data saved successfully to:", SAVE_FILE_PATH)
	else:
		print("Error: Unable to save caught fish data to:", SAVE_FILE_PATH)

func _load_caught_fish():
	var file = File.new()
	if file.file_exists(SAVE_FILE_PATH):
		if file.open(SAVE_FILE_PATH, File.READ) == OK:
			var data = file.get_as_text()
			previous_fish_data = parse_json(data)
			file.close()
			for fish_id in previous_fish_data.keys():
				for category in FISH_CATEGORIES:
					if PlayerData.journal_logs.has(category) and PlayerData.journal_logs[category].has(fish_id):
						PlayerData.journal_logs[category][fish_id] = previous_fish_data[fish_id]
			print("Caught fish data applied to journal_logs:", PlayerData.journal_logs)
		else:
			print("Error: Unable to load caught fish data.")
	else:
		print("No existing caught fish data file found. Starting fresh.")
