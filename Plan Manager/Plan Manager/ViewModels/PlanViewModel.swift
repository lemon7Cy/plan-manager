//
//  PlanViewModel.swift
//  Plan Manager
//

import Foundation
import SwiftUI

@Observable
@MainActor
class PlanViewModel {
    var plans: [Plan] = []
    var selectedDate: Date = Date()
    var isLoading = false
    var errorMessage: String?

    private let storage = LocalStorage.shared

    var completedCount: Int {
        plans.filter { $0.isCompleted }.count
    }

    var progress: Double {
        plans.isEmpty ? 0 : Double(completedCount) / Double(plans.count)
    }

    @MainActor
    func loadPlans(showIndicator: Bool = true) async {
        if showIndicator {
            isLoading = true
        }
        errorMessage = nil
        let requestedDate = selectedDate
        let storage = storage
        let loadedPlans = await Task.detached(priority: .userInitiated) {
            storage.loadPlans(for: requestedDate)
        }.value
        guard Calendar.current.isDate(requestedDate, inSameDayAs: selectedDate) else {
            isLoading = false
            return
        }
        plans = loadedPlans
        isLoading = false
    }

    @MainActor
    func createPlan(content: String, isPinned: Bool, tag: String) async {
        _ = storage.createPlan(
            content: content,
            executionDate: selectedDate,
            isPinned: isPinned,
            tag: tag
        )
        await loadPlans(showIndicator: false)
    }

    @MainActor
    func togglePlan(_ plan: Plan) async {
        let id = plan.id
        let newStatus = plan.isCompleted ? "pending" : "completed"

        if let index = plans.firstIndex(where: { $0.id == id }) {
            plans[index].status = newStatus
            storage.updatePlan(plans[index])
        }
    }

    @MainActor
    func togglePinned(_ plan: Plan) async {
        let id = plan.id
        if let index = plans.firstIndex(where: { $0.id == id }) {
            plans[index].isPinned.toggle()
            storage.updatePlan(plans[index])
            await loadPlans(showIndicator: false)
        }
    }

    @MainActor
    func deletePlan(_ plan: Plan) async {
        let id = plan.id
        storage.deletePlan(id: id)
        plans.removeAll { $0.id == id }
    }

    @MainActor
    func setDate(_ date: Date) {
        selectedDate = date
        Task {
            await loadPlans()
        }
    }

    // MARK: - Weekly Navigation Logic

    var currentWeekStart: Date = {
        let calendar = Calendar.current
        let today = Date()
        // Find the start of the current week (e.g. Sunday or Monday depending on locale)
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
    }()

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func nextWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
            currentWeekStart = newDate
            // Optionally select the same weekday in the new week, or keep selectedDate if it's within the new week?
            // User requirement: "swipe to see next week". Usually we don't change selectedDate immediately unless user taps a day.
            // But if we want to show plans for the new week, we might need to select a date in that week?
            // Actually, `selectedDate` drives the plan list. If we swipe the header, we might just be looking at the dates.
            // But usually, swiping the header should probably not change the *selected* date unless the user taps.
            // However, the `weekDayStatusBar` uses `weekStart` derived from `today`. We need to change that to use `currentWeekStart`.
        }
    }

    func prevWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }

    // Jump to today
    func jumpToToday() {
        let calendar = Calendar.current
        let today = Date()
        selectedDate = today
        currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        Task { await loadPlans() }
    }
}
