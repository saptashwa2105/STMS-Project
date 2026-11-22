extends SceneTree

func _init():
	print("=== Running STMS Simulation Automated Test Suite (v1.3) ===")
	# Load main scene
	var main_scene = load("res://scenes/MainIntersection.tscn").instantiate()
	root.add_child(main_scene)
	
	for i in range(10):
		await process_frame

	var controller = main_scene.get_node("TrafficController")
	var spawner = main_scene.get_node("VehicleSpawner")
	var telem = main_scene.get_node("TelemetryBridge")
	var clear_zone = main_scene.get_node("IntersectionClearZone")

	assert(controller != null, "TrafficController missing!")
	assert(spawner != null, "VehicleSpawner missing!")
	assert(telem != null, "TelemetryBridge missing!")
	assert(clear_zone != null, "IntersectionClearZone Area3D missing!")
	print("✓ Main nodes and IntersectionClearZone successfully instantiated.")

	# 1. Test civilian vehicle spawning with correct forward mesh orientation
	print("Testing vehicle spawning & orientation alignment...")
	var car = spawner.spawn_vehicle("north", "car", false)
	var bike = spawner.spawn_vehicle("east", "motorbike", false)
	var truck = spawner.spawn_vehicle("west", "truck", false)

	for i in range(10):
		await process_frame

	assert(car != null, "Failed to spawn car!")
	assert(bike != null, "Failed to spawn bike!")
	assert(truck != null, "Failed to spawn truck!")

	print("Spawned vehicle rotations -> North Car: ", car.rotation_degrees.y, " East Bike: ", bike.rotation_degrees.y, " West Truck: ", truck.rotation_degrees.y)
	assert(abs(abs(car.rotation_degrees.y) - 180.0) < 0.1, "North vehicle should face South (180 deg)!")
	assert(abs(bike.rotation_degrees.y - 90.0) < 0.1, "East vehicle should face West (90 deg)!")
	assert(abs(truck.rotation_degrees.y - (-90.0)) < 0.1 or abs(truck.rotation_degrees.y - 270.0) < 0.1, "West vehicle should face East (-90 deg)!")
	assert(car.clear_speed > car.max_speed, "Vehicle clear_speed should have sprint boost over max_speed!")
	print("✓ Vehicle orientations & speeds verified.")

	# 2. Test Force-Clear Junction Override
	print("Testing Force-Clear Junction Override...")
	car.is_in_intersection = true
	var eval_spd = car._evaluate_target_speed(0.016)
	assert(eval_spd >= car.clear_speed, "Vehicle inside intersection must sprint at clear_speed!")
	print("✓ Force-Clear Override verified: car inside intersection evaluates to ", eval_spd, " units/s.")
	car.is_in_intersection = false

	# 3. Test Emergency Vehicle Preemption on South lane
	print("Testing Emergency Vehicle Preemption (EVP)...")
	var amb = spawner.spawn_emergency_vehicle("ambulance", "south")
	print("Spawned amb: ", amb, " controller.emergency_active: ", controller.emergency_active, " active_emergency_lane: ", controller.active_emergency_lane, " count: ", controller.active_emergency_vehicles.size())
	assert(amb != null, "Failed to spawn ambulance on South lane!")
	assert(abs(amb.rotation_degrees.y) < 0.1, "South vehicle should face North (0 deg)!")

	assert(controller.emergency_active == true, "Emergency preemption should be active!")
	assert(controller.active_emergency_lane == "south", "Emergency lane mismatch!")
	print("✓ Emergency Preemption activated on [SOUTH] corridor! Phase: ", controller.current_phase)

	# Verify 1.5x speed flush on civilian car in the emergency corridor
	var south_car = spawner.spawn_vehicle("south", "car", false)
	if south_car:
		assert(south_car._is_emergency_flushing_lane() == true, "Civilian car in emergency lane must be in flush mode!")
		var flush_spd = south_car._evaluate_target_speed(0.016)
		assert(flush_spd >= south_car.max_speed * 1.4, "Civilian car ahead of emergency vehicle must receive 1.5x flush speed!")
		print("✓ Emergency lane flushing verified: civilian car receives 1.5x flush speed (", flush_spd, " units/s).")

	# 4. Test Telemetry Bridge dispatch to backend
	print("Testing Telemetry Bridge dispatch to backend...")
	var payload = controller.get_telemetry_payload()
	assert(payload.has("timestamp"), "Missing timestamp in telemetry!")
	assert(payload["emergency_active"] == true, "Telemetry payload emergency state mismatch!")
	assert(payload.has("max_wait_time_seconds"), "Missing max_wait_time_seconds in telemetry!")
	assert(payload.has("anti_starvation_active"), "Missing anti_starvation_active in telemetry!")
	print("✓ Enhanced Telemetry payload verified: ", JSON.stringify(payload))

	# 5. Simulate emergency clearance and Yellow transition
	print("Testing Emergency Clearance & Yellow Transition...")
	amb.has_exited_intersection = true
	controller.on_emergency_exited(amb)
	
	for i in range(10):
		await process_frame

	assert(controller.emergency_active == false, "Emergency preemption should be deactivated after exit!")
	print("✓ Emergency corridor released. Current phase returned to: ", controller.current_phase)

	# 6. Test Anti-Starvation logic trigger
	print("Testing Anti-Starvation tracking...")
	controller.lane_wait_times["east"] = 46.0
	controller.lane_densities["east"] = 2
	var starv_phase = controller._determine_optimal_next_phase("NS_GREEN")
	assert(starv_phase == "EW_GREEN", "Anti-starvation should have prioritized starving EW lane!")
	print("✓ Anti-Starvation override correctly prioritized starving East lane.")

	# 7. Test Dynamic Yellow Box Clearance & Anti-Phantom Bug
	print("Testing Dynamic Yellow Box physical overlap & Anti-Phantom state...")
	car.global_position = Vector3(0, 0.5, 0)
	
	# Wait for physics frames so Area3D registers the overlap
	for i in range(5):
		await physics_frame
	
	var count_in_junction = clear_zone.get_vehicles_count()
	print("Vehicles detected in junction when car is inside: ", count_in_junction)
	assert(count_in_junction >= 1, "IntersectionClearZone must detect car inside yellow box!")
	assert(controller.get_vehicles_count() >= 1, "TrafficController must reflect vehicle inside yellow box!")

	# Simulate sudden despawn/queue_free while inside area
	car.queue_free()

	for i in range(5):
		await physics_frame

	var count_after_despawn = clear_zone.get_vehicles_count()
	print("Vehicles detected in junction after queue_free: ", count_after_despawn)
	assert(count_after_despawn == 0, "IntersectionClearZone must report 0 after vehicle despawns!")
	assert(clear_zone.is_intersection_empty() == true, "clear_zone.is_intersection_empty() must be true!")
	assert(controller.is_intersection_empty() == true, "controller.is_intersection_empty() must be true!")
	assert(controller.get_vehicles_count() == 0, "controller.get_vehicles_count() must be 0!")
	assert(clear_zone.has_conflicting_vehicles("north") == false, "Conflicting vehicles must be false when empty!")
	print("✓ Dynamic Yellow Box check verified: No phantom blockage exists!")

	# 8. Test Simultaneous 4-Way Emergency Dispatch & Mutex Turn-Taking
	print("Testing 4-Way Simultaneous Emergency Dispatch & Mutex Lock...")
	spawner.clear_all_vehicles()
	for i in range(5):
		await physics_frame

	var ft_north = spawner.spawn_vehicle("north", "firetruck", true)
	var ft_south = spawner.spawn_vehicle("south", "firetruck", true)
	var ft_east = spawner.spawn_vehicle("east", "firetruck", true)
	var ft_west = spawner.spawn_vehicle("west", "firetruck", true)

	assert(ft_north != null and ft_south != null and ft_east != null and ft_west != null, "Failed to spawn 4 fire trucks!")
	print("Spawned 4 fire trucks on North, South, East, West.")

	for i in range(5):
		await physics_frame

	assert(controller.emergency_active == true, "Emergency preemption must be active!")
	assert(controller.emergency_queue.size() == 4, "All 4 fire trucks must be queued in emergency_queue!")
	assert(controller.active_emergency_lane == "north", "First spawned (North) must have active priority!")

	# Verify only North has GREEN light; South, East, West are strictly RED!
	assert(controller.get_lane_signal_state("north") == "GREEN", "North fire truck must receive GREEN corridor!")
	assert(controller.get_lane_signal_state("south") == "RED", "South fire truck must wait at RED!")
	assert(controller.get_lane_signal_state("east") == "RED", "East fire truck must wait at RED!")
	assert(controller.get_lane_signal_state("west") == "RED", "West fire truck must wait at RED!")

	# Verify Mutex Lock
	assert(controller.can_lane_enter("north") == true, "North must be allowed to enter!")
	assert(controller.can_lane_enter("east") == false, "East must be locked by mutex from entering!")
	assert(controller.can_lane_enter("west") == false, "West must be locked by mutex from entering!")
	print("✓ Mutex & Emergency Priority verified: Only North granted green, conflicting lanes held at RED.")

	# Verify in_junction raycast tuning on North fire truck once inside junction
	ft_north.is_in_intersection = true
	ft_north.is_past_stop_line = true
	ft_north.has_exited_intersection = false
	for i in range(2):
		await physics_frame
	assert(abs(ft_north.front_ray.target_position.z - (-0.2)) < 0.05, "RayCast3D must be reduced to 0.2m inside junction!")
	assert(ft_north._evaluate_target_speed(0.016) >= ft_north.clear_speed, "Vehicle inside junction must sprint at clear_speed!")
	print("✓ Long-vehicle raycast tuning verified: front raycast reduced to 0.2m in junction.")

	# Simulate North fire truck completing crossing and clearing junction
	ft_north.has_exited_intersection = true
	controller.on_emergency_exited(ft_north)

	for i in range(5):
		await physics_frame

	# Next in queue should now be granted green corridor
	assert(controller.emergency_queue.size() == 3, "Queue must decrease to 3 after North exits!")
	assert(controller.active_emergency_lane == "south", "Second fire truck (South) must now be granted active corridor!")
	assert(controller.get_lane_signal_state("south") == "GREEN", "South lane must now turn GREEN!")
	assert(controller.get_lane_signal_state("east") == "RED", "East lane must still be RED!")
	print("✓ Turn-taking verified: Next fire truck in queue granted green corridor after first clears.")

	# Clean up remaining test fire trucks
	spawner.clear_all_vehicles()
	for i in range(5):
		await physics_frame

	print("=== ALL STMS ENHANCED TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
