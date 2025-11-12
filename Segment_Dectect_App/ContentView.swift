import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var processor = SegmentationProcessor()
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputImage: UIImage?

    var body: some View {
        VStack {
            Text("YOLO CoreML Segmentation Demo")
                .font(.title)
                .bold()
                .padding(.bottom, 10)
            
            Divider()
            
            // Image Display Area
            Group {
                if let segmentedImage = processor.segmentedImage {
                    Image(uiImage: segmentedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("Select an image to begin"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            
            // Status Message
            Text(processor.statusMessage)
                .foregroundColor(processor.isProcessing ? .orange : .secondary)
                .padding(.bottom, 20)
            
            HStack(spacing: 20) {
                // Image Picker Button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select Image", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                
                // Run Segmentation Button
                Button {
                    if let img = inputImage {
                        processor.process(image: img)
                    }
                } label: {
                    Label("Run CoreML", systemImage: processor.isProcessing ? "hourglass" : "brain.head.profile")
                }
                .buttonStyle(.borderedProminent)
                // Disable button if no image is selected or processing is running
                .disabled(inputImage == nil || processor.isProcessing)
            }
        }
        .padding()
        // Handle image selection change - FIX applied here
        .onChange(of: selectedItem) { _, newItem in
            Task {
                // Safely unwrap the new item
                guard let newItem = newItem else { return }
                
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Update state variables when image is loaded
                    processor.segmentedImage = nil
                    inputImage = uiImage
                    processor.statusMessage = "Image selected. Ready to run."
                }
            }
        }
    }
}
