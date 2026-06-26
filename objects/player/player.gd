extends CharacterBody2D
class_name Player

# ==============================================================================
# 1. SIGNALS & ENUMS
# ==============================================================================

enum PLAYERSTATE {
	FLOOR,
	FALL,
	JUMP,
	WALLSLIDE,
	WALLJUMP,
	PUNCH,
	ABILITYONE,
	ABILITYTWO,
	ABILITYTHREE,
	ABILITYFOUR
}

# ==============================================================================
# 2. @ONREADY VARIABLES
# ==============================================================================

@onready var sprite: AnimatedSprite2D = %AnimatedSprite
@onready var airjumptimer: Timer = %AirJumpTimer
@onready var rayWallSlide: RayCast2D = %RayWallSlide
@onready var targetCamera: Node2D = %TargetCamera
@onready var cameraMain: Camera2D = %CameraMain
@onready var abilities: Node2D = %Abilities
@onready var cooldown_ability: Timer = %CooldownAbility

@onready var ability_2: Node2D = %ability2
@onready var ability_3: Node2D = %ability3
@onready var ability_4: Node2D = %ability4

# ==============================================================================
# 3. CONSTANTS
# ==============================================================================

# Velocities
const FALL_V := 700.0
const WALK_V := 250.0
const JUMP_V := 550.0
const DASH_V := 625.0
const WALLSLIDE_V := 500.0
const WALLJUMP_V := 550.0

# Movement distances & modifiers
const JUMP_D := 1000.0
const DASH_LEN := 200.0
const WALLJUMP_LEN := 30.0

# Ability Configuration
const ABILITY3_PROJ := preload("res://objects/ability3/ability3.tscn")
const ABILITY4_PROJ := preload("res://objects/ability4/ability4.tscn")
const ABILITY_POOL := [PLAYERSTATE.ABILITYONE,PLAYERSTATE.ABILITYTHREE, PLAYERSTATE.ABILITYFOUR]

# ==============================================================================
# 4. STATE & GAMEPLAY VARIABLES
# ==============================================================================

var activeState := PLAYERSTATE.FALL
var savedPosition := Vector2.ZERO
var facingDir := 1.0

var canDash := false
var dashJumpBuffer := false
var canUseAbility := true

var currentAbility: PLAYERSTATE = PLAYERSTATE.ABILITYONE
var nextAbility: PLAYERSTATE = choose_next_ability()

# Physics Constants
var GRAV: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var WALLSLIDE_GRAV: float = (ProjectSettings.get_setting("physics/2d/default_gravity")) / 4

# Stats
const MAX_HP := 100
var hp := 1000000

# ==============================================================================
# 5. BUILT-IN ENGINE FUNCTIONS
# ==============================================================================

func _ready() -> void:
	# Connect signals safely
	sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	cooldown_ability.timeout.connect(_on_cooldown_ability_timeout)
	
	switch_state(activeState)

func _physics_process(delta: float) -> void:
	process_state(delta)
	move_and_slide()

# ==============================================================================
# 6. STATE MACHINE: SWITCHING & LOGIC
# ==============================================================================

func switch_state(new_state: PLAYERSTATE) -> void:
	var prevState := activeState
	activeState = new_state
	
	match activeState:
		PLAYERSTATE.FALL:
			sprite.play("fall")
			if prevState == PLAYERSTATE.FLOOR:
				airjumptimer.start()
			
		PLAYERSTATE.FLOOR:
			canDash = true
			
		PLAYERSTATE.JUMP:
			sprite.play("jump")
			velocity.y = -JUMP_V
			airjumptimer.stop()
			
		PLAYERSTATE.WALLSLIDE:
			sprite.play("wallslide")
			velocity.y = 0
			canDash = true
			
		PLAYERSTATE.WALLJUMP:
			sprite.play("jump")
			velocity.y = -WALLJUMP_V
			set_facing_direction(-facingDir)
			savedPosition = position
			
		PLAYERSTATE.ABILITYONE:
			sprite.play("dashstart")
			velocity.y = 0
			
			var dash_input := signf(Input.get_axis("move_left", "move_right"))
			if dash_input != 0:
				set_facing_direction(dash_input)
				
			velocity.x = facingDir * DASH_V
			savedPosition = position
			
			# Consume dash charge immediately upon use
			canDash = false 
			dashJumpBuffer = false
			
		PLAYERSTATE.ABILITYTHREE:
			if prevState == PLAYERSTATE.FLOOR:
				sprite.play("throwstand")
			elif prevState == PLAYERSTATE.FALL or prevState == PLAYERSTATE.JUMP:
				sprite.play("throwair")
			
			# Instantiate and throw projectile
			var b = ABILITY3_PROJ.instantiate()
			b.global_position = ability_3.global_position
			
			if facingDir > 0:
				b.max_speed = clamp(400 * clamp(1 + velocity.x / 50, 0, 5), 0, 1000)
				b.rotation_speed = clamp(4 * clamp(1 + velocity.x / 50, 0, 5), 0, 16)
			else:
				b.max_speed = clamp(400 * clamp(-1 + velocity.x / 50, -5, 0), -1000, 0)
				b.rotation_speed = clamp(4 * clamp(-1 + velocity.x / 50, -5, 0), -16, 0)
			print(b.max_speed)
			b.speed = b.max_speed
			b.player = self
			
			get_tree().current_scene.add_child(b)
		PLAYERSTATE.ABILITYFOUR:
			if prevState == PLAYERSTATE.FLOOR:
				sprite.play("throwstand")
			elif prevState == PLAYERSTATE.FALL or prevState == PLAYERSTATE.JUMP:
				sprite.play("throwair")
			
			# Instantiate and throw projectile
			var b = ABILITY4_PROJ.instantiate()
			b.global_position = ability_4.global_position
			
			if facingDir > 0:
				b.speed = clamp(200 * clamp(1 + velocity.x / 50, 0, 5), 0, 800)
			else:
				b.speed = clamp(200 * clamp(-1 + velocity.x / 50, -5, 0), -800, 0)
				
			get_tree().current_scene.add_child(b)


