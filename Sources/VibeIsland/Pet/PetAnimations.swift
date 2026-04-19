import Foundation

// PetType 已移至 PetProgressManager.swift

// MARK: - 辅助函数

/// 在指定范围内填充矩形区域
func rectPixels(x: ClosedRange<Int>, y: ClosedRange<Int>, color: String) -> [PetFrame.Pixel] {
    var pixels: [PetFrame.Pixel] = []
    for px in x {
        for py in y {
            pixels.append(PetFrame.Pixel(x: px, y: py, color: color))
        }
    }
    return pixels
}

/// 生成单个像素点
func px(_ x: Int, _ y: Int, _ color: String) -> PetFrame.Pixel {
    PetFrame.Pixel(x: x, y: y, color: color)
}

/// 生成水平线段
func hline(x: ClosedRange<Int>, y: Int, color: String) -> [PetFrame.Pixel] {
    x.map { px($0, y, color) }
}

/// 生成垂直线段
func vline(x: Int, y: ClosedRange<Int>, color: String) -> [PetFrame.Pixel] {
    y.map { px(x, $0, color) }
}

// MARK: - 猫咪 (Cat) - 橙色 #FF9500

extension PetAnimationSet {
    static let cat = PetAnimationSet(
        idle: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .center, mouthOpen: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .right, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .left, mouthOpen: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: true) + catFace(eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: true, tailUp: false) + catFace(eyeLook: .center, mouthOpen: true), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: true, tailUp: true) + catFace(eyeLook: .center, mouthOpen: true) + [px(2, 1, "#FFD700"), px(13, 0, "#FFD700")], width: 16, height: 16),
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: true, tailUp: true) + catFace(eyeLook: .center, mouthOpen: true) + [px(1, 2, "#FFD700"), px(14, 1, "#FFD700")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .cross, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .cross2, mouthOpen: false), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: catBody(color: "#FF9500", earColor: "#FF6B00", legColor: "#E68A00", eyeLook: .center, mouthOpen: false, tailUp: false) + catFace(eyeLook: .closed, mouthOpen: false) + [px(13, 2, "#87CEEB"), px(14, 1, "#87CEEB"), px(14, 3, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum EyeLook { case center, left, right, down, closed, cross, cross2 }

    private static func catBody(color: String, earColor: String, legColor: String, eyeLook: EyeLook, mouthOpen: Bool, tailUp: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        // 身体
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 6...12, color: color))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 2...7, color: color))
        // 耳朵
        pixels.append(contentsOf: rectPixels(x: 3...5, y: 0...2, color: earColor))
        pixels.append(contentsOf: rectPixels(x: 10...12, y: 0...2, color: earColor))
        // 内耳
        pixels.append(px(4, 1, "#FFB6C1"))
        pixels.append(px(11, 1, "#FFB6C1"))
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...6, y: 12...14, color: legColor))
        pixels.append(contentsOf: rectPixels(x: 9...10, y: 12...14, color: legColor))
        // 尾巴
        if tailUp {
            pixels.append(contentsOf: [px(12, 7, color), px(13, 6, color), px(14, 5, color), px(14, 4, color)])
        } else {
            pixels.append(contentsOf: [px(12, 8, color), px(13, 8, color), px(14, 7, color), px(15, 6, color)])
        }
        return pixels
    }

    private static func catFace(eyeLook: EyeLook, mouthOpen: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        switch eyeLook {
        case .center:
            pixels.append(px(5, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
        case .left:
            pixels.append(px(4, 4, "#000000"))
            pixels.append(px(9, 4, "#000000"))
        case .right:
            pixels.append(px(6, 4, "#000000"))
            pixels.append(px(11, 4, "#000000"))
        case .down:
            pixels.append(px(5, 5, "#000000"))
            pixels.append(px(10, 5, "#000000"))
        case .closed:
            pixels.append(contentsOf: hline(x: 4...6, y: 4, color: "#000000"))
            pixels.append(contentsOf: hline(x: 9...11, y: 4, color: "#000000"))
        case .cross:
            pixels.append(contentsOf: [px(4, 3, "#FF0000"), px(6, 5, "#FF0000"), px(5, 4, "#FF0000"), px(4, 5, "#FF0000"), px(6, 3, "#FF0000")])
            pixels.append(contentsOf: [px(9, 3, "#FF0000"), px(11, 5, "#FF0000"), px(10, 4, "#FF0000"), px(9, 5, "#FF0000"), px(11, 3, "#FF0000")])
        case .cross2:
            pixels.append(contentsOf: [px(4, 3, "#FF4444"), px(6, 5, "#FF4444"), px(5, 4, "#FF4444"), px(4, 5, "#FF4444"), px(6, 3, "#FF4444")])
            pixels.append(contentsOf: [px(9, 3, "#FF4444"), px(11, 5, "#FF4444"), px(10, 4, "#FF4444"), px(9, 5, "#FF4444"), px(11, 3, "#FF4444")])
        }
        // 鼻子
        pixels.append(px(7, 5, "#FF69B4"))
        pixels.append(px(8, 5, "#FF69B4"))
        // 嘴巴
        if mouthOpen {
            pixels.append(contentsOf: rectPixels(x: 6...9, y: 6...7, color: "#FF1493"))
            pixels.append(px(7, 7, "#FF69B4"))
            pixels.append(px(8, 7, "#FF69B4"))
        } else {
            pixels.append(px(6, 6, "#FF1493"))
            pixels.append(px(9, 6, "#FF1493"))
        }
        // 胡须
        pixels.append(contentsOf: [px(2, 4, "#D2691E"), px(1, 4, "#D2691E"), px(13, 4, "#D2691E"), px(14, 4, "#D2691E")])
        return pixels
    }
}

// MARK: - 小狗 (Dog) - 棕色 #A0522D

extension PetAnimationSet {
    static let dog = PetAnimationSet(
        idle: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .normal) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .normal, tongueOut: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .up) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .up, tongueOut: false), width: 16, height: 16),
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .right) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .right, tongueOut: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .down) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .down, tongueOut: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: true, mouthOpen: false, eyeLook: .normal) + dogFace(earDroop: .normal, mouthOpen: true, eyeLook: .normal, tongueOut: false), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: true, mouthOpen: true, eyeLook: .normal) + dogFace(earDroop: .normal, mouthOpen: true, eyeLook: .normal, tongueOut: true) + [px(1, 1, "#FFD700"), px(14, 0, "#FFD700")], width: 16, height: 16),
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: true, mouthOpen: true, eyeLook: .normal) + dogFace(earDroop: .normal, mouthOpen: true, eyeLook: .normal, tongueOut: true) + [px(0, 2, "#FFD700"), px(15, 1, "#FFD700")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: dogBody(earDroop: .sad, tailWag: false, mouthOpen: false, eyeLook: .sad) + dogFace(earDroop: .sad, mouthOpen: false, eyeLook: .sad, tongueOut: false), width: 16, height: 16),
            PetFrame(pixels: dogBody(earDroop: .sad, tailWag: false, mouthOpen: false, eyeLook: .sad) + dogFace(earDroop: .sad, mouthOpen: true, eyeLook: .sad, tongueOut: false), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .down) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .down, tongueOut: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: dogBody(earDroop: .normal, tailWag: false, mouthOpen: false, eyeLook: .closed) + dogFace(earDroop: .normal, mouthOpen: false, eyeLook: .closed, tongueOut: false) + [px(13, 1, "#87CEEB"), px(14, 0, "#87CEEB"), px(14, 2, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum DogEar { case normal, sad }
    private enum DogEye { case normal, up, right, down, closed, sad }

    private static func dogBody(earDroop: DogEar, tailWag: Bool, mouthOpen: Bool, eyeLook: DogEye) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#A0522D"
        let dark = "#8B4513"
        let light = "#CD853F"
        // 身体
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 6...12, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 2...8, color: body))
        // 耳朵
        if earDroop == .normal {
            pixels.append(contentsOf: rectPixels(x: 2...4, y: 1...5, color: dark))
            pixels.append(contentsOf: rectPixels(x: 11...13, y: 1...5, color: dark))
        } else {
            pixels.append(contentsOf: rectPixels(x: 2...4, y: 2...6, color: dark))
            pixels.append(contentsOf: rectPixels(x: 11...13, y: 2...6, color: dark))
        }
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...6, y: 12...14, color: dark))
        pixels.append(contentsOf: rectPixels(x: 9...10, y: 12...14, color: dark))
        // 尾巴
        if tailWag {
            pixels.append(contentsOf: [px(12, 7, body), px(13, 5, body), px(14, 4, body), px(14, 3, body)])
        } else {
            pixels.append(contentsOf: [px(12, 8, body), px(13, 7, body), px(14, 7, body)])
        }
        // 肚皮 (浅色)
        pixels.append(contentsOf: rectPixels(x: 6...9, y: 8...11, color: light))
        return pixels
    }

    private static func dogFace(earDroop: DogEar, mouthOpen: Bool, eyeLook: DogEye, tongueOut: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let nose = "#333333"
        // 口鼻部 (浅色)
        pixels.append(contentsOf: rectPixels(x: 5...10, y: 6...8, color: "#CD853F"))
        // 眼睛
        switch eyeLook {
        case .normal:
            pixels.append(px(5, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
            pixels.append(px(6, 3, "#FFFFFF"))
            pixels.append(px(11, 3, "#FFFFFF"))
        case .up:
            pixels.append(px(5, 3, "#000000"))
            pixels.append(px(10, 3, "#000000"))
        case .right:
            pixels.append(px(6, 4, "#000000"))
            pixels.append(px(11, 4, "#000000"))
        case .down:
            pixels.append(px(5, 5, "#000000"))
            pixels.append(px(10, 5, "#000000"))
        case .closed:
            pixels.append(px(5, 4, "#000000"))
            pixels.append(px(6, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
            pixels.append(px(11, 4, "#000000"))
        case .sad:
            pixels.append(px(5, 5, "#000000"))
            pixels.append(px(10, 5, "#000000"))
            // 悲伤的眉毛
            pixels.append(px(4, 2, "#8B4513"))
            pixels.append(px(11, 3, "#8B4513"))
        }
        // 鼻子
        pixels.append(px(7, 6, nose))
        pixels.append(px(8, 6, nose))
        // 嘴巴
        if mouthOpen {
            pixels.append(contentsOf: rectPixels(x: 6...9, y: 7...8, color: "#8B0000"))
            if tongueOut {
                pixels.append(px(7, 8, "#FF69B4"))
                pixels.append(px(8, 8, "#FF69B4"))
            }
        } else {
            pixels.append(px(6, 7, nose))
            pixels.append(px(9, 7, nose))
        }
        return pixels
    }
}

// MARK: - 兔子 (Rabbit) - 白色 #F5F5F5

extension PetAnimationSet {
    static let rabbit = PetAnimationSet(
        idle: [
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: false, mouthOpen: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: rabbitBody(earUp: true, noseTwitch: false) + rabbitFace(earUp: true, eyeBlink: false, noseTwitch: false, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: true, mouthOpen: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: rabbitBody(earUp: true, noseTwitch: false) + rabbitFace(earUp: true, eyeBlink: false, noseTwitch: false, mouthOpen: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: true) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: true, mouthOpen: false), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: rabbitBody(earUp: true, noseTwitch: false) + rabbitFace(earUp: true, eyeBlink: false, noseTwitch: false, mouthOpen: true) + [px(2, 0, "#FFB6C1"), px(13, 1, "#FFB6C1")], width: 16, height: 16),
            PetFrame(pixels: rabbitBody(earUp: true, noseTwitch: false) + rabbitFace(earUp: true, eyeBlink: false, noseTwitch: false, mouthOpen: true) + [px(1, 1, "#FFB6C1"), px(14, 0, "#FFB6C1")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: false, mouthOpen: false, sad: true), width: 16, height: 16),
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: false, mouthOpen: true, sad: true), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: false, noseTwitch: false, mouthOpen: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: rabbitBody(earUp: false, noseTwitch: false) + rabbitFace(earUp: false, eyeBlink: true, noseTwitch: false, mouthOpen: false) + [px(13, 2, "#87CEEB"), px(14, 1, "#87CEEB"), px(14, 3, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private static func rabbitBody(earUp: Bool, noseTwitch: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#F5F5F5"
        let pink = "#FFB6C1"
        // 身体 (圆润)
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 7...13, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 5...10, color: body))
        // 耳朵
        if earUp {
            pixels.append(contentsOf: rectPixels(x: 5...6, y: 0...4, color: body))
            pixels.append(contentsOf: rectPixels(x: 9...10, y: 0...4, color: body))
            pixels.append(px(5, 1, pink))
            pixels.append(px(6, 1, pink))
            pixels.append(px(9, 1, pink))
            pixels.append(px(10, 1, pink))
        } else {
            pixels.append(contentsOf: rectPixels(x: 4...5, y: 1...5, color: body))
            pixels.append(contentsOf: rectPixels(x: 10...11, y: 1...5, color: body))
            pixels.append(px(4, 2, pink))
            pixels.append(px(11, 2, pink))
        }
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...7, y: 13...15, color: body))
        pixels.append(contentsOf: rectPixels(x: 8...10, y: 13...15, color: body))
        // 尾巴
        pixels.append(px(3, 10, "#FFFFFF"))
        pixels.append(px(3, 11, "#FFFFFF"))
        return pixels
    }

    private static func rabbitFace(earUp: Bool, eyeBlink: Bool, noseTwitch: Bool, mouthOpen: Bool, sad: Bool = false) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let eyeColor = sad ? "#FF6666" : "#000000"
        if eyeBlink {
            pixels.append(contentsOf: hline(x: 4...6, y: 6, color: eyeColor))
            pixels.append(contentsOf: hline(x: 9...11, y: 6, color: eyeColor))
        } else {
            pixels.append(px(5, 6, eyeColor))
            pixels.append(px(10, 6, eyeColor))
            pixels.append(px(6, 5, "#FFFFFF"))
            pixels.append(px(11, 5, "#FFFFFF"))
        }
        // 鼻子 (粉色)
        if noseTwitch {
            pixels.append(px(7, 7, "#FF69B4"))
            pixels.append(px(8, 7, "#FF69B4"))
            pixels.append(px(7, 8, "#FF69B4"))
        } else {
            pixels.append(px(7, 7, "#FFB6C1"))
            pixels.append(px(8, 7, "#FFB6C1"))
        }
        // 嘴巴
        if mouthOpen {
            pixels.append(px(6, 8, "#FF69B4"))
            pixels.append(px(9, 8, "#FF69B4"))
            pixels.append(px(7, 9, "#FF69B4"))
            pixels.append(px(8, 9, "#FF69B4"))
        } else {
            pixels.append(px(7, 8, "#FFB6C1"))
            pixels.append(px(8, 8, "#FFB6C1"))
        }
        // 腮红
        pixels.append(px(4, 7, "#FFD1DC"))
        pixels.append(px(11, 7, "#FFD1DC"))
        return pixels
    }
}

