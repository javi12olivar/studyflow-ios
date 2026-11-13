import Foundation

// MARK: - Document Attachment Model for StudyFlow
public struct DocumentAttachment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let fileData: Data
    public let mimeType: String
    public let fileSize: Int
    
    public init(id: UUID = UUID(), filename: String, fileData: Data, mimeType: String) {
        self.id = id
        self.filename = filename
        self.fileData = fileData
        self.mimeType = mimeType
        self.fileSize = fileData.count
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    public var fileExtension: String {
        (filename as NSString).pathExtension.uppercased()
    }
    
    public var systemIconName: String {
        let lower = filename.lowercased()
        if lower.hasSuffix(".pdf") {
            return "doc.text.fill"
        } else if lower.hasSuffix(".docx") || lower.hasSuffix(".doc") {
            return "doc.richtext.fill"
        } else if lower.hasSuffix(".txt") || lower.hasSuffix(".md") {
            return "doc.plaintext.fill"
        } else if lower.hasSuffix(".csv") || lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") {
            return "tablecells.fill"
        } else {
            return "doc.fill"
        }
    }
    
    public var isPDF: Bool {
        filename.lowercased().hasSuffix(".pdf") || mimeType == "application/pdf"
    }
}
