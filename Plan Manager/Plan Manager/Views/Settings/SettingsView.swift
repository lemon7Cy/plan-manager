//
//  SettingsView.swift
//  Plan Manager
//
//  Offline settings, local profile, notifications, and backup/restore.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var nickname = LocalStorage.shared.nickname
    @State private var showNotificationSettings = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var showRestoreConfirmation = false
    @State private var pendingRestoreData: Data?
    @State private var backupDocument = BackupDocument()
    @State private var alert: SettingsAlert?

    private let storage = LocalStorage.shared
    private var theme: AppThemeColors { AppThemeColors(colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                PMOfflineBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.spacingLG) {
                        profileCard
                        appearanceSection
                        backupSection
                        generalSection
                        appInfo
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingSM)
                    .padding(.bottom, DesignTokens.spacingXL)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                PMTopBar(title: "设置", subtitle: "离线数据与偏好") {
                    Color.clear.frame(width: 42, height: 42)
                }
            }
            .navigationDestination(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: defaultBackupFilename
            ) { result in
                switch result {
                case .success:
                    alert = SettingsAlert(title: "导出完成", message: "备份文件已生成。")
                case .failure(let error):
                    alert = SettingsAlert(title: "导出失败", message: error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importBackup(from: result)
            }
            .confirmationDialog(
                "恢复备份？",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("合并导入") {
                    restorePendingBackup()
                }
                Button("取消", role: .cancel) {
                    pendingRestoreData = nil
                }
            } message: {
                Text("备份会合并到当前数据中，重复的计划、支出、喝水和健身记录会跳过；昵称、身体档案、主题和提醒设置按备份覆盖。接口密钥不包含在备份中。")
            }
            .alert(item: $alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("好")))
            }
            .onReceive(NotificationCenter.default.publisher(for: .offlineDataDidChange)) { _ in
                nickname = storage.nickname
            }
        }
    }

    private var profileCard: some View {
        PMGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                HStack(spacing: DesignTokens.spacingMD) {
                    Text(String(nickname.prefix(1)))
                        .font(.title2.weight(.black))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(DesignTokens.primary, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本地昵称")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("用于通知称呼，只保存在本机和备份文件中")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: DesignTokens.spacingSM) {
                    TextField("输入昵称", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: DesignTokens.radiusMD, style: .continuous)
                        )

                    Button {
                        saveNickname()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 42)
                            .background(DesignTokens.primary, in: RoundedRectangle(cornerRadius: DesignTokens.radiusMD, style: .continuous))
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var appearanceSection: some View {
        section(title: "外观显示") {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.skyBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("主题")
                        .font(.body.weight(.medium))
                        .foregroundColor(theme.textPrimary)
                    Text(themeManager.currentTheme.displayName)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                Picker("主题", selection: Binding(
                    get: { themeManager.currentTheme },
                    set: { themeManager.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { option in
                        Image(systemName: option.icon).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .settingsCardBackground(colorScheme: colorScheme)
        }
    }

    private var backupSection: some View {
        section(title: "备份与恢复") {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("备份包含计划、支出、喝水、健身档案与训练记录、昵称、主题和提醒设置，不包含接口密钥。")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    Text("恢复时列表数据合并不重复，单例设置按备份覆盖。")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding([.horizontal, .top], DesignTokens.spacingMD)
                .padding(.bottom, 4)

                Button {
                    exportBackup()
                } label: {
                    settingsRow(icon: "square.and.arrow.up.fill", title: "导出备份", subtitle: defaultBackupFilename, color: DesignTokens.primary)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56)

                Button {
                    showImporter = true
                } label: {
                    settingsRow(icon: "square.and.arrow.down.fill", title: "恢复备份", subtitle: "合并不重复", color: DesignTokens.success)
                }
                .buttonStyle(.plain)
            }
            .settingsCardBackground(colorScheme: colorScheme)
        }
    }

    private var generalSection: some View {
        section(title: "通用设置") {
            VStack(spacing: 0) {
                Button {
                    showNotificationSettings = true
                } label: {
                    settingsRow(icon: "bell.circle.fill", title: "通知设置", subtitle: "计划、睡眠、喝水", color: DesignTokens.warning)
                }
            }
            .settingsCardBackground(colorScheme: colorScheme)
        }
    }

    private var appInfo: some View {
        VStack(spacing: 4) {
            Text("Plan Manager")
                .font(.footnote.bold())
                .foregroundColor(theme.textSecondary)
            Text("Version \(appVersion) · 本地数据")
                .font(.caption2)
                .foregroundColor(theme.textSecondary.opacity(0.7))
        }
        .padding(.top, DesignTokens.spacingSM)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(title)
                .font(.headline)
                .foregroundColor(theme.textSecondary)
                .padding(.leading, 4)
            content()
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(theme.textSecondary.opacity(0.55))
        }
        .padding()
        .contentShape(Rectangle())
    }

    private func saveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        storage.nickname = trimmed
        nickname = storage.nickname
        notificationManager.updateNickname(storage.nickname)
        alert = SettingsAlert(title: "已保存", message: "昵称已更新。")
    }

    private func exportBackup() {
        do {
            backupDocument = BackupDocument(data: try storage.encodedBackup(appVersion: appVersion))
            showExporter = true
        } catch {
            alert = SettingsAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func importBackup(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            pendingRestoreData = data
            showRestoreConfirmation = true
        } catch {
            alert = SettingsAlert(title: "恢复失败", message: "请确认选择的是 Plan Manager JSON 备份文件。")
        }
    }

    private func restorePendingBackup() {
        guard let data = pendingRestoreData else { return }
        pendingRestoreData = nil
        do {
            let imported = try storage.importBackup(data: data)
            nickname = storage.nickname
            themeManager.reloadTheme()
            notificationManager.reloadSettings()
            alert = SettingsAlert(
                title: "恢复完成",
                message: "新增计划 \(imported.importedPlans) 条，支出 \(imported.importedExpenses) 条，喝水记录 \(imported.importedWaterRecords) 条。若备份含健身数据，也已合并；接口密钥保持不变。"
            )
        } catch {
            alert = SettingsAlert(title: "恢复失败", message: "请确认选择的是 Plan Manager JSON 备份文件。")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Offline"
    }

    private var defaultBackupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "PlanManager-Backup-\(formatter.string(from: Date())).json"
    }
}

struct NotificationSettingsView: View {
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppThemeColors { AppThemeColors(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            PMOfflineBackground()

            ScrollView {
                VStack(spacing: DesignTokens.spacingLG) {
                    if !notificationManager.isAuthorized {
                        permissionWarning
                    }

                    VStack(spacing: 0) {
                        ToggleRow(
                            icon: "calendar.badge.clock",
                            title: "每日计划提醒",
                            color: DesignTokens.primary,
                            isOn: Binding(
                                get: { notificationManager.dailyReminderEnabled },
                                set: { notificationManager.toggleDailyReminder($0) }
                            ),
                            theme: theme
                        )

                        if notificationManager.dailyReminderEnabled {
                            Divider().padding(.leading, 56)
                            timePickerRow(
                                title: "提醒时间",
                                selection: Binding(
                                    get: { notificationManager.dailyReminderTime },
                                    set: { notificationManager.setDailyReminderTime($0) }
                                )
                            )
                            Divider().padding(.leading, 56)
                            ToggleRow(
                                icon: "hourglass",
                                title: "未完成提醒",
                                subtitle: "10:00 - 20:00 每小时",
                                color: DesignTokens.warning,
                                isOn: Binding(
                                    get: { notificationManager.hourlyReminderEnabled },
                                    set: { notificationManager.toggleHourlyReminder($0) }
                                ),
                                theme: theme
                            )
                        }

                        Divider().padding(.leading, 56)

                        ToggleRow(
                            icon: "moon.stars.fill",
                            title: "早睡提醒",
                            color: DesignTokens.primary,
                            isOn: Binding(
                                get: { notificationManager.sleepReminderEnabled },
                                set: { notificationManager.toggleSleepReminder($0) }
                            ),
                            theme: theme
                        )

                        if notificationManager.sleepReminderEnabled {
                            Divider().padding(.leading, 56)
                            timePickerRow(
                                title: "睡觉时间",
                                selection: Binding(
                                    get: { notificationManager.sleepReminderTime },
                                    set: { notificationManager.setSleepReminderTime($0) }
                                )
                            )
                        }
                    }
                    .settingsCardBackground(colorScheme: colorScheme)

                    Text("喝水提醒在喝水页右上角设置。")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding()
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var permissionWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignTokens.warning)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("通知权限未开启")
                    .font(.headline.bold())
                    .foregroundColor(theme.textPrimary)
                Text("开启权限以接收计划和喝水提醒")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Button("去开启") {
                Task {
                    let granted = await notificationManager.requestAuthorization()
                    if !granted, let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(DesignTokens.primary)
        }
        .padding()
        .settingsCardBackground(colorScheme: colorScheme)
    }

    private func timePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .foregroundColor(theme.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding()
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color
    @Binding var isOn: Bool
    let theme: AppThemeColors

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.primary)
        }
        .padding()
    }
}

struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension View {
    func settingsCardBackground(colorScheme: ColorScheme) -> some View {
        background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                )
        )
    }
}

#Preview {
    SettingsView()
        .environment(ThemeManager())
        .environment(NotificationManager())
}
