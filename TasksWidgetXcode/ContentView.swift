import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var authManager: GoogleAuthManager
    @EnvironmentObject private var viewModel: TasksViewModel
    @Environment(\.accentColor) private var accentColor
    @AppStorage("accentKey") private var accentKey = AccentOption.pink.rawValue
    @State private var showCreateListSheet = false
    @State private var newListTitle = ""
    @State private var showAvatarMenu = false
    @State private var isRefreshHovered = false
    @State private var listDropTargetIndex: Int? = nil
    @State private var refreshRotation: Double = 0
    
    var body: some View {
        Group {
            if viewModel.isSignedIn {
                mainContent
            } else {
                signInView
            }
        }
        .environment(\.accentColor, AccentOption.color(for: accentKey))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.restoreSessionAndLoad()
        }
    }
    
    // MARK: - Sign in
    
    private var signInView: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: AppTheme.spacingXL) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(accentColor)
                }
                
                VStack(spacing: AppTheme.spacingS) {
                    Text("Google Tasks")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Sign in to sync your lists and show them in your Mac widget.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 300)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .padding(.horizontal)
                }
                
                SignInButton {
                    Task {
                        do {
                            try await authManager.signIn(presentingWindow: NSApp.keyWindow)
                            await viewModel.restoreSessionAndLoad()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .padding(.top, AppTheme.spacingM)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main content (navbar + horizontal list cards)
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            navbar
            listCardsContainer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .onAppear {
            if viewModel.taskLists.isEmpty && !viewModel.isLoading {
                Task { await viewModel.loadTaskLists() }
            }
        }
    }
    
    private var navbar: some View {
        HStack(spacing: AppTheme.spacingM) {
            // Left: logo + title
            HStack(spacing: AppTheme.spacingS) {
                Image("NavbarLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                Text("Tasks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            Spacer(minLength: 0)
            
            // Right: refresh + avatar with menu
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { refreshRotation += 360 }
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isRefreshHovered ? AccentOption.color(for: accentKey) : AppTheme.textSecondary)
                    .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(.plain)
            .onHover { isRefreshHovered = $0 }
            
            Button {
                showAvatarMenu = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AccentOption.color(for: accentKey))
                        .frame(width: 32, height: 32)
                    Text(authManager.userInitial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAvatarMenu, arrowEdge: .top) {
                AvatarMenuContent(
                    email: authManager.currentUserEmail ?? "Signed in",
                    selectedAccentKey: $accentKey,
                    onLogOut: {
                        authManager.signOut()
                        showAvatarMenu = false
                    }
                )
            }
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.vertical, AppTheme.spacingM)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)
        }
    }
    
    @ViewBuilder
    private var listCardsContainer: some View {
        if viewModel.isLoading && viewModel.taskLists.isEmpty {
            loadingView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            errorView(error)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.taskLists.isEmpty {
            emptyView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AppTheme.spacingL) {
                    ForEach(Array(viewModel.taskLists.enumerated()), id: \.element.id) { index, list in
                        ListCardView(
                            list: list,
                            isDropTarget: listDropTargetIndex == index,
                            tasks: viewModel.tasksByListId[list.id],
                            isLoading: viewModel.isLoading && viewModel.tasksByListId[list.id] == nil,
                            onSelect: { viewModel.selectList(list) },
                            onRename: { id, newTitle in Task { await viewModel.renameList(taskListId: id, newTitle: newTitle) } },
                            onDelete: { id in Task { await viewModel.deleteList(taskListId: id) } },
                            onAddTask: { id, title in Task { await viewModel.addTask(taskListId: id, title: title) } },
                            onToggleTask: { task in Task { await viewModel.toggleTaskCompletion(taskListId: list.id, task: task) } },
                            onReorderTask: { sourceListId, taskId, previousTaskId, destinationListId in Task { await viewModel.reorderTask(sourceListId: sourceListId, taskId: taskId, previousTaskId: previousTaskId, destinationListId: destinationListId) } },
                            onUpdateTaskDetails: { listId, taskId, title, notes, dueRfc3339, clearDue in Task { await viewModel.updateTaskDetails(taskListId: listId, taskId: taskId, title: title, notes: notes, due: dueRfc3339, clearDue: clearDue) } },
                            onDeleteTask: { listId, taskId in Task { await viewModel.deleteTask(taskListId: listId, taskId: taskId) } },
                            onAddSubtask: { listId, parentId, title in Task { await viewModel.addSubtask(taskListId: listId, parentTaskId: parentId, title: title) } }
                        )
                        .onDrag {
                            NSItemProvider(object: list.id as NSString)
                        }
                        .onDrop(of: [.plainText], isTargeted: Binding(
                            get: { listDropTargetIndex == index },
                            set: { targeted in
                                if targeted {
                                    listDropTargetIndex = index
                                } else if listDropTargetIndex == index {
                                    listDropTargetIndex = nil
                                }
                            }
                        )) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: String.self) { id, _ in
                                guard let listId = id, !listId.contains("|") else { return }
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.reorderLists(draggedListId: listId, toIndex: index)
                                    }
                                    listDropTargetIndex = nil
                                }
                            }
                            return true
                        }
                    }
                    CreateNewListCardView(onTap: { showCreateListSheet = true })
                }
                .padding(.horizontal, AppTheme.spacingL)
                .padding(.vertical, AppTheme.spacingM)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showCreateListSheet) {
                createListSheetContent
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading lists…")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, AppTheme.spacingM)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer()
            Text("Couldn't load lists")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again") {
                Task { await viewModel.loadTaskLists() }
            }
            .font(.system(size: 14))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer()
            Text("No task lists")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: AppTheme.spacingM) {
                Button("Create new list") { showCreateListSheet = true }
                    .font(.system(size: 14))
                Button("Refresh") {
                    Task { await viewModel.loadTaskLists() }
                }
                .font(.system(size: 14))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var createListSheetContent: some View {
        VStack(spacing: AppTheme.spacingL) {
            Text("Create new list")
                .font(.headline)
            TextField("List name", text: $newListTitle)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
            HStack(spacing: AppTheme.spacingM) {
                Button("Cancel") {
                    showCreateListSheet = false
                    newListTitle = ""
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    let title = newListTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        Task {
                            await viewModel.createList(title: title)
                            showCreateListSheet = false
                            newListTitle = ""
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.spacingL)
        .frame(minWidth: 300)
    }
}

// MARK: - Create new list placeholder card

struct CreateNewListCardView: View {
    @Environment(\.accentColor) private var accentColor
    let onTap: () -> Void
    @State private var isHovered = false
    
    private let cardWidth: CGFloat = 320
    private let cardMinHeight: CGFloat = 380
    private let borderColorDefault = Color(white: 0.85)
    private let circleFillDefault = Color(white: 0.92)
    private let textColorDefault = Color(white: 0.35)
    private let hoverBg = Color(red: 0.98, green: 0.92, blue: 0.95)
    private let hoverCircleFill = Color(red: 0.95, green: 0.85, blue: 0.90)
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.radiusL)
                    .fill(isHovered ? hoverBg : AppTheme.surface)
                RoundedRectangle(cornerRadius: AppTheme.radiusL)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(isHovered ? accentColor : borderColorDefault)
                VStack(spacing: AppTheme.spacingM) {
                    ZStack {
                        Circle()
                            .fill(isHovered ? hoverCircleFill : circleFillDefault)
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isHovered ? accentColor : textColorDefault)
                    }
                    Text("Create new list")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isHovered ? accentColor : textColorDefault)
                }
            }
            .frame(width: cardWidth, alignment: .center)
            .frame(minHeight: cardMinHeight)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - List card (one per list, side by side)

