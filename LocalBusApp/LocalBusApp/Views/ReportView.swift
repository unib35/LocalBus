import SwiftUI
import PhotosUI
import UIKit

// MARK: - 시간표 제보 화면

struct ReportView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var description = ""

    private let maxCharacters = 200

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                uploadSection
                formSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("시간표 제보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 업로드 섹션

    private var uploadSection: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(HomeDashboardTheme.border)
                                .frame(width: 60, height: 60)
                            Image(systemName: "camera.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }
                        VStack(spacing: 4) {
                            Text("사진 업로드")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("변경된 시간표 사진을 찍어주세요")
                                .font(.system(size: 13))
                                .foregroundStyle(HomeDashboardTheme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                }
            }
            .background(HomeDashboardTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        HomeDashboardTheme.border,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }

    // MARK: - 폼 섹션

    private var formSection: some View {
        VStack(spacing: 20) {
            // 텍스트 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("추가 설명 (선택 사항)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 36)
                        .frame(minHeight: 148)
                        .background(HomeDashboardTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(HomeDashboardTheme.border, lineWidth: 1)
                        )
                        .onChange(of: description) { newValue in
                            if newValue.count > maxCharacters {
                                description = String(newValue.prefix(maxCharacters))
                            }
                        }

                    if description.isEmpty {
                        Text("변경된 내용에 대해 간략히 적어주세요.")
                            .font(.system(size: 15))
                            .foregroundStyle(HomeDashboardTheme.tertiaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(description.count)/\(maxCharacters)")
                                .font(.system(size: 11))
                                .foregroundStyle(HomeDashboardTheme.tertiaryText)
                                .padding(.trailing, 12)
                                .padding(.bottom, 10)
                        }
                    }
                    .frame(minHeight: 148)
                }
            }

            // 안내 박스
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .padding(.top, 1)

                Text("사용자님의 제보는 검토 후 서비스에 즉시 반영됩니다. 정확한 정보 공유를 위해 노력해주셔서 감사합니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeDashboardTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HomeDashboardTheme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - 하단 버튼

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(height: 1)

            Button {
                sendReport()
            } label: {
                Text("제보 보내기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .white.opacity(0.06), radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 17)
            .padding(.bottom, 32)
        }
        .background(HomeDashboardTheme.screenBackground)
    }

    // MARK: - 액션

    private func sendReport() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let email = "help@localbus.com"
        let subject = "[LocalBus] 시간표 변경 제보"
        let body: String
        if description.isEmpty {
            body = "\n\n---\n앱 버전: \(appVersion)\n기기: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
        } else {
            body = "\(description)\n\n---\n앱 버전: \(appVersion)\n기기: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
        }
        let encoded = "mailto:\(email)?subject=\(subject.reportURLEncoded)&body=\(body.reportURLEncoded)"
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - String Extension

private extension String {
    var reportURLEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportView()
    }
    .preferredColorScheme(.dark)
}