// MARK: - 狐狸 (Fox) - 橙红 #FF6347

extension PetAnimationSet {
    static let fox = PetAnimationSet(
        idle: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .normal, mouthOpen: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: foxBody(tailSide: .left, earPoint: .up) + foxFace(eyeLook: .up, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .right, mouthOpen: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .normal, mouthOpen: true), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .up) + foxFace(eyeLook: .normal, mouthOpen: true) + [px(1, 0, "#FFD700"), px(14, 1, "#FFD700")], width: 16, height: 16),
            PetFrame(pixels: foxBody(tailSide: .left, earPoint: .up) + foxFace(eyeLook: .normal, mouthOpen: true) + [px(0, 1, "#FFD700"), px(15, 0, "#FFD700")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .flat) + foxFace(eyeLook: .sad, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .flat) + foxFace(eyeLook: .sad, mouthOpen: true), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: foxBody(tailSide: .right, earPoint: .normal) + foxFace(eyeLook: .closed, mouthOpen: false) + [px(13, 2, "#87CEEB"), px(14, 1, "#87CEEB"), px(14, 3, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum TailSide { case left, right }
    private enum EarPoint { case normal, up, flat }
    private enum FoxEye { case normal, up, right, down, closed, sad }

    private static func foxBody(tailSide: TailSide, earPoint: EarPoint) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#FF6347"
        let white = "#FFFFFF"
        let dark = "#CC4F39"
        // 身体
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 7...13, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 3...9, color: body))
        // 下巴白色
        pixels.append(contentsOf: rectPixels(x: 5...10, y: 8...9, color: white))
        // 耳朵
        switch earPoint {
        case .normal:
            pixels.append(contentsOf: [px(4, 2, body), px(5, 1, body), px(6, 2, body)])
            pixels.append(contentsOf: [px(9, 2, body), px(10, 1, body), px(11, 2, body)])
            pixels.append(px(5, 1, dark))
            pixels.append(px(10, 1, dark))
        case .up:
            pixels.append(contentsOf: [px(4, 1, body), px(5, 0, body), px(6, 1, body)])
            pixels.append(contentsOf: [px(9, 1, body), px(10, 0, body), px(11, 1, body)])
            pixels.append(px(5, 0, dark))
            pixels.append(px(10, 0, dark))
        case .flat:
            pixels.append(contentsOf: [px(3, 3, body), px(4, 2, body), px(5, 3, body)])
            pixels.append(contentsOf: [px(10, 3, body), px(11, 2, body), px(12, 3, body)])
        }
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...6, y: 13...15, color: dark))
        pixels.append(contentsOf: rectPixels(x: 9...10, y: 13...15, color: dark))
        // 尾巴 (大尾巴)
        switch tailSide {
        case .right:
            pixels.append(contentsOf: rectPixels(x: 12...14, y: 8...10, color: body))
            pixels.append(px(15, 9, white))
            pixels.append(px(14, 7, white))
            pixels.append(px(15, 8, white))
        case .left:
            pixels.append(contentsOf: rectPixels(x: 1...3, y: 8...10, color: body))
            pixels.append(px(0, 9, white))
            pixels.append(px(1, 7, white))
            pixels.append(px(0, 8, white))
        }
        // 腹部白色
        pixels.append(contentsOf: rectPixels(x: 6...9, y: 9...12, color: white))
        return pixels
    }

    private static func foxFace(eyeLook: FoxEye, mouthOpen: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        switch eyeLook {
        case .normal:
            pixels.append(px(5, 5, "#000000"))
            pixels.append(px(10, 5, "#000000"))
            pixels.append(px(6, 4, "#FFFFFF"))
            pixels.append(px(11, 4, "#FFFFFF"))
        case .up:
            pixels.append(px(5, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
        case .right:
            pixels.append(px(6, 5, "#000000"))
            pixels.append(px(11, 5, "#000000"))
        case .down:
            pixels.append(px(5, 6, "#000000"))
            pixels.append(px(10, 6, "#000000"))
        case .closed:
            pixels.append(contentsOf: hline(x: 4...6, y: 5, color: "#000000"))
            pixels.append(contentsOf: hline(x: 9...11, y: 5, color: "#000000"))
        case .sad:
            pixels.append(px(5, 6, "#000000"))
            pixels.append(px(10, 6, "#000000"))
        }
        // 鼻子
        pixels.append(px(7, 7, "#000000"))
        pixels.append(px(8, 7, "#000000"))
        // 嘴巴
        if mouthOpen {
            pixels.append(contentsOf: rectPixels(x: 6...9, y: 8...8, color: "#8B0000"))
        } else {
            pixels.append(px(6, 7, "#CC4F39"))
            pixels.append(px(9, 7, "#CC4F39"))
        }
        return pixels
    }
}

// MARK: - 企鹅 (Penguin) - 深蓝灰 #2F4F4F

extension PetAnimationSet {
    static let penguin = PetAnimationSet(
        idle: [
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: false) + penguinFace(flipperSide: .down, eyeLook: .normal, mouthOpen: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: penguinBody(flipperSide: .chin, waddle: false) + penguinFace(flipperSide: .chin, eyeLook: .up, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: false) + penguinFace(flipperSide: .down, eyeLook: .right, mouthOpen: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: penguinBody(flipperSide: .forward, waddle: false) + penguinFace(flipperSide: .forward, eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: true) + penguinFace(flipperSide: .down, eyeLook: .normal, mouthOpen: false), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: penguinBody(flipperSide: .up, waddle: false) + penguinFace(flipperSide: .up, eyeLook: .normal, mouthOpen: true) + [px(2, 0, "#87CEEB"), px(13, 1, "#87CEEB")], width: 16, height: 16),
            PetFrame(pixels: penguinBody(flipperSide: .up, waddle: false) + penguinFace(flipperSide: .up, eyeLook: .normal, mouthOpen: true) + [px(1, 1, "#87CEEB"), px(14, 0, "#87CEEB")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: false) + penguinFace(flipperSide: .down, eyeLook: .sad, mouthOpen: false), width: 16, height: 16),
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: false) + penguinFace(flipperSide: .down, eyeLook: .sad, mouthOpen: true), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: penguinBody(flipperSide: .forward, waddle: false) + penguinFace(flipperSide: .forward, eyeLook: .down, mouthOpen: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: penguinBody(flipperSide: .down, waddle: false) + penguinFace(flipperSide: .down, eyeLook: .closed, mouthOpen: false) + [px(13, 2, "#87CEEB"), px(14, 1, "#87CEEB"), px(14, 3, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum FlipperSide { case down, chin, forward, up }
    private enum PenEye { case normal, up, right, down, closed, sad }

    private static func penguinBody(flipperSide: FlipperSide, waddle: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#2F4F4F"
        let white = "#F0F8FF"
        let dark = "#1C3333"
        // 身体 (圆润)
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 5...13, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 2...6, color: body))
        // 腹部白色
        pixels.append(contentsOf: rectPixels(x: 5...10, y: 6...12, color: white))
        // 脚
        pixels.append(contentsOf: [px(5, 14, "#FFA500"), px(6, 14, "#FFA500"), px(7, 14, "#FFA500")])
        pixels.append(contentsOf: [px(8, 14, "#FFA500"), px(9, 14, "#FFA500"), px(10, 14, "#FFA500")])
        if waddle {
            pixels.append(px(4, 14, "#FFA500"))
            pixels.append(px(11, 14, "#FFA500"))
        }
        // 翅膀/鳍
        switch flipperSide {
        case .down:
            pixels.append(contentsOf: vline(x: 3, y: 6...10, color: dark))
            pixels.append(contentsOf: vline(x: 12, y: 6...10, color: dark))
        case .chin:
            pixels.append(contentsOf: [px(3, 7, dark), px(2, 6, dark)])
            pixels.append(contentsOf: [px(12, 7, dark), px(13, 6, dark)])
        case .forward:
            pixels.append(contentsOf: [px(3, 8, dark), px(2, 9, dark)])
            pixels.append(contentsOf: [px(12, 8, dark), px(13, 9, dark)])
        case .up:
            pixels.append(contentsOf: [px(3, 6, dark), px(2, 5, dark), px(1, 4, dark)])
            pixels.append(contentsOf: [px(12, 6, dark), px(13, 5, dark), px(14, 4, dark)])
        }
        return pixels
    }

    private static func penguinFace(flipperSide: FlipperSide, eyeLook: PenEye, mouthOpen: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        switch eyeLook {
        case .normal:
            pixels.append(px(6, 4, "#000000"))
            pixels.append(px(9, 4, "#000000"))
            pixels.append(px(7, 3, "#FFFFFF"))
            pixels.append(px(10, 3, "#FFFFFF"))
        case .up:
            pixels.append(px(6, 3, "#000000"))
            pixels.append(px(9, 3, "#000000"))
        case .right:
            pixels.append(px(7, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
        case .down:
            pixels.append(px(6, 5, "#000000"))
            pixels.append(px(9, 5, "#000000"))
        case .closed:
            pixels.append(px(6, 4, "#000000"))
            pixels.append(px(7, 4, "#000000"))
            pixels.append(px(9, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
        case .sad:
            pixels.append(px(6, 5, "#000000"))
            pixels.append(px(9, 5, "#000000"))
        }
        // 嘴巴 (橙色喙)
        if mouthOpen {
            pixels.append(contentsOf: rectPixels(x: 6...9, y: 5...5, color: "#FFA500"))
            pixels.append(px(7, 6, "#FF6347"))
            pixels.append(px(8, 6, "#FF6347"))
        } else {
            pixels.append(px(7, 5, "#FFA500"))
            pixels.append(px(8, 5, "#FFA500"))
        }
        return pixels
    }
}

// MARK: - 机器人 (Robot) - 蓝灰 #4682B4

extension PetAnimationSet {
    static let robot = PetAnimationSet(
        idle: [
            PetFrame(pixels: robotBody(antenna: .normal, eyeGlow: .normal, armPos: .down) + robotFace(eyeGlow: .normal, mouthType: .normal, antenna: .normal, armPos: .down), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: robotBody(antenna: .blink, eyeGlow: .yellow, armPos: .chin) + robotFace(eyeGlow: .yellow, mouthType: .normal, antenna: .blink, armPos: .chin), width: 16, height: 16),
            PetFrame(pixels: robotBody(antenna: .normal, eyeGlow: .yellow, armPos: .chin) + robotFace(eyeGlow: .yellow, mouthType: .line, antenna: .normal, armPos: .chin), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: robotBody(antenna: .normal, eyeGlow: .blue, armPos: .forward) + robotFace(eyeGlow: .blue, mouthType: .normal, antenna: .normal, armPos: .forward), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: robotBody(antenna: .blink, eyeGlow: .normal, armPos: .down) + robotFace(eyeGlow: .normal, mouthType: .line, antenna: .blink, armPos: .down), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: robotBody(antenna: .blink, eyeGlow: .green, armPos: .up) + robotFace(eyeGlow: .green, mouthType: .smile, antenna: .blink, armPos: .up) + [px(1, 0, "#00FF00"), px(14, 1, "#00FF00")], width: 16, height: 16),
            PetFrame(pixels: robotBody(antenna: .normal, eyeGlow: .green, armPos: .up) + robotFace(eyeGlow: .green, mouthType: .smile, antenna: .normal, armPos: .up) + [px(0, 1, "#00FF00"), px(15, 0, "#00FF00")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: robotBody(antenna: .blink, eyeGlow: .red, armPos: .down) + robotFace(eyeGlow: .red, mouthType: .error, antenna: .blink, armPos: .down), width: 16, height: 16),
            PetFrame(pixels: robotBody(antenna: .blink, eyeGlow: .red, armPos: .down) + robotFace(eyeGlow: .red, mouthType: .error2, antenna: .blink, armPos: .down), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: robotBody(antenna: .normal, eyeGlow: .blue, armPos: .forward) + robotFace(eyeGlow: .blue, mouthType: .normal, antenna: .normal, armPos: .forward), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: robotBody(antenna: .off, eyeGlow: .off, armPos: .down) + robotFace(eyeGlow: .off, mouthType: .line, antenna: .off, armPos: .down) + [px(13, 2, "#87CEEB"), px(14, 1, "#87CEEB"), px(14, 3, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum Antenna { case normal, blink, off }
    private enum EyeGlow {
        case normal, yellow, blue, green, red, off
        var color: String {
            switch self {
            case .normal: return "#00FFFF"
            case .yellow: return "#FFFF00"
            case .blue: return "#00BFFF"
            case .green: return "#00FF00"
            case .red: return "#FF0000"
            case .off: return "#36648B"
            }
        }
    }
    private enum ArmPos { case down, chin, forward, up }
    private enum MouthType { case normal, line, smile, error, error2 }

    private static func robotBody(antenna: Antenna, eyeGlow: EyeGlow, armPos: ArmPos) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#4682B4"
        let dark = "#36648B"
        let light = "#5C94C4"
        // 身体
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 6...12, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 2...7, color: body))
        // 头部高光
        pixels.append(contentsOf: hline(x: 5...10, y: 2, color: light))
        // 身体面板
        pixels.append(contentsOf: rectPixels(x: 5...10, y: 7...11, color: dark))
        // 天线
        switch antenna {
        case .normal:
            pixels.append(contentsOf: vline(x: 7, y: 0...1, color: light))
            pixels.append(px(7, 0, "#FFD700"))
            pixels.append(contentsOf: vline(x: 8, y: 0...1, color: light))
            pixels.append(px(8, 0, "#FFD700"))
        case .blink:
            pixels.append(contentsOf: vline(x: 7, y: 0...1, color: light))
            pixels.append(px(7, 0, "#FF0000"))
            pixels.append(contentsOf: vline(x: 8, y: 0...1, color: light))
            pixels.append(px(8, 0, "#FF0000"))
        case .off:
            pixels.append(contentsOf: vline(x: 7, y: 0...1, color: dark))
            pixels.append(contentsOf: vline(x: 8, y: 0...1, color: dark))
        }
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...6, y: 12...14, color: dark))
        pixels.append(contentsOf: rectPixels(x: 9...10, y: 12...14, color: dark))
        // 脚
        pixels.append(contentsOf: hline(x: 4...7, y: 14, color: light))
        pixels.append(contentsOf: hline(x: 8...11, y: 14, color: light))
        // 手臂
        switch armPos {
        case .down:
            pixels.append(contentsOf: vline(x: 3, y: 6...10, color: light))
            pixels.append(contentsOf: vline(x: 12, y: 6...10, color: light))
        case .chin:
            pixels.append(contentsOf: [px(3, 7, light), px(2, 6, light)])
            pixels.append(contentsOf: [px(12, 7, light), px(13, 6, light)])
        case .forward:
            pixels.append(contentsOf: [px(3, 8, light), px(2, 8, light), px(1, 8, light)])
            pixels.append(contentsOf: [px(12, 8, light), px(13, 8, light), px(14, 8, light)])
        case .up:
            pixels.append(contentsOf: [px(3, 6, light), px(2, 5, light), px(1, 4, light)])
            pixels.append(contentsOf: [px(12, 6, light), px(13, 5, light), px(14, 4, light)])
        }
        // 胸灯
        pixels.append(px(7, 9, eyeGlow.color))
        pixels.append(px(8, 9, eyeGlow.color))
        return pixels
    }

    private static func robotFace(eyeGlow: EyeGlow, mouthType: MouthType, antenna: Antenna, armPos: ArmPos) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let color = eyeGlow.color
        // 眼睛
        if eyeGlow == .off {
            pixels.append(contentsOf: hline(x: 4...6, y: 4, color: "#36648B"))
            pixels.append(contentsOf: hline(x: 9...11, y: 4, color: "#36648B"))
        } else {
            pixels.append(px(5, 4, color))
            pixels.append(px(6, 4, color))
            pixels.append(px(9, 4, color))
            pixels.append(px(10, 4, color))
            pixels.append(px(5, 3, "#FFFFFF"))
            pixels.append(px(9, 3, "#FFFFFF"))
        }
        // 嘴巴
        switch mouthType {
        case .normal:
            pixels.append(contentsOf: hline(x: 5...10, y: 6, color: "#36648B"))
        case .line:
            pixels.append(px(7, 6, "#36648B"))
            pixels.append(px(8, 6, "#36648B"))
        case .smile:
            pixels.append(contentsOf: [px(5, 5, "#36648B"), px(10, 5, "#36648B")])
            pixels.append(contentsOf: hline(x: 6...9, y: 6, color: "#36648B"))
        case .error:
            pixels.append(px(6, 5, "#FF0000"))
            pixels.append(px(9, 5, "#FF0000"))
            pixels.append(px(7, 6, "#FF0000"))
            pixels.append(px(8, 6, "#FF0000"))
        case .error2:
            pixels.append(px(6, 6, "#FF4444"))
            pixels.append(px(9, 6, "#FF4444"))
            pixels.append(px(7, 5, "#FF4444"))
            pixels.append(px(8, 5, "#FF4444"))
        }
        return pixels
    }
}

// MARK: - 幽灵 (Ghost) - 半透明白色 #E8E8E8

extension PetAnimationSet {
    static let ghost = PetAnimationSet(
        idle: [
            PetFrame(pixels: ghostBody(float: .normal, wave: false) + ghostFace(float: .normal, eyeLook: .normal, mouthOpen: false, wave: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: ghostBody(float: .up, wave: false) + ghostFace(float: .up, eyeLook: .up, mouthOpen: false, wave: false), width: 16, height: 16),
            PetFrame(pixels: ghostBody(float: .normal, wave: false) + ghostFace(float: .normal, eyeLook: .right, mouthOpen: false, wave: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: ghostBody(float: .normal, wave: false) + ghostFace(float: .normal, eyeLook: .down, mouthOpen: false, wave: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: ghostBody(float: .normal, wave: true) + ghostFace(float: .normal, eyeLook: .normal, mouthOpen: false, wave: true), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: ghostBody(float: .up, wave: true) + ghostFace(float: .up, eyeLook: .normal, mouthOpen: true, wave: true) + [px(2, 0, "#E8E8E8"), px(13, 1, "#E8E8E8")], width: 16, height: 16),
            PetFrame(pixels: ghostBody(float: .up, wave: true) + ghostFace(float: .up, eyeLook: .normal, mouthOpen: true, wave: true) + [px(1, 1, "#E8E8E8"), px(14, 0, "#E8E8E8")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: ghostBody(float: .down, wave: false) + ghostFace(float: .down, eyeLook: .scared, mouthOpen: true, wave: false), width: 16, height: 16),
            PetFrame(pixels: ghostBody(float: .shake, wave: false) + ghostFace(float: .shake, eyeLook: .scared, mouthOpen: true, wave: false), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: ghostBody(float: .normal, wave: false) + ghostFace(float: .normal, eyeLook: .down, mouthOpen: false, wave: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: ghostBody(float: .normal, wave: false) + ghostFace(float: .normal, eyeLook: .closed, mouthOpen: false, wave: false) + [px(13, 1, "#87CEEB"), px(14, 0, "#87CEEB"), px(14, 2, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum FloatPos { case normal, up, down, shake }
    private enum GhostEye { case normal, up, right, down, closed, scared }

    private static func ghostBody(float: FloatPos, wave: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#E8E8E8"
        let shadow = "#CCCCCC"

        var yOffset = 0
        var xOffset = 0
        switch float {
        case .normal: break
        case .up: yOffset = -1
        case .down: yOffset = 1
        case .shake: xOffset = 1
        }

        // 幽灵身体 (圆顶 + 波浪底)
        let bodyPixels: [PetFrame.Pixel] = [
            // 圆顶
            px(7 + xOffset, 2 + yOffset, body), px(8 + xOffset, 2 + yOffset, body),
            px(6 + xOffset, 3 + yOffset, body), px(7 + xOffset, 3 + yOffset, body), px(8 + xOffset, 3 + yOffset, body), px(9 + xOffset, 3 + yOffset, body),
            // 身体
            px(5 + xOffset, 4 + yOffset, body), px(6 + xOffset, 4 + yOffset, body), px(7 + xOffset, 4 + yOffset, body), px(8 + xOffset, 4 + yOffset, body), px(9 + xOffset, 4 + yOffset, body), px(10 + xOffset, 4 + yOffset, body),
            px(4 + xOffset, 5 + yOffset, body), px(5 + xOffset, 5 + yOffset, body), px(6 + xOffset, 5 + yOffset, body), px(7 + xOffset, 5 + yOffset, body), px(8 + xOffset, 5 + yOffset, body), px(9 + xOffset, 5 + yOffset, body), px(10 + xOffset, 5 + yOffset, body), px(11 + xOffset, 5 + yOffset, body),
            px(4 + xOffset, 6 + yOffset, body), px(5 + xOffset, 6 + yOffset, body), px(6 + xOffset, 6 + yOffset, body), px(7 + xOffset, 6 + yOffset, body), px(8 + xOffset, 6 + yOffset, body), px(9 + xOffset, 6 + yOffset, body), px(10 + xOffset, 6 + yOffset, body), px(11 + xOffset, 6 + yOffset, body),
            px(4 + xOffset, 7 + yOffset, body), px(5 + xOffset, 7 + yOffset, body), px(6 + xOffset, 7 + yOffset, body), px(7 + xOffset, 7 + yOffset, body), px(8 + xOffset, 7 + yOffset, body), px(9 + xOffset, 7 + yOffset, body), px(10 + xOffset, 7 + yOffset, body), px(11 + xOffset, 7 + yOffset, body),
            // 波浪底部
            px(4 + xOffset, 8 + yOffset, body), px(5 + xOffset, 8 + yOffset, body), px(6 + xOffset, 8 + yOffset, body),
            px(7 + xOffset, 9 + yOffset, body), px(8 + xOffset, 9 + yOffset, body),
            px(9 + xOffset, 8 + yOffset, body), px(10 + xOffset, 8 + yOffset, body), px(11 + xOffset, 8 + yOffset, body),
            // 尾巴
            px(4 + xOffset, 9 + yOffset, shadow), px(11 + xOffset, 9 + yOffset, shadow),
            px(3 + xOffset, 10 + yOffset, shadow), px(12 + xOffset, 10 + yOffset, shadow),
        ]
        pixels.append(contentsOf: bodyPixels)

        if wave {
            // 挥动手
            pixels.append(px(3 + xOffset, 5 + yOffset, body))
            pixels.append(px(2 + xOffset, 4 + yOffset, body))
            pixels.append(px(12 + xOffset, 5 + yOffset, body))
            pixels.append(px(13 + xOffset, 4 + yOffset, body))
        }

        return pixels
    }

    private static func ghostFace(float: FloatPos, eyeLook: GhostEye, mouthOpen: Bool, wave: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        var yOffset = 0
        var xOffset = 0
        switch float {
        case .normal: break
        case .up: yOffset = -1
        case .down: yOffset = 1
        case .shake: xOffset = 1
        }

        switch eyeLook {
        case .normal:
            pixels.append(px(6 + xOffset, 4 + yOffset, "#000000"))
            pixels.append(px(9 + xOffset, 4 + yOffset, "#000000"))
        case .up:
            pixels.append(px(6 + xOffset, 3 + yOffset, "#000000"))
            pixels.append(px(9 + xOffset, 3 + yOffset, "#000000"))
        case .right:
            pixels.append(px(7 + xOffset, 4 + yOffset, "#000000"))
            pixels.append(px(10 + xOffset, 4 + yOffset, "#000000"))
        case .down:
            pixels.append(px(6 + xOffset, 5 + yOffset, "#000000"))
            pixels.append(px(9 + xOffset, 5 + yOffset, "#000000"))
        case .closed:
            pixels.append(contentsOf: hline(x: 5...7, y: 4 + yOffset, color: "#000000"))
            pixels.append(contentsOf: hline(x: 8...10, y: 4 + yOffset, color: "#000000"))
        case .scared:
            pixels.append(px(6 + xOffset, 4 + yOffset, "#000000"))
            pixels.append(px(9 + xOffset, 4 + yOffset, "#000000"))
            pixels.append(px(5 + xOffset, 3 + yOffset, "#000000"))
            pixels.append(px(10 + xOffset, 3 + yOffset, "#000000"))
        }

        // 嘴巴
        if mouthOpen {
            pixels.append(px(7 + xOffset, 6 + yOffset, "#000000"))
            pixels.append(px(8 + xOffset, 6 + yOffset, "#000000"))
        } else {
            pixels.append(px(7 + xOffset, 6 + yOffset, "#CCCCCC"))
            pixels.append(px(8 + xOffset, 6 + yOffset, "#CCCCCC"))
        }

        return pixels
    }
}

// MARK: - 小龙 (Dragon) - 绿色 #32CD32

extension PetAnimationSet {
    static let dragon = PetAnimationSet(
        idle: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .normal, mouthOpen: false, fire: false), width: 16, height: 16)
        ],
        thinking: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .up, hornUp: true) + dragonFace(tailSide: .right, wingFlap: .up, hornUp: true, eyeLook: .up, mouthOpen: false, fire: false), width: 16, height: 16),
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: true) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: true, eyeLook: .right, mouthOpen: false, fire: false), width: 16, height: 16)
        ],
        coding: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .down, mouthOpen: false, fire: false), width: 16, height: 16)
        ],
        waiting: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .normal, mouthOpen: true, fire: false), width: 16, height: 16)
        ],
        celebrating: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .up, hornUp: true) + dragonFace(tailSide: .right, wingFlap: .up, hornUp: true, eyeLook: .normal, mouthOpen: true, fire: true) + [px(1, 0, "#FFD700"), px(14, 1, "#FFD700")], width: 16, height: 16),
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .up, hornUp: true) + dragonFace(tailSide: .right, wingFlap: .up, hornUp: true, eyeLook: .normal, mouthOpen: true, fire: true) + [px(0, 1, "#FFD700"), px(15, 0, "#FFD700")], width: 16, height: 16)
        ],
        error: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .sad, mouthOpen: true, fire: false), width: 16, height: 16),
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .sad, mouthOpen: true, fire: true), width: 16, height: 16)
        ],
        compacting: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .down, mouthOpen: false, fire: false), width: 16, height: 16)
        ],
        sleeping: [
            PetFrame(pixels: dragonBody(tailSide: .right, wingFlap: .down, hornUp: false) + dragonFace(tailSide: .right, wingFlap: .down, hornUp: false, eyeLook: .closed, mouthOpen: false, fire: false) + [px(13, 1, "#87CEEB"), px(14, 0, "#87CEEB"), px(14, 2, "#87CEEB")], width: 16, height: 16)
        ]
    )

    private enum WingFlap { case up, down }
    private enum DragEye { case normal, up, right, down, closed, sad }

    private static func dragonBody(tailSide: TailSide, wingFlap: WingFlap, hornUp: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        let body = "#32CD32"
        let dark = "#228B22"
        let light = "#7CFC00"
        let belly = "#98FB98"

        // 身体
        pixels.append(contentsOf: rectPixels(x: 4...11, y: 7...13, color: body))
        // 头部
        pixels.append(contentsOf: rectPixels(x: 3...12, y: 3...8, color: body))
        // 腹部
        pixels.append(contentsOf: rectPixels(x: 6...9, y: 8...12, color: belly))
        // 角
        if hornUp {
            pixels.append(px(5, 2, "#FFD700"))
            pixels.append(px(6, 1, "#FFD700"))
            pixels.append(px(9, 2, "#FFD700"))
            pixels.append(px(10, 1, "#FFD700"))
        } else {
            pixels.append(px(5, 2, "#DAA520"))
            pixels.append(px(10, 2, "#DAA520"))
        }
        // 腿
        pixels.append(contentsOf: rectPixels(x: 5...6, y: 13...15, color: dark))
        pixels.append(contentsOf: rectPixels(x: 9...10, y: 13...15, color: dark))
        // 尾巴
        switch tailSide {
        case .right:
            pixels.append(contentsOf: [px(12, 9, body), px(13, 9, body), px(14, 8, body), px(15, 7, dark)])
        case .left:
            pixels.append(contentsOf: [px(3, 9, body), px(2, 9, body), px(1, 8, body), px(0, 7, dark)])
        }
        // 翅膀
        switch wingFlap {
        case .down:
            pixels.append(contentsOf: [px(2, 6, dark), px(1, 7, dark), px(0, 8, dark)])
            pixels.append(contentsOf: [px(13, 6, dark), px(14, 7, dark), px(15, 8, dark)])
        case .up:
            pixels.append(contentsOf: [px(2, 5, dark), px(1, 4, dark), px(0, 3, light)])
            pixels.append(contentsOf: [px(13, 5, dark), px(14, 4, dark), px(15, 3, light)])
        }
        // 背刺
        pixels.append(px(7, 6, light))
        pixels.append(px(8, 6, light))
        return pixels
    }

    private static func dragonFace(tailSide: TailSide, wingFlap: WingFlap, hornUp: Bool, eyeLook: DragEye, mouthOpen: Bool, fire: Bool) -> [PetFrame.Pixel] {
        var pixels: [PetFrame.Pixel] = []
        switch eyeLook {
        case .normal:
            pixels.append(px(5, 5, "#000000"))
            pixels.append(px(10, 5, "#000000"))
            pixels.append(px(6, 4, "#FFFFFF"))
            pixels.append(px(11, 4, "#FFFFFF"))
        case .up:
            pixels.append(px(5, 4, "#000000"))
            pixels.append(px(10, 4, "#000000"))
        case .right:
            pixels.append(px(6, 5, "#000000"))
            pixels.append(px(11, 5, "#000000"))
        case .down:
            pixels.append(px(5, 6, "#000000"))
            pixels.append(px(10, 6, "#000000"))
        case .closed:
            pixels.append(contentsOf: hline(x: 4...6, y: 5, color: "#000000"))
            pixels.append(contentsOf: hline(x: 9...11, y: 5, color: "#000000"))
        case .sad:
            pixels.append(px(5, 6, "#000000"))
            pixels.append(px(10, 6, "#000000"))
        }
        // 鼻子
        pixels.append(px(7, 6, "#228B22"))
        pixels.append(px(8, 6, "#228B22"))
        // 嘴巴
        if mouthOpen {
            pixels.append(contentsOf: rectPixels(x: 6...9, y: 7...7, color: "#8B0000"))
            if fire {
                pixels.append(contentsOf: [px(6, 8, "#FF4500"), px(7, 8, "#FFA500"), px(8, 8, "#FFA500"), px(9, 8, "#FF4500")])
                pixels.append(px(7, 9, "#FFD700"))
                pixels.append(px(8, 9, "#FFD700"))
            }
        } else {
            pixels.append(px(6, 7, "#228B22"))
            pixels.append(px(9, 7, "#228B22"))
        }
        return pixels
    }
}

