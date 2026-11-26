//
//  ExpenseView.swift
//  Plan Manager
//
//  Professional UI with Micro-interactions Design System
//

import SwiftUI
import Charts

struct ExpenseView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ExpenseViewModel()
    @State private var showAddSheet = false
    @State private var showFilterSheet = false
    @Environment(QuickActionManager.self) private var quickActionManager

    private var theme: AppThemeColors { AppThemeColors(colorScheme: colorScheme) }

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                PMOfflineBackground()

                List {
                    // Header Section (Summary)
                    Section {
                        VStack(spacing: DesignTokens.spacingLG) {
                            summaryCard

                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(DesignTokens.success)
                                    .padding(.top, 60)
                            } else if viewModel.filteredExpenses.isEmpty {
                                emptyState
                            }
                        }
                        .padding(.top, DesignTokens.spacingSM)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // Expense List Section
                    if !viewModel.isLoading && !viewModel.filteredExpenses.isEmpty {
                        ForEach(viewModel.filteredExpenses) { expense in
                            ExpenseRowView(expense: expense, theme: theme, currencyFormatter: currencyFormatter, dateFormatter: dateFormatter) {
                                Task { await viewModel.deleteExpense(expense) }
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
                    await viewModel.loadExpenses(showIndicator: false)
                }

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "yensign", color: DesignTokens.success) {
                            showAddSheet = true
                        }
                        .padding(.trailing, DesignTokens.spacingLG)
                        .padding(.bottom, DesignTokens.spacingMD)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                PMTopBar(
                    title: "消费记录",
                    subtitle: viewModel.selectedYear != nil
                        ? "\(viewModel.selectedYear!)年\(viewModel.selectedMonth ?? 1)月"
                        : "全部记录"
                ) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: viewModel.selectedYear != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
                AddExpenseSheetView(viewModel: viewModel, theme: theme)
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .task {
                await viewModel.loadExpenses()
            }
            .onReceive(NotificationCenter.default.publisher(for: .offlineDataDidChange)) { _ in
                Task {
                    await viewModel.loadExpenses(showIndicator: false)
                }
            }
            .onAppear {
                if quickActionManager.action == .addExpense {
                    showAddSheet = true
                    quickActionManager.action = nil
                }
            }
            .onChange(of: quickActionManager.action) { _, action in
                if action == .addExpense {
                    showAddSheet = true
                    quickActionManager.action = nil
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        PMGlassCard(cornerRadius: 24) {
            VStack(spacing: DesignTokens.spacingMD) {
                ExpenseChartView(
                    expenses: viewModel.filteredExpenses,
                    theme: theme,
                    title: viewModel.selectedYear != nil ? "\(viewModel.selectedYear!)年\(viewModel.selectedMonth ?? 1)月" : "总览"
                )

                HStack(spacing: 8) {
                    PMStatChip(title: "笔数", value: "\(viewModel.filteredExpenses.count)", color: DesignTokens.skyBlue)
                    PMStatChip(title: "总额", value: currencyFormatter.string(from: NSNumber(value: viewModel.filteredTotal)) ?? "¥0", color: DesignTokens.success)
                    PMStatChip(title: "最高分类", value: topCategoryTitle, color: DesignTokens.warning)
                }
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.bottom, DesignTokens.spacingSM)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.28 : 0.68), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: Color(hex: "3BDFFF").opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, DesignTokens.spacingMD)
    }

    // MARK: - Expense List

    // expenseList is now integrated into the main List view to support swipeActions correctly

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            PMIconBadge(systemName: "creditcard", color: DesignTokens.success, size: 60)

            Text(viewModel.selectedYear != nil ? "该时间段暂无消费" : "还没有消费记录")
                .font(.title3.weight(.medium))
                .foregroundColor(theme.textPrimary)

            Text("点击下方按钮记录消费")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)

            Button {
                showAddSheet = true
            } label: {
                Label("记录消费", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(DesignTokens.success, in: Capsule())
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

    private var topCategoryTitle: String {
        let grouped = Dictionary(grouping: viewModel.filteredExpenses) { $0.category }
        let top = grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .max { $0.total < $1.total }
        return top?.category ?? "-"
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            ZStack {
                web3Background

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("时间旅行")
                            .font(.title2.bold())
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Button {
                            showFilterSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(theme.textSecondary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    Spacer()

                    // Time Picker Area
                    HStack(spacing: 0) {
                        // Year Picker
                        Picker("年份", selection: Binding(
                            get: { viewModel.selectedYear ?? Calendar.current.component(.year, from: Date()) },
                            set: { viewModel.setFilter(year: $0, month: viewModel.selectedMonth ?? Calendar.current.component(.month, from: Date())) }
                        )) {
                            ForEach(2020...Calendar.current.component(.year, from: Date()) + 1, id: \.self) { year in
                                Text("\(String(year))").tag(year)
                                    .font(.title3.weight(.medium))
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)
                        .clipped()

                        // Month Picker
                        Picker("月份", selection: Binding(
                            get: { viewModel.selectedMonth ?? Calendar.current.component(.month, from: Date()) },
                            set: { viewModel.setFilter(year: viewModel.selectedYear ?? Calendar.current.component(.year, from: Date()), month: $0) }
                        )) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                                    .font(.title3.weight(.medium))
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)
                        .clipped()
                    }
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.05))
                            .padding(.horizontal, 20)
                    )

                    Spacer()

                    // Bottom Actions
                    HStack(spacing: 20) {
                        // "Now" Button
                        Button {
                            let currentYear = Calendar.current.component(.year, from: Date())
                            let currentMonth = Calendar.current.component(.month, from: Date())
                            viewModel.setFilter(year: currentYear, month: currentMonth)
                        } label: {
                            Text("现在")
                                .font(.headline)
                                .foregroundColor(DesignTokens.skyBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(DesignTokens.skyBlue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }

                        PMPrimaryButton(title: "完成") {
                            showFilterSheet = false
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .presentationDetents([.height(400)])
            .presentationCornerRadius(30)
        }
    }
}

// MARK: - Expense Row View

struct ExpenseRowView: View {
    let expense: Expense
    let theme: AppThemeColors
    let currencyFormatter: NumberFormatter
    let dateFormatter: DateFormatter
    let onDelete: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    private var category: ExpenseCategory {
        ExpenseCategory.from(expense.category)
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Category Icon
            ZStack {
                LinearGradient(colors: category.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMD))

                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }


            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                if let note = expense.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("-" + (currencyFormatter.string(from: NSNumber(value: expense.amount)) ?? ""))
                    .font(.headline)
                    .foregroundColor(DesignTokens.error)

                Text(dateFormatter.string(from: expense.createdAt))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.26 : 0.72), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(hex: "2B4AFF").opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 6, x: 0, y: 3)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Expense Sheet

struct AddExpenseSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ExpenseViewModel
    let theme: AppThemeColors

    @State private var amount = ""
    @State private var selectedCategory = ExpenseCategory.food
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PMOfflineBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                        sheetHeader
                        amountPanel
                        categoryPanel
                        notePanel
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingLG)
                    .padding(.bottom, 92)
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                amountFocused = true
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            PMIconBadge(systemName: "yensign", color: DesignTokens.primary, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("记录消费")
                    .font(.title2.weight(.bold))
                    .foregroundColor(theme.textPrimary)

                Text(selectedCategory.rawValue)
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.56), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var amountPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("金额")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(DesignTokens.primary)

                TextField("0.00", text: $amount)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .onChange(of: amount) { _, value in
                        amount = sanitizedAmount(value)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.58), lineWidth: 1)
                    )
            )

            HStack(spacing: 8) {
                ForEach(["12", "28", "58", "128"], id: \.self) { value in
                    Button {
                        amount = value
                    } label: {
                        Text("¥\(value)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.56))
                            )
                        }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(sheetPanelFill)
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ExpenseCategory.allCases, id: \.rawValue) { category in
                    ExpenseCategoryTile(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(sheetPanelFill)
    }

    private var notePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textSecondary)

            TextField("可选", text: $note)
                .font(.body.weight(.medium))
                .foregroundColor(theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMD, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
                )
        }
        .padding(DesignTokens.spacingMD)
        .background(sheetPanelFill)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.58))
                    )
            }
            .buttonStyle(.plain)

            PMPrimaryButton(title: "保存", icon: "checkmark", isDisabled: !canSave) {
                saveExpense()
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var sheetPanelFill: some View {
        RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLG, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.58), lineWidth: 1)
            )
    }

    private var amountValue: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amountValue else { return false }
        return amountValue > 0
    }

    private func sanitizedAmount(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        var output = ""
        var hasDecimalSeparator = false
        var decimalCount = 0

        for character in normalized {
            if character.isNumber {
                if hasDecimalSeparator {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                output.append(character)
            } else if character == ".", !hasDecimalSeparator {
                hasDecimalSeparator = true
                output.append(character)
            }
        }

        if output.count > 9 {
            output = String(output.prefix(9))
        }
        return output
    }

    private func saveExpense() {
        guard let amountValue, amountValue > 0 else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        Task {
            await viewModel.createExpense(
                amount: amountValue,
                category: selectedCategory.rawValue,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            )
            dismiss()
        }
    }
}

