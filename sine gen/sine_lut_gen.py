import math

NUM_STEPS = 4096
MAX_ANGLE_DEG = 60
SCALE = 4096

with open("sine_lut.txt", "w") as f:
    for i in range(NUM_STEPS):
        # Map index to angle (0 → 60 degrees)
        angle_deg = (i / (NUM_STEPS - 1)) * MAX_ANGLE_DEG
        angle_rad = math.radians(angle_deg)

        # Compute scaled sine and round
        value = round(math.sin(angle_rad) * SCALE)

        # Write in required Verilog format
        f.write(f"        12'd{i}: sine <= 12'd{value};\n")

print("File 'sine_lut.txt' generated successfully.")
