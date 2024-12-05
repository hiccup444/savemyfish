# main.gd but with comments detailing the code.

extends Node

# Dictionary to store previously caught fish data.
var previous_fish_data = {}

# File path to store caught fish data.
const SAVE_FILE_PATH = "user://caught_fish.json"

# Categories of fish (lake, ocean, and rain).
const FISH_CATEGORIES = ["lake", "ocean", "rain"]

# Called when the node is ready (i.e., after the scene is loaded).
func _ready():
    # Print a message when the script is loaded.
    print("[SAVEMYFISH] SaveMyFish loaded.")
    
    # Connect to a signal from PlayerData that triggers when the journal is updated.
    if PlayerData.has_signal("_journal_update"):
        PlayerData.connect("_journal_update", self, "_poll_journal_data")
    
    # Load previously caught fish data.
    _load_caught_fish()

    # Clean up the save file if necessary.
    clean_up_save_file()

# Poll the journal data to update fish caught information.
func _poll_journal_data():
    # Iterate over each fish category.
    for category in FISH_CATEGORIES:
        # If there is data for the current category in the journal logs.
        if PlayerData.journal_logs.has(category):
            var current_fish_data = PlayerData.journal_logs[category]

            # Iterate over each fish entry in the current category's data.
            for fish_id in current_fish_data.keys():
                # Skip invalid fish IDs.
                if not _is_fish_id_valid(fish_id):
                    continue
                
                # If the fish count is greater than zero, process it.
                if current_fish_data[fish_id]["count"] > 0:
                    var is_new_catch = false

                    # Check if the current fish data is newer or different from the previously saved data.
                    if not previous_fish_data.has(fish_id) or current_fish_data[fish_id]["count"] > previous_fish_data[fish_id]["count"]:
                        previous_fish_data[fish_id] = current_fish_data[fish_id]
                        is_new_catch = true

                    # Check and update the fish quality information.
                    var current_qualities = current_fish_data[fish_id]["quality"]
                    var previous_qualities = previous_fish_data[fish_id].get("quality", [])

                    # Add new qualities to the previous data.
                    for quality in current_qualities:
                        if not _list_has(previous_qualities, quality):
                            if not previous_fish_data[fish_id].has("quality"):
                                previous_fish_data[fish_id]["quality"] = []
                            previous_fish_data[fish_id]["quality"].append(quality)
                            is_new_catch = true

                    # Remove duplicate qualities from the previous data.
                    if previous_fish_data[fish_id].has("quality"):
                        previous_fish_data[fish_id]["quality"] = _remove_duplicates(previous_fish_data[fish_id]["quality"])

                    # If new fish data is added or updated, save it.
                    if is_new_catch:
                        save_caught_fish()

# Save the caught fish data to a file.
func save_caught_fish():
    var file = File.new()

    # Open the save file for writing.
    if file.open(SAVE_FILE_PATH, File.WRITE) == OK:
        var filtered_data = {}
        
        # Filter out invalid fish and only store those with a positive count.
        for fish_id in previous_fish_data.keys():
            if not _is_fish_id_valid(fish_id):
                continue

            if previous_fish_data[fish_id]["count"] > 0:
                filtered_data[fish_id] = previous_fish_data[fish_id]

        # Write the filtered data to the save file.
        file.store_string(to_json(filtered_data))
        file.close()

# Load the previously saved fish data from a file.
func _load_caught_fish():
    var file = File.new()

    # If the save file exists, read it.
    if file.file_exists(SAVE_FILE_PATH):
        if file.open(SAVE_FILE_PATH, File.READ) == OK:
            var data = file.get_as_text()
            previous_fish_data = parse_json(data)
            file.close()

            # Wait briefly before processing the loaded data.
            yield(get_tree().create_timer(4), "timeout")

            # Process each fish ID in the previously loaded data.
            for fish_id in previous_fish_data.keys():
                if not _is_fish_id_valid(fish_id):
                    print("[SAVEMYFISH] Skipping invalid fish ID during load:", fish_id)
                    continue

                var fish_data = previous_fish_data[fish_id]
                var category = _get_fish_category(fish_id)

                # If the fish category is unknown, assign it to "modded".
                if not category:
                    category = "modded"

                    # If the category doesn't exist in the journal, create it.
                    if not PlayerData.journal_logs.has(category):
                        PlayerData.journal_logs[category] = {}

                    # If the fish ID doesn't exist in the category, create a new entry.
                    if not PlayerData.journal_logs[category].has(fish_id):
                        PlayerData.journal_logs[category][fish_id] = {
                            "count": 0,
                            "record": 0.0,
                            "quality": []
                        }

                # Log the fish data to the journal (first-time catch).
                PlayerData._log_item(fish_id, fish_data["record"], 0, true)

                # Log the fish quality data.
                for quality in fish_data["quality"]:
                    PlayerData._log_item(fish_id, fish_data["record"], quality, false)

# Clean up the save file by removing duplicates in the stored fish quality data.
func clean_up_save_file():
    var file = File.new()

    # If the save file exists, read it.
    if file.file_exists(SAVE_FILE_PATH):
        if file.open(SAVE_FILE_PATH, File.READ) == OK:
            var data = parse_json(file.get_as_text())
            file.close()

            # If data exists, clean up the fish quality data.
            if data:
                var cleaned_data = {}
                for fish_id in data.keys():
                    var fish_data = data[fish_id]
                    
                    # Remove duplicates in the quality list.
                    if fish_data.has("quality"):
                        fish_data["quality"] = _remove_duplicates(fish_data["quality"])

                    cleaned_data[fish_id] = fish_data

                # Rewrite the cleaned data to the save file.
                file.open(SAVE_FILE_PATH, File.WRITE)
                file.store_string(to_json(cleaned_data))
                file.close()
                print("[SAVEMYFISH] Save file cleaned and re-saved:")

# Helper function to get the category of a fish based on its ID.
func _get_fish_category(fish_id):
    if Globals.item_data.has(fish_id):
        return Globals.item_data[fish_id]["file"].loot_table
    return null

# Helper function to check if the fish ID is valid.
func _is_fish_id_valid(fish_id):
    return Globals.item_data.has(fish_id)

# Helper function to check if a list contains a specific value.
func _list_has(list, value):
    for item in list:
        if item == value:
            return true
    return false

# Helper function to remove duplicates from a list.
func _remove_duplicates(list):
    var unique_list = []
    for item in list:
        if not _list_has(unique_list, item):
            unique_list.append(item)
    return unique_list
