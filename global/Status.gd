extends Node

signal task_changed
signal new_warning
signal new_error

var task := ""
var warnings := []
var errors := []

var mutex := Mutex.new()

func reset() -> void:
	task = ""
	warnings.clear()
	errors.clear()


func is_busy() -> bool:
	return not task.is_empty()


func set_task(next_task: String) -> void:
	task = next_task
	task_changed.emit.call_deferred(task)


func add_warning(warning: String) -> void:
	var collated := "Warning (%s): %s" % [task, warning]
	warnings.push_back(collated)
	new_warning.emit(collated)


func add_error(error: String) -> void:
	var collated := "Error (%s): %s" % [task, error]
	errors.push_back(collated)
	new_error.emit(collated)
