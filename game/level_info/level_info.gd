class_name LevelInfo
extends Resource

@export var display_name: String = "NONE"
@export var scene: PackedScene
## Optional maximum times for one, two, and three stars (fastest).
@export var star_1_time: float = -1.0
@export var star_2_time: float = -1.0
@export var star_3_time: float = -1.0


## Identity comes from this saved resource, not its display name or level scene.
func get_uid() -> int:
	if resource_path.is_empty() or resource_path.contains("::"):
		return ResourceUID.INVALID_ID
	return ResourceLoader.get_resource_uid(resource_path)


func get_stars(best_time: float) -> int:
	if best_time < 0.0:
		return 0
	if star_3_time >= 0.0 and best_time <= star_3_time:
		return 3
	if star_2_time >= 0.0 and best_time <= star_2_time:
		return 2
	if star_1_time >= 0.0 and best_time <= star_1_time:
		return 1
	return 0


## The next configured reward above the stars earned on this run.
## A negative result means there is no higher configured star to earn.
func get_next_star_time(completion_time: float) -> float:
	var thresholds: Array[float] = [star_1_time, star_2_time, star_3_time]
	for index in range(get_stars(completion_time), thresholds.size()):
		if thresholds[index] >= 0.0:
			return thresholds[index]
	return -1.0
