extends CharacterBody2D

const bounce_damping := 0.6
const damage := 200

var GRAV: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var dir := Vector2.RIGHT
var speed := 0

@onready var sprite: Sprite2D = %Sprite
@onready var lifetime: Timer = %Lifetime

func _ready():
	lifetime.timeout.connect(_on_life_timer_timeout) 
	lifetime.start()
	velocity = dir * speed

func _physics_process(delta: float) -> void:
	velocity.y += GRAV * delta
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		velocity *= bounce_damping

func explode() -> void:
	queue_free()

func _on_life_timer_timeout():
	explode()