func process_state(delta: float) -> void:
	handle_input_and_camera(delta)
	handle_ability_execution()
	
	match activeState:
		PLAYERSTATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_V, GRAV * delta)
			handle_standard_movement()
			
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif Input.is_action_just_pressed("jump") and airjumptimer.time_left > 0:
				switch_state(PLAYERSTATE.JUMP)
			elif is_input_toward_facing() and can_wall_slide():
				switch_state(PLAYERSTATE.WALLSLIDE)
				
		PLAYERSTATE.FLOOR:
			if Input.get_axis("move_left", "move_right"):
				sprite.play("walk")
			else:
				sprite.play("idle")
				
			handle_standard_movement()
			
			if not is_on_floor():
				switch_state(PLAYERSTATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(PLAYERSTATE.JUMP)
				
		PLAYERSTATE.JUMP, PLAYERSTATE.WALLJUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_D * delta)
			
			if activeState == PLAYERSTATE.WALLJUMP:
				var dist := absf(position.x - savedPosition.x)
				if dist >= WALLJUMP_LEN or can_wall_slide():
					switch_state(PLAYERSTATE.JUMP)
				else:
					apply_movement_velocity(facingDir)
			else:
				handle_standard_movement()
			
			if Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(PLAYERSTATE.FALL)
				
		PLAYERSTATE.WALLSLIDE:
			velocity.y = move_toward(velocity.y, WALLSLIDE_V, WALLSLIDE_GRAV * delta)
			handle_standard_movement()
			
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif not can_wall_slide():
				switch_state(PLAYERSTATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(PLAYERSTATE.WALLJUMP)
			
		PLAYERSTATE.ABILITYONE:
			if is_on_floor():
				airjumptimer.start()
			if Input.is_action_just_pressed("jump"):
				dashJumpBuffer = true
				
			var dist := absf(position.x - savedPosition.x)
			if dist >= DASH_LEN or is_on_wall():
				if dashJumpBuffer and airjumptimer.time_left > 0:
					switch_state(PLAYERSTATE.JUMP)
				elif is_on_floor():
					switch_state(PLAYERSTATE.FLOOR)
				else:
					switch_state(PLAYERSTATE.FALL)
			elif can_wall_slide():
				switch_state(PLAYERSTATE.WALLSLIDE)
				
		PLAYERSTATE.ABILITYTWO:
			pass
			
		PLAYERSTATE.ABILITYFOUR, PLAYERSTATE.ABILITYTHREE:
			if is_on_floor():
				switch_state(PLAYERSTATE.FLOOR)
			elif can_wall_slide():
				switch_state(PLAYERSTATE.WALLSLIDE)
			else:
				switch_state(PLAYERSTATE.FALL)

# ==============================================================================
# 7. HELPER FUNCTIONS
# ==============================================================================

func handle_standard_movement() -> void:
	var dir = signf(Input.get_axis("move_left", "move_right"))
	apply_movement_velocity(dir)

func apply_movement_velocity(inputDir: float) -> void:
	if inputDir != 0:
		set_facing_direction(inputDir)
	velocity.x = inputDir * WALK_V

func handle_input_and_camera(delta: float) -> void:
	var inputDir = signf(Input.get_axis("move_left", "move_right"))
	
	# Adjust target camera position
	match inputDir:
		0.0: targetCamera.position.x = 0.0
		-1.0: targetCamera.position.x = -100.0
		1.0: targetCamera.position.x = 100.0
	
	# Smooth camera
	cameraMain.position = cameraMain.position.lerp(targetCamera.global_position, 7 * delta)

func handle_ability_execution() -> void:
	if Input.is_action_just_pressed("ability") and hp > 10 and canUseAbility:
		if _try_execute_ability():
			canUseAbility = false
			hp -= 10
			cooldown_ability.start() # Start ability cooldown upon activation

func set_facing_direction(dir: float) -> void:
	if dir == 0: return
	
	sprite.flip_h = (dir < 0)
	abilities.scale.x = dir
	facingDir = dir
	
	rayWallSlide.position.x = dir * absf(rayWallSlide.position.x)
	rayWallSlide.target_position.x = dir * absf(rayWallSlide.target_position.x)
	rayWallSlide.force_raycast_update()

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facingDir

func can_wall_slide() -> bool:
	return is_on_wall_only() and rayWallSlide.is_colliding()

func choose_next_ability() -> PLAYERSTATE:
	var available = ABILITY_POOL.duplicate()
	available.erase(currentAbility)
	return available.pick_random() as PLAYERSTATE

func _try_execute_ability() -> bool:
	var executed := false
	
	match currentAbility:
		PLAYERSTATE.ABILITYONE:
			if canDash:
				switch_state(PLAYERSTATE.ABILITYONE)
				executed = true
		PLAYERSTATE.ABILITYTWO, PLAYERSTATE.ABILITYTHREE, PLAYERSTATE.ABILITYFOUR:
			switch_state(currentAbility)
			executed = true
		
	if executed:
		currentAbility = nextAbility
		nextAbility = choose_next_ability()
		
	return executed

# ==============================================================================
# 8. SIGNAL CALLBACKS
# ==============================================================================

func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == "dashstart":
		sprite.play("dash")

func _on_cooldown_ability_timeout() -> void:
	print("Cooldown of ability refreshed!")
	canUseAbility = true
