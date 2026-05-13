import Foundation
import OSLog

// MARK: - Vibe Coding 时长追踪器

/// 记录用户的真实 vibe coding 时长
///
/// 工作原理：
/// 1. 监听 SessionFileWatcher 的会话状态变化
/// 2. 仅当会话处于"活跃编码"状态时累计时长（coding/thinking/waitingPermission）
/// 3. 空闲/完成/错误状态不计入时长
/// 4. 每 30 秒持久化一次，防止数据丢失
@MainActor
@Observable
final class CodingTimeTracker {
    static let shared = CodingTimeTracker()
    
    // MARK: 公开状态
    
    /// 今日累计编码时长（秒）
    private(set) var todayCodingSeconds: Int = 0
    
    /// 本周累计编码时长（秒）
    private(set) var weekCodingSeconds: Int = 0
    
    /// 总累计编码时长（秒）
    private(set) var totalCodingSeconds: Int = 0
    
    /// 今日编码时长（分钟，四舍五入）
    var todayCodingMinutes: Int { todayCodingSeconds / 60 }
    
    /// 本周编码时长（分钟，四舍五入）
    var weekCodingMinutes: Int { weekCodingSeconds / 60 }
    
    /// 总编码时长（分钟，四舍五入）
    var totalCodingMinutes: Int { totalCodingSeconds / 60 }
    
    // MARK: 内部状态
    
    /// 当前活跃编码会话的集合
    private var activeCodingSessions: Set<String> = []
    
    /// 上次状态检查时间
    private var lastCheckDate: Date = Date()
    
    /// 持久化定时器
    private var persistTimer: Timer?
    
    /// 今日日期标记（用于判断是否跨天）
    private var todayMarker: Date = Calendar.current.startOfDay(for: Date())
    
    /// 本周一日期标记（用于判断是否跨周）
    private var weekMarker: Date = {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return Calendar.current.startOfDay(for: Calendar.current.date(from: components) ?? Date())
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "CodingTimeTracker"
    )
    
    // MARK: 初始化
    
    private init() {
        loadPersistedData()
        startPersistTimer()
    }
    
    // MARK: 生命周期
    
    /// 启动追踪器
    func start() {
        Self.logger.info("CodingTimeTracker 已启动")
    }
    
    /// 停止追踪器
    func stop() {
        persistTimer?.invalidate()
        persistTimer = nil
        persistData()
        Self.logger.info("CodingTimeTracker 已停止")
    }
    
    // MARK: 事件处理
    
    /// 处理会话状态变化
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - state: 新状态
    func handleSessionStateChange(sessionId: String, state: SessionState) {
        checkDateMarkers()
        
        let isCodingState = isCodingActiveState(state)
        let wasActive = activeCodingSessions.contains(sessionId)
        
        if isCodingState && !wasActive {
            // 会话进入编码状态
            activeCodingSessions.insert(sessionId)
            Self.logger.debug("会话 \(sessionId) 进入编码状态: \(state.rawValue)")
        } else if !isCodingState && wasActive {
            // 会话离开编码状态
            activeCodingSessions.remove(sessionId)
            Self.logger.debug("会话 \(sessionId) 离开编码状态: \(state.rawValue)")
        }
    }
    
    /// 定时更新（每 30 秒调用一次）
    func tick() {
        checkDateMarkers()
        
        let now = Date()
        let interval = now.timeIntervalSince(lastCheckDate)
        lastCheckDate = now
        
        // 如果有活跃编码会话，累计时长
        if !activeCodingSessions.isEmpty {
            let seconds = max(0, Int(interval))
            todayCodingSeconds += seconds
            weekCodingSeconds += seconds
            totalCodingSeconds += seconds
        }
    }
    
    // MARK: 私有方法
    
    /// 判断状态是否为"活跃编码"状态
    private func isCodingActiveState(_ state: SessionState) -> Bool {
        switch state {
        case .thinking, .coding, .waitingPermission:
            return true  // 这些状态表示用户正在 actively 编码
        case .idle, .waiting, .completed, .error, .compacting:
            return false  // 这些状态不计入编码时长
        }
    }
    
    /// 检查日期标记是否需要更新（跨天/跨周）
    private func checkDateMarkers() {
        let now = Date()
        let calendar = Calendar.current
        
        let newToday = calendar.startOfDay(for: now)
        if newToday > todayMarker {
            // 跨天了，重置今日计数
            Self.logger.info("跨天检测：重置今日计数")
            todayCodingSeconds = 0
            todayMarker = newToday
        }
        
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekDate = calendar.date(from: components) else { return }
        let newWeek = calendar.startOfDay(for: weekDate)
        if newWeek > weekMarker {
            // 跨周了，重置本周计数
            Self.logger.info("跨周检测：重置本周计数")
            weekCodingSeconds = 0
            weekMarker = newWeek
        }
    }
    
    // MARK: 持久化
    
    private func startPersistTimer() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistData()
            }
        }
    }
    
    private func persistData() {
        let defaults = UserDefaults.standard
        defaults.set(todayCodingSeconds, forKey: "vibe-island.today-coding-seconds")
        defaults.set(weekCodingSeconds, forKey: "vibe-island.week-coding-seconds")
        defaults.set(totalCodingSeconds, forKey: "vibe-island.total-coding-seconds")
        defaults.set(todayMarker.timeIntervalSince1970, forKey: "vibe-island.today-marker")
        defaults.set(weekMarker.timeIntervalSince1970, forKey: "vibe-island.week-marker")
        Self.logger.debug("编码时长数据已持久化")
    }
    
    private func loadPersistedData() {
        let defaults = UserDefaults.standard
        todayCodingSeconds = defaults.integer(forKey: "vibe-island.today-coding-seconds")
        weekCodingSeconds = defaults.integer(forKey: "vibe-island.week-coding-seconds")
        totalCodingSeconds = defaults.integer(forKey: "vibe-island.total-coding-seconds")
        
        if let marker = defaults.object(forKey: "vibe-island.today-marker") as? TimeInterval {
            todayMarker = Date(timeIntervalSince1970: marker)
        }
        if let marker = defaults.object(forKey: "vibe-island.week-marker") as? TimeInterval {
            weekMarker = Date(timeIntervalSince1970: marker)
        }
        
        // 检查是否需要重置（跨天/跨周）
        checkDateMarkers()
        
        Self.logger.info("编码时长数据已加载：今日 \(self.todayCodingMinutes) 分钟，总计 \(self.totalCodingMinutes) 分钟")
    }
    
    /// 重置所有数据（测试用）
    func reset() {
        todayCodingSeconds = 0
        weekCodingSeconds = 0
        totalCodingSeconds = 0
        activeCodingSessions.removeAll()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "vibe-island.today-coding-seconds")
        defaults.removeObject(forKey: "vibe-island.week-coding-seconds")
        defaults.removeObject(forKey: "vibe-island.total-coding-seconds")
        Self.logger.info("编码时长数据已重置")
    }
}
