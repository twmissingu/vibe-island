import SwiftUI

// MARK: - 会话列表视图

/// 显示所有活跃会话列表，支持点击选择要跟踪的会话
/// 支持"自动"模式（默认，跟踪最高优先级）
struct SessionListView: View {
    @Environment(StateManager.self) private var viewModel
    private var sessionManager: SessionManager { .shared }

    /// 会话行组件
    private struct SessionRow: View {
        let session: Session
        let sessionId: String
        let isTracked: Bool
        let isAutoMode: Bool
        let onSelect: () -> Void

        var body: some View {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    // 状态图标
                    Image(systemName: session.status.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(session.status.color)

                    // 状态名称
                    Text(session.status.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(session.status.color)
                        .frame(width: 48, alignment: .leading)

                    // 会话名
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = session.sessionName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Text(shortenedCwd(session.cwd))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // 跟踪指示器
                    if isTracked {
                        Image(systemName: isAutoMode ? "arrow.triangle.2.circlepath" : "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isTracked ? Color.blue.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }

        /// 缩短工作目录路径
        private func shortenedCwd(_ cwd: String) -> String {
            let components = cwd.split(separator: "/")
            guard components.count > 3 else { return cwd }
            return ".../" + components.suffix(2).joined(separator: "/")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 头部：模式切换
            HStack {
                Text("会话")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // 自动/手动切换按钮
                Button {
                    sessionManager.toggleTrackingMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sessionManager.trackingMode.isAuto ? "arrow.triangle.2.circlepath" : "pin.fill")
                            .font(.system(size: 10))
                        Text(sessionManager.trackingMode.isAuto ? "自动" : "固定")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 自动模式指示
            if sessionManager.trackingMode.isAuto {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("自动跟踪最高优先级会话")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            } else if let pinnedId = sessionManager.pinnedSessionId,
                      let pinnedSession = sessionManager.session(id: pinnedId) {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("已固定: \(pinnedSession.sessionName ?? pinnedSession.sessionId)")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 4)
            }

            // 会话列表
            if sessionManager.sortedSessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 2) {
                    ForEach(sessionManager.sortedSessions, id: \.sessionId) { session in
                        SessionRow(
                            session: session,
                            sessionId: session.sessionId,
                            isTracked: isSessionTracked(session),
                            isAutoMode: sessionManager.trackingMode.isAuto,
                            onSelect: {
                                selectSession(session)
                            }
                        )
                    }
                }
            }
        }
        .padding(8)
    }

    // MARK: - 辅助方法

    private func isSessionTracked(_ session: Session) -> Bool {
        if sessionManager.trackingMode.isAuto {
            // 自动模式下，最高优先级会话被视为"跟踪"
            guard let top = sessionManager.sortedSessions.first else { return false }
            return top.sessionId == session.sessionId
        } else {
            return session.sessionId == sessionManager.pinnedSessionId
        }
    }

    private func selectSession(_ session: Session) {
        // 如果点击的已经是当前跟踪的会话，不做任何操作
        if session.sessionId == sessionManager.trackedSession?.sessionId {
            return
        }
        sessionManager.setTrackingModeManual(sessionId: session.sessionId)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("暂无活跃会话")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - SessionState 扩展

extension SessionState {
    /// 状态对应的 SF Symbol 图标
    var icon: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .thinking: return "brain.head.filled"
        case .coding: return "hammer.fill"
        case .waiting: return "text.bubble.fill"
        case .waitingPermission: return "lock.shield.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .compacting: return "arrow.up.arrow.down.circle.fill"
        }
    }
}
