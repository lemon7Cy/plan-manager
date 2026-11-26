import SwiftUI

struct GlassInputAlert: View {
    @Binding var isPresented: Bool
    let title: String
    let placeholder: String
    @Binding var text: String
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed Background
                LinearGradient(
                    colors: [Color.black.opacity(0.35), Color.black.opacity(0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)

                // Alert Content
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("输入后点击保存即可更新")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            onSave()
                        }

                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                                )
                        }

                        Button(action: onSave) {
                            Text("保存")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: "5DADE2"))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color(hex: "5DADE2").opacity(0.35), radius: 8, x: 0, y: 5)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(24)
                .frame(width: 320)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.58), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .onAppear {
                    isFocused = true
                }
            }
            .zIndex(100) // Ensure it's on top
        }
    }
}