struct ListCardView: View {
    @Environment(\.accentColor) private var accentColor
    let list: GoogleTaskList
    var isDropTarget: Bool = false
    let tasks: [GoogleTask]?
    let isLoading: Bool
    let onSelect: () -> Void
    let onRename: (String, String) -> Void
    let onDelete: (String) -> Void
    let onAddTask: (String, String) -> Void
    let onToggleTask: (GoogleTask) -> Void
    /// (sourceListId, taskId, previousTaskId, destinationListId). destinationListId nil = reorder within source.
    var onReorderTask: ((String, String, String?, String?) -> Void)? = nil
    var onUpdateTaskDetails: ((String, String, String?, String?, String?, Bool) -> Void)? = nil
    var onDeleteTask: ((String, String) -> Void)? = nil
    var onAddSubtask: ((String, String, String) -> Void)? = nil
    
    @State private var showRenameSheet = false
    @State private var completedSectionExpanded = true
    @State private var renameTitle = ""
    @State private var showDeleteConfirm = false
    @State private var showAddTaskSheet = false
    @State private var addTaskTitle = ""
    @State private var isAddTaskHovered = false
    @State private var isTaskDropTargeted = false
    @State private var isCardDropTargeted = false
    @State private var taskToEdit: GoogleTask?
    
