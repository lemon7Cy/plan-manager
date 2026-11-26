//
//  ExpenseViewModel.swift
//  Plan Manager
//

import Foundation
import SwiftUI

@Observable
@MainActor
class ExpenseViewModel {
    var expenses: [Expense] = []
    var total: Double = 0
    var isLoading = false
    var errorMessage: String?

    var selectedYear: Int?
    var selectedMonth: Int?

    private let storage = LocalStorage.shared

    var filteredExpenses: [Expense] {
        guard selectedYear != nil || selectedMonth != nil else {
            return expenses
        }

        return expenses.filter { expense in
            let calendar = Calendar.current
            let year = calendar.component(.year, from: expense.createdAt)
            let month = calendar.component(.month, from: expense.createdAt)

            if let selectedYear = selectedYear, year != selectedYear { return false }
            if let selectedMonth = selectedMonth, month != selectedMonth { return false }
            return true
        }
    }

    var filteredTotal: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    @MainActor
    func loadExpenses(showIndicator: Bool = true) async {
        if showIndicator {
            isLoading = true
        }
        errorMessage = nil
        let storage = storage
        let loadedExpenses = await Task.detached(priority: .userInitiated) {
            storage.loadExpenses()
        }.value
        expenses = loadedExpenses
        total = expenses.reduce(0) { $0 + $1.amount }
        isLoading = false
    }

    @MainActor
    func createExpense(amount: Double, category: String, note: String?) async {
        let newExpense = storage.createExpense(amount: amount, category: category, note: note)
        expenses.insert(newExpense, at: 0)
        total += amount
    }

    @MainActor
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }

        let amount = expense.amount
        storage.deleteExpense(id: id)
        expenses.removeAll { $0.id == id }
        total -= amount
    }

    func setFilter(year: Int?, month: Int?) {
        selectedYear = year
        selectedMonth = month
    }

    func clearFilter() {
        selectedYear = nil
        selectedMonth = nil
    }
}
