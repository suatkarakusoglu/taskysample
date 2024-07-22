//
//  TasksView.swift
//  TaskySample
//
//  Created by Suat Karakusoglu (Dogus Teknoloji) on 22.07.2024.
//

import SwiftUI
import Foundation
import Combine

struct TasksView: View {
    class Model: ObservableObject {
        @Published var tasks: [TaskDetail] = []
        @Published var isLoading: Bool = false
        @Published var isTaskInputValid = false
        @Published var taskInput: String = ""

        init(tasks: [TaskDetail]) {
            self.tasks = tasks
        }
    }

    enum Event {
        case addTaskDemanded(title: String)
        case playback
        case delete(indexSet: IndexSet)
        case taskInputChanged(input: String)
        case favoriteStateChange(id: TaskDetail.ID, isFavorited: Bool)
    }

    typealias EventHandler = (Event) async -> Void

    var handleEvent: EventHandler

    @ObservedObject
    var model: Model

    @State
    private var isDeletionApprovalShowing: Bool = false

    @State
    private var taskToDelete: IndexSet? {
        didSet {
            isDeletionApprovalShowing = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    taskEntryView
                    taskSubmitView
                }.padding()
                taskList
            }
              .confirmationDialog("Delete?", isPresented: self.$isDeletionApprovalShowing, titleVisibility: .visible) {
                  Button(role: .destructive) {
                      Task{
                          await handleEvent(.delete(indexSet: self.taskToDelete!))
                      }
                  } label: {
                      Text("Yes")
                  }

                  Button(role: .cancel) {
                      print("Not deleted.")
                  } label: {
                      Text("No")
                  }

              }.navigationTitle("My Tasks.")
              .toolbar{
                  ToolbarItem(placement: .topBarTrailing) {
                      Button(action: {
                                 Task{
                                     await handleEvent(.playback)
                                 }
                             }) {
                          Image(systemName: "play")
                      }
                  }
              }
        }
          .overlay(
            Group {
                if model.isLoading {
                    ProgressView()
                }
            }
          )
          .tint(.teal)
    }

    var taskEntryView: some View {
        TextField("Enter task title", text: $model.taskInput) {
            Task{
                await handleEvent(.addTaskDemanded(title: model.taskInput))
            }
        }
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .onChange(of: model.taskInput) { oldTitle, newTitle in
              Task {
                  await handleEvent(.taskInputChanged(input: newTitle))
              }
          }.submitLabel(.done)
    }

    var taskSubmitView: some View {
        Button(action: {
                   Task{
                       await handleEvent(.addTaskDemanded(title: model.taskInput))
                   }
               }) {
            Image(systemName: "plus")
        }.disabled(model.isLoading || !model.isTaskInputValid)
    }

    var taskList: some View {
        List {
            ForEach(model.tasks) { task in
                NavigationLink {
                    Text("Detail")
                } label: {
                    HStack{
                        Text(task.title).transition(.move(edge: .trailing))
                        Spacer()
                        Button {
                            print("UnFavorite this")
                        } label: {
                            Text(task.isFavorited ?  "❤️" : "🤍")
                        }
                          .simultaneousGesture(TapGesture().onEnded {
                                                   // Prevents Navigation Link from triggering
                                                   Task {
                                                       await handleEvent(.favoriteStateChange(id: task.id, isFavorited: !task.isFavorited))
                                                   }
                                               })
                    }
                }

            }.onDelete { deletionIndex in
                self.taskToDelete = deletionIndex
            }
        }.animation(.default, value: model.tasks)
          .listStyle(.plain)
    }
}

extension TasksView {
    init(viewModel: TasksViewModel) {
        self.handleEvent = viewModel.handleEvent(_:)
        self.model = viewModel.model
    }
}

struct TaskDetail: Identifiable, Equatable {
    static func == (lhs: TaskDetail, rhs: TaskDetail) -> Bool {
        return lhs.id == rhs.id
    }

    typealias ID = String

    var id: ID
    var title: String
    var isFavorited: Bool = false

    init(id: ID, title: String, isFavorited: Bool) {
        self.id = id
        self.title = title
        self.isFavorited = isFavorited
    }
}

class TasksViewModel {
    typealias View = TasksView

    var model: View.Model
    private var events: [View.Event] = []

    init(model: View.Model) {
        self.model = model
    }

    convenience init() {
        self.init(model: View.Model(tasks: []))
    }

    @MainActor
    func handleEvent(_ event: View.Event) async {
        self.events.append(event)

        switch event {
        case let .addTaskDemanded(title):
            model.isLoading = true

            try? await Task.sleep(nanoseconds: 1000000000)
            if !title.isEmpty {

                let newTask = TaskDetail(
                  id: title,
                  title: title,
                  isFavorited: title.contains("love") || title.contains("Suat")
                )
                model.tasks.insert(newTask, at: 0)
                model.taskInput = ""
            }

            model.isLoading = false
        case .playback:
            await self.playEventsFromStart()

        case .delete(indexSet: let indexSet):
            if let indexToDelete = indexSet.first
            {
                model.tasks.remove(at: indexToDelete)
            }
        case let .taskInputChanged(input):
            let isLongEnough = input.count > 3
            model.isTaskInputValid = isLongEnough

        case let .favoriteStateChange(id, isFavorited):
            if let taskToFavoriteIndex = model.tasks.firstIndex(where: { taskDetail in
                                                                         taskDetail.id == id
                                                                     }) {
                var taskToFavorite = model.tasks[taskToFavoriteIndex]
                taskToFavorite.isFavorited = isFavorited
                model.tasks[taskToFavoriteIndex] = taskToFavorite
            }
        }
    }

    func recordEvents(_ event: View.Event) {
        self.events.append(event)
    }

    @MainActor
    func playEventsFromStart() async {
        // Remove play events from start to break loop
        self.events.removeLast()

        self.model.tasks = []

        let events = self.events
        self.events = []

        for event in events {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await self.handleEvent(event)
        }

    }
}

#Preview {
    TasksView(viewModel: TasksViewModel())
}
