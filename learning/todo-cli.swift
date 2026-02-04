#!/usr/bin/env swift
/*
 * TODO CLI - Simple task manager
 * Compile: swiftc todo-cli.swift -o todo-cli
 * Run: ./todo-cli or swift todo-cli.swift
 */

import Foundation

struct Todo: Codable {
    var task: String
    var done: Bool
}

let TODO_FILE = "todos.json"

func loadTodos() -> [Todo] {
    let fileURL = URL(fileURLWithPath: TODO_FILE)
    
    guard let data = try? Data(contentsOf: fileURL) else {
        return []
    }
    
    guard let todos = try? JSONDecoder().decode([Todo].self, from: data) else {
        return []
    }
    
    return todos
}

func saveTodos(_ todos: [Todo]) {
    let fileURL = URL(fileURLWithPath: TODO_FILE)
    
    guard let data = try? JSONEncoder().encode(todos) else {
        print("Error: Could not save todos")
        return
    }
    
    try? data.write(to: fileURL)
}

func listTodos(_ todos: [Todo]) {
    if todos.isEmpty {
        print("No tasks yet!")
        return
    }
    
    print("\n=== Your Tasks ===")
    for (index, todo) in todos.enumerated() {
        let status = todo.done ? "X" : " "
        print("\(index + 1). [\(status)] \(todo.task)")
    }
}

func addTodo(_ todos: inout [Todo], task: String) {
    let newTodo = Todo(task: task, done: false)
    todos.append(newTodo)
    saveTodos(todos)
    print("Added: \(task)")
}

func completeTodo(_ todos: inout [Todo], index: Int) {
    if index > 0 && index <= todos.count {
        todos[index - 1].done = true
        saveTodos(todos)
        print("Completed: \(todos[index - 1].task)")
    } else {
        print("Invalid task number")
    }
}

func main() {
    var todos = loadTodos()
    
    while true {
        print("\n=== TODO CLI ===")
        print("1. List tasks")
        print("2. Add task")
        print("3. Complete task")
        print("4. Exit")
        
        print("\nChoice: ", terminator: "")
        guard let choice = readLine() else { continue }
        
        switch choice {
        case "1":
            listTodos(todos)
        case "2":
            print("Enter task: ", terminator: "")
            if let task = readLine() {
                addTodo(&todos, task: task)
            }
        case "3":
            listTodos(todos)
            print("Task number to complete: ", terminator: "")
            if let numStr = readLine(), let num = Int(numStr) {
                completeTodo(&todos, index: num)
            } else {
                print("Invalid number")
            }
        case "4":
            print("Goodbye!")
            return
        default:
            print("Invalid choice")
        }
    }
}

main()
