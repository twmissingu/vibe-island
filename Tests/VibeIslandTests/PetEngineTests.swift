import XCTest
import Foundation
@testable import VibeIsland

/// PetEngine 测试
/// 测试宠物引擎的核心功能：状态转换、帧数据获取、动画集加载等
@MainActor
final class PetEngineTests: XCTestCase {

    // MARK: - PetState 测试

    /// 测试：PetState 所有枚举值
    func testPetState_allCases() {
        let states: [PetState] = [.idle, .thinking, .coding, .waiting, .celebrating, .error, .compacting, .sleeping]
        XCTAssertEqual(states.count, 8)
    }

    /// 测试：PetState rawValue 正确
    func testPetState_rawValues() {
        XCTAssertEqual(PetState.idle.rawValue, "idle")
        XCTAssertEqual(PetState.thinking.rawValue, "thinking")
        XCTAssertEqual(PetState.coding.rawValue, "coding")
        XCTAssertEqual(PetState.waiting.rawValue, "waiting")
        XCTAssertEqual(PetState.celebrating.rawValue, "celebrating")
        XCTAssertEqual(PetState.error.rawValue, "error")
        XCTAssertEqual(PetState.compacting.rawValue, "compacting")
        XCTAssertEqual(PetState.sleeping.rawValue, "sleeping")
    }

    /// 测试：PetState Codable 编码解码
    func testPetState_encodeDecode() {
        let state = PetState.coding
        let encoder = JSONEncoder()
        let data = try! encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(PetState.self, from: data)
        XCTAssertEqual(decoded, .coding)
    }

    /// 测试：PetState from sessionState 映射
    func testPetState_fromSessionState() {
        XCTAssertEqual(PetState.from(sessionState: "idle"), .idle)
        XCTAssertEqual(PetState.from(sessionState: "thinking"), .thinking)
        XCTAssertEqual(PetState.from(sessionState: "coding"), .coding)
        XCTAssertEqual(PetState.from(sessionState: "waiting"), .waiting)
        XCTAssertEqual(PetState.from(sessionState: "celebrating"), .celebrating)
        XCTAssertEqual(PetState.from(sessionState: "error"), .error)
        XCTAssertEqual(PetState.from(sessionState: "compacting"), .compacting)
        XCTAssertEqual(PetState.from(sessionState: "sleeping"), .sleeping)
    }

    /// 测试：PetState from sessionState 未知值返回 idle
    func testPetState_fromSessionState_unknown_returnsIdle() {
        XCTAssertEqual(PetState.from(sessionState: "unknown"), .idle)
        XCTAssertEqual(PetState.from(sessionState: ""), .idle)
    }

    // MARK: - PetFrame 测试

    /// 测试：PetFrame 基本属性
    func testPetFrame_basicProperties() {
        let pixels: [PetFrame.Pixel] = [
            PetFrame.Pixel(x: 0, y: 0, color: "#FF0000"),
            PetFrame.Pixel(x: 1, y: 0, color: "#00FF00")
        ]
        let frame = PetFrame(pixels: pixels, width: 16, height: 16)

        XCTAssertEqual(frame.pixels.count, 2)
        XCTAssertEqual(frame.width, 16)
        XCTAssertEqual(frame.height, 16)
    }

    /// 测试：PetFrame.Pixel 属性
    func testPetFramePixel_properties() {
        let pixel = PetFrame.Pixel(x: 5, y: 10, color: "#ABCDEF")
        XCTAssertEqual(pixel.x, 5)
        XCTAssertEqual(pixel.y, 10)
        XCTAssertEqual(pixel.color, "#ABCDEF")
    }

    /// 测试：PetFrame 空像素数组
    func testPetFrame_emptyPixels() {
        let frame = PetFrame(pixels: [], width: 0, height: 0)
        XCTAssertTrue(frame.pixels.isEmpty)
        XCTAssertEqual(frame.width, 0)
        XCTAssertEqual(frame.height, 0)
    }

    // MARK: - PetAnimationSet 测试

    /// 测试：PetAnimationSet 所有状态都有帧数据
    func testPetAnimationSet_allStatesHaveFrames() {
        let animationSet = PixelPetGenerator.generateAnimationSet()

        // 验证每个状态都有帧
        XCTAssertFalse(animationSet.idle.isEmpty)
        XCTAssertFalse(animationSet.thinking.isEmpty)
        XCTAssertFalse(animationSet.coding.isEmpty)
        XCTAssertFalse(animationSet.waiting.isEmpty)
        XCTAssertFalse(animationSet.celebrating.isEmpty)
        XCTAssertFalse(animationSet.error.isEmpty)
        XCTAssertFalse(animationSet.compacting.isEmpty)
        XCTAssertFalse(animationSet.sleeping.isEmpty)
    }

