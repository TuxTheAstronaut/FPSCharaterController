extends CharacterBody3D

###################-VARIABLES-####################

# Camera3D
@export var mouse_sensitivity: float = 16
@export var FOV: float = 90.0
var mouse_axis := Vector2()
var camera_roll := 0.5
@onready var ctrl_axis: = get_node("%ControlAxis")
@onready var head: Node3D = get_node("%Head")
@onready var cam: Camera3D = get_node("%Camera3D")
@onready var collision: CollisionShape3D = get_node("%Collision")
@onready var collision_ray: RayCast3D = get_node("%CollisionRay")
# Move
var localVelocity := Vector3()
var direction := Vector3()
var move_axis := Vector2()
var sprint_enabled := true
var sprinting := false
var crouching := false
# Walk
@export var gravity = 30.0
@export var walk_speed = 8
@export var sprint_speed = 12
@export var acceleration: int = 8
@export var deacceleration: int = 8
@export var air_control = 3 # (float, 0.0, 1.0, 0.05)
@export var jump_height = 10
var _speed: int
var _is_sprinting_input := false
var _is_jumping_input := false

# Setup
func _ready():
	#ctrl_axis.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)  ! waiting for physics interp to be added to godot 4!
	#ctrl_axis.set_as_top_level(true)
	pass

# Movment input
func _process(_delta: float) -> void:
	move_axis.x = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	move_axis.y = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	if Input.is_action_just_pressed("move_jump"):
		_is_jumping_input = true
	
	if Input.is_action_pressed("move_sprint"):
		_is_sprinting_input = true
	
	#var target = get_global_transform_interpolated().origin   ! waiting for physics interp to be added to godot 4 !
	#ctrl_axis.global_transform.origin = target
	
	cam.rotation.z = clamp(lerp(cam.rotation.z,-localVelocity.x/150,camera_roll),deg_to_rad(-20),deg_to_rad(20))
	cam.rotation.x = clamp(lerp(cam.rotation.x,localVelocity.z/200,camera_roll),deg_to_rad(-20),deg_to_rad(20))

# Called when there is an input event
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_axis = event.relative
		camera_rotation()
	
	if event.is_action_pressed("move_crouch"):
		crouch()

# Determins the direction vector based checked the input and player rotation
func direction_input() -> void:
	direction = Vector3()
	var aim: Basis = ctrl_axis.get_global_transform().basis
	if move_axis.x >= 0.5:
		direction -= aim.z
	if move_axis.x <= -0.5:
		direction += aim.z
	if move_axis.y <= -0.5:
		direction -= aim.x
	if move_axis.y >= 0.5:
		direction += aim.x
	direction.y = 0
	direction = direction.normalized()

# Physics
func _physics_process(delta: float) -> void:
	walk(delta)

# Controls the players walking physics
func walk(delta: float) -> void:
	direction_input()
	
	if is_on_floor():
		
		floor_snap_length = 0.3
		
		# Workaround for sliding down after jump checked slope
		if velocity.y < 0:
			velocity.y = 0
		
		jump()
	else:
		# Workaround for 'vertical bump' when going unchecked platform
		if floor_snap_length != 0.0 && velocity.y != 0:
			velocity.y = 0
		
		if is_on_wall() and move_axis.x > 0 and sprinting:
			if camera_roll == 0.5 and not crouching and can_wallrun():
				velocity += get_slide_collision(0).get_normal() * 8
				velocity += -ctrl_axis.global_transform.basis.z * 18
				velocity.y = jump_height
		
		
		floor_snap_length = 0
		
		velocity.y -= gravity * delta
	
	sprint(delta)
	
	accelerate(delta)
	
	set_velocity(velocity)
	# TODOConverter40 looks that snap in Godot 4.0 is float, not vector like in Godot 3 - previous value `snap`
	set_max_slides(4)
	# TODOConverter40 infinite_inertia were removed in Godot 4.0 - previous value `false`
	move_and_slide()
	velocity = velocity
	_is_jumping_input = false
	_is_sprinting_input = false
	localVelocity = cam.to_local(position + velocity)
	

# Handels players acceleration and deacceleration
func accelerate(delta: float) -> void:
	# Where would the player go
	var _temp_vel: Vector3 = velocity
	var _temp_accel: float
	var _target: Vector3 = direction * _speed
	
	_temp_vel.y = 0
	if direction.dot(_temp_vel) > 0 and is_on_floor():
		_temp_accel = acceleration + velocity.length()
	else:
		_temp_accel = deacceleration
		if not is_on_floor():
			_temp_accel = 0.5 - velocity.length()/2 * delta
	
	_temp_accel = clamp(_temp_accel,0.1,1000)
	
	if not is_on_floor() and direction.length() > 0.0:
		_temp_accel *= air_control
	
	# Interpolation
	_temp_vel = _temp_vel.lerp(_target, _temp_accel * delta)
	
	velocity.x = _temp_vel.x
	velocity.z = _temp_vel.z
	
	# Make too low values zero
	if direction.dot(velocity) == 0:
		var _vel_clamp := 0.01
		if abs(velocity.x) < _vel_clamp:
			velocity.x = 0
		if abs(velocity.z) < _vel_clamp:
			velocity.z = 0

func camera_rotation() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if mouse_axis.length() > 0:
		var horizontal: float = -mouse_axis.x * (mouse_sensitivity / 100.0)
		var vertical: float = -mouse_axis.y * (mouse_sensitivity / 100.0)
		mouse_axis = Vector2()
		
		ctrl_axis.rotate_y(deg_to_rad(horizontal))
		head.rotate_x(deg_to_rad(vertical))
		
		# Clamp mouse rotation
		var temp_rot: Vector3 = head.rotation
		temp_rot.x = clamp(temp_rot.x, deg_to_rad(-89), deg_to_rad(89))
		head.rotation = temp_rot

# sets the camera roll interpolation value
func set_cam_roll(value):
	camera_roll = value

# handels player jumpint
func jump() -> void:
	if _is_jumping_input:
		floor_snap_length = 0
		velocity.y = jump_height

# changes speed camera and collision height for crouching and uncrouching
func crouch():
	var tween = get_tree().create_tween()
	if crouching:
		if collision_ray.is_colliding(): return
		collision.shape.height = 2
		collision.position.y = 0
		collision_ray.target_position = Vector3(1,0,0)
		tween.tween_property(head, "position:y", 0.6,0.1)
		crouching = false
		walk_speed = walk_speed*2
	else:
		collision.shape.height = 1.5
		collision.position.y = -0.25
		collision_ray.target_position = Vector3(0,1.051,0)
		tween.tween_property(head, "position:y", 0,0.1)
		crouching = true
		walk_speed = walk_speed/2

# determins if we can sprint
func can_sprint() -> bool:
	return (sprint_enabled and _is_sprinting_input and not crouching and move_axis.x >= 0.5)

# sets the sprint speed and fov
func sprint(delta: float) -> void:
	if can_sprint():
		_speed = sprint_speed
		cam.set_fov(lerp(cam.fov, FOV * 1.05, delta * 8))
		sprinting = true
		
	else:
		_speed = walk_speed
		cam.set_fov(lerp(cam.fov, FOV, delta * 8))
		sprinting = false

# Handels wallrun/jump camera tilt and movment
func can_wallrun():
	if collision_ray.is_colliding():
		var tween = get_tree().create_tween()
		camera_roll = 0.1
		tween.tween_property(cam, "rotation:z", deg_to_rad(20*collision_ray.target_position.x),0.13)
		tween.tween_method(set_cam_roll, camera_roll, 0.5, 1)
		return true
	collision_ray.target_position.x *= -1
	return false
