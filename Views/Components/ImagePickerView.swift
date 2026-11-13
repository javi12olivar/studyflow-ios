import SwiftUI
import UIKit

// MARK: - Native iOS Image & Camera Picker
public struct ImagePickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    public var sourceType: UIImagePickerController.SourceType
    public var onImagePicked: (UIImage) -> Void
    
    public init(
        sourceType: UIImagePickerController.SourceType = .photoLibrary,
        onImagePicked: @escaping (UIImage) -> Void
    ) {
        self.sourceType = sourceType
        self.onImagePicked = onImagePicked
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
