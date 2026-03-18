import WidgetKit
import SwiftUI

// MARK: - Widget theme (matches main app AppTheme)

private enum WidgetTheme {
    static let background = Color(white: 0.97)
    static let textPrimary = Color(white: 0.15)
    static let textSecondary = Color(white: 0.4)
    static let textTertiary = Color(white: 0.55)
    static let accent = Color(red: 0.91, green: 0.35, blue: 0.58)
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
}

// MARK: - Timeline Entry

struct TasksWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [GoogleTask]
    let listTitle: String?
    let isLoggedIn: Bool
}

// MARK: - Timeline Provider

struct TasksWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksWidgetEntry {
        TasksWidgetEntry(
            date: Date(),
            tasks: [
                GoogleTask(id: "1", title: "Sample task", notes: nil, status: "needsAction", due: nil, completed: nil, parent: nil, position: nil),
                GoogleTask(id: "2", title: "Another task", notes: nil, status: "completed", due: nil, completed: nil, parent: nil, position: nil)
            ],
            listTitle: "My List",
            isLoggedIn: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TasksWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let tasks = TaskStore.loadTasks()
        let entry = TasksWidgetEntry(
            date: Date(),
            tasks: tasks,
            listTitle: TaskStore.selectedListTitle,
            isLoggedIn: !tasks.isEmpty || TaskStore.selectedListId != nil
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksWidgetEntry>) -> Void) {
        let tasks = TaskStore.loadTasks()
        let entry = TasksWidgetEntry(
            date: Date(),
            tasks: tasks,
            listTitle: TaskStore.selectedListTitle,
            isLoggedIn: !tasks.isEmpty || TaskStore.selectedListId != nil
        )
        // Refresh again in 15 minutes so widget updates when app fetches new data
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct TasksWidgetView: View {
    var entry: TasksWidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    var body: some View {
        // Per Apple: "read widgetRenderingMode to create SwiftUI views for each applicable rendering mode"
        contentWithRenderingMode
            .containerBackground(for: .widget) {
                WidgetTheme.background
            }
    }
    
    @ViewBuilder private var contentWithRenderingMode: some View {
        switch renderingMode {
        case .fullColor:
            contentByFamily
        case .accented:
            contentByFamily
                .widgetAccentable()
        case .vibrant:
            contentByFamily
        default:
            contentByFamily
        }
    }
    
    @ViewBuilder private var contentByFamily: some View {
        switch family {
        case .systemSmall:
            SmallTasksView(entry: entry)
        case .systemMedium:
            MediumTasksView(entry: entry)
        case .systemLarge:
            LargeTasksView(entry: entry)
        default:
            MediumTasksView(entry: entry)
        }
    }
}


struct SmallTasksView: View {
    let entry: TasksWidgetEntry
    
    private let widgetTitle = "Tasks"
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.spacingS) {
            Text(widgetTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)
            Rectangle()
                .fill(WidgetTheme.accent)
                .frame(height: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, WidgetTheme.spacingL)
                .padding(.bottom, WidgetTheme.spacingS)
            if entry.tasks.isEmpty && !entry.isLoggedIn {
                signInPrompt
            } else if entry.tasks.isEmpty {
                emptyState
            } else {
                taskList(tasks: Array(entry.tasks.prefix(5)))
            }
        }
        .padding()
    }
    
    private var signInPrompt: some View {
        Text("Open app to sign in")
            .font(.caption2)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private var emptyState: some View {
        Text("No tasks")
            .font(.caption2)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private func taskList(tasks: [GoogleTask]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(tasks) { task in
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.accent : WidgetTheme.textTertiary)
                    Text(task.displayTitle)
                        .font(.caption2)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.textTertiary : WidgetTheme.textPrimary)
                }
            }
        }
    }
}

struct MediumTasksView: View {
    let entry: TasksWidgetEntry
    
    private let widgetTitle = "Tasks"
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.spacingS) {
            Text(widgetTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)
            Rectangle()
                .fill(WidgetTheme.accent)
                .frame(height: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, WidgetTheme.spacingL)
                .padding(.bottom, WidgetTheme.spacingS)
            if entry.tasks.isEmpty && !entry.isLoggedIn {
                signInPrompt
            } else if entry.tasks.isEmpty {
                emptyState
            } else {
                taskList(tasks: Array(entry.tasks.prefix(8)))
            }
        }
        .padding()
    }
    
    private var signInPrompt: some View {
        Text("Open the app to sign in with Google and sync your tasks.")
            .font(.caption)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private var emptyState: some View {
        Text("No tasks in this list")
            .font(.caption)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private func taskList(tasks: [GoogleTask]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tasks) { task in
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.accent : WidgetTheme.textTertiary)
                    Text(task.displayTitle)
                        .font(.caption)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.textTertiary : WidgetTheme.textPrimary)
                }
            }
        }
    }
}

struct LargeTasksView: View {
    let entry: TasksWidgetEntry
    
    private let widgetTitle = "Tasks"
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.spacingM) {
            Text(widgetTitle)
                .font(.headline)
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)
            Rectangle()
                .fill(WidgetTheme.accent)
                .frame(height: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, WidgetTheme.spacingL)
                .padding(.bottom, WidgetTheme.spacingS)
            if entry.tasks.isEmpty && !entry.isLoggedIn {
                signInPrompt
            } else if entry.tasks.isEmpty {
                emptyState
            } else {
                taskList(tasks: Array(entry.tasks.prefix(15)))
            }
        }
        .padding()
    }
    
    private var signInPrompt: some View {
        Text("Open the app to sign in with Google and sync your tasks to this widget.")
            .font(.subheadline)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private var emptyState: some View {
        Text("No tasks in this list")
            .font(.subheadline)
            .foregroundStyle(WidgetTheme.textTertiary)
    }
    
    private func taskList(tasks: [GoogleTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tasks) { task in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.accent : WidgetTheme.textTertiary)
                    Text(task.displayTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? WidgetTheme.textTertiary : WidgetTheme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Widget

@main
struct GoogleTasksWidgetBundle: WidgetBundle {
    var body: some Widget {
        GoogleTasksWidget()
    }
}

struct GoogleTasksWidget: Widget {
    let kind: String = "GoogleTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksWidgetProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("Google Tasks")
        .description("Shows your Google Tasks to-do list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
