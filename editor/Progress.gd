extends Window


func _ready() -> void:
	Status.task_changed.connect(set_status_label)
	Status.new_error.connect(add_error)
	Status.new_warning.connect(add_error)


func set_status_label(task: String) -> void:
	%StatusLabel.text = task


func add_error(error: String) -> void:
	%Errors.text += error + "\n"


func show_close_button() -> void:
	%ButtonArea.show()


func _on_close_button_pressed() -> void:
	queue_free()