private struct ExpenseCategoryTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isSelected ? .white : category.colors[0])
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: category.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(category.colors[0].opacity(colorScheme == .dark ? 0.16 : 0.12)),
                        in: Circle()
                    )

                Text(category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? DesignTokens.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD, style: .continuous)
                    .fill(isSelected ? DesignTokens.primary.opacity(colorScheme == .dark ? 0.18 : 0.12) : Color.white.opacity(colorScheme == .dark ? 0.05 : 0.50))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMD, style: .continuous)
                            .stroke(isSelected ? DesignTokens.primary.opacity(0.55) : Color.white.opacity(colorScheme == .dark ? 0.10 : 0.52), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExpenseView()
        .environment(QuickActionManager())
}

// MARK: - Expense Chart View

struct ExpenseChartData: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let amount: Double

    var color: Color {
        category.colors.first ?? DesignTokens.primary
    }
}

struct ExpenseChartView: View {
    let expenses: [Expense]
    let theme: AppThemeColors
    var title: String? = nil

    // Group expenses by category and sum amounts
    private var data: [ExpenseChartData] {
        let grouped = Dictionary(grouping: expenses) { ExpenseCategory.from($0.category) }
        return grouped.map { category, expenses in
            ExpenseChartData(
                category: category,
                amount: expenses.reduce(0) { $0 + $1.amount }
            )
        }.sorted { $0.amount > $1.amount }
    }

