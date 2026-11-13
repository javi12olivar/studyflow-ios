import SwiftUI
import UIKit
import UniformTypeIdentifiers
import OSLog

// MARK: - Native iOS Document & PDF Picker
public struct DocumentPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    public var onDocumentPicked: (DocumentAttachment) -> Void
    
    private static let logger = Logger(subsystem: "com.studyflow.app", category: "DocumentPickerView")
    
    public init(onDocumentPicked: @escaping (DocumentAttachment) -> Void) {
        self.onDocumentPicked = onDocumentPicked
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes: [UTType] = [
            .pdf,
            .text,
            .plainText,
            .rtf,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "csv") ?? .commaSeparatedText
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.dismiss()
                return
            }
            
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let maxBytes = 15 * 1024 * 1024 // 15MB limit to prevent OOM
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard !data.isEmpty, data.count <= maxBytes else {
                    DocumentPickerView.logger.warning("Selected document is empty or exceeds 15MB limit")
                    parent.dismiss()
                    return
                }
                
                let filename = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                
                let mimeType: String
                switch ext {
                case "pdf":
                    mimeType = "application/pdf"
                case "txt":
                    mimeType = "text/plain"
                case "md":
                    mimeType = "text/markdown"
                case "csv":
                    mimeType = "text/csv"
                case "rtf":
                    mimeType = "application/rtf"
                case "docx":
                    mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                case "doc":
                    mimeType = "application/msword"
                default:
                    mimeType = "application/octet-stream"
                }
                
                let attachment = DocumentAttachment(
                    filename: filename,
                    fileData: data,
                    mimeType: mimeType
                )
                parent.onDocumentPicked(attachment)
            } catch {
                DocumentPickerView.logger.error("Error reading picked document: \(error.localizedDescription)")
            }
            
            parent.dismiss()
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
