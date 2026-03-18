import Foundation

/// Shared store for task data. Used by both the main app (write) and widget (read).
/// Uses App Group UserDefaults so the widget can display the latest tasks.
enum TaskStore {
    private static let suiteName = "group.com.googletasks.widget"
    private static let tasksKey = "cached_tasks"
    private static let taskListIdKey = "selected_task_list_id"
    private static let taskListTitleKey = "selected_task_list_title"
    private static let lastUpdatedKey = "last_updated"
    
    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    static func saveTasks(_ tasks: [GoogleTask], listId: String, listTitle: String) {
        guard let defaults = shared else { return }
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: tasksKey)
            defaults.set(listId, forKey: taskListIdKey)
            defaults.set(listTitle, forKey: taskListTitleKey)
            defaults.set(Date(), forKey: lastUpdatedKey)
            defaults.synchronize()
        }
    }
    
    static func loadTasks() -> [GoogleTask] {
        guard let defaults = shared,
              let data = defaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([GoogleTask].self, from: data) else {
            return []
        }
        return tasks
    }
    
    static var selectedListId: String? {
        shared?.string(forKey: taskListIdKey)
    }
    
    static var selectedListTitle: String? {
        shared?.string(forKey: taskListTitleKey)
    }
    
    static var lastUpdated: Date? {
        shared?.object(forKey: lastUpdatedKey) as? Date
    }
}