    private var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Header with Title
            if let title = title {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.headline)
                        .foregroundColor(DesignTokens.accentMint)
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
            }

            HStack(spacing: DesignTokens.spacingMD) {
                // Donut Chart
                if data.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(DesignTokens.cleanGray.opacity(0.16), lineWidth: 16)
                        Text("¥0")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(width: 140, height: 140)
                } else {
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.65),
                            angularInset: 2.0
                        )
                        .cornerRadius(6)
                        .foregroundStyle(item.color)
                    }
                    .frame(width: 140, height: 140)
                    .chartBackground { proxy in
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Text("Total")
                                    .font(.caption.bold())
                                    .foregroundColor(theme.textSecondary)
                                Text("¥\(Int(totalAmount))")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                }

                // Legend / List
                VStack(alignment: .leading, spacing: 12) {
                    if data.isEmpty {
                        Text("No expenses yet")
                            .foregroundColor(theme.textSecondary)
                            .font(.subheadline)
                    } else {
                        ForEach(data.prefix(4)) { item in
                            HStack {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)

                                Text(item.category.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(theme.textPrimary)

                                Spacer()

                                Text("¥\(Int(item.amount))")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DesignTokens.spacingLG)
    }
}

private extension ExpenseView {
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
                .fill(Color(hex: "5B7BFF").opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: -150, y: 320)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
