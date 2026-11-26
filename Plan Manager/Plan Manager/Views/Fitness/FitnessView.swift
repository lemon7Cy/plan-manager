import SwiftUI

struct FitnessView: View {
    @State private var store = FitnessStore.shared
    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var readiness = FitnessReadiness()
    @State private var showProfile = false
    @State private var showEquipment = false
    @State private var showConnection = false
    @State private var showHistory = false
    @State private var logPlan: FitnessPlan?
    @State private var generation: Task<Void, Never>?
    @State private var generating = false
    @State private var error: String?

    private var plan: FitnessPlan? {
        store.archive.plans.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .max { $0.createdAt < $1.createdAt }
    }
    private var completed: Bool { store.archive.sessions.contains { Calendar.current.isDate($0.plan.date, inSameDayAs: date) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    if let storageError = store.storageError {
                        Text(storageError).foregroundStyle(.red)
                    } else if store.archive.profile == nil {
                        onboarding
                    } else {
                        preparation
                        if let plan { planCard(plan) }
                        else {
                            ContentUnavailableView("从今天开始", systemImage: "figure.strengthtraining.traditional",
                                                   description: Text("补记昨天的训练，或生成今天的安排。每次真实反馈都会成为下一次计划的依据。"))
                        }
                        if !completed {
                            Button(action: generate) {
                                HStack {
                                    if generating { ProgressView().tint(.white) }
                                    Text(generating ? "正在安排训练…" : (plan == nil ? "生成训练计划" : "按最新情况重新安排"))
                                }.frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(generating)
                            .accessibilityIdentifier("fitness.generate")
                            if generating {
                                Button("取消生成") { generation?.cancel() }.frame(maxWidth: .infinity)
                            }
                        }
                        memoryCard
                    }
                }.padding(16)
            }
            .background(PMOfflineBackground())
            .navigationTitle("健身")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showConnection = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("模型接口设置")
                }
            }
            .sheet(isPresented: $showProfile) { FitnessProfileEditor(store: store) }
            .sheet(isPresented: $showEquipment) { FitnessEquipmentView(store: store) }
            .sheet(isPresented: $showConnection) { FitnessConnectionView() }
            .sheet(isPresented: $showHistory) { FitnessHistoryView(store: store) }
            .sheet(item: $logPlan) { FitnessLogView(store: store, plan: $0) }
            .fitnessError($error)
            .onAppear { readiness = plan?.readiness ?? FitnessReadiness() }
            .onChange(of: date) { _, _ in readiness = plan?.readiness ?? FitnessReadiness() }
            .onDisappear { generation?.cancel() }
        }
        .tint(DesignTokens.skyBlue)
    }

    private var introduction: some View {
        PMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional").font(.largeTitle).foregroundStyle(DesignTokens.skyBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("稳稳进步，慢慢变强").font(.title3.bold())
                        Text("你的训练记录，就是教练的记忆").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let profile = store.archive.profile {
                    HStack {
                        Label(String(format: "%.1f kg", profile.weightKG), systemImage: "scalemass")
                        Spacer()
                        Text(String(format: "BMI %.1f", profile.bmi))
                    }.font(.subheadline.monospacedDigit())
                    if let fat = profile.estimatedBodyFat {
                        Text(String(format: "估测体脂 %.1f%% · RFM 公式，仅供趋势参考", fat)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("身体档案") { showProfile = true }.accessibilityIdentifier("fitness.profile")
                    Spacer()
                    Button("我的器材") { showEquipment = true }.accessibilityIdentifier("fitness.equipment")
                    Spacer()
                    Button("训练历史") { showHistory = true }.accessibilityIdentifier("fitness.history")
                }.font(.subheadline)
            }
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("先认识你，再制定计划").font(.title2.bold())
            Text("填写身体数据、训练时间和可用器材。第一次不用知道该举多重，教练会让你从轻重量试做开始。")
                .foregroundStyle(.secondary)
            Button("建立身体档案") { showProfile = true }.buttonStyle(.borderedProminent)
            Text("训练数据保存在本机。生成时会发送必要的身体数据和训练摘要给你设置的模型服务。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical)
    }

    private var preparation: some View {
        PMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("训练日期", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .disabled(generating)
                Text("这一天的恢复情况").font(.headline)
                Text("点选酸痛肌群。临近训练时若状态变化，请重新安排。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Button(muscle.rawValue) {
                            if readiness.soreMuscles.contains(muscle) { readiness.soreMuscles.remove(muscle) }
                            else { readiness.soreMuscles.insert(muscle) }
                        }
                        .buttonStyle(.bordered)
                        .tint(readiness.soreMuscles.contains(muscle) ? .orange : DesignTokens.skyBlue)
                    }
                }
                Toggle("今天比较疲劳", isOn: $readiness.fatigued)
                Toggle("有疼痛或受伤，暂停负重", isOn: $readiness.hasPain)
                TextField("其他情况，例如睡眠不足", text: $readiness.note, axis: .vertical)
                    .lineLimit(2...3)
                Text("已有记录会自动避开前一天练过的肌群；疼痛不能只靠天数判断恢复。")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(generating)
        }
    }

    private func planCard(_ plan: FitnessPlan) -> some View {
        PMGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(plan.exercises.isEmpty ? "恢复日" : "训练安排").font(.title3.bold())
                    Spacer()
                    if completed { Label("已记录", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                Text(plan.summary).font(.subheadline)
                if plan.readiness != readiness && !completed {
                    Label("恢复情况已变化，请先重新安排再训练。", systemImage: "arrow.clockwise")
                        .font(.caption).foregroundStyle(.orange)
                }
                if !plan.exercises.isEmpty {
                    Text("\(plan.startDate.formatted(date: .omitted, time: .shortened))–\(plan.startDate.addingTimeInterval(Double(plan.durationMinutes * 60)).formatted(date: .omitted, time: .shortened)) · 约 \(plan.durationMinutes) 分钟")
                        .font(.subheadline.bold()).foregroundStyle(DesignTokens.skyBlue)
                    Label("热身 5 分钟 · 轻松活动关节和低强度有氧", systemImage: "figure.walk").font(.caption)
                    ForEach(plan.exercises) { exercise in
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(exercise.equipment.name).font(.headline)
                                Spacer()
                                Text(plan.start(of: exercise).formatted(date: .omitted, time: .shortened)).font(.caption)
                            }
                            Text("\(exercise.sets) 组 × \(exercise.reps) 次 · 组间休息 \(exercise.restSeconds) 秒")
                                .font(.subheadline)
                            Text(fitnessWeightText(exercise.weight, equipment: exercise.equipment)).font(.headline).foregroundStyle(DesignTokens.skyBlue)
                            Text(exercise.weightReason).font(.caption).foregroundStyle(.secondary)
                            Text(exercise.instructions).font(.subheadline)
                            if let suggested = exercise.suggestedWeight, !completed {
                                Button("试加至 \(suggested.formatted()) \(exercise.equipment.unit.rawValue)") {
                                    do { try store.adoptSuggestedWeight(planID: plan.id, exerciseID: exercise.id) }
                                    catch { self.error = error.localizedDescription }
                                }.buttonStyle(.bordered).disabled(plan.readiness != readiness || generating)
                            }
                        }
                    }
                    Divider()
                    Label("放松 5 分钟 · 轻松走动、恢复呼吸", systemImage: "wind").font(.caption)
                    if !completed {
                        Button("记录本次训练") { logPlan = plan }
                            .buttonStyle(.borderedProminent)
                            .disabled(plan.date > Date() || plan.readiness != readiness || generating)
                            .accessibilityIdentifier("fitness.log")
                    }
                }
                Text("\(plan.source) · \(plan.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var memoryCard: some View {
        PMGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("教练记忆", systemImage: "brain").font(.headline)
                Text("已记录 \(store.archive.sessions.count) 次训练 · \(store.archive.equipment.filter(\.active).count) 台可用器材")
                Text("逐组反馈会更新这台器材的重量基准。新反馈后，后续未完成的计划需要重新生成。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("补记训练 / 查看历史") { showHistory = true }
            }
        }
    }

    private func generate() {
        guard !generating else { return }
        guard readiness.note.count <= 500 else { error = "恢复备注请控制在 500 字以内。"; return }
        let snapshot = store.archive, version = store.revision, requestedDate = date, checkIn = readiness
        generating = true
        generation = Task { @MainActor in
            defer { generating = false; generation = nil }
            do {
                let result: FitnessPlan
                if let rest = FitnessPolicy.restPlan(archive: snapshot, date: requestedDate, readiness: checkIn) {
                    result = rest
                } else {
                    let settings = FitnessLLMSettings.load
                    result = try await FitnessLLM.generate(archive: snapshot, date: requestedDate, readiness: checkIn,
                                                          settings: settings, key: FitnessKeychain.read(account: settings.credentialAccount))
                }
                try Task.checkCancellation()
                try store.savePlan(result, expectedRevision: version)
            } catch is CancellationError { }
            catch let network as URLError {
                if network.code != .cancelled { error = "网络请求未完成，请检查连接后重试。已保存的计划仍可查看。" }
            } catch { self.error = error.localizedDescription }
        }
    }
}

func fitnessWeightText(_ weight: Double?, equipment: FitnessEquipment) -> String {
    if equipment.movement.bodyweight { return "徒手 · 不负重" }
    guard let weight else { return "先轻重量试做，记录实际重量" }
    return "\(weight.formatted()) \(equipment.unit.rawValue) · \(equipment.basis.rawValue)"
}

extension View {
    func fitnessError(_ error: Binding<String?>) -> some View {
        alert("健身教练", isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button("好", role: .cancel) { error.wrappedValue = nil }
        } message: { Text(error.wrappedValue ?? "") }
    }
}