    private let cardWidth: CGFloat = 320
    private let cardMinHeight: CGFloat = 380
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header: title + menu — header is the drag source so tap on body doesn't block list reorder
            HStack {
                Text(list.title ?? "Unnamed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Menu {
                    Button("Rename list") {
                        renameTitle = list.title ?? ""
                        showRenameSheet = true
                    }
                    Button("Delete list", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(accentColor)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingS)
            
            // Accent line under title (left-aligned, not full width)
            Rectangle()
                .fill(accentColor)
                .frame(height: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppTheme.spacingM)
                .padding(.trailing, AppTheme.spacingXL)
                .padding(.bottom, AppTheme.spacingS)
            
            // Add a task (only when this list is selected) — aligned with task rows, hover on icon + text only
            if tasks != nil {
                Button {
                    addTaskTitle = ""
                    showAddTaskSheet = true
                } label: {
                    HStack(alignment: .center, spacing: AppTheme.spacingS) {
                        ZStack {
                            Circle()
                                .strokeBorder(isAddTaskHovered ? accentColor : AppTheme.rowBorder, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isAddTaskHovered ? accentColor : AppTheme.textTertiary)
                        }
                        Text("Add a task")
                            .font(.system(size: 14))
                            .foregroundStyle(isAddTaskHovered ? accentColor : AppTheme.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.leading, AppTheme.spacingM + AppTheme.spacingS)
                    .padding(.trailing, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingS)
                }
                .buttonStyle(.plain)
                .onHover { isAddTaskHovered = $0 }
            }
            
            // Task list or placeholder
            if let tasks = tasks {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacingXL)
                } else {
                    let topLevelIncomplete = TaskListFilter.topLevel(tasks).filter { !$0.isCompleted }
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(topLevelIncomplete.enumerated()), id: \.element.id) { index, task in
                                TaskRowView(
                                    task: task,
                                    onToggle: { onToggleTask(task) },
                                    onTap: {
                                        taskToEdit = task
                                    }
                                )
                                .onDrag {
                                    NSItemProvider(object: "\(list.id)|\(task.id)" as NSString)
                                }
                                .onDrop(of: [UTType.plainText], isTargeted: $isTaskDropTargeted) { providers in
                                    guard let reorder = onReorderTask, let provider = providers.first else { return false }
                                    _ = provider.loadObject(ofClass: String.self) { payload, _ in
                                        guard let raw = payload, raw != task.id else { return }
                                        let (sourceListId, taskId): (String, String) = {
                                            if raw.contains("|"), let sep = raw.firstIndex(of: "|") {
                                                let a = String(raw[..<sep])
                                                let b = String(raw[raw.index(after: sep)...])
                                                return (a, b)
                                            }
                                            return (list.id, raw)
                                        }()
                                        guard taskId != task.id else { return }
                                        let prev: String? = index > 0 ? topLevelIncomplete[index - 1].id : nil
                                        let dest: String? = sourceListId != list.id ? list.id : nil
                                        DispatchQueue.main.async { reorder(sourceListId, taskId, prev, dest) }
                                    }
                                    return true
                                }
                                // Subtasks (incomplete) under this task — same completion toggle and tap-to-edit as main tasks
                                ForEach(TaskListFilter.subtasks(for: task.id, from: tasks).filter { !$0.isCompleted }) { subtask in
                                    TaskRowView(
                                        task: subtask,
                                        onToggle: { onToggleTask(subtask) },
                                        onTap: { taskToEdit = subtask }
                                    )
                                    .padding(.leading, AppTheme.spacingL)
                                }
                            }
                            completedSection(tasks: tasks, onToggleTask: onToggleTask, isExpanded: $completedSectionExpanded)
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                Text("Tap to view tasks")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingL)
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .frame(minHeight: cardMinHeight)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL))
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 2)
        .overlay(alignment: .leading) {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
            }
        }
        .onTapGesture { onSelect() }
        .onDrop(of: [UTType.plainText], isTargeted: $isCardDropTargeted) { providers in
            guard let reorder = onReorderTask, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { payload, _ in
                guard let raw = payload, raw.contains("|"), let sep = raw.firstIndex(of: "|") else { return }
                let sourceListId = String(raw[..<sep])
                let taskId = String(raw[raw.index(after: sep)...])
                guard sourceListId != list.id else { return }
                DispatchQueue.main.async { reorder(sourceListId, taskId, nil, list.id) }
            }
            return true
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .confirmationDialog("Delete list?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete(list.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(list.title ?? "Unnamed")\" and its tasks. This cannot be undone.")
        }
        .sheet(isPresented: $showAddTaskSheet) {
            addTaskSheet
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskSheetView(
                taskListId: list.id,
                task: task,
                allTasks: tasks ?? [],
                onUpdateDetails: { title, notes, dueRfc3339, clearDue in
                    onUpdateTaskDetails?(list.id, task.id, title, notes, dueRfc3339, clearDue)
                },
                onDeleteTask: { onDeleteTask?(list.id, task.id) },
                onAddSubtask: { title in onAddSubtask?(list.id, task.id, title) },
                onUpdateSubtask: { subtaskId, title, notes in
                    onUpdateTaskDetails?(list.id, subtaskId, title, notes, nil, false)
                },
                onDeleteSubtask: { subtaskId in onDeleteTask?(list.id, subtaskId) },
                onDismiss: { taskToEdit = nil }
            )
        }
    }
    
    private var renameSheet: some View {
        VStack(spacing: AppTheme.spacingL) {
            Text("Rename list")
                .font(.headline)
            TextField("List name", text: $renameTitle)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
            HStack(spacing: AppTheme.spacingM) {
                Button("Cancel") { showRenameSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        onRename(list.id, title)
                        showRenameSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.spacingL)
        .frame(minWidth: 300)
    }
    
    private var addTaskSheet: some View {
        VStack(spacing: AppTheme.spacingL) {
            Text("Add a task")
                .font(.headline)
            TextField("Task title", text: $addTaskTitle)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
            HStack(spacing: AppTheme.spacingM) {
                Button("Cancel") { showAddTaskSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let title = addTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        onAddTask(list.id, title)
                        showAddTaskSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(addTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.spacingL)
        .frame(minWidth: 300)
    }
    
    @ViewBuilder private func completedSection(tasks: [GoogleTask], onToggleTask: @escaping (GoogleTask) -> Void, isExpanded: Binding<Bool>) -> some View {
        let completed = TaskListFilter.topLevel(tasks).filter(\.isCompleted)
        if !completed.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("Completed (\(completed.count))")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingS)
                if isExpanded.wrappedValue {
                    ForEach(completed) { task in
                        TaskRowView(task: task, onToggle: { onToggleTask(task) }, onTap: {
                            taskToEdit = task
                        })
                    }
                }
            }
        }
    }
}

// MARK: - Task row (inside list card)

struct TaskRowView: View {
    @Environment(\.accentColor) private var accentColor
    let task: GoogleTask
    var onToggle: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    
    @State private var isRowHovered = false
    @State private var isCheckboxHovered = false
    
    private let rowHighlightBorder = Color(white: 0.75)
    private static let dueFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            if let onToggle = onToggle {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(checkboxColor)
                }
                .buttonStyle(.plain)
                .onHover { isCheckboxHovered = $0 }
            } else {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? accentColor : AppTheme.textTertiary)
            }
            
            Button {
                onTap?()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.displayTitle)
                        .font(.system(size: 15))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if let date = task.dueDate {
                        Text(Self.dueFormatter.string(from: date))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, AppTheme.spacingS)
        .background(AppTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusS))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusS)
                .strokeBorder(isRowHovered ? rowHighlightBorder : Color.clear, lineWidth: 1)
        )
        .onHover { isRowHovered = $0 }
    }
    
    private var checkboxColor: Color {
        if task.isCompleted { return accentColor }
        return isCheckboxHovered ? accentColor : AppTheme.textTertiary
    }
}