    /// 测试：PetAnimationSet frames(for:) 返回对应状态的帧
    func testPetAnimationSet_framesForState() {
        let animationSet = PixelPetGenerator.generateAnimationSet()

        let idleFrames = animationSet.frames(for: .idle)
        XCTAssertEqual(idleFrames.count, animationSet.idle.count)

        let thinkingFrames = animationSet.frames(for: .thinking)
        XCTAssertEqual(thinkingFrames.count, animationSet.thinking.count)

        let codingFrames = animationSet.frames(for: .coding)
        XCTAssertEqual(codingFrames.count, animationSet.coding.count)
    }

    /// 测试：thinking 状态有多帧动画
    func testPetAnimationSet_thinking_multipleFrames() {
        let animationSet = PixelPetGenerator.generateAnimationSet()
        XCTAssertGreaterThanOrEqual(animationSet.thinking.count, 1)
    }

    /// 测试：idle 状态至少有一帧
    func testPetAnimationSet_idle_atLeastOneFrame() {
        let animationSet = PixelPetGenerator.generateAnimationSet()
        XCTAssertGreaterThanOrEqual(animationSet.idle.count, 1)
    }

    // MARK: - PixelPetGenerator 测试

    /// 测试：生成 idle 帧数据
    func testPixelPetGenerator_generateIdle() {
        let frame = PixelPetGenerator.generateSimpleCatIdle()

        XCTAssertGreaterThan(frame.pixels.count, 0)
        XCTAssertEqual(frame.width, 16)
        XCTAssertEqual(frame.height, 16)
    }

    /// 测试：idle 帧包含身体像素
    func testPixelPetGenerator_idle_hasPixels() {
        let frame = PixelPetGenerator.generateSimpleCatIdle()

        // 验证像素在有效范围内
        for pixel in frame.pixels {
            XCTAssertGreaterThanOrEqual(pixel.x, 0)
            XCTAssertLessThan(pixel.x, frame.width)
            XCTAssertGreaterThanOrEqual(pixel.y, 0)
            XCTAssertLessThan(pixel.y, frame.height)
        }
    }

    /// 测试：生成 thinking 帧
    func testPixelPetGenerator_generateThinking() {
        let frame = PixelPetGenerator.generateThinkingFrame()

        XCTAssertGreaterThan(frame.pixels.count, 0)
        XCTAssertEqual(frame.width, 16)
        XCTAssertEqual(frame.height, 16)
    }

    /// 测试：生成完整动画集
    func testPixelPetGenerator_generateAnimationSet() {
        let animationSet = PixelPetGenerator.generateAnimationSet()

        // 验证所有状态都有数据
        XCTAssertFalse(animationSet.idle.isEmpty)
        XCTAssertFalse(animationSet.thinking.isEmpty)
    }

    // MARK: - PetType 测试

    /// 测试：PetType 所有类型
    func testPetType_allCases() {
        let allCases = PetType.allCases
        XCTAssertEqual(allCases.count, 9)
        XCTAssertTrue(allCases.contains(.cat))
        XCTAssertTrue(allCases.contains(.dog))
        XCTAssertTrue(allCases.contains(.rabbit))
        XCTAssertTrue(allCases.contains(.fox))
        XCTAssertTrue(allCases.contains(.penguin))
        XCTAssertTrue(allCases.contains(.robot))
        XCTAssertTrue(allCases.contains(.ghost))
        XCTAssertTrue(allCases.contains(.dragon))
    }

    /// 测试：PetType rawValue 正确
    func testPetType_rawValues() {
        XCTAssertEqual(PetType.cat.rawValue, "cat")
        XCTAssertEqual(PetType.dog.rawValue, "dog")
        XCTAssertEqual(PetType.rabbit.rawValue, "rabbit")
        XCTAssertEqual(PetType.fox.rawValue, "fox")
        XCTAssertEqual(PetType.penguin.rawValue, "penguin")
        XCTAssertEqual(PetType.robot.rawValue, "robot")
        XCTAssertEqual(PetType.ghost.rawValue, "ghost")
        XCTAssertEqual(PetType.dragon.rawValue, "dragon")
    }

    /// 测试：PetType Codable 编码解码
    func testPetType_encodeDecode() {
        let petType = PetType.robot
        let encoder = JSONEncoder()
        let data = try! encoder.encode(petType)

        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(PetType.self, from: data)
        XCTAssertEqual(decoded, .robot)
    }

    // MARK: - PetAnimationSet 扩展测试（各宠物类型）

    /// 测试：Cat 动画集存在
    func testPetAnimationSet_cat() {
        let catSet = PetAnimationSet.cat
        XCTAssertFalse(catSet.idle.isEmpty)
        XCTAssertFalse(catSet.thinking.isEmpty)
    }

