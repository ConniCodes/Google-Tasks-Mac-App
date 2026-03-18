import Foundation

/// Model matching Google Tasks API task structure. Shared between app and widget.
struct GoogleTask: Codable, Identifiable {
    let id: String
    let title: String?
    let notes: String?
    let status: String?  // "needsAction" or "completed"
    let due: String?     // RFC 3339 timestamp
    let completed: String? // RFC 3339 when completed
    let parent: String?
    let position: String?
    
    var isCompleted: Bool {
        status == "completed"
    }
    
    var displayTitle: String {
        title ?? "Untitled"
    }
    
    /// Parsed due date for display/editing (RFC 3339 / ISO8601).
    var dueDate: Date? {
        guard let due = due, !due.isEmpty else { return nil }
        return Self.rfc3339Formatter.date(from: due)
    }
    
    /// Format a Date as RFC 3339 for the API (due date: use start of day UTC).
    static func rfc3339String(from date: Date) -> String {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.timeZone = TimeZone(identifier: "UTC")
        let startOfDayUTC = cal.date(from: comps) ?? date
        return Self.rfc3339Formatter.string(from: startOfDayUTC)
    }
    
    private static let rfc3339Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

/// Helpers for task list filtering (top-level vs subtasks).
enum TaskListFilter {
    /// Top-level tasks only (no parent).
    static func topLevel(_ tasks: [GoogleTask]) -> [GoogleTask] {
        tasks.filter { ($0.parent ?? "").isEmpty }
    }
    
    /// Subtasks for a given parent task id.
    static func subtasks(for parentId: String, from tasks: [GoogleTask]) -> [GoogleTask] {
        tasks.filter { $0.parent == parentId }
    }
}

/// Response from GET tasks/v1/lists/{taskListId}/tasks
struct GoogleTasksResponse: Codable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let items: [GoogleTask]?
}

/// Model matching Google Tasks API task list structure
struct GoogleTaskList: Codable, Identifiable {
    let id: String
    let title: String?
    let updated: String?
}

/// Response from GET tasks/v1/users/@me/lists
struct GoogleTaskListsResponse: Codable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let items: [GoogleTaskList]?
}
