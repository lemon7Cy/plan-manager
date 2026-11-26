//
//  WaterView.swift
//  Plan Manager
//
//  Professional UI with Micro-interactions Design System
//

import SwiftUI
import UserNotifications
import UIKit

struct WaterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(NotificationManager.self) private var notificationManager
    @State private var viewModel = WaterViewModel()
    @State private var showSettingsSheet = false
    @State private var selectedDrink: DrinkType?
    @State private var amount: Int = 250
    @State private var amountInput: String = "250"

    private var theme: AppThemeColors { AppThemeColors(colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                PMOfflineBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.spacingLG) {
                        progressCard

                        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                            Text("快速添加")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)

                            drinkGrid
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                            Text("今日记录")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)

                            if viewModel.records.isEmpty {
                                emptyRecords
                            } else {
                                recordsList
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingSM)
                    .padding(.bottom, 50)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                PMTopBar(title: "喝水记录", subtitle: "今日 \(viewModel.todayTotal)ml / 目标 \(viewModel.dailyGoal)ml") {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: notificationManager.waterReminderEnabled ? "bell.badge.fill" : "bell.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(notificationManager.waterReminderEnabled ? .white : DesignTokens.skyBlue)
                            .frame(width: 42, height: 42)
                            .background(
                                notificationManager.waterReminderEnabled
                                    ? AnyShapeStyle(DesignTokens.skyBlue)
                                    : AnyShapeStyle(.regularMaterial),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                            )
                            .shadow(color: DesignTokens.softShadow(for: colorScheme), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .sheet(item: $selectedDrink) { drink in
                addAmountSheet(drink: drink)
            }
            .sheet(isPresented: $showSettingsSheet) {
                waterSettingsSheet
            }
            .onReceive(NotificationCenter.default.publisher(for: .offlineDataDidChange)) { _ in
                viewModel.loadData()
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        PMGlassCard(cornerRadius: 24) {
            VStack(spacing: DesignTokens.spacingMD) {
                HStack(spacing: DesignTokens.spacingLG) {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        Text("今日饮水")
                            .foregroundColor(theme.textSecondary)

                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(viewModel.todayTotal)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(DesignTokens.info)

                            Text("ml")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .padding(.bottom, 8)
                        }

                        Text("目标 \(viewModel.dailyGoal) ml")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    ProgressRingView(
                        progress: viewModel.progress,
                        size: 95,
                        lineWidth: 10,
                        gradient: LinearGradient(
                            colors: [DesignTokens.info, DesignTokens.accentCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }

                HStack(spacing: 8) {
                    PMStatChip(title: "剩余", value: "\(max(viewModel.dailyGoal - viewModel.todayTotal, 0)) ml", color: DesignTokens.info)
                    PMStatChip(title: "记录", value: "\(viewModel.records.count)", color: DesignTokens.skyBlue)
                    PMStatChip(title: "完成度", value: "\(Int(viewModel.progress * 100))%", color: DesignTokens.success)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.28 : 0.66), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: Color(hex: "45D6FF").opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 12, x: 0, y: 6)
    }

    // MARK: - Drink Grid

    private var drinkGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.spacingMD), count: 4), spacing: DesignTokens.spacingMD) {
            ForEach(DrinkType.all) { drink in
                drinkButton(drink)
            }
        }
    }

    private func drinkButton(_ drink: DrinkType) -> some View {
        Button {
            selectedDrink = drink
            amount = drink.defaultAmount
            amountInput = "\(drink.defaultAmount)"
            triggerHaptic(.light)
        } label: {
            VStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: drink.icon)
                    .font(.title2.weight(.bold))
                    .foregroundColor(drink.color)

                Text(drink.name)
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                    .fill(colorScheme == .dark ? drink.color.opacity(0.17) : drink.color.opacity(0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.58), lineWidth: 1)
                    )
                    .shadow(color: drink.color.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 6, x: 0, y: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLG))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Records List

    private var recordsList: some View {
        LazyVStack(spacing: DesignTokens.spacingSM) {
            ForEach(viewModel.records) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: WaterRecord) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: record.iconName)
                .font(.title3)
                .foregroundColor(record.color)
                .frame(width: 42, height: 42)
                .background(record.color.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(record.type)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.textPrimary)

                Text(formatTime(record.time))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Text("\(record.amount) ml")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignTokens.info)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.58), lineWidth: 1)
                )
                .shadow(color: Color(hex: "3A74FF").opacity(colorScheme == .dark ? 0.10 : 0.05), radius: 6, x: 0, y: 3)
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteRecord(record)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var emptyRecords: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            PMIconBadge(systemName: "drop", color: DesignTokens.info, size: 54)

            Text("还没有记录")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.spacingXL)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusXL)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusXL)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.56), lineWidth: 1)
                )
        )
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // MARK: - Add Amount Sheet

    private func addAmountSheet(drink: DrinkType) -> some View {
        NavigationStack {
            ZStack {
                web3Background

                VStack(spacing: DesignTokens.spacingMD) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: drink.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(drink.color)
                            Text(drink.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                        Text("自定义添加喝水量")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingSM)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(displayAmount)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Text("ml")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(DesignTokens.skyBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.bottom, 4)

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            amountKey("1")
                            amountKey("2")
                            amountKey("3")
                            amountIconKey(systemName: "delete.left", role: .delete)
                        }
                        HStack(spacing: 10) {
                            amountKey("4")
                            amountKey("5")
                            amountKey("6")
                            amountIconKey(systemName: "xmark", role: .clear)
                        }
                        HStack(spacing: 10) {
                            amountKey("7")
                            amountKey("8")
                            amountKey("9")
                            amountKey("+50", role: .plus50)
                        }
                        HStack(spacing: 10) {
                            amountKey("0")
                            amountKey("00")
                            amountKey("+100", role: .plus100)
                            Button {
                                confirmAdd(drink: drink)
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 62)
                                    .background(isAmountValid ? DesignTokens.skyBlue : DesignTokens.cleanGray.opacity(0.42))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isAmountValid)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.bottom, DesignTokens.spacingLG)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                        )
                )
                .padding(DesignTokens.spacingMD)
            }
            .navigationTitle("添加喝水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        selectedDrink = nil
                    }
                    .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        confirmAdd(drink: drink)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.primary)
                    .disabled(!isAmountValid)
                }
            }
        }
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
    }

    private var displayAmount: String {
        amountInput.isEmpty ? "0" : amountInput
    }

    private var isAmountValid: Bool {
        guard let value = Int(amountInput) else { return false }
        return value > 0
    }

    private enum AmountKeyRole {
        case append
        case delete
        case clear
        case plus50
        case plus100
    }

    @ViewBuilder
    private func amountKey(_ title: String, role: AmountKeyRole = .append) -> some View {
        Button {
            switch role {
            case .append:
                appendAmountText(title)
            case .plus50:
                increaseAmount(by: 50)
            case .plus100:
                increaseAmount(by: 100)
            case .delete, .clear:
                break
            }
        } label: {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(hex: "E9EEF6"))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func amountIconKey(systemName: String, role: AmountKeyRole) -> some View {
        Button {
            switch role {
            case .delete:
                deleteAmountText()
            case .clear:
                clearAmountText()
            case .append, .plus50, .plus100:
                break
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(hex: "E9EEF6"))
                )
        }
        .buttonStyle(.plain)
    }

    private func appendAmountText(_ text: String) {
        let newValue = amountInput + text
        let digitsOnly = newValue.filter { $0.isNumber }
        amountInput = String(digitsOnly.prefix(4))
        if amountInput == "0" { amountInput = "" }
        triggerHaptic(.light)
    }

    private func increaseAmount(by value: Int) {
        let current = Int(amountInput) ?? 0
        let next = min(9999, current + value)
        amountInput = "\(next)"
        triggerHaptic(.light)
    }

    private func deleteAmountText() {
        guard !amountInput.isEmpty else { return }
        amountInput.removeLast()
        triggerHaptic(.light)
    }

    private func clearAmountText() {
        amountInput = ""
        triggerHaptic(.medium)
    }

    private func confirmAdd(drink: DrinkType) {
        guard let input = Int(amountInput), input > 0 else { return }
        amount = input
        viewModel.addRecord(drinkType: drink, amount: input)
        triggerSuccessHaptic()
        selectedDrink = nil
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    // MARK: - Settings Sheet

    // MARK: - Water Settings Sheet (Clean Minimal Style)

    private var waterSettingsSheet: some View {
        NavigationStack {
            ZStack {
                web3Background

                VStack(spacing: DesignTokens.spacingLG) {
                    // Header
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundColor(DesignTokens.info)
                        Text("喝水设置")
                            .font(.title2.weight(.black))
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Button {
                            showSettingsSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(theme.textSecondary)
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                                )
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, DesignTokens.spacingLG)
                    .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: DesignTokens.spacingLG) {

                            // Daily Goal Section
                            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                                Text("每日目标")
                                    .font(.headline)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.leading, 4)

                                HStack {
                                    Text("目标水量")
                                        .font(.body)
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Picker("目标量", selection: Binding(
                                        get: { viewModel.dailyGoal },
                                        set: { viewModel.updateSettings(dailyGoal: $0) }
                                    )) {
                                        ForEach([1000, 1500, 2000, 2500, 3000, 3500, 4000], id: \.self) { ml in
                                            Text("\(ml) ml").tag(ml)
                                        }
                                    }
                                    .tint(DesignTokens.primary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal)

                            // Reminder Settings Section
                            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                                Text("提醒设置")
                                    .font(.headline)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.leading, 4)

                                VStack(spacing: 0) {
                                    Toggle(isOn: Binding(
                                        get: { notificationManager.waterReminderEnabled },
                                        set: { enabled in
                                            if enabled {
                                                Task {
                                                    _ = await notificationManager.requestAuthorization()
                                                    await MainActor.run {
                                                        notificationManager.toggleWaterReminder(true)
                                                    }
                                                }
                                            } else {
                                                notificationManager.toggleWaterReminder(false)
                                            }
                                        }
                                    )) {
                                        Text("开启提醒")
                                            .font(.body)
                                            .foregroundColor(theme.textPrimary)
                                    }
                                    .padding()
                                    .tint(DesignTokens.primary)

                                    if notificationManager.waterReminderEnabled {
                                        Divider().padding(.leading)

                                        HStack {
                                            Text("开始时间")
                                                .font(.body)
                                                .foregroundColor(theme.textPrimary)
                                            Spacer()
                                            Picker("开始时间", selection: Binding(
                                                get: { notificationManager.waterStartHour },
                                                set: { hour in
                                                    notificationManager.updateWaterSettings(
                                                        startHour: hour,
                                                        intervalMinutes: notificationManager.waterInterval
                                                    )
                                                }
                                            )) {
                                                ForEach(6...22, id: \.self) { hour in
                                                    Text("\(hour):00").tag(hour)
                                                }
                                            }
                                            .tint(DesignTokens.primary)
                                        }
                                        .padding()

                                        Divider().padding(.leading)

                                        HStack {
                                            Text("提醒间隔")
                                                .font(.body)
                                                .foregroundColor(theme.textPrimary)
                                            Spacer()
                                            Picker("提醒间隔", selection: Binding(
                                                get: { notificationManager.waterInterval },
                                                set: { interval in
                                                    notificationManager.updateWaterSettings(
                                                        startHour: notificationManager.waterStartHour,
                                                        intervalMinutes: interval
                                                    )
                                                }
                                            )) {
                                                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                                                    Text("\(mins) 分钟").tag(mins)
                                                }
                                            }
                                            .tint(DesignTokens.primary)
                                        }
                                        .padding()
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal)

                            if notificationManager.waterReminderEnabled {
                                 Button {
                                    sendTestNotification()
                                } label: {
                                    HStack {
                                        Image(systemName: "bell.badge.fill")
                                        Text("发送测试通知")
                                    }
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(DesignTokens.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(DesignTokens.primary.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    Spacer()

                    PMPrimaryButton(title: "完成") {
                        showSettingsSheet = false
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(30)
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "💧 喝水提醒"
        content.body = "该喝水啦！今日已喝 \(viewModel.todayTotal) ml，目标 \(viewModel.dailyGoal) ml"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}

#Preview {
    WaterView()
}

private extension WaterView {
    var web3Background: some View {
        ZStack {
            FluidGradientBackground(
                colors: colorScheme == .dark
                ? [Color(hex: "060B16"), Color(hex: "0B1A33"), Color(hex: "0A3340"), Color(hex: "111827")]
                : [Color(hex: "DCEBFF"), Color(hex: "CFE3FF"), Color(hex: "D9FCFF"), Color(hex: "ECF6FF")]
            )

            Circle()
                .fill(Color(hex: "4CE0FF").opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 120, y: -280)
                .allowsHitTesting(false)

            Circle()
                .fill(Color(hex: "2A56FF").opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: -160, y: 320)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
