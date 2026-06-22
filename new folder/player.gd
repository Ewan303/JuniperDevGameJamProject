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
const FALL_V := 700.0
const WALK_V := 300.0
const JUMP_V := 550.0
const DASH_V := 600.0
const WALLSLIDE_V := 500.0
const WALLJUMP_V := 400.0

# Other constants
const JUMP_D := 1000.0
const DASH_LEN := 200.0
const WALLJUMP_LEN := 40.0

# Variables
var activeState := PLAYERSTATE.FALL
var savedPosition := Vector2.ZERO
var facingDir := 1.0
var canDash := false
var dashJumpBuffer := false
var GRAV: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var WALLSLIDE_GRAV: float = (ProjectSettings.get_setting("physics/2d/default_gravity"))/2.5


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
		PLAYERSTATE.WALLSLIDE:
			sprite.play("wallslide")
			velocity.y = 0
		PLAYERSTATE.WALLJUMP:
			sprite.play("jump")
			velocity.y = -(WALLJUMP_V)
			set_facing_direction(-facingDir)
			savedPosition = position
func process_state(delta: float) -> void:
	match activeState:
		PLAYERSTATE.FALL:
			velocity.y = move_toward(velocity.y,FALL_V,GRAV * delta)
			movement()
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and airjumptimer.time_left > 0:
				switch_state(PLAYERSTATE.JUMP)
			elif is_input_toward_facing() and can_wall_slide():
				switch_state(PLAYERSTATE.WALLSLIDE)
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
		PLAYERSTATE.JUMP, PLAYERSTATE.WALLJUMP:
			velocity.y = move_toward(velocity.y,0,JUMP_D * delta)
			if activeState == PLAYERSTATE.WALLJUMP:
				var dist := absf(position.x - savedPosition.x)
				if dist >= WALLJUMP_LEN or can_wall_slide():
					activeState = PLAYERSTATE.JUMP
				else:
					movement(facingDir)
			
			if activeState != PLAYERSTATE.WALLJUMP:
				movement()
			if Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(PLAYERSTATE.FALL)
		PLAYERSTATE.WALLSLIDE:
			velocity.y = move_toward(velocity.y,WALLSLIDE_V,WALLSLIDE_GRAV * delta)
			movement()
			
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif not can_wall_slide():
				switch_state(PLAYERSTATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(PLAYERSTATE.WALLJUMP)
# Movement of player character
func movement(inputDir: float = 0) -> void:
	if inputDir == 0:
		inputDir = signf(Input.get_axis("move_left","move_right"))
	set_facing_direction(inputDir)
	velocity.x = inputDir * WALK_V

func set_facing_direction(dir: float) -> void:
	if dir:
		sprite.flip_h = (0 > dir)
		facingDir = dir
		rayWallSlide.position.x = dir * absf(rayWallSlide.position.x)
		rayWallSlide.target_position.x = dir * absf(rayWallSlide.target_position.x)
		rayWallSlide.force_raycast_update()

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left","move_right")) == facingDir

func can_wall_slide() -> bool:
	return is_on_wall_only() and rayWallSlide.is_colliding()
