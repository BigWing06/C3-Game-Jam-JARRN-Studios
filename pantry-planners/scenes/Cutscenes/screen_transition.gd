extends CanvasLayer

@onready var anim = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func fade_out():
	print("Fade out")
	anim.play("fade_out")
	await anim.animation_finished

func fade_in():
	print("Fade in")
	anim.play("fade_in")
	await anim.animation_finished