// MARK: - 公共 API: 根据 PetType 获取动画

extension PetAnimationSet {
    static func forPet(_ type: PetType, level: PetLevel = .basic) -> PetAnimationSet {
        let base: PetAnimationSet
        switch type {
        case .cat: base = .cat
        case .dog: base = .dog
        case .rabbit: base = .rabbit
        case .fox: base = .fox
        case .penguin: base = .penguin
        case .robot: base = .robot
        case .ghost: base = .ghost
        case .dragon: base = .dragon
        }
        if level == .basic { return base }
        return base.withSkin(PetSkinPalette.palette(for: type, level: level))
    }
}

// MARK: - 皮肤调色板系统

/// 皮肤颜色映射：将原始颜色替换为皮肤特定颜色
struct PetSkinPalette {
    /// 原始颜色 → 皮肤颜色的映射（key 均为大写）
    let colorMap: [String: String]

    /// 应用调色板到颜色
    func apply(_ color: String) -> String {
        colorMap[color.uppercased()] ?? color
    }

    /// 获取指定宠物和等级的调色板
    static func palette(for pet: PetType, level: PetLevel) -> PetSkinPalette {
        switch pet {
        case .cat: return catPalette(level)
        case .dog: return dogPalette(level)
        case .rabbit: return rabbitPalette(level)
        case .fox: return foxPalette(level)
        case .penguin: return penguinPalette(level)
        case .robot: return robotPalette(level)
        case .ghost: return ghostPalette(level)
        case .dragon: return dragonPalette(level)
        }
    }

