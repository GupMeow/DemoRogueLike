extends CharacterBody3D

# Player nodes

@onready var head: Node3D = $head
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var head_collision_cast: RayCast3D = $head_collision_cast
@onready var ground_collision_cast: RayCast3D = $ground_collision_cast
@onready var slanted_wall: CSGBox3D = $"../stage/Slanted Wall"

# Physics

var slope_angle = 0

const terminal_velo = 50

var nudge = Vector3.ZERO

var crouch_velo = Vector3.ZERO

# Speed vars

var previous_y_position: float

var speed_current = 0

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
	
	var velocities = get_real_velocity()
	# Get input direction
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	
	var button_state := Input.get_vector("left", "right", "forward", "backward")

	var target_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var acceleration_speed = 10.0  # Faster acceleration value that is adjustable
	direction = direction.lerp(target_dir, acceleration_speed * delta)
	
	var floor_normal = get_floor_normal()
	
		# Walking
				
	# Crouching logic
	if Input.is_action_pressed("crouch"):
		
		var collided_node = null
	# Ground collision cast to check if the player is grounded

		# Perform the cast
		ground_collision_cast.force_raycast_update() # Ensure the ray is updated before checking for collisions
		
		if ground_collision_cast.is_colliding():
			collided_node = ground_collision_cast.get_collider()
			
		
		speed_current = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta*lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		

		var slope_angle = slope_physics()
		
		if slope_angle > deg_to_rad(10):
			if collided_node != null:
				print("Collided with:", collided_node) # not pressing direction, only crouch
				var slope_accel = collided_node.transform.basis.x * (rad_to_deg(slope_angle))
				var max_velocity = terminal_velo * collided_node.transform.basis.x
				velocity += slope_accel * delta
				velocity = crouch_velo.min(max_velocity)
				#var x_slope_acceleration = (1 + slope_angle) * velocities[0]
				#var z_slope_acceleration = (1 + slope_angle) * velocities[2]
				#velocity.x += x_slope_acceleration * delta
				#velocity.z += z_slope_acceleration * delta
		else:
			velocity.x = move_toward(velocity.x, 0, dec * delta * 2.5)
			velocity.z = move_toward(velocity.z, 0, dec * delta * 2.5)
		
	# Prevent wall clipping
	elif !head_collision_cast.is_colliding():
		
		# Standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta*lerp_speed)
		
			
	#print(slope_angle) THIS IS PRINTING ZEROOOOOO!!!!! # Update walking speed
	if !Input.is_action_pressed("crouch"):
		speed_current = walking_speed
		if slope_angle > deg_to_rad(10):
			var x_slope_acceleration = (1 + slope_angle) * velocities[0]
			var z_slope_acceleration = (1 + slope_angle) * velocities[2]
			
			velocity.x = direction.x * (speed_current * x_slope_acceleration)
			velocity.z = direction.z * (speed_current * z_slope_acceleration)
		else:
			velocity.x = direction.x * speed_current
			velocity.z = direction.z * speed_current

	elif !direction.length() > 0 and slope_angle < deg_to_rad(10):
		## Exponentially decelerate when walk ends, but only if this isnt a slope anymore
		velocity.x = move_toward(velocity.x, 0, dec * delta * 10)
		velocity.z = move_toward(velocity.z, 0, dec * delta * 10)
		
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

	move_and_slide()
