import SwiftUI

// MARK: - 会话列表视图

/// 显示活跃会话列表，支持点击选择要高亮显示的会话
struct SessionListView: View {
    @Environment(StateManager.self) private var viewModel
    private var sessionManager: SessionManager { .shared }

    /// 会话行组件
    private struct SessionRow: View {
        let session: Session
        let isSelected: Bool
        let onSelect: () -> Void

        var body: some View {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    // 会话名
                    Text(session.sessionName ?? session.cwd.shortenedCwd())
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 工具来源
                    Text(session.toolDisplayName)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    // 状态图标 + 名称
                    HStack(spacing: 2) {
                        Image(systemName: session.status.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(session.status.color)
                        Text(session.status.statusName)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(session.status.color)
                    }
                    .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.blue.opacity(0.6) : Color.gray.opacity(0.15),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sessionManager.sortedSessions.isEmpty {
                emptyState
            } else {
                ForEach(Array(sessionManager.sortedSessions.prefix(8)), id: \.sessionId) { session in
                    SessionRow(
                        session: session,
                        isSelected: isSessionSelected(session),
                        onSelect: {
                            selectSession(session)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 辅助方法

    private func isSessionSelected(_ session: Session) -> Bool {
        switch sessionManager.trackingMode {
        case .auto:
            return false
        case .manual(let sessionId):
            return sessionId == session.sessionId
        }
    }

    private func selectSession(_ session: Session) {
        switch sessionManager.trackingMode {
        case .auto:
            sessionManager.setTrackingModeManual(sessionId: session.sessionId)
        case .manual(let sessionId):
            if sessionId == session.sessionId {
                sessionManager.toggleTrackingMode()
            } else {
                sessionManager.setTrackingModeManual(sessionId: session.sessionId)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
            Text("No active sessions")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - SessionState 扩展

extension SessionState {
    /// 状态名称（英文）
    var statusName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .coding: return "Coding"
        case .waiting: return "Waiting"
        case .waitingPermission: return "Permission"
        case .completed: return "Completed"
        case .error: return "Error"
        case .compacting: return "Compacting"
        }
    }

    /// 状态对应的 SF Symbol 图标
    var icon: String {
        switch self {
        case .idle: return "moon.fill"
        case .thinking: return "brain.fill"
        case .coding: return "terminal.fill"
        case .waiting: return "text.bubble.fill"
        case .waitingPermission: return "lock.shield.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .compacting: return "shippingbox.fill"
        }
    }
}