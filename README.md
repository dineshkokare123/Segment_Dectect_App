YOLO CoreML Segmentation Demo🚀 
Overview:
This is a SwiftUI application demonstrating real-time instance segmentation on iOS using a pre-trained YOLO (YOLOv8n-seg) model converted to Core ML.

The app allows the user to select an image from their photo library, run the image through the Core ML model, and visualize the segmentation mask overlaid onto the original image.

Feature	Description:
Model:	YOLOv8 Nano Segmentation (yolov8n-seg)
Framework:	Core ML, Vision
UI:	SwiftUI
Functionality:	Image selection via PhotosPicker, asynchronous ML processing, and mask visualization.
💻 Project Structure:
The key components handling the machine learning pipeline are:

yolov8n-seg.mlpackage: The Core ML model file (must be exported from PyTorch/Ultralytics).

SegmentationProcessor.swift: The ObservableObject class that handles the Vision pipeline, runs the VNCoreMLRequest, and manages the app's state (isProcessing, segmentedImage).

MLMultiArray+Mask.swift: An extension responsible for converting the raw MLMultiArray segmentation map output from the model into a visual UIImage mask overlay.

ContentView.swift: The main SwiftUI view for image selection, display, and running the processing function.

🛠️ Setup and Installation:
Prerequisites:

Xcode (latest version recommended):

An Apple Developer Account (Free or Paid) to run on a physical device.

1. Export the Core ML Model

If you haven't already, you must export your YOLO segmentation weights (best.pt or yolov8n-seg.pt) to the Core ML format using the Ultralytics library in Python:

Bash
# Assuming you have the ultralytics library and PyTorch installed
from ultralytics import YOLO

# Load the segmentation model
model = YOLO('yolov8n-seg.pt') 

# Export to CoreML format (creates a yolov8n-seg.mlpackage file)
model.export(format='coreml')
2. Add the Model to Xcode

Drag the generated yolov8n-seg.mlpackage file into your Xcode project's file navigator.

Ensure it is correctly integrated with the main target (Segment_Dectect_App).

3. Permissions

Since the app uses PhotosPicker to load images from the photo library, you must add the appropriate privacy string to your Info.plist file:

Key	Value
Privacy - Photo Library Usage Description	We need access to your photo library to select an image for segmentation.
💡 Code Highlights
Core ML Model Loading (SegmentationProcessor.swift)

The model is initialized using the generated Swift class name:

Swift
private lazy var visionModel: VNCoreMLModel? = {
    do {
        // Xcode generates the yolov8n_seg class from the mlpackage file
        let coreMLModel = try yolov8n_seg(configuration: MLModelConfiguration()).model
        return try VNCoreMLModel(for: coreMLModel)
    } catch {
        // ...
    }
}()
Mask Generation (MLMultiArray+Mask.swift)

This utility is crucial for visually interpreting the raw model output:

Swift
// Logic to map the raw class index (Float) from MLMultiArray 
// to a specific color defined in `classColors` (e.g., class 2 is blue)
let classIndex = Int(dataPointer[index])
let colorIndex = min(classIndex, classColors.count - 1)
let uiColor = classColors[colorIndex]


Screenshots:

https://github.com/user-attachments/assets/7f0f3e59-7d2e-49f9-91c7-d8033dd68d4b

