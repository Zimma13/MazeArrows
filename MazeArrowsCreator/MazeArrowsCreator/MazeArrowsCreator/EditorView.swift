import SwiftUI

// MARK: - Editor root

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    let store: LevelStore

    @State private var isDrawMode = true
    @State private var showSettings = false
    @State private var saveFlash = false
    @State private var saveFlashRequestID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            validationBar
            gridArea
            Divider()
            bottomBar
            actionBar
        }
        .navigationTitle(vm.name.isEmpty ? "Уровень \(vm.index)" : vm.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showSettings)   { LevelSettingsSheet(vm: vm) }
        .sheet(isPresented: $vm.showProperties) { PropertiesSheet(vm: vm) }
        .sheet(isPresented: $vm.showExport)  { ExportSheet(vm: vm) }
        .onAppear {
            vm.scheduleValidation()
        }
        .onDisappear {
            vm.cancelValidation()
        }
        .task(id: saveFlashRequestID) {
            guard let requestID = saveFlashRequestID else { return }
            do {
                try await Task.sleep(for: .milliseconds(1_200))
            } catch {
                return
            }
            guard !Task.isCancelled, saveFlashRequestID == requestID else { return }
            withAnimation { saveFlash = false }
            saveFlashRequestID = nil
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isDrawMode.toggle()
            } label: {
                Image(systemName: isDrawMode ? "pencil.circle.fill" : "hand.draw")
            }
            .help(isDrawMode ? "Режим рисования (нажми для прокрутки)" : "Режим прокрутки (нажми для рисования)")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            Button {
                store.save(vm)
                withAnimation { saveFlash = true }
                saveFlashRequestID = UUID()
            } label: {
                Image(systemName: saveFlash ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .foregroundStyle(saveFlash ? .green : .accentColor)
            }
            Button { vm.showExport = true } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    // MARK: Subviews

    private var validationBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.validationColor)
                .frame(width: 8, height: 8)
            Text(vm.validationText)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text("\(vm.pieces.count) фиг. | \(vm.obstacles.count) пр.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var gridArea: some View {
        ScrollView([.horizontal, .vertical]) {
            GridCanvasView(vm: vm)
                .padding(8)
        }
        .scrollDisabled(isDrawMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!vm.canUndo)

            Spacer()

            Menu {
                ForEach(EditorMode.allModes, id: \.displayName) { mode in
                    Button {
                        vm.mode = mode
                        vm.deselect()
                    } label: {
                        if vm.mode == mode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(vm.mode.displayName)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(.capsule)
            }

            Spacer()

            Button { vm.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!vm.canRedo)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var actionBar: some View {
        if let cp = vm.currentPiece {
            HStack(spacing: 12) {
                Text("\(cp.cells.count) кл.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Отмена", role: .cancel) { vm.cancelPiece() }
                    .buttonStyle(.bordered)
                Button("Зафиксировать") { vm.finishPiece() }
                    .buttonStyle(.borderedProminent)
                    .disabled(cp.cells.count < 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        } else if vm.selectedId != nil {
            HStack {
                Spacer()
                Button(role: .destructive) { vm.deleteSelected() } label: {
                    Label("Удалить", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// MARK: - Level settings sheet

private struct LevelSettingsSheet: View {
    @Bindable var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private let difficulties = ["easy", "medium", "hard"]
    private let difficultyNames = ["Лёгкий", "Средний", "Сложный"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Уровень") {
                    HStack {
                        Text("Номер")
                        Spacer()
                        Stepper("\(vm.index)", value: $vm.index, in: 1...999)
                    }
                    TextField("Название (необязательно)", text: $vm.name)
                    Picker("Сложность", selection: $vm.difficulty) {
                        ForEach(difficulties.indices, id: \.self) { i in
                            Text(difficultyNames[i]).tag(difficulties[i])
                        }
                    }
                }

                Section("Сетка") {
                    HStack {
                        Text("Ширина")
                        Spacer()
                        Stepper("\(vm.width)", value: $vm.width, in: 3...20)
                    }
                    HStack {
                        Text("Высота")
                        Spacer()
                        Stepper("\(vm.height)", value: $vm.height, in: 3...28)
                    }
                    HStack {
                        Text("Размер клетки")
                        Spacer()
                        Stepper("\(Int(vm.cellSize))", value: $vm.cellSize, in: 26...60, step: 2)
                    }
                }

                Section("Игра") {
                    HStack {
                        Text("Жизни")
                        Spacer()
                        Stepper("\(vm.lives)", value: $vm.lives, in: 1...10)
                    }
                    HStack {
                        Text("3 звезды (макс. ошибок)")
                        Spacer()
                        Stepper("\(vm.threeStarMaxMistakes)", value: $vm.threeStarMaxMistakes, in: 0...10)
                    }
                    HStack {
                        Text("2 звезды (макс. ошибок)")
                        Spacer()
                        Stepper("\(vm.twoStarMaxMistakes)", value: $vm.twoStarMaxMistakes, in: 0...10)
                    }
                }

                Section("Цель") {
                    Picker("Тип цели", selection: $vm.goal.kind) {
                        ForEach(GoalKind.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    if vm.goal.kind.needsValue {
                        TextField("Значение", text: $vm.goal.valueString)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Настройки уровня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        vm.scheduleValidation()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Properties sheet (piece or obstacle)

private struct PropertiesSheet: View {
    let vm: EditorViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let p = vm.selectedPiece {
                    PiecePropertiesView(vm: vm, piece: p)
                } else if let o = vm.selectedObstacle {
                    ObstaclePropertiesView(vm: vm, obstacle: o)
                } else {
                    ContentUnavailableView("Ничего не выбрано", systemImage: "hand.tap")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Piece properties

private struct PiecePropertiesView: View {
    let vm: EditorViewModel
    let piece: Piece
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Тип") {
                Picker("Тип", selection: Binding(
                    get: { piece.kind },
                    set: { k in vm.updatePiece(id: piece.id) { $0.kind = k } }
                )) {
                    ForEach(PieceKind.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Направление") {
                Picker("", selection: Binding(
                    get: { piece.direction },
                    set: { d in vm.updatePiece(id: piece.id) { $0.direction = d } }
                )) {
                    ForEach(Direction.allCases, id: \.self) { d in
                        Text("\(d.arrow)  \(d.rawValue)").tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Группа цвета") {
                HStack {
                    Text(piece.colorGroup.map { "Группа \($0)" } ?? "Нет группы")
                        .foregroundStyle(piece.colorGroup == nil ? .secondary : .primary)
                    Spacer()
                    Stepper("", value: Binding(
                        get: { piece.colorGroup ?? 0 },
                        set: { v in vm.updatePiece(id: piece.id) { $0.colorGroup = v == 0 ? nil : v } }
                    ), in: 0...9)
                }
            }

            if piece.kind == .frozen {
                Section("Разморозить после N удалений") {
                    Stepper(
                        "\(piece.frozenUnlockNeighbors ?? 1)",
                        value: Binding(
                            get: { piece.frozenUnlockNeighbors ?? 1 },
                            set: { v in vm.updatePiece(id: piece.id) { $0.frozenUnlockNeighbors = v } }
                        ),
                        in: 1...20
                    )
                }
            }

            if piece.kind == .double {
                Section("Второе направление") {
                    Picker("", selection: Binding(
                        get: { piece.secondaryDirection ?? .right },
                        set: { d in vm.updatePiece(id: piece.id) { $0.secondaryDirection = d } }
                    )) {
                        ForEach(Direction.allCases, id: \.self) { d in
                            Text("\(d.arrow)  \(d.rawValue)").tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if piece.kind == .chain {
                Section("ID цепной фигуры") {
                    TextField("например p3", text: Binding(
                        get: { piece.chainedPieceId ?? "" },
                        set: { v in vm.updatePiece(id: piece.id) { $0.chainedPieceId = v.isEmpty ? nil : v } }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
            }

            Section {
                Button(role: .destructive) {
                    vm.deleteSelected()
                    dismiss()
                } label: {
                    Label("Удалить фигуру", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Фигура \(piece.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            }
        }
    }
}

// MARK: Obstacle properties

private struct ObstaclePropertiesView: View {
    let vm: EditorViewModel
    let obstacle: Obstacle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Тип") {
                Label(obstacle.kind.displayName, systemImage: "square.fill")
                    .foregroundStyle(.secondary)
            }

            if obstacle.kind == .gate {
                Section("Направление ворот") {
                    Picker("", selection: Binding(
                        get: { obstacle.parameter ?? "right" },
                        set: { v in vm.updateObstacle(id: obstacle.id) { $0.parameter = v } }
                    )) {
                        ForEach(Direction.allCases, id: \.self) { d in
                            Text("\(d.arrow)  \(d.rawValue)").tag(d.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Группа цвета") {
                HStack {
                    Text(obstacle.colorGroup.map { "Группа \($0)" } ?? "Нет группы")
                        .foregroundStyle(obstacle.colorGroup == nil ? .secondary : .primary)
                    Spacer()
                    Stepper("", value: Binding(
                        get: { obstacle.colorGroup ?? 0 },
                        set: { v in vm.updateObstacle(id: obstacle.id) { $0.colorGroup = v == 0 ? nil : v } }
                    ), in: 0...9)
                }
            }

            Section {
                Button(role: .destructive) {
                    vm.deleteSelected()
                    dismiss()
                } label: {
                    Label("Удалить препятствие", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Препятствие \(obstacle.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            }
        }
    }
}

// MARK: - Export sheet

private struct ExportSheet: View {
    let vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var copyFlashRequestID: UUID?

    private var json: String {
        (try? vm.exportGameJSON()) ?? "{ \"error\": \"validation failed\" }"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("JSON экспорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIPasteboard.general.string = json
                        withAnimation { copied = true }
                        copyFlashRequestID = UUID()
                    } label: {
                        Label(
                            copied ? "Скопировано!" : "Копировать",
                            systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .foregroundStyle(copied ? .green : .accentColor)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: json, preview: SharePreview("level_\(vm.index).json"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: copyFlashRequestID) {
            guard let requestID = copyFlashRequestID else { return }
            do {
                try await Task.sleep(for: .milliseconds(1_500))
            } catch {
                return
            }
            guard !Task.isCancelled, copyFlashRequestID == requestID else { return }
            withAnimation { copied = false }
            copyFlashRequestID = nil
        }
    }
}
