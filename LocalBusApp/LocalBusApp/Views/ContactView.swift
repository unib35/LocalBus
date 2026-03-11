import SwiftUI

// MARK: - 문의 유형

private enum ContactType: String, CaseIterable {
    case schedule = "버스 시간 관련"
    case feature = "앱 기능 문의"
    case other = "기타"
}

// MARK: - 문의하기 화면

struct ContactView: View {
    @State private var selectedType: ContactType = .schedule
    @State private var content = ""

    private let maxCharacters = 500

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                typeSection
                contentSection
                infoBox
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color(red: 16/255, green: 25/255, blue: 34/255).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 16/255, green: 25/255, blue: 34/255).opacity(0.8), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 문의 유형 섹션

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("문의 유형")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 225/255))

            Picker("문의 유형", selection: $selectedType) {
                ForEach(ContactType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(Color(red: 148/255, green: 163/255, blue: 184/255))
        }
    }

    // MARK: - 내용 섹션

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 225/255))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 11)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(minHeight: 180)
                    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 51/255, green: 65/255, blue: 85/255), lineWidth: 1)
                    )
                    .onChange(of: content) { newValue in
                        if newValue.count > maxCharacters {
                            content = String(newValue.prefix(maxCharacters))
                        }
                    }

                if content.isEmpty {
                    Text("문의 내용을 입력해주세요.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(content.count)/\(maxCharacters)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    // MARK: - 안내 박스

    private var infoBox: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                .padding(.top, 2)

            Text("문의 내용은 검토 후 이메일로 답변 드립니다. 빠른 답변을 위해 문의 유형을 정확히 선택해 주세요.")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                .lineSpacing(3)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 하단 버튼

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
                .frame(height: 1)

            Button {
                sendContact()
            } label: {
                Text("보내기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 17)
            .padding(.bottom, 32)
        }
        .background(Color(red: 16/255, green: 25/255, blue: 34/255))
    }

    // MARK: - 액션

    private func sendContact() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let email = "help@localbus.com"
        let subject = "[LocalBus] \(selectedType.rawValue)"
        let bodyContent = content.isEmpty ? "" : "\(content)\n\n"
        let body = "\(bodyContent)---\n앱 버전: \(appVersion)\n기기: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
        let encoded = "mailto:\(email)?subject=\(subject.contactURLEncoded)&body=\(body.contactURLEncoded)"
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - String Extension

private extension String {
    var contactURLEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContactView()
    }
    .preferredColorScheme(.dark)
}
