import Combine
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class TasksViewModel: ObservableObject {
    @Published var taskLists: [GoogleTaskList] = []
    @Published var tasks: [GoogleTask] = [] // Selected list's tasks (for TaskStore/widget)
    @Published var tasksByListId: [String: [GoogleTask]] = [:] // All lists' tasks for display
    @Published var selectedListId: String?
    @Published var selectedListTitle: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authManager: GoogleAuthManager
    private var tasksAPI: GoogleTasksAPI?
    
    init(authManager: GoogleAuthManager) {
        self.authManager = authManager
        self.tasksAPI = GoogleTasksAPI(getAccessToken: { [weak authManager] in
            try await authManager?.getAccessToken() ?? ""
        })
    }
    
    var isSignedIn: Bool {
        authManager.isSignedIn
    }
    
    func restoreSessionAndLoad() async {
        await authManager.restorePreviousSignIn()
        if authManager.isSignedIn {
            await loadTaskLists()
        }
    }
    
    /// Loads all task lists and then tasks for each list in parallel. Updates tasksByListId and selected list / widget.
    func loadTaskLists() async {
        guard authManager.isSignedIn else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let lists = try await tasksAPI?.fetchTaskLists() ?? []
            taskLists = lists
            var byId: [String: [GoogleTask]] = [:]
            await withTaskGroup(of: (String, [GoogleTask]).self) { group in
                for list in lists {
                    group.addTask {
                        let fetched = (try? await self.tasksAPI?.fetchTasks(taskListId: list.id)) ?? []
                        return (list.id, fetched)
                    }
                }
                for await (id, fetched) in group {
                    byId[id] = fetched
                }
            }
            tasksByListId = byId
            if let id = TaskStore.selectedListId, byId[id] != nil {
                selectedListId = id
                selectedListTitle = TaskStore.selectedListTitle ?? taskLists.first(where: { $0.id == id })?.title
                tasks = byId[id] ?? []
                TaskStore.saveTasks(tasks, listId: id, listTitle: selectedListTitle ?? "Tasks")
            } else if let first = lists.first {
                selectedListId = first.id
                selectedListTitle = first.title
                tasks = byId[first.id] ?? []
                TaskStore.saveTasks(tasks, listId: first.id, listTitle: first.title ?? "Tasks")
            } else {
                tasks = []
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "GoogleTasksWidget")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Refreshes a single list's tasks (e.g. after add/toggle). Updates tasksByListId and TaskStore if that list is selected.
    func loadTasks(listId: String, listTitle: String? = nil) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            let fetched = try await tasksAPI?.fetchTasks(taskListId: listId) ?? []
            tasksByListId[listId] = fetched
            if selectedListId == listId {
                selectedListTitle = listTitle ?? taskLists.first(where: { $0.id == listId })?.title
                tasks = fetched
                TaskStore.saveTasks(fetched, listId: listId, listTitle: selectedListTitle ?? "Tasks")
                WidgetCenter.shared.reloadTimelines(ofKind: "GoogleTasksWidget")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func selectList(_ list: GoogleTaskList) {
        selectedListId = list.id
        selectedListTitle = list.title
        tasks = tasksByListId[list.id] ?? []
        TaskStore.saveTasks(tasks, listId: list.id, listTitle: list.title ?? "Tasks")
        WidgetCenter.shared.reloadTimelines(ofKind: "GoogleTasksWidget")
    }
    
    func refresh() async {
        await loadTaskLists()
    }
    
    /// Reorder task lists (e.g. after drag and drop). Updates local order only; Google Tasks API does not support list order.
    func reorderLists(draggedListId: String, toIndex: Int) {
        guard let sourceIndex = taskLists.firstIndex(where: { $0.id == draggedListId }) else { return }
        let destIndex = min(max(0, toIndex), taskLists.count)
        if sourceIndex == destIndex { return }
        let list = taskLists.remove(at: sourceIndex)
        let insertIndex = sourceIndex < destIndex ? destIndex - 1 : destIndex
        taskLists.insert(list, at: insertIndex)
    }
    
    /// Create a new task list via Google Tasks API (tasklists.insert), then reload all lists.
    func createList(title: String) async {
        guard authManager.isSignedIn, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        do {
            _ = try await tasksAPI?.insertList(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
            await loadTaskLists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Rename a task list via Google Tasks API (tasklists.patch).
    func renameList(taskListId: String, newTitle: String) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            let updated = try await tasksAPI?.updateList(taskListId: taskListId, title: newTitle)
            if let updated = updated, let idx = taskLists.firstIndex(where: { $0.id == taskListId }) {
                taskLists[idx] = updated
                if selectedListId == taskListId { selectedListTitle = updated.title }
            }
            await loadTaskLists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Delete a task list via Google Tasks API (tasklists.delete).
    func deleteList(taskListId: String) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            try await tasksAPI?.deleteList(taskListId: taskListId)
            taskLists.removeAll { $0.id == taskListId }
            tasksByListId.removeValue(forKey: taskListId)
            if selectedListId == taskListId {
                selectedListId = taskLists.first?.id
                selectedListTitle = taskLists.first?.title
                tasks = tasksByListId[selectedListId ?? ""] ?? []
                if let id = selectedListId, let title = selectedListTitle {
                    TaskStore.saveTasks(tasks, listId: id, listTitle: title)
                }
                WidgetCenter.shared.reloadTimelines(ofKind: "GoogleTasksWidget")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Add a task to a list via Google Tasks API (tasks.insert).
    func addTask(taskListId: String, title: String, notes: String? = nil) async {
        guard authManager.isSignedIn, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        do {
            _ = try await tasksAPI?.insertTask(taskListId: taskListId, title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes)
            await loadTasks(listId: taskListId, listTitle: taskLists.first(where: { $0.id == taskListId })?.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Toggle a task's completed state via Google Tasks API (tasks.patch), then refresh that list's tasks.
    func toggleTaskCompletion(taskListId: String, task: GoogleTask) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            _ = try await tasksAPI?.updateTask(taskListId: taskListId, taskId: task.id, completed: !task.isCompleted)
            await loadTasks(listId: taskListId, listTitle: taskLists.first(where: { $0.id == taskListId })?.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Update task title, notes, and/or due date. Google Tasks API: tasks.patch. clearDue true removes the due date.
    func updateTaskDetails(taskListId: String, taskId: String, title: String?, notes: String?, due: String?, clearDue: Bool = false) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            _ = try await tasksAPI?.patchTask(taskListId: taskListId, taskId: taskId, title: title, notes: notes, due: due, clearDue: clearDue)
            await loadTasks(listId: taskListId, listTitle: taskLists.first(where: { $0.id == taskListId })?.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Delete a task. Google Tasks API: tasks.delete.
    func deleteTask(taskListId: String, taskId: String) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        do {
            try await tasksAPI?.deleteTask(taskListId: taskListId, taskId: taskId)
            await loadTasks(listId: taskListId, listTitle: taskLists.first(where: { $0.id == taskListId })?.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Add a subtask. Google Tasks API: tasks.insert with parent.
    func addSubtask(taskListId: String, parentTaskId: String, title: String, notes: String? = nil) async {
        guard authManager.isSignedIn, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        do {
            _ = try await tasksAPI?.insertTask(taskListId: taskListId, title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes, parentTaskId: parentTaskId)
            await loadTasks(listId: taskListId, listTitle: taskLists.first(where: { $0.id == taskListId })?.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Reorder a task within a list, or move it to another list. Google Tasks API: tasks.move.
    /// - Parameters:
    ///   - sourceListId: List the task is currently in.
    ///   - taskId: Task to move.
    ///   - previousTaskId: In the destination list, the task that should precede this one; nil = first.
    ///   - destinationListId: If nil or same as sourceListId, reorder within source; otherwise move task to this list.
    func reorderTask(sourceListId: String, taskId: String, previousTaskId: String?, destinationListId: String? = nil) async {
        guard authManager.isSignedIn else { return }
        errorMessage = nil
        let destId = destinationListId ?? sourceListId
        do {
            _ = try await tasksAPI?.moveTask(
                taskListId: sourceListId,
                taskId: taskId,
                previousTaskId: previousTaskId,
                destinationTaskListId: destId != sourceListId ? destId : nil
            )
            await loadTasks(listId: sourceListId, listTitle: taskLists.first(where: { $0.id == sourceListId })?.title)
            if destId != sourceListId {
                await loadTasks(listId: destId, listTitle: taskLists.first(where: { $0.id == destId })?.title)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
