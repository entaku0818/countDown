//
//  EventImages.swift
//  countDown
//
//  事前に用意したイベント画像の一覧
//

import SwiftUI
import UIKit

/// 利用可能な事前定義画像
struct EventImages {
    /// 利用可能な画像名の一覧
    static let available: [(name: String, displayName: String, icon: String)] = [
        ("birthday", "誕生日", "birthday.cake.fill"),
        ("travel", "旅行", "airplane"),
        ("wedding", "結婚式", "heart.fill"),
        ("baby", "出産", "stroller.fill"),
        ("graduation", "卒業", "graduationcap.fill"),
        ("anniversary", "記念日", "gift.fill"),
        ("holiday", "休日", "sun.max.fill"),
        ("christmas", "クリスマス", "snowflake"),
        ("newyear", "お正月", "sparkles"),
        ("concert", "コンサート", "music.mic"),
        ("sports", "スポーツ", "sportscourt.fill"),
        ("party", "パーティー", "party.popper.fill"),
    ]

    /// 画像を取得（Assets内の画像、なければSF Symbol）
    @ViewBuilder
    static func image(for name: String?, size: CGFloat = 60) -> some View {
        if let name = name, let info = available.first(where: { $0.name == name }) {
            if let uiImage = UIImage(named: "event_\(name)") {
                // Assetsに画像がある場合
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // SF Symbolsをフォールバック
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: size, height: size)
                    Image(systemName: info.icon)
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.blue)
                }
            }
        } else {
            // 画像未設定
            EmptyView()
        }
    }
}

/// 画像選択ビュー
struct ImagePickerView: View {
    @Binding var selectedImage: String?
    var onCustomImageSelected: ((UIImage) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingPhotoPicker = false

    let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // カスタム画像を添付
                    Section {
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                Text("写真を選択")
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text("カスタム画像")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    // 用意した画像
                    Section {
                        LazyVGrid(columns: columns, spacing: 16) {
                            // 「なし」オプション
                            Button {
                                selectedImage = nil
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 60, height: 60)
                                        Image(systemName: "xmark")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedImage == nil ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                    Text("なし")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }

                            // 用意した画像
                            ForEach(EventImages.available, id: \.name) { item in
                                Button {
                                    selectedImage = item.name
                                    dismiss()
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            if let uiImage = UIImage(named: "event_\(item.name)") {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.blue.opacity(0.1))
                                                    .frame(width: 60, height: 60)
                                                Image(systemName: item.icon)
                                                    .font(.title2)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedImage == item.name ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        Text(item.displayName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("テンプレート")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("画像を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPicker { image in
                    onCustomImageSelected?(image)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Photo Picker
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var onImageSelected: (UIImage) -> Void

        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.onImageSelected(image)
                    }
                }
            }
        }
    }
}
