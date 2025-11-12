//
//  MLMultiArray+Mask.swift
//  Segment_Dectect_App
//
//  Created by Dinesh Kokare on 12/11/25.
//

import CoreML
import Accelerate
import UIKit

// Define colors for visualizing different segments (classes).
// Add more colors if your model has more classes. Class 0 is usually the background.
let classColors: [UIColor] = [
    .clear,
    UIColor.systemRed.withAlphaComponent(0.6),      // Class 1
    UIColor.systemBlue.withAlphaComponent(0.6),     // Class 2
    UIColor.systemGreen.withAlphaComponent(0.6),    // Class 3
    UIColor.systemPurple.withAlphaComponent(0.6),   // Class 4
    .systemYellow.withAlphaComponent(0.6),          // Class 5
    .systemOrange.withAlphaComponent(0.6),
    .systemPink.withAlphaComponent(0.6),
]

extension MLMultiArray {
    
    // Converts the MLMultiArray segmentation map to a visual UIImage mask overlay.
    func createMaskImage(resizedTo targetSize: CGSize) -> UIImage? {
        // Ensure data is accessible and the shape is as expected (H, W or 1, H, W)
        let dataPointer = self.dataPointer.bindMemory(to: Float32.self, capacity: self.count)
        let shape = self.shape.map { $0.intValue }
        guard shape.count >= 2 else { return nil }
        let height = shape[shape.count - 2]
        let width = shape[shape.count - 1]
        
        // 1. Prepare a buffer for the mask pixels (ARGB format)
        var maskPixels = [UInt32](repeating: 0, count: width * height)

        // 2. Iterate through the model output and map class indices to colors
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                // Read the class index (float) and convert to an integer index
                let classIndex = Int(dataPointer[index])
                
                // Get the visualization color, ensuring we don't go out of bounds
                let colorIndex = min(classIndex, classColors.count - 1)
                let uiColor = classColors[colorIndex]
                
                // Convert UIColor to ARGB UInt32 format (AARRGGBB)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                let alpha = UInt32(a * 255.0)
                let red = UInt32(r * 255.0)
                let green = UInt32(g * 255.0)
                let blue = UInt32(b * 255.0)
                
                let argb: UInt32 = (alpha << 24) | (red << 16) | (green << 8) | blue
                maskPixels[index] = argb
            }
        }
        
        // 3. Create the CGImage from the pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue) // ARGB
        let bytesPerRow = width * MemoryLayout<UInt32>.size

        guard let context = CGContext(
            data: &maskPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        guard let cgImage = context.makeImage() else { return nil }

        // 4. Convert CGImage to UIImage and resize to the target display size
        let maskImage = UIImage(cgImage: cgImage)
        
        // Use UIGraphicsImageRenderer to handle resizing cleanly
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            maskImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
