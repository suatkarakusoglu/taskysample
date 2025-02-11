//
//  TaskySampleApp.swift
//  TaskySample
//
//  Created by Suat Karakusoglu (Dogus Teknoloji) on 22.07.2024.
//

import SwiftUI

@main
struct TaskySampleApp: App {
    let tasksViewModel = TasksViewModel()

    var body: some Scene {
        WindowGroup {
            TasksView(viewModel: tasksViewModel)
        }
    }
}
