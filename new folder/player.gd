extends CharacterBody2D

# Player states

enum PLAYERSTATE {
	FLOOR,
	FALL,
	JUMP,
	DASH,
	WALLSLIDE,
	WALLJUMP
}

@onready var sprite: AnimatedSprite2D = %AnimatedSprite
@onready var airjumptimer: Timer = %AirJumpTimer
@onready var cooldownDash: Timer = %CooldownDash
@onready var rayWallSlide: RayCast2D = %RayWallSlide


# Constant velocities
const FALL_V := 500.0
const WALK_V := 200.0
const JUMP_V := 500.0
const DASH_V = 600.0
const WALLSLIDE_V = 500.0

# Other constants
const JUMP_D := 1000.0
const DASH_LEN = 200.0

# Variables
var activeState := PLAYERSTATE.FALL
var facingDir := 1.0
var canDash := false
var dashJumpBuffer := false
var GRAV: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var WALLSLIDE_GRAV: float = (ProjectSettings.get_setting("physics/2d/default_gravity"))/2


# Update character with func _physics_process and _ready
func _ready() -> void:
	switch_state(activeState)

func _physics_process(delta: float) -> void:
	print(activeState)
	process_state(delta)
	move_and_slide()

# Switching states
func switch_state(state: PLAYERSTATE) -> void:
	var prevState := activeState
	activeState = state
	
	# Run only once upon entering new state 
	match activeState:
		PLAYERSTATE.FALL:
			sprite.play("fall")
			if prevState == PLAYERSTATE.FLOOR:
				airjumptimer.start()
		PLAYERSTATE.FLOOR:
			canDash = true
		PLAYERSTATE.JUMP:
			sprite.play("jump")
			velocity.y = -(JUMP_V)
			airjumptimer.stop()
		PLAYERSTATE.DASH:
			if cooldownDash.time_left > 0:
				activeState = prevState
				return
			sprite.play("dash")
			velocity.y = 0

func process_state(delta: float) -> void:
	match activeState:
		PLAYERSTATE.FALL:
			velocity.y = move_toward(velocity.y,FALL_V,GRAV * delta)
			movement()
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and airjumptimer.time_left > 0:
				switch_state(PLAYERSTATE.JUMP)

		PLAYERSTATE.FLOOR:
			if Input.get_axis("move_left","move_right"):
				sprite.play("walk")
			else:
				sprite.play("idle")
			movement()
			if not is_on_floor():
				switch_state(PLAYERSTATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(PLAYERSTATE.JUMP)
		PLAYERSTATE.JUMP:
			velocity.y = move_toward(velocity.y,0,JUMP_D * delta)
			movement()
			
			if Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(PLAYERSTATE.FALL)
# Movement of player character
func movement() -> void:
	var inputDir := signf(Input.get_axis("move_left","move_right"))
	if inputDir:
		sprite.flip_h = (0 > inputDir)
		facingDir = inputDir
		rayWallSlide.position.x = inputDir * absf(rayWallSlide.position.x)
		rayWallSlide.target_position.x = inputDir * absf(rayWallSlide.target_position.x)
		rayWallSlide
	velocity.x = inputDir * WALK_V

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left","move_right")) == facingDir
