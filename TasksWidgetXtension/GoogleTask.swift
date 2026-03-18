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
