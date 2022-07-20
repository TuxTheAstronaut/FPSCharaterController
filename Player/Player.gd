extends KinematicBody

###################-VARIABLES-####################

# Camera
export(float) var mouse_sensitivity = 10
export(NodePath) var head_path = "Head"
export(NodePath) var cam_path = "Head/Camera"
export(NodePath) var collision_path = "Collision"
export(NodePath) var collision_ray_path = "CollisionRay"
export(float) var FOV = 80.0
var mouse_axis := Vector2()
var camera_roll := 0.5
onready var head: Spatial = get_node(head_path)
onready var cam: Camera = get_node(cam_path)
onready var collision: CollisionShape = get_node(collision_path)
onready var collision_ray: RayCast = get_node(collision_ray_path)
# Move
export(Vector3) var velocity := Vector3()
var localVelocity := Vector3()
var direction := Vector3()
var move_axis := Vector2()
var snap := Vector3()
var fallVelocity : int
var sprint_enabled := true
var sprinting := false
var crouching := false
# Walk
const FLOOR_MAX_ANGLE: float = deg2rad(46.0)
var gravity = 30.0
var walk_speed = 8
var sprint_speed = 12
export(int) var acceleration = 8
export(int) var deacceleration = 10
export(float, 0.0, 1.0, 0.05) var air_control = 3
var jump_height = 10
var _speed: int
var _is_sprinting_input := false
var _is_jumping_input := false

# Movment input
func _process(_delta: float) -> void:
	move_axis.x = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	move_axis.y = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	if Input.is_action_just_pressed("move_jump"):
		_is_jumping_input = true
	
	if Input.is_action_pressed("move_sprint"):
		_is_sprinting_input = true
		

# Called when there is an input event
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_axis = event.relative
		camera_rotation()
	
	if event.is_action_pressed("move_crouch"):
		crouch()

# Determins the direction vector based on the input and player rotation
func direction_input() -> void:
	direction = Vector3()
	var aim: Basis = get_global_transform().basis
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
		
		snap = -get_floor_normal() - get_floor_velocity() * delta
		
		# Workaround for sliding down after jump on slope
		if velocity.y < 0:
			velocity.y = 0
		
		jump()
	else:
		# Workaround for 'vertical bump' when going off platform
		if snap != Vector3.ZERO && velocity.y != 0:
			velocity.y = 0
		
		if is_on_wall() and move_axis.x > 0 and sprinting:
			if camera_roll == 0.5 and not crouching and can_wallrun():
				velocity += get_slide_collision(0).normal * 5
				velocity += -global_transform.basis.z * sprint_speed
				velocity.y = jump_height
		
		
		snap = Vector3.ZERO
		
		velocity.y -= gravity * delta
		fallVelocity = velocity.y
	
	sprint(delta)
	
	accelerate(delta)
	
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, FLOOR_MAX_ANGLE, false)
	_is_jumping_input = false
	_is_sprinting_input = false
	localVelocity = cam.to_local(translation + velocity)
	
	cam.rotation.z = lerp(cam.rotation.z,-localVelocity.x/125,camera_roll)
	cam.rotation.x = lerp(cam.rotation.x,localVelocity.z/150,camera_roll)

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
	_temp_vel = _temp_vel.linear_interpolate(_target, _temp_accel * delta)
	
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
		
		rotate_y(deg2rad(horizontal))
		head.rotate_x(deg2rad(vertical))
		
		# Clamp mouse rotation
		var temp_rot: Vector3 = head.rotation_degrees
		temp_rot.x = clamp(temp_rot.x, -89, 89)
		head.rotation_degrees = temp_rot

# sets the camera roll interpolation value
func set_cam_roll(value):
	camera_roll = value

# handels player jumpint
func jump() -> void:
	if _is_jumping_input:
		velocity.y = jump_height
		snap = Vector3.ZERO

# changes speed camera and collision height for crouching and uncrouching
func crouch():
	if crouching:
		if collision_ray.is_colliding(): return
		collision.shape.height = 1.1
		collision.translation.y = 0
		collision_ray.cast_to = Vector3(1,0,0)
		$Tween.interpolate_property(head, "translation:y", 0,0.6,0.1)
		$Tween.start()
		crouching = false
		walk_speed = walk_speed*2
	else:
		collision.shape.height = 0.55
		collision.translation.y = -0.275
		collision_ray.cast_to = Vector3(0,1.051,0)
		$Tween.interpolate_property(head, "translation:y", 0.6,0,0.1)
		$Tween.start()
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
		camera_roll = 0.1
		$Tween.interpolate_property(cam, "rotation:z", cam.rotation.z,deg2rad(20*collision_ray.cast_to.x),0.13)
		$Tween.interpolate_method(self, "set_cam_roll", camera_roll, 0.5, 1)
		$Tween.start()
		return true
	collision_ray.cast_to.x *= -1
	return false
