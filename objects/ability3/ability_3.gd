extends CharacterBody2D

enum STATE { THROW, PEAK, RETURN }
var current_state := STATE.THROW

var dir := Vector2.RIGHT
var speed := 0.0
var max_speed := 0.0
var acceleration := 1200.0
var return_acceleration := 1800.0
var rotation_speed := 0.0
var player: CharacterBody2D = null

const damage := 100

# New variable to remember the original movement direction sign
var velocity_sign := 1.0

@onready var sprite: Sprite2D = %Sprite
@onready var lifetime: Timer = %Lifetime

func setup(facingDir: float, x: float, p: CharacterBody2D, pos: Vector2) -> void:
	sprite = %Sprite 
	
	if facingDir > 0:
		sprite.flip_h = false
		max_speed = clamp(400 * clamp(1 + x/ 50, 0, 5), 0, 1000)
		rotation_speed = clamp(4 * clamp(1 + x / 50, 0, 5), 0, 16)
	else:
		sprite.flip_h = true
		max_speed = clamp(400 * clamp(-1 + x / 50, -5, 0), -1000, 0)
		rotation_speed = clamp(4 * clamp(-1 + x / 50, -5, 0), -16, 0)
	
	speed = max_speed
	player = p
	self.global_position = pos


func _ready():
	lifetime.timeout.connect(_on_life_timer_timeout)
	lifetime.start()
	
	# Determine if speed is negative and remember its sign
	velocity_sign = signf(speed)
	if velocity_sign == 0:
		velocity_sign = 1.0 # Prevent multiplication by zero
		
	# Ensure direction vector is normalized
	dir = dir.normalized()
	velocity = dir * speed

func _physics_process(delta: float) -> void:
	if sprite:
		sprite.rotation += rotation_speed * delta
		
	match current_state:
		STATE.THROW:
			process_throw(delta)
		STATE.PEAK:
			process_peak(delta)
		STATE.RETURN:
			process_return(delta)

func process_throw(delta: float) -> void:
	# Smoothly decelerate toward 0.0, handling both positive and negative initial speeds
	speed = move_toward(speed, 0.0, acceleration * delta)
	velocity = dir * speed
	
	move_and_slide()
	
	# Transition to peak when speed gets close to zero or hits a wall
	if abs(speed) <= 10.0 or is_on_wall():
		current_state = STATE.PEAK

func process_peak(delta: float) -> void:
	# Zero out velocity briefly for a weightless, floaty apex feel
	velocity = Vector2.ZERO
	speed = 0.0
	current_state = STATE.RETURN

func process_return(delta: float) -> void:
	if not player:
		queue_free()
		return
		
	# Smoothly accelerate back toward the player's moving position
	var target_dir = global_position.direction_to(player.global_position)
	
	# Speed magnitude must become completely absolute/positive during the return phase
	var target_max_speed = abs(max_speed) * 1.2
	speed = move_toward(speed, target_max_speed, return_acceleration * delta)
	
	# Interpolate velocity vector for a smooth, curved homing path
	velocity = velocity.lerp(target_dir * speed, 10.0 * delta)
	move_and_slide()
	
	# Check distance to catch instead of physical collision (prevents jitter)
	if global_position.distance_to(player.global_position) <= 20.0:
		queue_free()

func _on_life_timer_timeout():
	queue_free()
