from ultralytics import YOLO

# ⚠️ Use the verified path for the YOLOv8 model found by the 'find' command
model_path = "/Users/dineshkokare/Documents/Project/object_tracker_app/yolov8n.pt" 

# Use 640 or the input size your model expects
INPUT_SIZE = 640

# Load the model
model = YOLO(model_path) 
    
print(f"Starting export of model: {model_path}...")

# Export the model to Core ML format (.mlpackage)
# This will generate a file named 'yolov8n.mlpackage' in the same directory.
model.export(
    format="coreml",
    half=True,  
    imgsz=INPUT_SIZE
)

print("✅ Core ML model (.mlpackage) successfully generated!")