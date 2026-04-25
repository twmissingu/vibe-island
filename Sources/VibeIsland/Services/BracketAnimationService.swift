import Foundation

// MARK: - 括号弹跳动画服务

@MainActor
@Observable
final class BracketAnimationService {
    var isExpanded = false
    private var timer: Timer?
    private var isRunning = false
    
    func start(interval: TimeInterval = 0.2) {
        guard !isRunning else { return }
        isRunning = true
        isExpanded = true
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isExpanded = false
    }
    
    private func toggle() {
        isExpanded.toggle()
    }
}