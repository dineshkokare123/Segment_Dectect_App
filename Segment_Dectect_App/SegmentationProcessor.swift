import CoreML
import Vision
import UIKit
import SwiftUI
internal import Combine

class SegmentationProcessor: ObservableObject {
    
    public init() {}
    
    @Published var segmentedImage: UIImage?
    @Published var statusMessage: String = "Ready to segment."
    @Published var isProcessing: Bool = false

    // Load the Core ML Model (MUST match the name Xcode generated)
    private lazy var visionModel: VNCoreMLModel? = {
        do {
            // ⚠️ REPLACE 'YourYOLOSegModel' with your actual model class name (e.g., 'Best')
            let coreMLModel = try yolov8n_seg(configuration: MLModelConfiguration()).model
            return try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("Error loading Core ML model: \(error)")
            DispatchQueue.main.async { self.statusMessage = "Error: Failed to load Core ML model." }
            return nil
        }
    }()

    func process(image: UIImage) {
        // Validation checks
        guard !isProcessing,
              let ciImage = CIImage(image: image),
              let visionModel = visionModel
        else {
            statusMessage = isProcessing ? "Already processing." : "Image or Model not ready."
            return
        }

        DispatchQueue.main.async {
            self.isProcessing = true
            self.statusMessage = "Processing..."
            self.segmentedImage = nil // Clear previous result
        }

        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            guard let self = self else { return }
            
            // Check for execution errors
            if let error = error {
                DispatchQueue.main.async {
                    self.statusMessage = "Vision request failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
                return
            }

            // 1. Extract the MLMultiArray segmentation map from results
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
                  let multiArray = observations.first?.featureValue.multiArrayValue else {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to get mask output."
                    self.isProcessing = false
                }
                return
            }
            
            // 2. Convert raw mask data to a visual UIImage overlay
            if let maskImage = multiArray.createMaskImage(resizedTo: image.size) {
                // 3. Combine the original image and the mask
                if let combinedImage = self.combine(original: image, mask: maskImage) {
                    DispatchQueue.main.async {
                        self.segmentedImage = combinedImage
                        self.statusMessage = "Segmentation complete (\(multiArray.shape.last?.intValue ?? 0)x\(multiArray.shape[multiArray.shape.count - 2].intValue))"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to create mask image."
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }

        // 4. Execute the Vision Request on a background thread
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Handler failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Utility to overlay the mask onto the original image
    private func combine(original: UIImage, mask: UIImage) -> UIImage? {
        let size = original.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: size))
            mask.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 1.0)
        }
    }
}//
//  SegmentationProcessor.swift
//  Segment_Dectect_App
//
//  Created by Dinesh Kokare on 12/11/25.
//

