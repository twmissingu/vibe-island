import XCTest
@testable import VibeIsland

// MARK: - 宠物动画测试

final class PetAnimationsTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 8 款宠物动画集存在性测试

    /// 测试：Cat 动画集存在且非空
    func testPetAnimationSet_catExists() {
        let catSet = PetAnimationSet.cat
        XCTAssertFalse(catSet.idle.isEmpty, "Cat idle 动画不应为空")
        XCTAssertFalse(catSet.thinking.isEmpty, "Cat thinking 动画不应为空")
        XCTAssertFalse(catSet.coding.isEmpty, "Cat coding 动画不应为空")
        XCTAssertFalse(catSet.waiting.isEmpty, "Cat waiting 动画不应为空")
        XCTAssertFalse(catSet.celebrating.isEmpty, "Cat celebrating 动画不应为空")
        XCTAssertFalse(catSet.error.isEmpty, "Cat error 动画不应为空")
        XCTAssertFalse(catSet.compacting.isEmpty, "Cat compacting 动画不应为空")
        XCTAssertFalse(catSet.sleeping.isEmpty, "Cat sleeping 动画不应为空")
    }

    /// 测试：Dog 动画集存在且非空
    func testPetAnimationSet_dogExists() {
        let dogSet = PetAnimationSet.dog
        XCTAssertFalse(dogSet.idle.isEmpty)
        XCTAssertFalse(dogSet.thinking.isEmpty)
        XCTAssertFalse(dogSet.coding.isEmpty)
        XCTAssertFalse(dogSet.waiting.isEmpty)
        XCTAssertFalse(dogSet.celebrating.isEmpty)
        XCTAssertFalse(dogSet.error.isEmpty)
        XCTAssertFalse(dogSet.compacting.isEmpty)
        XCTAssertFalse(dogSet.sleeping.isEmpty)
    }

    /// 测试：Rabbit 动画集存在且非空
    func testPetAnimationSet_rabbitExists() {
        let rabbitSet = PetAnimationSet.rabbit
        XCTAssertFalse(rabbitSet.idle.isEmpty)
        XCTAssertFalse(rabbitSet.thinking.isEmpty)
        XCTAssertFalse(rabbitSet.coding.isEmpty)
        XCTAssertFalse(rabbitSet.waiting.isEmpty)
        XCTAssertFalse(rabbitSet.celebrating.isEmpty)
        XCTAssertFalse(rabbitSet.error.isEmpty)
        XCTAssertFalse(rabbitSet.compacting.isEmpty)
        XCTAssertFalse(rabbitSet.sleeping.isEmpty)
    }

    /// 测试：Fox 动画集存在且非空
    func testPetAnimationSet_foxExists() {
        let foxSet = PetAnimationSet.fox
        XCTAssertFalse(foxSet.idle.isEmpty)
        XCTAssertFalse(foxSet.thinking.isEmpty)
        XCTAssertFalse(foxSet.coding.isEmpty)
        XCTAssertFalse(foxSet.waiting.isEmpty)
        XCTAssertFalse(foxSet.celebrating.isEmpty)
        XCTAssertFalse(foxSet.error.isEmpty)
        XCTAssertFalse(foxSet.compacting.isEmpty)
        XCTAssertFalse(foxSet.sleeping.isEmpty)
    }

    /// 测试：Penguin 动画集存在且非空
    func testPetAnimationSet_penguinExists() {
        let penguinSet = PetAnimationSet.penguin
        XCTAssertFalse(penguinSet.idle.isEmpty)
        XCTAssertFalse(penguinSet.thinking.isEmpty)
        XCTAssertFalse(penguinSet.coding.isEmpty)
        XCTAssertFalse(penguinSet.waiting.isEmpty)
        XCTAssertFalse(penguinSet.celebrating.isEmpty)
        XCTAssertFalse(penguinSet.error.isEmpty)
        XCTAssertFalse(penguinSet.compacting.isEmpty)
        XCTAssertFalse(penguinSet.sleeping.isEmpty)
    }

    /// 测试：Robot 动画集存在且非空
    func testPetAnimationSet_robotExists() {
        let robotSet = PetAnimationSet.robot
        XCTAssertFalse(robotSet.idle.isEmpty)
        XCTAssertFalse(robotSet.thinking.isEmpty)
        XCTAssertFalse(robotSet.coding.isEmpty)
        XCTAssertFalse(robotSet.waiting.isEmpty)
        XCTAssertFalse(robotSet.celebrating.isEmpty)
        XCTAssertFalse(robotSet.error.isEmpty)
        XCTAssertFalse(robotSet.compacting.isEmpty)
        XCTAssertFalse(robotSet.sleeping.isEmpty)
    }

    /// 测试：Ghost 动画集存在且非空
    func testPetAnimationSet_ghostExists() {
        let ghostSet = PetAnimationSet.ghost
        XCTAssertFalse(ghostSet.idle.isEmpty)
        XCTAssertFalse(ghostSet.thinking.isEmpty)
        XCTAssertFalse(ghostSet.coding.isEmpty)
        XCTAssertFalse(ghostSet.waiting.isEmpty)
        XCTAssertFalse(ghostSet.celebrating.isEmpty)
        XCTAssertFalse(ghostSet.error.isEmpty)
        XCTAssertFalse(ghostSet.compacting.isEmpty)
        XCTAssertFalse(ghostSet.sleeping.isEmpty)
    }

    /// 测试：Dragon 动画集存在且非空
    func testPetAnimationSet_dragonExists() {
        let dragonSet = PetAnimationSet.dragon
        XCTAssertFalse(dragonSet.idle.isEmpty)
        XCTAssertFalse(dragonSet.thinking.isEmpty)
        XCTAssertFalse(dragonSet.coding.isEmpty)
        XCTAssertFalse(dragonSet.waiting.isEmpty)
        XCTAssertFalse(dragonSet.celebrating.isEmpty)
        XCTAssertFalse(dragonSet.error.isEmpty)
        XCTAssertFalse(dragonSet.compacting.isEmpty)
        XCTAssertFalse(dragonSet.sleeping.isEmpty)
    }

    // MARK: - PetType 与动画集映射测试

    /// 测试：PetType 所有类型都能获取动画集
    func testPetAnimationSet_forPetType_allTypes() {
        for petType in PetType.allCases {
            let animationSet = PetAnimationSet.forPet(petType)
            XCTAssertFalse(animationSet.idle.isEmpty, "\(petType.rawValue) 应有 idle 动画")
            XCTAssertFalse(animationSet.thinking.isEmpty, "\(petType.rawValue) 应有 thinking 动画")
        }
    }

    /// 测试：PetType 数量为 8
    func testPetType_count() {
        XCTAssertEqual(PetType.allCases.count, 8)
    }

    /// 测试：PetType 包含所有预期类型
    func testPetType_containsAllExpectedTypes() {
        let allTypes = PetType.allCases
        XCTAssertTrue(allTypes.contains(.cat))
        XCTAssertTrue(allTypes.contains(.dog))
        XCTAssertTrue(allTypes.contains(.rabbit))
        XCTAssertTrue(allTypes.contains(.fox))
        XCTAssertTrue(allTypes.contains(.penguin))
        XCTAssertTrue(allTypes.contains(.robot))
        XCTAssertTrue(allTypes.contains(.ghost))
        XCTAssertTrue(allTypes.contains(.dragon))
    }

    // MARK: - 帧数据完整性测试

    /// 测试：所有动画帧宽度一致（16）
    func testPetFrame_widthConsistency() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                           animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

            for frame in allFrames {
                XCTAssertEqual(frame.width, 16, "帧宽度应为 16")
                XCTAssertEqual(frame.height, 16, "帧高度应为 16")
            }
        }
    }

    /// 测试：所有像素坐标在有效范围内
    func testPetFrame_pixelCoordinatesInRange() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                           animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

            for frame in allFrames {
                for pixel in frame.pixels {
                    XCTAssertGreaterThanOrEqual(pixel.x, 0, "像素 x 坐标不应小于 0")
                    XCTAssertLessThan(pixel.x, frame.width, "像素 x 坐标不应超过宽度")
                    XCTAssertGreaterThanOrEqual(pixel.y, 0, "像素 y 坐标不应小于 0")
                    XCTAssertLessThan(pixel.y, frame.height, "像素 y 坐标不应超过高度")
                }
            }
        }
    }

    /// 测试：所有像素颜色值非空
    func testPetFrame_pixelColorsNotEmpty() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                           animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

            for frame in allFrames {
                for pixel in frame.pixels {
                    XCTAssertFalse(pixel.color.isEmpty, "像素颜色不应为空")
                    XCTAssertTrue(pixel.color.hasPrefix("#"), "像素颜色应为十六进制格式")
                }
            }
        }
    }

    /// 测试：每帧至少包含一个像素
    func testPetFrame_atLeastOnePixel() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                           animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

            for frame in allFrames {
                XCTAssertGreaterThan(frame.pixels.count, 0, "每帧应至少包含一个像素")
            }
        }
    }

    // MARK: - 动画帧数量测试

    /// 测试：idle 状态至少有一帧
    func testAnimationFrames_idle_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.idle.count, 1, "idle 应至少有一帧")
        }
    }

    /// 测试：thinking 状态至少有一帧
    func testAnimationFrames_thinking_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.thinking.count, 1, "thinking 应至少有一帧")
        }
    }

    /// 测试：coding 状态至少有一帧
    func testAnimationFrames_coding_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.coding.count, 1, "coding 应至少有一帧")
        }
    }

    /// 测试：waiting 状态至少有一帧
    func testAnimationFrames_waiting_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.waiting.count, 1, "waiting 应至少有一帧")
        }
    }

    /// 测试：celebrating 状态至少有一帧
    func testAnimationFrames_celebrating_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.celebrating.count, 1, "celebrating 应至少有一帧")
        }
    }

    /// 测试：error 状态至少有一帧
    func testAnimationFrames_error_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.error.count, 1, "error 应至少有一帧")
        }
    }

    /// 测试：compacting 状态至少有一帧
    func testAnimationFrames_compacting_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.compacting.count, 1, "compacting 应至少有一帧")
        }
    }

    /// 测试：sleeping 状态至少有一帧
    func testAnimationFrames_sleeping_atLeastOne() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        for animSet in animationSets {
            XCTAssertGreaterThanOrEqual(animSet.sleeping.count, 1, "sleeping 应至少有一帧")
        }
    }

    // MARK: - 像素坐标范围测试

    /// 测试：Cat 像素坐标范围
    func testCat_pixelCoordinateRange() {
        let animSet = PetAnimationSet.cat
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Dog 像素坐标范围
    func testDog_pixelCoordinateRange() {
        let animSet = PetAnimationSet.dog
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Rabbit 像素坐标范围
    func testRabbit_pixelCoordinateRange() {
        let animSet = PetAnimationSet.rabbit
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Fox 像素坐标范围
    func testFox_pixelCoordinateRange() {
        let animSet = PetAnimationSet.fox
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Penguin 像素坐标范围
    func testPenguin_pixelCoordinateRange() {
        let animSet = PetAnimationSet.penguin
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Robot 像素坐标范围
    func testRobot_pixelCoordinateRange() {
        let animSet = PetAnimationSet.robot
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Ghost 像素坐标范围
    func testGhost_pixelCoordinateRange() {
        let animSet = PetAnimationSet.ghost
        validateAllFramesCoordinateRange(animSet)
    }

    /// 测试：Dragon 像素坐标范围
    func testDragon_pixelCoordinateRange() {
        let animSet = PetAnimationSet.dragon
        validateAllFramesCoordinateRange(animSet)
    }

    // MARK: - 辅助函数测试

    /// 测试：rectPixels 生成正确数量的像素
    func testRectPixels_correctCount() {
        let pixels = rectPixels(x: 0...3, y: 0...2, color: "#FF0000")
        // 4 * 3 = 12 个像素
        XCTAssertEqual(pixels.count, 12)
    }

    /// 测试：rectPixels 生成正确坐标
    func testRectPixels_correctCoordinates() {
        let pixels = rectPixels(x: 1...3, y: 2...4, color: "#00FF00")

        for pixel in pixels {
            XCTAssertGreaterThanOrEqual(pixel.x, 1)
            XCTAssertLessThanOrEqual(pixel.x, 3)
            XCTAssertGreaterThanOrEqual(pixel.y, 2)
            XCTAssertLessThanOrEqual(pixel.y, 4)
            XCTAssertEqual(pixel.color, "#00FF00")
        }
    }

    /// 测试：px 生成单个像素
    func testPx_singlePixel() {
        let pixel = px(5, 10, "#ABCDEF")
        XCTAssertEqual(pixel.x, 5)
        XCTAssertEqual(pixel.y, 10)
        XCTAssertEqual(pixel.color, "#ABCDEF")
    }

    /// 测试：hline 生成正确数量的像素
    func testHline_correctCount() {
        let pixels = hline(x: 0...4, y: 5, color: "#FF0000")
        XCTAssertEqual(pixels.count, 5)
    }

    /// 测试：hline 生成正确坐标
    func testHline_correctCoordinates() {
        let pixels = hline(x: 2...6, y: 8, color: "#00FF00")

        for pixel in pixels {
            XCTAssertEqual(pixel.y, 8)
            XCTAssertGreaterThanOrEqual(pixel.x, 2)
            XCTAssertLessThanOrEqual(pixel.x, 6)
        }
    }

    /// 测试：vline 生成正确数量的像素
    func testVline_correctCount() {
        let pixels = vline(x: 3, y: 0...4, color: "#0000FF")
        XCTAssertEqual(pixels.count, 5)
    }

    /// 测试：vline 生成正确坐标
    func testVline_correctCoordinates() {
        let pixels = vline(x: 7, y: 1...5, color: "#FF00FF")

        for pixel in pixels {
            XCTAssertEqual(pixel.x, 7)
            XCTAssertGreaterThanOrEqual(pixel.y, 1)
            XCTAssertLessThanOrEqual(pixel.y, 5)
        }
    }

    // MARK: - PetAnimationSet frames(for:) 测试

    /// 测试：frames(for:) 返回 idle 帧
    func testFramesFor_idle() {
        let animSet = PetAnimationSet.cat
        let idleFrames = animSet.frames(for: .idle)
        XCTAssertEqual(idleFrames.count, animSet.idle.count)
    }

    /// 测试：frames(for:) 返回 thinking 帧
    func testFramesFor_thinking() {
        let animSet = PetAnimationSet.dog
        let thinkingFrames = animSet.frames(for: .thinking)
        XCTAssertEqual(thinkingFrames.count, animSet.thinking.count)
    }

    /// 测试：frames(for:) 返回 coding 帧
    func testFramesFor_coding() {
        let animSet = PetAnimationSet.rabbit
        let codingFrames = animSet.frames(for: .coding)
        XCTAssertEqual(codingFrames.count, animSet.coding.count)
    }

    /// 测试：frames(for:) 返回 waiting 帧
    func testFramesFor_waiting() {
        let animSet = PetAnimationSet.fox
        let waitingFrames = animSet.frames(for: .waiting)
        XCTAssertEqual(waitingFrames.count, animSet.waiting.count)
    }

    /// 测试：frames(for:) 返回 celebrating 帧
    func testFramesFor_celebrating() {
        let animSet = PetAnimationSet.penguin
        let celebratingFrames = animSet.frames(for: .celebrating)
        XCTAssertEqual(celebratingFrames.count, animSet.celebrating.count)
    }

    /// 测试：frames(for:) 返回 error 帧
    func testFramesFor_error() {
        let animSet = PetAnimationSet.robot
        let errorFrames = animSet.frames(for: .error)
        XCTAssertEqual(errorFrames.count, animSet.error.count)
    }

    /// 测试：frames(for:) 返回 compacting 帧
    func testFramesFor_compacting() {
        let animSet = PetAnimationSet.ghost
        let compactingFrames = animSet.frames(for: .compacting)
        XCTAssertEqual(compactingFrames.count, animSet.compacting.count)
    }

    /// 测试：frames(for:) 返回 sleeping 帧
    func testFramesFor_sleeping() {
        let animSet = PetAnimationSet.dragon
        let sleepingFrames = animSet.frames(for: .sleeping)
        XCTAssertEqual(sleepingFrames.count, animSet.sleeping.count)
    }

    // MARK: - 颜色格式测试

    /// 测试：Cat 颜色格式正确
    func testCat_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.cat)
    }

    /// 测试：Dog 颜色格式正确
    func testDog_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.dog)
    }

    /// 测试：Rabbit 颜色格式正确
    func testRabbit_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.rabbit)
    }

    /// 测试：Fox 颜色格式正确
    func testFox_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.fox)
    }

    /// 测试：Penguin 颜色格式正确
    func testPenguin_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.penguin)
    }

    /// 测试：Robot 颜色格式正确
    func testRobot_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.robot)
    }

    /// 测试：Ghost 颜色格式正确
    func testGhost_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.ghost)
    }

    /// 测试：Dragon 颜色格式正确
    func testDragon_colorFormat() {
        validateAllFramesColorFormat(PetAnimationSet.dragon)
    }

    // MARK: - PetFrame Pixel 测试

    /// 测试：PetFrame.Pixel 基本属性
    func testPetFramePixel_basicProperties() {
        let pixel = PetFrame.Pixel(x: 3, y: 7, color: "#FF5500")
        XCTAssertEqual(pixel.x, 3)
        XCTAssertEqual(pixel.y, 7)
        XCTAssertEqual(pixel.color, "#FF5500")
    }

    /// 测试：PetFrame 基本属性
    func testPetFrame_basicProperties() {
        let pixels: [PetFrame.Pixel] = [
            PetFrame.Pixel(x: 0, y: 0, color: "#000000"),
            PetFrame.Pixel(x: 1, y: 0, color: "#FFFFFF")
        ]
        let frame = PetFrame(pixels: pixels, width: 16, height: 16)

        XCTAssertEqual(frame.pixels.count, 2)
        XCTAssertEqual(frame.width, 16)
        XCTAssertEqual(frame.height, 16)
    }

    /// 测试：PetFrame 空帧
    func testPetFrame_emptyFrame() {
        let frame = PetFrame(pixels: [], width: 0, height: 0)
        XCTAssertTrue(frame.pixels.isEmpty)
        XCTAssertEqual(frame.width, 0)
        XCTAssertEqual(frame.height, 0)
    }

    // MARK: - 动画集总数测试

    /// 测试：所有动画集总帧数
    func testTotalFrameCount() {
        let animationSets: [PetAnimationSet] = [
            .cat, .dog, .rabbit, .fox, .penguin, .robot, .ghost, .dragon
        ]

        var totalFrames = 0
        for animSet in animationSets {
            totalFrames += animSet.idle.count
            totalFrames += animSet.thinking.count
            totalFrames += animSet.coding.count
            totalFrames += animSet.waiting.count
            totalFrames += animSet.celebrating.count
            totalFrames += animSet.error.count
            totalFrames += animSet.compacting.count
            totalFrames += animSet.sleeping.count
        }

        XCTAssertGreaterThan(totalFrames, 0, "总帧数应大于 0")
    }

    // MARK: - PetState 测试

    /// 测试：PetState 所有枚举
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

    /// 测试：PetState Codable 编解码
    func testPetState_encodeDecode() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let states: [PetState] = [.idle, .thinking, .coding, .waiting, .celebrating, .error, .compacting, .sleeping]

        for state in states {
            let data = try! encoder.encode(state)
            let decoded = try! decoder.decode(PetState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - 辅助验证方法

    private func validateAllFramesCoordinateRange(_ animSet: PetAnimationSet) {
        let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                       animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

        for frame in allFrames {
            for pixel in frame.pixels {
                XCTAssertGreaterThanOrEqual(pixel.x, 0)
                XCTAssertLessThan(pixel.x, frame.width)
                XCTAssertGreaterThanOrEqual(pixel.y, 0)
                XCTAssertLessThan(pixel.y, frame.height)
            }
        }
    }

    private func validateAllFramesColorFormat(_ animSet: PetAnimationSet) {
        let allFrames = animSet.idle + animSet.thinking + animSet.coding + animSet.waiting +
                       animSet.celebrating + animSet.error + animSet.compacting + animSet.sleeping

        for frame in allFrames {
            for pixel in frame.pixels {
                XCTAssertFalse(pixel.color.isEmpty)
                XCTAssertTrue(pixel.color.hasPrefix("#"), "颜色 '\(pixel.color)' 应以 # 开头")
            }
        }
    }
}
