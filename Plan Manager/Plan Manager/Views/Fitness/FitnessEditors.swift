import SwiftUI

struct FitnessProfileEditor: View {
    var store: FitnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile: FitnessProfile
    @State private var height: String
    @State private var weight: String
    @State private var waist: String
    @State private var start = Date()
    @State private var error: String?

    init(store: FitnessStore) {
        self.store = store
        let profile = store.archive.profile ?? FitnessProfile()
        _profile = State(initialValue: profile)
        _height = State(initialValue: store.archive.profile == nil ? "" : String(profile.heightCM))
        _weight = State(initialValue: store.archive.profile == nil ? "" : String(profile.weightKG))
        _waist = State(initialValue: profile.waistCM.map(String.init(describing:)) ?? "")
        _start = State(initialValue: Calendar.current.date(bySettingHour: profile.startHour, minute: profile.startMinute, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("身体数据") {
                    field("身高 cm", text: $height, id: "fitness.height")
                    field("体重 kg", text: $weight, id: "fitness.weight")
                    Stepper("年龄：\(profile.age) 岁", value: $profile.age, in: 18...85)
                    Picker("生理性别", selection: $profile.sex) { ForEach(FitnessSex.allCases) { Text($0.rawValue).tag($0) } }
                    field("腰围 cm（选填）", text: $waist, id: "fitness.waist")
                    Text("BMI = 体重 ÷ 身高²。体脂采用成年人的 RFM 腰围估算公式，不适用于孕期，也不能替代实际体脂测量。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("训练目标") {
                    Picker("目标", selection: $profile.goal) {
                        ForEach(["养成训练习惯", "减脂", "增肌", "提升体能"], id: \.self) { Text($0) }
                    }
                    Toggle("我是新手，从保守训练量开始", isOn: $profile.beginner)
                    TextField("伤病、活动限制或不适（没有可留空）", text: $profile.limitations, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("固定训练时间") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Self.dayNames[day - 1], isOn: Binding(
                            get: { profile.trainingDays.contains(day) },
                            set: { enabled in
                                if enabled { profile.trainingDays.append(day) }
                                else { profile.trainingDays.removeAll { $0 == day } }
                            }))
                    }
                    DatePicker("开始时间", selection: $start, displayedComponents: .hourAndMinute)
                    Stepper("每次最多 \(profile.durationMinutes) 分钟", value: $profile.durationMinutes, in: 15...90, step: 5)
                }
                Section {
                    Text("身体数据保存在本机。生成训练计划时，必要的身体信息、限制和相关训练摘要会发给你配置的模型接口。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("身体档案")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).accessibilityIdentifier("fitness.profile.save")
                }
            }
            .fitnessError($error)
        }
    }

    static let dayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private func field(_ title: String, text: Binding<String>, id: String) -> some View {
        HStack {
            Text(title)
            TextField(title, text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }
    private func save() {
        do {
            guard let height = Double(height), let weight = Double(weight) else { throw FitnessIssue.invalid("请填写真实身高和体重。") }
            profile.heightCM = height; profile.weightKG = weight
            if waist.trimmingCharacters(in: .whitespaces).isEmpty { profile.waistCM = nil }
            else {
                guard let waist = Double(waist) else { throw FitnessIssue.invalid("请填写有效腰围。") }
                profile.waistCM = waist
            }
            profile.startHour = Calendar.current.component(.hour, from: start)
            profile.startMinute = Calendar.current.component(.minute, from: start)
            profile.trainingDays.sort()
            try store.saveProfile(profile); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FitnessEquipmentView: View {
    var store: FitnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("同一种动作在不同器材上的阻力可能不同。每台器材单独记录；更换单位或器材时请新增档案。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(store.archive.equipment) { equipment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(equipment.name).font(.headline)
                            Spacer()
                            Button(equipment.active ? "停用" : "启用") {
                                do { try store.toggleEquipment(equipment.id) } catch { self.error = error.localizedDescription }
                            }.buttonStyle(.bordered)
                        }
                        Text("\(equipment.movement.rawValue) · \(equipment.muscles.map(\.rawValue).sorted().joined(separator: " / "))")
                        if !equipment.movement.bodyweight {
                            Text("\(equipment.unit.rawValue) · \(equipment.basis.rawValue) · 最小档位 \(equipment.increment.formatted())")
                                .font(.caption).foregroundStyle(.secondary)
                            let load = FitnessPolicy.load(for: equipment, date: Date(), fatigued: false, sessions: store.archive.sessions)
                            Text("记忆：\(fitnessWeightText(load.weight, equipment: equipment))")
                                .font(.caption).foregroundStyle(DesignTokens.skyBlue)
                        }
                    }.opacity(equipment.active ? 1 : 0.5)
                }
                Button("添加器材 / 徒手动作") { showAdd = true }
                    .accessibilityIdentifier("fitness.equipment.add")
            }
            .navigationTitle("我的器材")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showAdd) { FitnessEquipmentEditor(store: store) }
            .fitnessError($error)
        }
    }
}

struct FitnessEquipmentEditor: View {
    var store: FitnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var movement = FitnessMovement.chestPress
    @State private var unit = FitnessUnit.kg
    @State private var basis = LoadBasis.machine
    @State private var increment = "2.5"
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("器材名称，例如健身房 A 区推胸机", text: $name).accessibilityIdentifier("fitness.equipment.name")
                Picker("动作", selection: $movement) { ForEach(FitnessMovement.allCases) { Text($0.rawValue).tag($0) } }
                if !movement.bodyweight {
                    Picker("重量单位", selection: $unit) { ForEach(FitnessUnit.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("重量含义", selection: $basis) { ForEach(LoadBasis.allCases) { Text($0.rawValue).tag($0) } }
                    HStack {
                        Text("最小加重档位")
                        TextField("2.5", text: $increment).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Text("第一次使用不会预设重量。先轻重量试做，并在训练后记录实际使用的重量。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("添加器材")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            guard let increment = Double(increment) else { throw FitnessIssue.invalid("请填写有效的档位。") }
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let item = FitnessEquipment(name: trimmed.isEmpty ? movement.rawValue : trimmed, movement: movement,
                                                        unit: unit, basis: basis, increment: increment)
                            try store.addEquipment(item); dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("fitness.equipment.save")
                }
            }
            .fitnessError($error)
        }
    }
}

struct FitnessConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = FitnessLLMSettings.load
    @State private var key = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("模型接口") {
                    TextField("API Base URL", text: $settings.baseURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("模型名称", text: $settings.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("fitness.api.key")
                }
                Section {
                    Text("密钥只存设备钥匙串，不包含在备份中。清空密钥并保存即可移除。更换地址后需要重新填写对应密钥。")
                    Text("生成计划时会向此接口发送必要的身体数据和训练摘要。请使用你信任的服务。")
                    if settings.baseURL.lowercased().hasPrefix("http://") {
                        Label("当前使用 HTTP，密钥与请求明文传输。有 HTTPS 地址后请在此更换。", systemImage: "lock.open")
                            .foregroundStyle(.orange)
                    }
                }.font(.caption)
            }
            .navigationTitle("模型接口")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try settings.save(key: key); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            .onAppear { key = FitnessKeychain.read(account: settings.credentialAccount) }
            .onChange(of: settings.baseURL) { _, _ in key = "" }
            .fitnessError($error)
        }
    }
}
