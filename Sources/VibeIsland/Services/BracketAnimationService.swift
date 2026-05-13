import Foundation
import SwiftUI

// MARK: - 括号弹跳动画服务

@MainActor
@Observable
final class BracketAnimationService {
    var isExpanded = false
    private var timer: Timer?
    private var isRunning = false
    
    func start(interval: TimeInterval = 0.2) {
        if isRunning { return }
        isRunning = true
        isExpanded = true
        
        timer?.invalidate() // 安全：先清理残留 timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }
    }
    
    func stop(immediately: Bool = false) {
        guard isRunning else { return }
        isRunning = false

        timer?.invalidate()
        timer = nil

        if immediately {
            isExpanded = false
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded = false
            }
        }
    }
    
    private func toggle() {
        isExpanded.toggle()
    }
}