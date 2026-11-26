//
//  PlanView.swift
//  Plan Manager
//
//  Professional UI with Micro-interactions Design System
//

import SwiftUI
import UIKit

struct PlanView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = PlanViewModel()
    @Environment(NotificationManager.self) private var notificationManager
    @State private var showAddSheet = false
    @State private var showDatePicker = false
    @State private var newPlanContent = ""
    @State private var newPlanPinned = false
    @State private var newPlanTag = ""
    @State private var showPinnedOnly = false
    @State private var selectedTagFilter: String?

    private var theme: AppThemeColors { AppThemeColors(colorScheme: colorScheme) }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US") // Modern English Date looks cleaner
        f.dateFormat = "MMM d"
        return f
    }()

    @Environment(QuickActionManager.self) private var quickActionManager

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack {
                PMOfflineBackground()

                Circle()
                    .fill(Color(hex: "4CE0FF").opacity(colorScheme == .dark ? 0.14 : 0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 40)
                    .offset(x: 120, y: -280)
                    .allowsHitTesting(false)

                List {
                    // Header Section (Summary)
                    Section {
                        VStack(spacing: DesignTokens.spacingLG) {
                            summaryCard

                            if !viewModel.isLoading && !viewModel.plans.isEmpty {
                                filterBar
                            }

                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(DesignTokens.primary)
                                    .padding(.top, 60)
                            } else if viewModel.plans.isEmpty {
                                emptyState
                            } else if filteredPlans.isEmpty {
                                filteredEmptyState
                            }
                        }
                        .padding(.top, DesignTokens.spacingSM)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // Plan List Section
                    if !viewModel.isLoading && !viewModel.plans.isEmpty {
                        ForEach(filteredPlans) { plan in
                            PlanRowView(plan: plan, theme: theme, isEditable: viewModel.isToday) {
                                Task { await viewModel.togglePlan(plan) }
                            } onTogglePinned: {
                                Task { await viewModel.togglePinned(plan) }
                            } onDelete: {
                                Task { await viewModel.deletePlan(plan) }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: DesignTokens.spacingMD, bottom: 8, trailing: DesignTokens.spacingMD))
                        }
                    }

                    // Content Spacer for FAB
                    Section {
                        Color.clear.frame(height: 80)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // Allow ZStack background to show
                .refreshable {
                    await viewModel.loadPlans(showIndicator: false)
                }

                // Floating Action Button (Clean Minimal Style)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1B3A57"))
                                .frame(width: 56, height: 56)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.72), .white.opacity(0.22)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.2
                                        )
                                )
                                .clipShape(Circle())
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
                        }
                        .padding(.trailing, DesignTokens.spacingLG)
                        .padding(.bottom, DesignTokens.spacingMD)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                PMTopBar(title: viewModel.isToday ? "今天" : "计划", subtitle: dateFormatter.string(from: viewModel.selectedDate)) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignTokens.skyBlue)
                            .frame(width: 42, height: 42)
                            .background(.regularMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                            )
                            .shadow(color: DesignTokens.softShadow(for: colorScheme), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addPlanSheet
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .task {
                await viewModel.loadPlans()
                syncHourlyReminderState()
            }
            .onReceive(NotificationCenter.default.publisher(for: .offlineDataDidChange)) { _ in
                Task {
                    await viewModel.loadPlans(showIndicator: false)
                    syncHourlyReminderState()
                }
            }
            .onAppear {
                if quickActionManager.action == .addPlan {
                    showAddSheet = true
                    quickActionManager.action = nil
                }
            }
            .onChange(of: quickActionManager.action) { _, action in
                if action == .addPlan {
                    showAddSheet = true
                    quickActionManager.action = nil
                }
            }
        }
        .onChange(of: viewModel.plans) { _, _ in
            syncHourlyReminderState()
        }

        // Error Alert
        .alert("出错了", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("好") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Summary Card (Clean Minimal Style)

    private func syncHourlyReminderState() {
        let plans = viewModel.plans
        let allCompleted = !plans.isEmpty && plans.allSatisfy { $0.isCompleted }
        notificationManager.updatePlanCompletionStatus(
            planCount: plans.count,
            isAllCompleted: allCompleted
        )
    }

    private var sortedPlans: [Plan] {
        viewModel.plans.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var filteredPlans: [Plan] {
        sortedPlans.filter { plan in
            let passPinned = !showPinnedOnly || plan.isPinned
            let passTag = selectedTagFilter == nil || plan.tag == selectedTagFilter
            return passPinned && passTag
        }
    }

    private var availableTags: [String] {
        Array(Set(viewModel.plans.map { $0.tag.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
        .sorted()
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(
                    title: "全部",
                    isActive: !showPinnedOnly && selectedTagFilter == nil
                ) {
                    showPinnedOnly = false
                    selectedTagFilter = nil
                }

                filterChip(
                    title: "置顶",
                    isActive: showPinnedOnly
                ) {
                    showPinnedOnly.toggle()
                }

                ForEach(availableTags, id: \.self) { tag in
                    filterChip(
                        title: "#\(tag)",
                        isActive: selectedTagFilter == tag
                    ) {
                        selectedTagFilter = (selectedTagFilter == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func filterChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? Color.white : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isActive
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [DesignTokens.primary, DesignTokens.accentCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isActive ? 0.25 : (colorScheme == .dark ? 0.18 : 0.5)), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        let summaryFill = colorScheme == .dark
            ? Color(hex: "17304B").opacity(0.50)
            : Color.white.opacity(0.58)

        return VStack(spacing: DesignTokens.spacingMD) {
            weekDayStatusBar
                .padding(.horizontal, 6)

            centralProgressRing
                .padding(.horizontal, 10)

            HStack(spacing: 8) {
                PMStatChip(title: "总数", value: "\(viewModel.plans.count)", color: DesignTokens.skyBlue)
                PMStatChip(title: "完成", value: "\(viewModel.completedCount)", color: DesignTokens.success)
                PMStatChip(title: "置顶", value: "\(viewModel.plans.filter { $0.isPinned }.count)", color: DesignTokens.warning)
            }

            if !viewModel.plans.isEmpty {
                Text(viewModel.progress >= 1.0 ? "太棒了！所有任务都完成了 🎉" : "加油！继续完成今日计划")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .background(summaryFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.42), lineWidth: 0.8)
        )
        .padding(.horizontal, DesignTokens.spacingMD)
    }

    // MARK: - Week Day Status Bar

    private var weekDayStatusBar: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = viewModel.currentWeekStart // Use ViewModel's current week start

        return VStack(spacing: 0) {
            // Week Header (Month/Year display optional, or just rely on the days)
            // Maybe show range? e.g. "Feb 5 - Feb 11"

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                    let dayNumber = calendar.component(.day, from: date)
                    let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
                    let isToday = calendar.isDateInToday(date) // Check if this specific day is today

                    let selectedFill = colorScheme == .dark
                        ? AnyShapeStyle(Color.white.opacity(0.08))
                        : AnyShapeStyle(.thinMaterial)

                    Button {
                        viewModel.setDate(date)
                    } label: {
                        VStack(spacing: 8) {
                            // Weekday Name (e.g. Mon, Tue)
                            Text(dateFormatter.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1])
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.textSecondary)

                            // Day Number
                            Text("\(dayNumber)")
                                .font(.system(size: 15, weight: isToday ? .bold : .medium)) // Highlight Today
                                .foregroundColor(isToday ? DesignTokens.info : theme.textPrimary)

                            // Vivid 3D-Style Icon (Sun/Cloud Face)
                            vividDayIcon(date: date, isSelected: isSelected)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            // Highlight selected day background?
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? selectedFill : AnyShapeStyle(Color.clear))
                                .shadow(color: isSelected ? Color.black.opacity(0.04) : .clear, radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DesignTokens.spacingSM)
            .contentShape(Rectangle()) // Make the whole area swipeable
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -50 {
                            // Swipe Left -> Next Week
                            withAnimation {
                                viewModel.nextWeek()
                            }
                        } else if value.translation.width > 50 {
                            // Swipe Right -> Prev Week
                            withAnimation {
                                viewModel.prevWeek()
                            }
                        }
                    }
            )

            // "Return to Today" indicator if not in current week
            if !Calendar.current.isDate(today, equalTo: viewModel.currentWeekStart, toGranularity: .weekOfYear) {
                Button {
                    withAnimation {
                        viewModel.jumpToToday()
                    }
                } label: {
                    Text("回到本周")
                        .font(.caption.bold())
                        .foregroundColor(DesignTokens.primary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(DesignTokens.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // Vivid 3D-Style Icon for week day status
    private func vividDayIcon(date: Date, isSelected: Bool) -> some View {
        // Placeholder Status Logic (simulation)
        let isPerfect = viewModel.progress >= 1.0 // In real app, check progress for specific date

        // Icon Selection
        let iconName = isSelected ? (isPerfect ? "sun.max.fill" : "cloud.sun.fill") : "cloud.fill"

        // Gradient Colors
        let gradientColors: [Color] = isSelected
            ? (isPerfect ? [Color(hex: "FFD700"), Color(hex: "FFA500")] : [Color(hex: "87CEEB"), Color(hex: "4682B4")])
            : [DesignTokens.cleanGray.opacity(0.3), DesignTokens.cleanGray.opacity(0.4)]

        return Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .font(.system(size: 24))
        .scaleEffect(isSelected ? 1.08 : 1.0)
    }


    // MARK: - Central Progress Ring (Compact & Animated)

    private var centralProgressRing: some View {
        let progressGradient = LinearGradient(
            colors: [Color(hex: "FFD700"), Color(hex: "FFA500"), Color(hex: "FF6347")],
            startPoint: .leading,
            endPoint: .trailing
        )

        return VStack(spacing: 0) {
            ZStack {
                // Background Track (Dashed)
                Circle()
                    .trim(from: 0.15, to: 0.85) // Open bottom arc (approx 250 degrees)
                    .stroke(
                        DesignTokens.cleanGray.opacity(0.15),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round, dash: [1, 3])
                    )
                    .rotationEffect(.degrees(90)) // Rotate to open at bottom

                // Solid Background Track Base
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        DesignTokens.cleanGray.opacity(0.1),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))

                // Progress Arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + (viewModel.plans.isEmpty ? 0 : viewModel.progress * 0.7)) // Max fill is 0.7 (70% of circle = 252 deg)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .shadow(color: Color(hex: "FFD700").opacity(0.14), radius: 4, x: 0, y: 0)

                // Center Content
                VStack(spacing: 0) {
                    // Weather/Status Icon (Small top icon inside ring)
                    Image(systemName: viewModel.progress >= 1.0 ? "star.fill" : "cloud.sun.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "B0C4DE"), Color(hex: "708090")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 1)
                        .padding(.bottom, 4)

                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "2C3E50")) // Dark Blue-Gray for high contrast
                        .shadow(color: .white, radius: 0, x: 1, y: 1)

                    Text(viewModel.progress >= 1.0 ? "Perfect Day" : "Keep Going")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(DesignTokens.cleanGray)
                }
                .offset(y: -5)
            }
            .frame(width: 126, height: 126)

            // Vivid Animated Emoji at bottom
            ZStack {
                Text(viewModel.progress >= 1.0 ? "🤩" : (viewModel.progress > 0.5 ? "😎" : "🙂"))
                    .font(.system(size: 32))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
            }
            .offset(y: -12)
        }
    }

    // MARK: - Plan List

    // MARK: - Plan List

    // planList is now integrated into the main List view to support swipeActions correctly

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            PMIconBadge(systemName: "checkmark.circle", color: DesignTokens.skyBlue, size: 60)

            Text("今天还没有计划")
                .font(.title3.weight(.medium))
                .foregroundColor(theme.textPrimary)

            Text("点击下方按钮添加你的第一个计划")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("添加计划", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(DesignTokens.primary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusXL, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusXL, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignTokens.spacingMD)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            PMIconBadge(systemName: "line.3.horizontal.decrease.circle", color: DesignTokens.skyBlue, size: 54)

            Text("没有符合筛选的计划")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textPrimary)

            Button {
                showPinnedOnly = false
                selectedTagFilter = nil
            } label: {
                Text("清除筛选")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignTokens.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DesignTokens.primary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusXL, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusXL, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignTokens.spacingMD)
    }

    // MARK: - Add Plan Sheet

    private var addPlanSheet: some View {
        NavigationStack {
            ZStack {
                // Background
                FluidGradientBackground(
                    colors: colorScheme == .dark
                    ? [Color(hex: "0E1726"), Color(hex: "1B2A44"), Color(hex: "0F3B4A"), Color(hex: "111827")]
                    : [Color(hex: "EAF5FF"), Color(hex: "D9EEFF"), Color(hex: "EAFDF6"), Color(hex: "F7FAFF")]
                )

                VStack(spacing: DesignTokens.spacingLG) {
                    Spacer()

                    // Header Illustration/Icon
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.skyBlue, DesignTokens.skyBlue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                        )
                    .shadow(color: DesignTokens.skyBlue.opacity(0.22), radius: 8, x: 0, y: 4)
                        .padding(.top, DesignTokens.spacingLG)

                    Text("开始新计划")
                        .font(.title.weight(.black))
                        .foregroundColor(theme.textPrimary)

                    // Input Card
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("接下来要做什么？", text: $newPlanContent)
                            .font(.title3.weight(.medium))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding()
                            .background(
                                colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.03)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMD))

                        Toggle(isOn: $newPlanPinned) {
                            HStack(spacing: 10) {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(DesignTokens.warning)
                                    .frame(width: 26, height: 26)
                                    .background(DesignTokens.warning.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("置顶")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(theme.textPrimary)
                                    Text("重要计划会固定在列表前面")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                        .tint(DesignTokens.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.03),
                            in: RoundedRectangle(cornerRadius: 12)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("标签（可选）")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(theme.textSecondary)
                            TextField("例如：工作 / 学习 / 健康", text: $newPlanTag)
                                .font(.body.weight(.medium))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLG))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.62), lineWidth: 1)
                    )
                    .shadow(color: DesignTokens.softShadow(for: colorScheme), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    Spacer()

                    // Action Buttons
                    HStack(spacing: DesignTokens.spacingMD) {
                        Button {
                            showAddSheet = false
                            newPlanContent = ""
                            newPlanPinned = false
                            newPlanTag = ""
                        } label: {
                            Text("取消")
                                .font(.headline.bold())
                                .foregroundColor(theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.clear)
                        }

                        PMPrimaryButton(
                            title: "确认",
                            isDisabled: newPlanContent.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                            Task {
                                await viewModel.createPlan(
                                    content: newPlanContent,
                                    isPinned: newPlanPinned,
                                    tag: newPlanTag.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                                showAddSheet = false
                                newPlanContent = ""
                                newPlanPinned = false
                                newPlanTag = ""
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, DesignTokens.spacingXL)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("选择日期", selection: Binding(
                get: { viewModel.selectedDate },
                set: { viewModel.setDate($0) }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .tint(DesignTokens.skyBlue)
            .padding()
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Plan Row View

struct PlanRowView: View {
    let plan: Plan
    let theme: AppThemeColors
    let isEditable: Bool // New property
    let onToggle: () -> Void
    let onTogglePinned: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let rowFill = colorScheme == .dark
            ? Color(hex: "17304B").opacity(0.55)
            : Color.white.opacity(0.62)

        HStack(spacing: DesignTokens.spacingMD) {
            // Checkbox
            Button {
                UIImpactFeedbackGenerator(style: plan.isCompleted ? .light : .medium).impactOccurred()
                onToggle()
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            plan.isCompleted ? DesignTokens.success : DesignTokens.skyBlue,
                            lineWidth: 3
                        )
                        .frame(width: 28, height: 28)

                    if plan.isCompleted {
                        Circle()
                            .fill(DesignTokens.success)
                            .frame(width: 20, height: 20)

                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEditable) // Disable if not editable
            .opacity(isEditable ? 1.0 : 0.5) // Visual cue

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if plan.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.warning)
                    }

                    Text(plan.content)
                        .font(.body.weight(.medium))
                        .foregroundColor(plan.isCompleted ? theme.textSecondary : theme.textPrimary)
                        .strikethrough(plan.isCompleted, color: theme.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if plan.isPinned {
                        pinnedBadge
                    }
                    if !plan.tag.isEmpty {
                        tagBadge
                    }
                }
            }

            Spacer()
        }
        .padding(DesignTokens.spacingMD + 2)
        .background(rowFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "A5EFFF").opacity(colorScheme == .dark ? 0.38 : 0.58), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isEditable { // Only show delete if editable
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if isEditable {
                Button {
                    onTogglePinned()
                } label: {
                    Label(plan.isPinned ? "取消置顶" : "置顶", systemImage: plan.isPinned ? "pin.slash" : "pin")
                }
                .tint(DesignTokens.warning)
            }
        }
    }

    private var pinnedBadge: some View {
        Text("置顶")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DesignTokens.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignTokens.warning.opacity(0.16), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignTokens.warning.opacity(0.22), lineWidth: 0.8)
            )
    }

    private var tagBadge: some View {
        Text("#\(plan.tag)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color(hex: "4B5D73"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.45)), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.55), lineWidth: 0.8)
            )
    }
}

#Preview {
    PlanView()
        .environment(NotificationManager())
        .environment(QuickActionManager())
}
