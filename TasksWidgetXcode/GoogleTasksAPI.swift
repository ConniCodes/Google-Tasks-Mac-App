import Foundation

/// Fetches task lists and tasks from Google Tasks API using a valid access token.
final class GoogleTasksAPI {
    private let baseURL = "https://tasks.googleapis.com/tasks/v1"
    private let getAccessToken: () async throws -> String
    
    init(getAccessToken: @escaping () async throws -> String) {
        self.getAccessToken = getAccessToken
    }
    
    func fetchTaskLists() async throws -> [GoogleTaskList] {
        let token = try await getAccessToken()
        var allItems: [GoogleTaskList] = []
        var pageToken: String?
        
        repeat {
            var urlString = "\(baseURL)/users/@me/lists?maxResults=100"
            if let token = pageToken {
                urlString += "&pageToken=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)"
            }
            guard let url = URL(string: urlString) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            
            let decoded = try JSONDecoder().decode(GoogleTaskListsResponse.self, from: data)
            if let items = decoded.items {
                allItems.append(contentsOf: items)
            }
            pageToken = decoded.nextPageToken
        } while pageToken != nil
        
        return allItems
    }
    
    func fetchTasks(taskListId: String, showCompleted: Bool = true, maxResults: Int = 100) async throws -> [GoogleTask] {
        let token = try await getAccessToken()
        var allItems: [GoogleTask] = []
        var pageToken: String?
        let encodedId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        
        repeat {
            var urlString = "\(baseURL)/lists/\(encodedId)/tasks?maxResults=\(maxResults)&showCompleted=\(showCompleted)"
            if let token = pageToken {
                urlString += "&pageToken=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)"
            }
            guard let url = URL(string: urlString) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            
            let decoded = try JSONDecoder().decode(GoogleTasksResponse.self, from: data)
            if let items = decoded.items {
                allItems.append(contentsOf: items)
            }
            pageToken = decoded.nextPageToken
        } while pageToken != nil
        
        return allItems
    }
    
    /// POST a new task list. Google Tasks API: tasklists.insert
    func insertList(title: String) async throws -> GoogleTaskList {
        let token = try await getAccessToken()
        guard let url = URL(string: "\(baseURL)/users/@me/lists") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["title": title])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTaskList.self, from: data)
    }
    
    /// PATCH list title (rename). Google Tasks API: tasklists.patch
    func updateList(taskListId: String, title: String) async throws -> GoogleTaskList {
        let token = try await getAccessToken()
        let encodedId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        guard let url = URL(string: "\(baseURL)/users/@me/lists/\(encodedId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["title": title]
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTaskList.self, from: data)
    }
    
    /// DELETE a task list. Google Tasks API: tasklists.delete
    func deleteList(taskListId: String) async throws {
        let token = try await getAccessToken()
        let encodedId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        guard let url = URL(string: "\(baseURL)/users/@me/lists/\(encodedId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { return }
        try validateResponse(response, data: data)
    }
    
    /// POST a new task. Google Tasks API: tasks.insert. parentTaskId = nil for top-level, set for subtask.
    func insertTask(taskListId: String, title: String, notes: String? = nil, parentTaskId: String? = nil) async throws -> GoogleTask {
        let token = try await getAccessToken()
        let encodedId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        var urlString = "\(baseURL)/lists/\(encodedId)/tasks"
        if let parent = parentTaskId, !parent.isEmpty {
            urlString += "?parent=\(parent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? parent)"
        }
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["title": title]
        if let notes = notes, !notes.isEmpty { body["notes"] = notes }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }
    
    /// PATCH task details (title, notes, due). Google Tasks API: tasks.patch. Set clearDue true to remove due date.
    func patchTask(taskListId: String, taskId: String, title: String? = nil, notes: String? = nil, due: String? = nil, clearDue: Bool = false) async throws -> GoogleTask {
        let token = try await getAccessToken()
        let encodedListId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        guard let url = URL(string: "\(baseURL)/lists/\(encodedListId)/tasks/\(encodedTaskId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if let t = title { body["title"] = t }
        if let n = notes { body["notes"] = n }
        if clearDue { body["due"] = NSNull() }
        else if let d = due { body["due"] = d }
        if body.isEmpty { return try await getTask(taskListId: taskListId, taskId: taskId) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }
    
    /// GET a single task. Used when patch has no body.
    private func getTask(taskListId: String, taskId: String) async throws -> GoogleTask {
        let token = try await getAccessToken()
        let encodedListId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        guard let url = URL(string: "\(baseURL)/lists/\(encodedListId)/tasks/\(encodedTaskId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }
    
    /// DELETE a task. Google Tasks API: tasks.delete.
    func deleteTask(taskListId: String, taskId: String) async throws {
        let token = try await getAccessToken()
        let encodedListId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        guard let url = URL(string: "\(baseURL)/lists/\(encodedListId)/tasks/\(encodedTaskId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { return }
        try validateResponse(response, data: Data())
    }
    
    /// Move a task to a new position (and optionally to another list). Google Tasks API: tasks.move.
    /// - Parameters:
    ///   - taskListId: Source list (where the task currently is).
    ///   - taskId: Task to move.
    ///   - previousTaskId: In the destination list, the task that should precede this one; nil = first.
    ///   - destinationTaskListId: If set, move the task to this list; otherwise move within taskListId.
    func moveTask(taskListId: String, taskId: String, previousTaskId: String?, destinationTaskListId: String? = nil) async throws -> GoogleTask {
        let token = try await getAccessToken()
        let encodedListId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        var urlString = "\(baseURL)/lists/\(encodedListId)/tasks/\(encodedTaskId)/move"
        var queryItems: [String] = []
        if let prev = previousTaskId, !prev.isEmpty {
            queryItems.append("previous=\(prev.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prev)")
        }
        if let dest = destinationTaskListId, !dest.isEmpty {
            queryItems.append("destinationTasklist=\(dest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dest)")
        }
        if !queryItems.isEmpty {
            urlString += "?" + queryItems.joined(separator: "&")
        }
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }
    
    /// PATCH task status. Google Tasks API: tasks.patch (mark completed or needsAction).
    func updateTask(taskListId: String, taskId: String, completed: Bool) async throws -> GoogleTask {
        let token = try await getAccessToken()
        let encodedListId = taskListId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskListId
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        guard let url = URL(string: "\(baseURL)/lists/\(encodedListId)/tasks/\(encodedTaskId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = completed
            ? ["status": "completed"]
            : ["status": "needsAction", "completed": NSNull()]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("HTTP \(http.statusCode)")
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let msg): return msg
        }
    }
}
