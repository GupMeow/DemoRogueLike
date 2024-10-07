extends CharacterBody3D

# Player nodes

@onready var head: Node3D = $head
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var head_collision_cast: RayCast3D = $head_collision_cast
@onready var ground_collision_cast: RayCast3D = $ground_collision_cast

# Physics

var slide_velo = Vector3()

var slope_angle = 0

const terminal_Velo = 50

# Speed vars

var previous_y_position: float


var speed_current = 0

const sprinting_speed = 15.0
const crouching_speed = 10.0
const walking_speed = 12.0

# Acceleration/Deceleration

var slide_acc = 5

var dec = 1

var speed_target = 200

# Movement vars

var jump_velocity = 4.5
var crouching_depth = -0.5
var lerp_speed = 10.0

# Input vars

var direction = Vector3.ZERO
const mouse_sens = 0.3


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	previous_y_position = global_transform.origin.y
	
func _input(event):
	
	# Mouse looking logic
	
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
# Changes velocity to zero when past a certain threshold
func snap_to_zero(value):
	if abs(value) < 0.01:
		return 0.0
	return value

# Allow for speeding up on slopes when sliding	
func slope_physics():
	
	if is_on_floor():
		# Get floor normal
		var floor_normal = get_floor_normal()
		#Get floor angle
		var slope_angle = floor_normal.angle_to(Vector3.UP)
		return slope_angle
	return 0.0
		

func _physics_process(delta: float) -> void:
	
	# Handle movement state
	
	# Crouching
	if Input.is_action_pressed("crouch"):
		speed_current = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta*lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		# Get input direction for crouching
		var input_dir := Input.get_vector("left", "right", "forward", "backward")
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		var slope_angle = slope_physics()
		
		var velocities = get_real_velocity()
		
		if slope_angle > deg_to_rad(10):
			if !direction.length() > 0: # not pressing direction, only crouch
				var x_slope_acceleration = (1 + slope_angle) * velocities[0]
				var z_slope_acceleration = (1 + slope_angle) * velocities[2]
				if velocities[1] < 0:
					velocity.x += x_slope_acceleration * delta
					velocity.z += z_slope_acceleration * delta
				else:
					velocity.x = velocity.x * 0.7 
					velocity.z = velocity.z * 0.7
			
		elif direction.length() > 0 and slope_angle != 0:
			velocity.x = direction.x * speed_current 
			velocity.z = direction.z * speed_current
		else:
			velocity.x = move_toward(velocity.x, 0, dec * delta * 1.5)
			velocity.z = move_toward(velocity.z, 0, dec * delta * 1.5)
		
	# Prevent wall clipping
	elif !head_collision_cast.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta*lerp_speed)

	# Standing
	if Input.is_action_pressed("sprint"):
		# Sprinting
		speed_current = sprinting_speed
	elif Input.is_action_pressed("backward") || Input.is_action_pressed("forward") || Input.is_action_pressed("right") || Input.is_action_pressed("left"):
		# Walking
		speed_current = walking_speed
	# Movement when standing
	if direction.length() > 0 and !Input.is_action_pressed("crouch"):
		velocity.x = direction.x * speed_current
		velocity.z = direction.z * speed_current
	else:
		# Exponentially decelerate when crouching and not pressing any input
		velocity.x = move_toward(velocity.x, 0, dec * delta * 4)
		velocity.z = move_toward(velocity.z, 0, dec * delta * 4)
		
	# Stop the super low decimals
	velocity.x = snap_to_zero(velocity.x)
	velocity.z = snap_to_zero(velocity.z)
			
			
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*lerp_speed)

	move_and_slide()
