import SwiftUI

struct FitnessLogView: View {
    var store: FitnessStore
    var plan: FitnessPlan
    var manual = false
    @Environment(\.dismiss) private var dismiss
    @State private var results: [FitnessResult]
    @State private var error: String?
    @State private var confirm = false

    init(store: FitnessStore, plan: FitnessPlan, manual: Bool = false) {
        self.store = store; self.plan = plan; self.manual = manual
        _results = State(initialValue: plan.exercises.map { exercise in
            FitnessResult(exercise: exercise, sets: (0..<exercise.sets).map { _ in FitnessSet(weight: exercise.weight) })
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(plan.date.formatted(date: .abbreviated, time: .omitted)) · 仅保存你实际完成的训练")
                    Text("先填写每组实际重量与次数，再勾选完成。没有做的组不勾选；出现疼痛，即使没完成也请记录。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach($results) { $result in
                    Section(result.exercise.equipment.name) {
                        ForEach(Array(result.sets.indices), id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("第 \(index + 1) 组已完成", isOn: $result.sets[index].completed)
                                HStack {
                                    if !result.exercise.equipment.movement.bodyweight {
                                        TextField("实际重量", value: $result.sets[index].weight, format: .number)
                                            .keyboardType(.decimalPad)
                                        Text(result.exercise.equipment.unit.rawValue).foregroundStyle(.secondary)
                                    }
                                    TextField("次数", value: $result.sets[index].reps, format: .number).keyboardType(.numberPad)
                                    Text("次").foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 4)
                        }
                        Picker("体感", selection: $result.effort) { ForEach(FitnessEffort.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented)
                        Toggle("这个动作出现疼痛", isOn: $result.pain).tint(.orange)
                        TextField("反馈，例如最后两次比较吃力", text: $result.note, axis: .vertical)
                    }
                }
                Section {
                    Button("完成并保存反馈") { confirm = true }.accessibilityIdentifier("fitness.feedback.save")
                    Text("保存后作为实际训练历史保留，后续未完成计划需重新生成。请核对重量单位和已完成组。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("记录训练")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .confirmationDialog("保存实际训练记录？", isPresented: $confirm, titleVisibility: .visible) {
                Button("保存反馈") {
                    do {
                        let session = FitnessSession(plan: plan, results: results)
                        if manual { try store.recordManual(session) } else { try store.finish(session) }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
            .fitnessError($error)
        }
    }
}

struct FitnessHistoryView: View {
    var store: FitnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var showManual = false
    var body: some View {
        NavigationStack {
            List {
                Button("补记一次训练") { showManual = true }.disabled(store.archive.equipment.isEmpty)
                if store.archive.sessions.isEmpty {
                    Text("还没有训练记录。先添加器材，就可以补记昨天练过的动作。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.archive.sessions.sorted { $0.plan.date > $1.plan.date }) { session in
                    NavigationLink {
                        List {
                            Text(session.plan.summary)
                            ForEach(session.results) { result in
                                Section(result.exercise.equipment.name) {
                                    ForEach(Array(result.finished.enumerated()), id: \.element.id) { index, set in
                                        Text("第 \(index + 1) 组 · \(fitnessWeightText(set.weight, equipment: result.exercise.equipment)) × \(set.reps) 次")
                                    }
                                    Text("\(result.effort.rawValue) · \(result.pain ? "有疼痛" : "无疼痛")")
                                    if !result.note.isEmpty { Text(result.note) }
                                }
                            }
                        }.navigationTitle(session.plan.date.formatted(date: .abbreviated, time: .omitted))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.plan.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            Text(session.results.filter { !$0.finished.isEmpty || $0.pain }.map { $0.exercise.equipment.name }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("训练历史")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showManual) { FitnessManualEntry(store: store) }
        }
    }
}

struct FitnessManualEntry: View {
    var store: FitnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var selected: Set<UUID> = []
    @State private var sets = 2
    @State private var reps = 10
    @State private var plan: FitnessPlan?
    @State private var originalCount = 0
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("实际训练日期", selection: $date, in: ...Date(), displayedComponents: .date)
                Section("做过的动作（最多 5 个）") {
                    ForEach(store.archive.equipment) { equipment in
                        Toggle(equipment.name, isOn: Binding(
                            get: { selected.contains(equipment.id) },
                            set: { on in if on { selected.insert(equipment.id) } else { selected.remove(equipment.id) } }))
                    }
                }
                Section("当时的目标，用于判断是否完成") {
                    Stepper("每动作 \(sets) 组", value: $sets, in: 1...4)
                    Stepper("每组目标 \(reps) 次", value: $reps, in: 8...15)
                }
                Button("填写实际重量与反馈") {
                    let exercises = store.archive.equipment.filter { selected.contains($0.id) }.map {
                        FitnessExercise(equipment: $0, sets: sets, reps: reps, restSeconds: 90,
                                        weight: nil, suggestedWeight: nil, weightReason: "手动补记", instructions: "")
                    }
                    plan = FitnessPlan(date: Calendar.current.startOfDay(for: date), startHour: 19, startMinute: 0,
                                       availableMinutes: 90, summary: "手动补记的实际训练", exercises: exercises,
                                       readiness: FitnessReadiness(), source: "手动补记")
                }.disabled(selected.isEmpty || selected.count > 5)
            }
            .navigationTitle("补记训练")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear { originalCount = store.archive.sessions.count }
            .sheet(item: $plan, onDismiss: { if store.archive.sessions.count > originalCount { dismiss() } }) {
                FitnessLogView(store: store, plan: $0, manual: true)
            }
        }
    }
}