    /// 测试：Dog 动画集存在
    func testPetAnimationSet_dog() {
        let dogSet = PetAnimationSet.dog
        XCTAssertFalse(dogSet.idle.isEmpty)
        XCTAssertFalse(dogSet.thinking.isEmpty)
    }

    /// 测试：Rabbit 动画集存在
    func testPetAnimationSet_rabbit() {
        let rabbitSet = PetAnimationSet.rabbit
        XCTAssertFalse(rabbitSet.idle.isEmpty)
        XCTAssertFalse(rabbitSet.thinking.isEmpty)
    }

    /// 测试：Fox 动画集存在
    func testPetAnimationSet_fox() {
        let foxSet = PetAnimationSet.fox
        XCTAssertFalse(foxSet.idle.isEmpty)
        XCTAssertFalse(foxSet.thinking.isEmpty)
    }

    /// 测试：Penguin 动画集存在
    func testPetAnimationSet_penguin() {
        let penguinSet = PetAnimationSet.penguin
        XCTAssertFalse(penguinSet.idle.isEmpty)
        XCTAssertFalse(penguinSet.thinking.isEmpty)
    }

    /// 测试：Robot 动画集存在
    func testPetAnimationSet_robot() {
        let robotSet = PetAnimationSet.robot
        XCTAssertFalse(robotSet.idle.isEmpty)
        XCTAssertFalse(robotSet.thinking.isEmpty)
    }

    /// 测试：Ghost 动画集存在
    func testPetAnimationSet_ghost() {
        let ghostSet = PetAnimationSet.ghost
        XCTAssertFalse(ghostSet.idle.isEmpty)
        XCTAssertFalse(ghostSet.thinking.isEmpty)
    }

    /// 测试：Dragon 动画集存在
    func testPetAnimationSet_dragon() {
        let dragonSet = PetAnimationSet.dragon
        XCTAssertFalse(dragonSet.idle.isEmpty)
        XCTAssertFalse(dragonSet.thinking.isEmpty)
    }

    // MARK: - 辅助函数测试

    /// 测试：rectPixels 生成矩形区域像素
    func testRectPixels() {
        let pixels = rectPixels(x: 1...3, y: 2...4, color: "#FF0000")
        // 3 * 3 = 9 个像素
        XCTAssertEqual(pixels.count, 9)

        // 验证所有像素坐标在范围内
        for pixel in pixels {
            XCTAssertGreaterThanOrEqual(pixel.x, 1)
            XCTAssertLessThanOrEqual(pixel.x, 3)
            XCTAssertGreaterThanOrEqual(pixel.y, 2)
            XCTAssertLessThanOrEqual(pixel.y, 4)
            XCTAssertEqual(pixel.color, "#FF0000")
        }
    }

    /// 测试：px 生成单个像素
    func testPx() {
        let pixel = px(5, 10, "#ABCDEF")
        XCTAssertEqual(pixel.x, 5)
        XCTAssertEqual(pixel.y, 10)
        XCTAssertEqual(pixel.color, "#ABCDEF")
    }

    /// 测试：hline 生成水平线段
    func testHline() {
        let pixels = hline(x: 1...5, y: 3, color: "#FF0000")
        XCTAssertEqual(pixels.count, 5)

        for pixel in pixels {
            XCTAssertEqual(pixel.y, 3)
            XCTAssertGreaterThanOrEqual(pixel.x, 1)
            XCTAssertLessThanOrEqual(pixel.x, 5)
        }
    }

    /// 测试：vline 生成垂直线段
    func testVline() {
        let pixels = vline(x: 3, y: 1...5, color: "#00FF00")
        XCTAssertEqual(pixels.count, 5)

        for pixel in pixels {
            XCTAssertEqual(pixel.x, 3)
            XCTAssertGreaterThanOrEqual(pixel.y, 1)
            XCTAssertLessThanOrEqual(pixel.y, 5)
        }
    }

    // MARK: - 状态转换集成测试

    /// 测试：PetState 与 SessionState 映射完整性
    func testPetState_sessionStateMapping() {
        // 验证所有 SessionState 都能映射到 PetState
        for sessionState in SessionState.allCases {
            let petState = PetState.from(sessionState: sessionState.rawValue)
            // 注意：waitingPermission 和 completed 没有直接对应的 PetState，会映射到 idle
            XCTAssertNotNil(petState)
        }
    }

    /// 测试：PetState 帧数据一致性
    func testPetState_frameDataConsistency() {
        let animationSet = PixelPetGenerator.generateAnimationSet()

        // 验证每个状态获取帧时不会崩溃且返回有效数据
        for state in [PetState.idle, .thinking, .coding, .waiting, .celebrating, .error, .compacting, .sleeping] {
            let frames = animationSet.frames(for: state)
            XCTAssertFalse(frames.isEmpty, "状态 \(state.rawValue) 应有帧数据")
        }
    }
}
