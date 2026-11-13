class_name LevelManager
extends Resource

## The array order is the order used by level select.
@export var levels: Array[LevelInfo] = []


func get_level(level_uid: int) -> LevelInfo:
	if level_uid < 0:
		return null
	for info in levels:
		if info != null and info.get_uid() == level_uid:
			return info
	return null


func get_available_levels() -> Array[LevelInfo]:
	var available: Array[LevelInfo] = []
	var seen_uids: Dictionary = {}
	for info in levels:
		if info == null:
			continue
		var uid := info.get_uid()
		if uid == ResourceUID.INVALID_ID or info.scene == null:
			push_warning("Skipping a level without a saved LevelInfo resource UID or scene.")
			continue
		if seen_uids.has(uid):
			push_warning("Skipping duplicate LevelInfo resource: " + ResourceUID.id_to_text(uid))
			continue
		seen_uids[uid] = true
		available.append(info)
	return available


func get_next_level(level_uid: int) -> LevelInfo:
	var available := get_available_levels()
	for index in range(available.size() - 1):
		if available[index].get_uid() == level_uid:
			return available[index + 1]
	return null
