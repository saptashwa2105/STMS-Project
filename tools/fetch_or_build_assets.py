"""
Asset pipeline for 3D Smart Traffic Management Digital Twin.
Generates rich, beautiful low-poly 3D models:
- Passenger Car (sedan with wheels, windows, headlights, taillights)
- Motorbike (chassis, wheels, handlebar, rider silhouette)
- Cargo Truck (heavy cab, large ribbed cargo container, 6 wheels)
- Ambulance (medical van with livery, roof strobe lightbars)
- Fire Truck (fire rescue chassis, roll doors, ladder, strobe lightbars)
- Streetlamp (pole with warm emissive lamp head)
- Low-Poly Tree (pine / stylized foliage)
- Traffic Light Pole (heavy cantilever arm with visored signal housing)
"""
import os
import math

ASSETS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "simulation", "assets", "models"))
os.makedirs(ASSETS_DIR, exist_ok=True)

class OBJBuilder:
    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = [] # list of (material_name, [v_indices])
        self.materials = {} # mat_name -> dict(diffuse, specular, emission, roughness)
        self.current_material = "default"

    def add_material(self, name, diffuse=(0.8, 0.8, 0.8), emission=(0, 0, 0), roughness=0.5):
        self.materials[name] = {
            "diffuse": diffuse,
            "emission": emission,
            "roughness": roughness
        }

    def use_material(self, name):
        if name not in self.materials:
            self.add_material(name)
        self.current_material = name

    def add_box(self, center, size, mat_name=None):
        if mat_name:
            self.use_material(mat_name)
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0

        base_v = len(self.vertices) + 1
        corners = [
            (cx - sx, cy - sy, cz - sz),
            (cx + sx, cy - sy, cz - sz),
            (cx + sx, cy + sy, cz - sz),
            (cx - sx, cy + sy, cz - sz),
            (cx - sx, cy - sy, cz + sz),
            (cx + sx, cy - sy, cz + sz),
            (cx + sx, cy + sy, cz + sz),
            (cx - sx, cy + sy, cz + sz),
        ]
        self.vertices.extend(corners)

        faces_quads = [
            (0, 3, 2, 1), # Front (-Z)
            (5, 6, 7, 4), # Back (+Z)
            (4, 7, 3, 0), # Left (-X)
            (1, 2, 6, 5), # Right (+X)
            (4, 0, 1, 5), # Bottom (-Y)
            (3, 7, 6, 2), # Top (+Y)
        ]

        for q in faces_quads:
            v0 = base_v + q[0]
            v1 = base_v + q[1]
            v2 = base_v + q[2]
            v3 = base_v + q[3]
            self.faces.append((self.current_material, [v0, v1, v2]))
            self.faces.append((self.current_material, [v0, v2, v3]))

    def add_cone(self, center, radius, height, segments=12, mat_name=None):
        if mat_name:
            self.use_material(mat_name)
        cx, cy, cz = center
        h2 = height / 2.0
        base_v = len(self.vertices) + 1
        apex_idx = base_v
        bot_center_idx = base_v + 1

        self.vertices.append((cx, cy + h2, cz))
        self.vertices.append((cx, cy - h2, cz))

        ring_start = len(self.vertices) + 1
        for i in range(segments):
            angle = 2.0 * math.pi * i / segments
            cos_a = math.cos(angle) * radius
            sin_a = math.sin(angle) * radius
            self.vertices.append((cx + cos_a, cy - h2, cz + sin_a))

        for i in range(segments):
            next_i = (i + 1) % segments
            cur_i = ring_start + i
            nxt_i = ring_start + next_i
            # Side tri
            self.faces.append((self.current_material, [apex_idx, cur_i, nxt_i]))
            # Bot tri
            self.faces.append((self.current_material, [bot_center_idx, nxt_i, cur_i]))

    def add_cylinder(self, center, radius, height, segments=12, axis='y', mat_name=None):
        if mat_name:
            self.use_material(mat_name)
        cx, cy, cz = center
        h2 = height / 2.0
        base_v = len(self.vertices) + 1

        top_center_idx = base_v
        bot_center_idx = base_v + 1

        if axis == 'y':
            self.vertices.append((cx, cy + h2, cz))
            self.vertices.append((cx, cy - h2, cz))
        elif axis == 'x':
            self.vertices.append((cx + h2, cy, cz))
            self.vertices.append((cx - h2, cy, cz))
        elif axis == 'z':
            self.vertices.append((cx, cy, cz + h2))
            self.vertices.append((cx, cy, cz - h2))

        ring_start = len(self.vertices) + 1
        for i in range(segments):
            angle = 2.0 * math.pi * i / segments
            cos_a = math.cos(angle) * radius
            sin_a = math.sin(angle) * radius
            if axis == 'y':
                self.vertices.append((cx + cos_a, cy + h2, cz + sin_a))
                self.vertices.append((cx + cos_a, cy - h2, cz + sin_a))
            elif axis == 'x':
                self.vertices.append((cx + h2, cy + cos_a, cz + sin_a))
                self.vertices.append((cx - h2, cy + cos_a, cz + sin_a))
            elif axis == 'z':
                self.vertices.append((cx + cos_a, cy + sin_a, cz + h2))
                self.vertices.append((cx + cos_a, cy + sin_a, cz - h2))

        for i in range(segments):
            next_i = (i + 1) % segments
            top_i = ring_start + i * 2
            bot_i = ring_start + i * 2 + 1
            top_next = ring_start + next_i * 2
            bot_next = ring_start + next_i * 2 + 1

            self.faces.append((self.current_material, [top_center_idx, top_i, top_next]))
            self.faces.append((self.current_material, [bot_center_idx, bot_next, bot_i]))
            self.faces.append((self.current_material, [top_i, bot_i, bot_next]))
            self.faces.append((self.current_material, [top_i, bot_next, top_next]))

    def write_files(self, output_dir):
        obj_path = os.path.join(output_dir, f"{self.name}.obj")
        mtl_path = os.path.join(output_dir, f"{self.name}.mtl")
        mtl_filename = f"{self.name}.mtl"

        with open(mtl_path, "w", encoding="utf-8") as f:
            f.write(f"# Material file for {self.name}\n\n")
            for mat_name, props in self.materials.items():
                f.write(f"newmtl {mat_name}\n")
                r, g, b = props["diffuse"]
                f.write(f"Kd {r:.4f} {g:.4f} {b:.4f}\n")
                f.write("Ka 0.25 0.25 0.25\n")
                f.write("Ks 0.5 0.5 0.5\n")
                f.write("Ns 32.0\n")
                f.write("d 1.0\n")
                er, eg, eb = props.get("emission", (0, 0, 0))
                if er > 0 or eg > 0 or eb > 0:
                    f.write(f"Ke {er:.4f} {eg:.4f} {eb:.4f}\n")
                f.write("\n")

        with open(obj_path, "w", encoding="utf-8") as f:
            f.write(f"# OBJ file for {self.name}\n")
            f.write(f"mtllib {mtl_filename}\n\n")
            for v in self.vertices:
                f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
            f.write("\n")

            cur_mat = None
            for mat, tri in self.faces:
                if mat != cur_mat:
                    cur_mat = mat
                    f.write(f"usemtl {cur_mat}\n")
                f.write(f"f {tri[0]} {tri[1]} {tri[2]}\n")

        print(f"Generated {obj_path} and {mtl_path}")