// MARK: - Edit task sheet (details, due, subtasks)

struct EditTaskSheetView: View {
    @Environment(\.accentColor) private var accentColor
    let taskListId: String
    let task: GoogleTask
    let allTasks: [GoogleTask]
    let onUpdateDetails: (String?, String?, String?, Bool) -> Void
    let onDeleteTask: () -> Void
    let onAddSubtask: (String) -> Void
    let onUpdateSubtask: (String, String?, String?) -> Void
    let onDeleteSubtask: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var editTitle: String = ""
    @State private var editNotes: String = ""
    @State private var editDue: Date?
    @State private var newSubtaskTitle: String = ""
    @State private var editingSubtask: GoogleTask?
    @State private var editSubtaskTitle: String = ""
    @State private var editSubtaskNotes: String = ""
    
    private var subtasks: [GoogleTask] {
        TaskListFilter.subtasks(for: task.id, from: allTasks)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            HStack {
                Text("Edit task")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Done") {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("Task title", text: $editTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextEditor(text: $editNotes)
                            .frame(minHeight: 60)
                            .padding(4)
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(AppTheme.rowBorder, lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack {
                            if editDue != nil {
                                DatePicker("", selection: Binding(get: { editDue ?? Date() }, set: { editDue = $0 }), displayedComponents: .date)
                                    .labelsHidden()
                                Button("Clear") {
                                    editDue = nil
                                }
                                .foregroundStyle(accentColor)
                            } else {
                                Button("Add due date") {
                                    editDue = Date()
                                }
                                .foregroundStyle(accentColor)
                            }
                        }
                    }
                    
                    HStack(spacing: AppTheme.spacingM) {
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        Button("Delete task", role: .destructive) {
                            onDeleteTask()
                            onDismiss()
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, AppTheme.spacingS)
                    
                    Text("Subtasks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    ForEach(subtasks) { subtask in
                        if editingSubtask?.id == subtask.id {
                            HStack(spacing: AppTheme.spacingS) {
                                TextField("Subtask title", text: $editSubtaskTitle)
                                    .textFieldStyle(.roundedBorder)
                                Button("Save") {
                                    onUpdateSubtask(subtask.id, editSubtaskTitle, editSubtaskNotes.isEmpty ? nil : editSubtaskNotes)
                                    editingSubtask = nil
                                }
                                .disabled(editSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Button("Cancel") {
                                    editingSubtask = nil
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack {
                                Text(subtask.displayTitle)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button("Edit") {
                                    editingSubtask = subtask
                                    editSubtaskTitle = subtask.title ?? ""
                                    editSubtaskNotes = subtask.notes ?? ""
                                }
                                .foregroundStyle(accentColor)
                                Button("Delete", role: .destructive) {
                                    onDeleteSubtask(subtask.id)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    HStack(spacing: AppTheme.spacingS) {
                        TextField("New subtask", text: $newSubtaskTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let t = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty {
                                onAddSubtask(t)
                                newSubtaskTitle = ""
                            }
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundStyle(accentColor)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxHeight: 400)
        }
        .padding(AppTheme.spacingL)
        .frame(minWidth: 380)
        .background(AppTheme.surface)
        .preferredColorScheme(.light)
        .onAppear {
            editTitle = task.title ?? ""
            editNotes = task.notes ?? ""
            editDue = task.dueDate
        }
    }
    
    private func saveAndDismiss() {
        let title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueRfc3339 = editDue.map { GoogleTask.rfc3339String(from: $0) }
        let clearDue = task.dueDate != nil && editDue == nil
        onUpdateDetails(title.isEmpty ? nil : title, notes.isEmpty ? nil : notes, dueRfc3339, clearDue)
        onDismiss()
    }
}

// MARK: - Avatar menu (email header, accent colour, log out)

struct AvatarMenuContent: View {
    @Environment(\.accentColor) private var accentColor
    let email: String
    @Binding var selectedAccentKey: String
    let onLogOut: () -> Void
    @State private var isLogOutHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Email as non-interactive header
            Text(email)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingS)
            
            // Accent colour options
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text("Accent colour")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, AppTheme.spacingM)
                HStack(spacing: AppTheme.spacingS) {
                    ForEach(AccentOption.allCases, id: \.rawValue) { option in
                        let isSelected = selectedAccentKey == option.rawValue
                        Button {
                            selectedAccentKey = option.rawValue
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected ? AppTheme.textPrimary : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingM)
            }
            
            Button(action: onLogOut) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 12, weight: .medium))
                    Text("Log out")
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, AppTheme.spacingS)
                .contentShape(Rectangle())
                .foregroundStyle(isLogOutHovered ? accentColor : AppTheme.textPrimary)
                .background(isLogOutHovered ? accentColor.opacity(0.15) : Color.clear)
            }
            .buttonStyle(.plain)
            .onHover { isLogOutHovered = $0 }
        }
        .frame(minWidth: 220)
        .padding(.bottom, AppTheme.spacingS)
        .background(AppTheme.background)
    }
}

// MARK: - Sign in button

struct SignInButton: View {
    @Environment(\.accentColor) private var accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 18))
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.vertical, 14)
            .background(accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(GoogleAuthManager())
        .environmentObject(TasksViewModel(authManager: GoogleAuthManager()))
        .frame(width: 800, height: 560)
}