    // MARK: 猫咪调色板

    private static func catPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#FF9500": "#FFB347",  // 亮橙
                "#FF6B00": "#FF8C42",  // 亮深橙
                "#E68A00": "#FFAA33",  // 亮腿色
                "#FF69B4": "#FF85C8",  // 亮粉鼻
                "#FF1493": "#FF3CAA",  // 亮粉嘴
                "#D2691E": "#E8873D",  // 亮胡须
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#FF9500": "#C0C0C0",  // 银灰身体
                "#FF6B00": "#A9A9A9",  // 深银耳
                "#E68A00": "#B0B0B0",  // 银灰腿
                "#FF69B4": "#D4D4D4",  // 银灰鼻
                "#FF1493": "#808080",  // 深银嘴
                "#D2691E": "#A0A0A0",  // 银灰胡须
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#FF9500": "#FF00FF",  // 品红身体
                "#FF6B00": "#CC00CC",  // 深品红耳
                "#E68A00": "#FF33FF",  // 品红腿
                "#FF69B4": "#00FFFF",  // 青色鼻
                "#FF1493": "#FF00AA",  // 亮品红嘴
                "#D2691E": "#AA00FF",  // 紫胡须
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#FF9500": "#FFD700",  // 金身体
                "#FF6B00": "#DAA520",  // 深金耳
                "#E68A00": "#FFCC00",  // 金腿
                "#FF69B4": "#FF4500",  // 红宝石鼻
                "#FF1493": "#DC143C",  // 深红嘴
                "#D2691E": "#B8860B",  // 暗金胡须
            ])
        }
    }

    // MARK: 小狗调色板

    private static func dogPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#A0522D": "#C07848",  // 亮棕
                "#8B4513": "#A65D2E",  // 亮深棕
                "#CD853F": "#E09850",  // 亮浅棕
                "#333333": "#555555",  // 亮黑鼻
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#A0522D": "#B87333",  // 铜色身体
                "#8B4513": "#8B6914",  // 深铜耳
                "#CD853F": "#CD853F",  // 保持浅色肚皮
                "#333333": "#4A3728",  // 铜暗鼻
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#A0522D": "#00FF88",  // 霓虹绿身体
                "#8B4513": "#00CC66",  // 深绿耳
                "#CD853F": "#33FFAA",  // 亮绿肚皮
                "#333333": "#008844",  // 深绿鼻
                "#8B0000": "#00FF00",  // 霓虹绿嘴
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#A0522D": "#8B0000",  // 深红身体
                "#8B4513": "#660000",  // 暗红耳
                "#CD853F": "#FFD700",  // 金肚皮
                "#333333": "#4A0000",  // 暗红鼻
                "#8B0000": "#FF0000",  // 鲜红嘴
            ])
        }
    }

    // MARK: 兔子调色板

    private static func rabbitPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#F5F5F5": "#FFFFFF",  // 纯白
                "#FFB6C1": "#FFC0CB",  // 亮粉
                "#FFD1DC": "#FFE0E8",  // 亮腮红
                "#FF69B4": "#FF85C8",  // 亮深粉
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#F5F5F5": "#E8E8E8",  // 银白
                "#FFB6C1": "#C0C0C0",  // 银灰内耳
                "#FFD1DC": "#D0D0D0",  // 银灰腮红
                "#FF69B4": "#A0A0A0",  // 深银
                "#FFB6C1": "#B8B8B8",  // 银灰鼻
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#F5F5F5": "#E0FFFF",  // 淡青身体
                "#FFB6C1": "#00FFFF",  // 青色内耳
                "#FFD1DC": "#00EEEE",  // 青色腮红
                "#FF69B4": "#00DDFF",  // 青色深粉
                "#FFB6C1": "#00FFFF",  // 青色鼻
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#F5F5F5": "#FFF8DC",  // 玉米丝白
                "#FFB6C1": "#FFD700",  // 金内耳
                "#FFD1DC": "#FFCC00",  // 金腮红
                "#FF69B4": "#FF4500",  // 橙红深粉
                "#FFB6C1": "#DAA520",  // 金鼻
                "#FFFFFF": "#FFFACD",  // 金白尾巴
            ])
        }
    }

    // MARK: 狐狸调色板

    private static func foxPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#FF6347": "#FF7F6E",  // 亮橙红
                "#CC4F39": "#DD6650",  // 亮深橙红
                "#FFFFFF": "#FFF5F0",  // 暖白
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#FF6347": "#B8860B",  // 暗金身体
                "#CC4F39": "#8B6914",  // 深金耳
                "#FFFFFF": "#FFD700",  // 金白色
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#FF6347": "#FF00FF",  // 品红身体
                "#CC4F39": "#CC00CC",  // 深品红耳
                "#FFFFFF": "#FF88FF",  // 淡品红白
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#FF6347": "#4B0082",  // 靛蓝身体
                "#CC4F39": "#380066",  // 深靛蓝耳
                "#FFFFFF": "#FFD700",  // 金白色
            ])
        }
    }

    // MARK: 企鹅调色板

    private static func penguinPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#2F4F4F": "#3D6363",  // 亮深蓝灰
                "#1C3333": "#2A4444",  // 亮暗色
                "#F0F8FF": "#FFFFFF",  // 纯白腹
                "#FFA500": "#FFB833",  // 亮橙脚
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#2F4F4F": "#708090",  // 石板灰
                "#1C3333": "#4A5568",  // 深石板
                "#F0F8FF": "#C0C0C0",  // 银白腹
                "#FFA500": "#B87333",  // 铜色脚
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#2F4F4F": "#000080",  // 海军蓝
                "#1C3333": "#000066",  // 深海军蓝
                "#F0F8FF": "#00BFFF",  // 深天蓝腹
                "#FFA500": "#00FF00",  // 霓虹绿脚
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#2F4F4F": "#4B0082",  // 靛蓝
                "#1C3333": "#380066",  // 深靛蓝
                "#F0F8FF": "#FFD700",  // 金腹
                "#FFA500": "#FF4500",  // 红宝石脚
            ])
        }
    }

    // MARK: 机器人调色板

    private static func robotPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#4682B4": "#5A9FD4",  // 亮钢蓝
                "#36648B": "#4A7AAA",  // 亮深蓝
                "#5C94C4": "#70AADE",  // 亮浅蓝
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#4682B4": "#C0C0C0",  // 银色
                "#36648B": "#808080",  // 深银
                "#5C94C4": "#D4D4D4",  // 亮银
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#4682B4": "#00FF00",  // 霓虹绿
                "#36648B": "#008800",  // 深绿
                "#5C94C4": "#33FF33",  // 亮绿
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#4682B4": "#FFD700",  // 金
                "#36648B": "#B8860B",  // 暗金
                "#5C94C4": "#FFE44D",  // 亮金
            ])
        }
    }

    // MARK: 幽灵调色板

    private static func ghostPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#E8E8E8": "#FFFFFF",  // 纯白
                "#CCCCCC": "#E0E0E0",  // 亮灰影
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#E8E8E8": "#B0C4DE",  // 钢蓝灰
                "#CCCCCC": "#8BA0B8",  // 深钢蓝
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#E8E8E8": "#00FFFF",  // 青色
                "#CCCCCC": "#00CCCC",  // 深青影
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#E8E8E8": "#DDA0DD",  // 梅红
                "#CCCCCC": "#BA55D3",  // 中兰紫影
            ])
        }
    }

    // MARK: 小龙调色板

    private static func dragonPalette(_ level: PetLevel) -> PetSkinPalette {
        switch level {
        case .basic:
            return PetSkinPalette(colorMap: [:])
        case .glow:
            return PetSkinPalette(colorMap: [
                "#32CD32": "#50FF50",  // 亮绿
                "#228B22": "#33BB33",  // 亮深绿
                "#7CFC00": "#90FF20",  // 亮浅绿
                "#98FB98": "#AAFFAA",  // 亮腹绿
                "#DAA520": "#FFD700",  // 亮金角
            ])
        case .metal:
            return PetSkinPalette(colorMap: [
                "#32CD32": "#C0C0C0",  // 银灰
                "#228B22": "#808080",  // 深银
                "#7CFC00": "#D4D4D4",  // 亮银
                "#98FB98": "#E0E0E0",  // 银白腹
                "#DAA520": "#A0A0A0",  // 银灰角
            ])
        case .neon:
            return PetSkinPalette(colorMap: [
                "#32CD32": "#FF00FF",  // 品红
                "#228B22": "#CC00CC",  // 深品红
                "#7CFC00": "#FF33FF",  // 亮品红
                "#98FB98": "#FF88FF",  // 淡品红腹
                "#DAA520": "#00FFFF",  // 青角
                "#FF4500": "#FF0088",  // 品红火
                "#FFA500": "#FF00AA",  // 品红火
                "#FFD700": "#FF00CC",  // 品红火尖
            ])
        case .king:
            return PetSkinPalette(colorMap: [
                "#32CD32": "#FFD700",  // 金
                "#228B22": "#B8860B",  // 暗金
                "#7CFC00": "#FFE44D",  // 亮金
                "#98FB98": "#FFF8DC",  // 金丝白腹
                "#DAA520": "#FF4500",  // 红宝石角
                "#FF4500": "#FF0000",  // 红火
                "#FFA500": "#FF2200",  // 红火
                "#FFD700": "#FF4400",  // 红火尖
            ])
        }
    }
}

// MARK: - PetAnimationSet 皮肤应用

extension PetAnimationSet {
    /// 应用皮肤调色板，返回新的动画集
    func withSkin(_ palette: PetSkinPalette) -> PetAnimationSet {
        PetAnimationSet(
            idle: idle.map { $0.withPalette(palette) },
            thinking: thinking.map { $0.withPalette(palette) },
            coding: coding.map { $0.withPalette(palette) },
            waiting: waiting.map { $0.withPalette(palette) },
            celebrating: celebrating.map { $0.withPalette(palette) },
            error: error.map { $0.withPalette(palette) },
            compacting: compacting.map { $0.withPalette(palette) },
            sleeping: sleeping.map { $0.withPalette(palette) }
        )
    }
}

extension PetFrame {
    /// 应用调色板到帧
    func withPalette(_ palette: PetSkinPalette) -> PetFrame {
        PetFrame(
            pixels: pixels.map { pixel in
                PetFrame.Pixel(x: pixel.x, y: pixel.y, color: palette.apply(pixel.color))
            },
            width: width,
            height: height
        )
    }
}
