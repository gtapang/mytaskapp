import SwiftUI
import SwiftData
import HermesNotesCore

/// Dedicated planning screen: a real four-quadrant matrix, not a filtered
/// list. Drag tasks between quadrants; a quiet tray below holds unassigned
/// open tasks. The quadrant backgrounds use the `quadrantWash` Metal shader
/// so the surface stays fluid while dragging.
struct EisenhowerView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<TaskItem> { $0.statusRaw != "done" && $0.statusRaw != "dropped" })
    private var openTasks: [TaskItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    axisHeader

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(EisenhowerQuadrant.matrix, id: \.self) { quadrant in
                            QuadrantCell(
                                quadrant: quadrant,
                                tasks: tasks(in: quadrant),
                                onDrop: { assign($0, to: quadrant) }
                            )
                        }
                    }

                    unassignedTray
                }
                .padding(CalmTheme.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Eisenhower")
        }
    }

    private var axisHeader: some View {
        HStack {
            Text("Urgent ↔ Not urgent across · Important ↕ Not important down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var unassignedTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            CalmSectionLabel("Unassigned")
            let unassigned = tasks(in: .unassigned)
            if unassigned.isEmpty {
                Text("Everything is placed. Drag tasks here to unplan them.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(unassigned) { task in
                    DraggableTaskChip(task: task)
                }
            }
        }
        .calmCard()
        .dropDestination(for: String.self) { ids, _ in
            handleDrop(ids, quadrant: .unassigned)
        }
    }

    private func tasks(in quadrant: EisenhowerQuadrant) -> [TaskItem] {
        openTasks
            .filter { $0.quadrant == quadrant }
            .sorted { $0.priority > $1.priority }
    }

    private func assign(_ ids: [String], to quadrant: EisenhowerQuadrant) {
        handleDrop(ids, quadrant: quadrant)
    }

    @discardableResult
    private func handleDrop(_ ids: [String], quadrant: EisenhowerQuadrant) -> Bool {
        var moved = false
        for idString in ids {
            guard let id = UUID(uuidString: idString),
                  let task = openTasks.first(where: { $0.id == id })
            else { continue }
            task.quadrant = quadrant
            task.updatedAt = .now
            moved = true
        }
        return moved
    }
}

private struct QuadrantCell: View {
    let quadrant: EisenhowerQuadrant
    let tasks: [TaskItem]
    let onDrop: ([String]) -> Void

    @State private var isTargeted = false

    private var tint: Color {
        switch quadrant {
        case .doFirst: .red
        case .schedule: CalmTheme.accent
        case .delegate: .orange
        case .eliminate: .gray
        case .unassigned: .clear
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quadrantShortName(quadrant))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                Text("Drop tasks here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                ForEach(tasks) { task in
                    DraggableTaskChip(task: task)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: CalmTheme.cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .quadrantWash(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isTargeted ? tint.opacity(0.6) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .dropDestination(for: String.self) { ids, _ in
            onDrop(ids)
            return true
        } isTargeted: {
            isTargeted = $0
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

private struct DraggableTaskChip: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: 6) {
            if task.priority != .none {
                Circle()
                    .fill(CalmTheme.priorityColor(task.priority))
                    .frame(width: 6, height: 6)
            }
            Text(task.title)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .draggable(task.id.uuidString)
    }
}
