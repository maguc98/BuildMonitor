import SwiftUI
import Foundation
import ZIPFoundation

enum ArtifactArchiveService {
    static func extract(zipURL: URL, name: String, id: Int) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("Artifacts", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let safeName = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let destination = root.appendingPathComponent("\(safeName)-\(id)", isDirectory: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw NSError(domain: "BuildMonitor.Artifact", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法打开 ZIP 文件。"])
        }
        for entry in archive {
            let components = entry.path.split(separator: "/").map(String.init)
            guard !components.isEmpty, !components.contains(".."), !entry.path.hasPrefix("/") else {
                throw NSError(domain: "BuildMonitor.Artifact", code: 2, userInfo: [NSLocalizedDescriptionKey: "ZIP 中包含不安全的路径，已停止解压。"])
            }
            let target = components.reduce(destination) { $0.appendingPathComponent($1) }
            if entry.type == .directory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                let parent = target.deletingLastPathComponent()
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: target)
            }
        }
        return destination
    }
}

struct ArtifactFileItem: Identifiable {
    let url: URL
    let isDirectory: Bool
    var id: String { url.path }
    var size: Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

struct ArtifactBrowserView: View {
    let rootURL: URL
    @State private var files: [ArtifactFileItem] = []
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                ForEach(files) { item in
                    if item.isDirectory {
                        NavigationLink {
                            ArtifactBrowserView(rootURL: item.url)
                        } label: {
                            row(item)
                        }
                    } else {
                        NavigationLink {
                            ArtifactFilePreviewView(fileURL: item.url)
                        } label: {
                            row(item)
                        }
                    }
                }
            } header: {
                Text(rootURL.lastPathComponent)
            }
        }
        .navigationTitle("产物文件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: rootURL) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder private func row(_ item: ArtifactFileItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(item.url))
                .foregroundStyle(item.isDirectory ? Palette.blue : Palette.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent).font(.system(size: 13, weight: .medium))
                if !item.isDirectory { Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)).font(.system(size: 10)).foregroundStyle(Palette.secondary) }
            }
        }
    }

    private func load() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
            files = urls.sorted { a, b in
                let ad = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bd = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if ad != bd { return ad }
                return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
            }.map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return ArtifactFileItem(url: url, isDirectory: isDir)
            }
        } catch { errorText = error.localizedDescription }
    }

    private func fileIcon(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "ipa": return "app.badge"
        case "pdf": return "doc.richtext"
        case "json": return "curlybraces"
        case "txt", "log", "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo"
        case "zip": return "doc.zipper"
        default: return "doc"
        }
    }
}

struct ArtifactFilePreviewView: View {
    let fileURL: URL
    @State private var text: String?

    var body: some View {
        VStack {
            if let text {
                ScrollView {
                    Text(text).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding()
                }
            } else {
                ContentUnavailableView("无法预览此文件", systemImage: "doc", description: Text("可使用分享菜单导出到其他 App。"))
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: fileURL) { Image(systemName: "square.and.arrow.up") } }
        }
        .onAppear {
            let ext = fileURL.pathExtension.lowercased()
            guard ["txt", "log", "md", "json", "xml", "plist", "yaml", "yml", "swift", "sh", "html", "css"].contains(ext),
                  let data = try? Data(contentsOf: fileURL),
                  data.count <= 2_000_000,
                  let content = String(data: data, encoding: .utf8) else { return }
            text = content
        }
    }
}
