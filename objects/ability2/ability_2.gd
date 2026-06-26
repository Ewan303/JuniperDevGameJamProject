extends CharacterBody2D

const damage := 40
const boost_v := 550.0
const knockback_x := 100.0
const knockback_y := 400

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D

func setup( p: CharacterBody2D, pos: Vector2) -> void:
	self.global_position = pos
	p.velocity.y = -(boost_v)

func _ready() -> void:
	sprite.play("default")
	sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