def build_all_models():
    # 1. Passenger Car
    car = OBJBuilder("car")
    car.add_material("car_body", diffuse=(0.18, 0.52, 0.96))
    car.add_material("car_roof", diffuse=(0.12, 0.40, 0.82))
    car.add_material("glass", diffuse=(0.12, 0.18, 0.28))
    car.add_material("grille", diffuse=(0.15, 0.15, 0.17))
    car.add_material("tire", diffuse=(0.14, 0.14, 0.16))
    car.add_material("rim", diffuse=(0.85, 0.85, 0.88))
    car.add_material("headlight", diffuse=(1.0, 1.0, 0.85), emission=(1.2, 1.2, 0.8))
    car.add_material("taillight", diffuse=(0.95, 0.1, 0.1), emission=(1.0, 0.1, 0.1))

    # Lower body
    car.add_box((0, 0.42, 0), (1.65, 0.44, 3.6), "car_body")
    # Front bumper & grille
    car.add_box((0, 0.38, -1.82), (1.5, 0.28, 0.08), "grille")
    # Hood slope accent
    car.add_box((0, 0.65, -0.9), (1.55, 0.12, 1.4), "car_body")
    # Cabin roof
    car.add_box((0, 0.98, 0.0), (1.38, 0.56, 1.9), "car_roof")
    # Windows (Windshield, Rear, Sides)
    car.add_box((0, 0.98, -0.96), (1.30, 0.48, 0.05), "glass")
    car.add_box((0, 0.98, 0.96), (1.30, 0.48, 0.05), "glass")
    car.add_box((0, 0.98, 0.0), (1.42, 0.46, 1.8), "glass")
    # Headlights & Taillights
    car.add_box((-0.60, 0.46, -1.81), (0.32, 0.16, 0.06), "headlight")
    car.add_box((0.60, 0.46, -1.81), (0.32, 0.16, 0.06), "headlight")
    car.add_box((-0.60, 0.46, 1.81), (0.32, 0.16, 0.06), "taillight")
    car.add_box((0.60, 0.46, 1.81), (0.32, 0.16, 0.06), "taillight")
    # 4 Wheels
    for wx in [-0.85, 0.85]:
        for wz in [-1.05, 1.05]:
            car.add_cylinder((wx, 0.32, wz), 0.34, 0.24, segments=12, axis='x', mat_name="tire")
            car.add_cylinder((wx * 1.05, 0.32, wz), 0.20, 0.26, segments=8, axis='x', mat_name="rim")
    car.write_files(ASSETS_DIR)

    # 2. Motorbike
    bike = OBJBuilder("motorbike")
    bike.add_material("bike_frame", diffuse=(0.95, 0.35, 0.08))
    bike.add_material("bike_metal", diffuse=(0.28, 0.30, 0.34))
    bike.add_material("tire", diffuse=(0.14, 0.14, 0.16))
    bike.add_material("rider_suit", diffuse=(0.15, 0.65, 0.45))
    bike.add_material("rider_helmet", diffuse=(0.18, 0.18, 0.22))
    bike.add_material("headlight", diffuse=(1.0, 1.0, 0.85), emission=(1.2, 1.2, 0.8))
    bike.add_material("taillight", diffuse=(0.95, 0.1, 0.1), emission=(1.0, 0.1, 0.1))

    # Wheels
    bike.add_cylinder((0, 0.30, -0.8), 0.30, 0.14, segments=12, axis='x', mat_name="tire")
    bike.add_cylinder((0, 0.30, 0.8), 0.30, 0.16, segments=12, axis='x', mat_name="tire")
    # Chassis & Engine block
    bike.add_box((0, 0.45, 0.0), (0.32, 0.38, 1.2), "bike_metal")
    # Fuel tank & seat
    bike.add_box((0, 0.68, -0.2), (0.38, 0.24, 0.55), "bike_frame")
    bike.add_box((0, 0.62, 0.3), (0.30, 0.16, 0.45), "tire")
    # Handlebars & Fork
    bike.add_box((0, 0.82, -0.62), (0.75, 0.06, 0.08), "bike_metal")
    bike.add_box((0, 0.65, -0.85), (0.18, 0.18, 0.08), "headlight")
    bike.add_box((0, 0.58, 0.95), (0.14, 0.12, 0.06), "taillight")
    # Rider Body & Helmet
    bike.add_box((0, 0.96, 0.18), (0.38, 0.55, 0.32), "rider_suit")
    bike.add_box((0, 1.34, 0.08), (0.30, 0.30, 0.32), "rider_helmet")
    bike.write_files(ASSETS_DIR)

    # 3. Cargo Truck
    truck = OBJBuilder("truck")
    truck.add_material("truck_cab", diffuse=(0.96, 0.58, 0.10))
    truck.add_material("truck_container", diffuse=(0.88, 0.90, 0.94))
    truck.add_material("truck_chassis", diffuse=(0.18, 0.20, 0.24))
    truck.add_material("glass", diffuse=(0.12, 0.18, 0.28))
    truck.add_material("tire", diffuse=(0.14, 0.14, 0.16))
    truck.add_material("rim", diffuse=(0.75, 0.75, 0.78))
    truck.add_material("headlight", diffuse=(1.0, 1.0, 0.85), emission=(1.2, 1.2, 0.8))
    truck.add_material("taillight", diffuse=(0.95, 0.1, 0.1), emission=(1.0, 0.1, 0.1))

    # Long heavy chassis frame
    truck.add_box((0, 0.48, 0.0), (2.0, 0.36, 6.4), "truck_chassis")
    # Cab (front -Z)
    truck.add_box((0, 1.35, -2.25), (2.0, 1.45, 1.8), "truck_cab")
    truck.add_box((0, 1.55, -3.16), (1.8, 0.75, 0.06), "glass")
    truck.add_box((0, 1.55, -2.25), (2.06, 0.70, 1.1), "glass")
    # Bumper & Grille
    truck.add_box((0, 0.60, -3.16), (1.9, 0.45, 0.08), "truck_chassis")
    # Headlights
    truck.add_box((-0.75, 0.65, -3.17), (0.38, 0.22, 0.06), "headlight")
    truck.add_box((0.75, 0.65, -3.17), (0.38, 0.22, 0.06), "headlight")
    # Huge Ribbed Cargo Container
    truck.add_box((0, 1.70, 0.8), (2.15, 2.1, 4.6), "truck_container")
    truck.add_box((0, 2.76, 0.8), (2.20, 0.08, 4.65), "truck_chassis")
    # Taillights
    truck.add_box((-0.80, 0.55, 3.21), (0.38, 0.22, 0.06), "taillight")
    truck.add_box((0.80, 0.55, 3.21), (0.38, 0.22, 0.06), "taillight")
    # 6 Heavy Wheels
    for wz in [-2.25, 1.1, 2.4]:
        for wx in [-1.10, 1.10]:
            truck.add_cylinder((wx, 0.48, wz), 0.48, 0.32, segments=14, axis='x', mat_name="tire")
            truck.add_cylinder((wx * 1.05, 0.48, wz), 0.28, 0.34, segments=8, axis='x', mat_name="rim")
    truck.write_files(ASSETS_DIR)

    # 4. Emergency Ambulance
    amb = OBJBuilder("ambulance")
    amb.add_material("amb_white", diffuse=(0.96, 0.96, 0.98))
    amb.add_material("amb_red_stripe", diffuse=(0.95, 0.12, 0.12))
    amb.add_material("glass", diffuse=(0.12, 0.18, 0.28))
    amb.add_material("tire", diffuse=(0.14, 0.14, 0.16))
    amb.add_material("siren_blue", diffuse=(0.1, 0.5, 1.0), emission=(0.3, 1.2, 3.5))
    amb.add_material("siren_red", diffuse=(1.0, 0.15, 0.15), emission=(3.5, 0.3, 0.3))
    amb.add_material("headlight", diffuse=(1.0, 1.0, 0.85), emission=(1.2, 1.2, 0.8))
    amb.add_material("taillight", diffuse=(0.95, 0.1, 0.1), emission=(1.0, 0.1, 0.1))

    # Main ambulance box body
    amb.add_box((0, 1.05, 0.15), (1.9, 1.35, 4.0), "amb_white")
    amb.add_box((0, 0.70, -1.65), (1.9, 0.70, 1.1), "amb_white")
    # Red reflective side stripes
    amb.add_box((0, 0.90, 0.15), (1.94, 0.32, 4.02), "amb_red_stripe")
    # Medical cross on sides
    amb.add_box((-0.98, 1.25, 0.4), (0.05, 0.50, 0.16), "amb_red_stripe")
    amb.add_box((-0.98, 1.25, 0.4), (0.05, 0.16, 0.50), "amb_red_stripe")
    amb.add_box((0.98, 1.25, 0.4), (0.05, 0.50, 0.16), "amb_red_stripe")
    amb.add_box((0.98, 1.25, 0.4), (0.05, 0.16, 0.50), "amb_red_stripe")
    # Windows
    amb.add_box((0, 1.25, -1.15), (1.75, 0.58, 0.06), "glass")
    amb.add_box((0, 1.25, -0.65), (1.94, 0.50, 0.8), "glass")
    # Dual Rooftop Strobe Lightbars
    amb.add_box((-0.42, 1.82, -0.65), (0.42, 0.18, 0.28), "siren_red")
    amb.add_box((0.42, 1.82, -0.65), (0.42, 0.18, 0.28), "siren_blue")
    # Headlights & Taillights
    amb.add_box((-0.70, 0.60, -2.21), (0.34, 0.20, 0.06), "headlight")
    amb.add_box((0.70, 0.60, -2.21), (0.34, 0.20, 0.06), "headlight")
    amb.add_box((-0.70, 0.60, 2.16), (0.34, 0.20, 0.06), "taillight")
    amb.add_box((0.70, 0.60, 2.16), (0.34, 0.20, 0.06), "taillight")
    # 4 Wheels
    for wx in [-0.98, 0.98]:
        for wz in [-1.25, 1.35]:
            amb.add_cylinder((wx, 0.40, wz), 0.40, 0.28, segments=12, axis='x', mat_name="tire")
    amb.write_files(ASSETS_DIR)

    # 5. Emergency Fire Truck
    ft = OBJBuilder("firetruck")
    ft.add_material("ft_red", diffuse=(0.92, 0.10, 0.10))
    ft.add_material("ft_white", diffuse=(0.96, 0.96, 0.98))
    ft.add_material("ft_yellow", diffuse=(0.96, 0.82, 0.12))
    ft.add_material("ft_silver", diffuse=(0.75, 0.78, 0.82))
    ft.add_material("glass", diffuse=(0.12, 0.18, 0.28))
    ft.add_material("tire", diffuse=(0.14, 0.14, 0.16))
    ft.add_material("siren_red", diffuse=(1.0, 0.15, 0.15), emission=(3.5, 0.3, 0.3))
    ft.add_material("siren_blue", diffuse=(0.1, 0.5, 1.0), emission=(0.3, 1.2, 3.5))
    ft.add_material("headlight", diffuse=(1.0, 1.0, 0.85), emission=(1.2, 1.2, 0.8))
    ft.add_material("taillight", diffuse=(0.95, 0.1, 0.1), emission=(1.0, 0.1, 0.1))

    # Main heavy red body
    ft.add_box((0, 1.30, 0.0), (2.15, 1.6, 6.0), "ft_red")
    ft.add_box((0, 1.55, -3.01), (1.9, 0.75, 0.06), "glass")
    ft.add_box((0, 1.55, -2.1), (2.18, 0.70, 1.3), "glass")
    ft.add_box((0, 0.90, 0.0), (2.18, 0.28, 6.04), "ft_white")
    # Equipment roller doors on sides
    for sz in [-0.2, 1.2, 2.2]:
        ft.add_box((-1.10, 1.25, sz), (0.06, 0.85, 0.80), "ft_silver")
        ft.add_box((1.10, 1.25, sz), (0.06, 0.85, 0.80), "ft_silver")
    # Extendable rescue ladder
    ft.add_box((0, 2.25, 0.4), (0.8, 0.18, 4.2), "ft_silver")
    ft.add_box((0, 2.38, 0.4), (0.6, 0.12, 3.8), "ft_yellow")
    # Rooftop Lightbar
    ft.add_box((-0.60, 2.20, -2.3), (0.50, 0.20, 0.32), "siren_red")
    ft.add_box((0.60, 2.20, -2.3), (0.50, 0.20, 0.32), "siren_blue")
    ft.add_box((0.0, 2.20, -2.3), (0.35, 0.16, 0.28), "ft_white")
    # Headlights & Taillights
    ft.add_box((-0.80, 0.65, -3.01), (0.38, 0.22, 0.06), "headlight")
    ft.add_box((0.80, 0.65, -3.01), (0.38, 0.22, 0.06), "headlight")
    ft.add_box((-0.80, 0.65, 3.01), (0.38, 0.22, 0.06), "taillight")
    ft.add_box((0.80, 0.65, 3.01), (0.38, 0.22, 0.06), "taillight")
    # 6 Heavy Wheels
    for wz in [-2.0, 1.1, 2.3]:
        for wx in [-1.15, 1.15]:
            ft.add_cylinder((wx, 0.50, wz), 0.50, 0.35, segments=14, axis='x', mat_name="tire")
    ft.write_files(ASSETS_DIR)

    # 6. Low-Poly Pine Tree
    tree = OBJBuilder("tree_pine")
    tree.add_material("trunk", diffuse=(0.35, 0.22, 0.12))
    tree.add_material("foliage", diffuse=(0.14, 0.45, 0.22))
    tree.add_cylinder((0, 1.2, 0), 0.25, 2.4, segments=8, axis='y', mat_name="trunk")
    tree.add_cone((0, 3.0, 0), 1.8, 2.4, segments=8, mat_name="foliage")
    tree.add_cone((0, 4.4, 0), 1.4, 2.2, segments=8, mat_name="foliage")
    tree.add_cone((0, 5.6, 0), 0.9, 1.8, segments=8, mat_name="foliage")
    tree.write_files(ASSETS_DIR)

    # 7. Streetlamp
    lamp = OBJBuilder("streetlamp")
    lamp.add_material("lamp_pole", diffuse=(0.22, 0.25, 0.30))
    lamp.add_material("lamp_bulb", diffuse=(1.0, 0.95, 0.8), emission=(2.5, 2.2, 1.2))
    lamp.add_cylinder((0, 3.0, 0), 0.10, 6.0, segments=8, axis='y', mat_name="lamp_pole")
    lamp.add_cylinder((0.8, 5.8, 0), 0.08, 1.6, segments=8, axis='x', mat_name="lamp_pole")
    lamp.add_box((1.5, 5.6, 0), (0.4, 0.25, 0.35), "lamp_pole")
    lamp.add_cylinder((1.5, 5.4, 0), 0.15, 0.10, segments=8, axis='y', mat_name="lamp_bulb")
    lamp.write_files(ASSETS_DIR)

    # 8. Traffic Light Pole
    tl = OBJBuilder("traffic_light_post")
    tl.add_material("pole_metal", diffuse=(0.20, 0.22, 0.26))
    tl.add_material("signal_housing", diffuse=(0.12, 0.14, 0.16))
    tl.add_cylinder((0, 3.0, 0), 0.14, 6.0, segments=12, axis='y', mat_name="pole_metal")
    tl.add_cylinder((1.8, 5.8, 0), 0.10, 3.6, segments=10, axis='x', mat_name="pole_metal")
    tl.add_box((3.2, 5.3, 0), (0.6, 1.6, 0.4), "signal_housing")
    tl.write_files(ASSETS_DIR)

    print("All enhanced 3D assets generated successfully!")

if __name__ == "__main__":
    build_all_models()
