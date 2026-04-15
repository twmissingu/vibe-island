import Foundation
import SwiftUI

/// 宠物帧数据结构
struct PetFrame {
    var pixels: [Pixel]  // 像素点数组（可变）
    let width: Int
    let height: Int
    
    struct Pixel {
        let x: Int
        let y: Int
        let color: String  // hex color
    }
}

/// 宠物动画帧数据
struct PetAnimationSet {
    let idle: [PetFrame]
    let thinking: [PetFrame]
    let coding: [PetFrame]
    let waiting: [PetFrame]
    let celebrating: [PetFrame]
    let error: [PetFrame]
    let compacting: [PetFrame]
    let sleeping: [PetFrame]
    
    /// 根据状态获取帧序列
    func frames(for state: PetState) -> [PetFrame] {
        switch state {
        case .idle: return idle
        case .thinking: return thinking
        case .coding: return coding
        case .waiting: return waiting
        case .celebrating: return celebrating
        case .error: return error
        case .compacting: return compacting
        case .sleeping: return sleeping
        }
    }
}

/// 示例像素帧数据生成器（原型阶段使用简单几何图形）
struct PixelPetGenerator {
    /// 生成一个简单的像素猫 idle 帧（16x16）
    static func generateSimpleCatIdle() -> PetFrame {
        var pixels: [PetFrame.Pixel] = []
        let size = 16
        
        // 身体（橙色）
        for x in 4...11 {
            for y in 6...12 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#FF9500"))
            }
        }
        
        // 头部（橙色）
        for x in 3...12 {
            for y in 2...7 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#FF9500"))
            }
        }
        
        // 耳朵（深橙色）
        for x in 3...5 {
            for y in 0...2 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#FF6B00"))
            }
        }
        for x in 10...12 {
            for y in 0...2 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#FF6B00"))
            }
        }
        
        // 眼睛（黑色）
        pixels.append(PetFrame.Pixel(x: 5, y: 4, color: "#000000"))
        pixels.append(PetFrame.Pixel(x: 10, y: 4, color: "#000000"))
        
        // 鼻子（粉色）
        pixels.append(PetFrame.Pixel(x: 7, y: 5, color: "#FF69B4"))
        pixels.append(PetFrame.Pixel(x: 8, y: 5, color: "#FF69B4"))
        
        // 嘴巴（深粉色）
        pixels.append(PetFrame.Pixel(x: 6, y: 6, color: "#FF1493"))
        pixels.append(PetFrame.Pixel(x: 9, y: 6, color: "#FF1493"))
        
        // 腿（深橙色）
        for x in 5...6 {
            for y in 12...14 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#E68A00"))
            }
        }
        for x in 9...10 {
            for y in 12...14 {
                pixels.append(PetFrame.Pixel(x: x, y: y, color: "#E68A00"))
            }
        }
        
        // 尾巴（橙色渐变）
        for i in 0...3 {
            pixels.append(PetFrame.Pixel(x: 12 + i, y: 8 - i, color: "#FF9500"))
        }
        
        return PetFrame(pixels: pixels, width: size, height: size)
    }
    
    /// 生成 thinking 帧（眼睛转动）
    static func generateThinkingFrame() -> PetFrame {
        var frame = generateSimpleCatIdle()
        // 修改眼睛位置表示思考
        frame.pixels.removeAll { pixel in
            (pixel.x == 5 && pixel.y == 4) || (pixel.x == 10 && pixel.y == 4)
        }
        frame.pixels.append(PetFrame.Pixel(x: 6, y: 4, color: "#000000"))
        frame.pixels.append(PetFrame.Pixel(x: 9, y: 4, color: "#000000"))
        return frame
    }
    
    /// 生成完整的动画集
    static func generateAnimationSet() -> PetAnimationSet {
        let idle = generateSimpleCatIdle()
        let thinking = generateThinkingFrame()
        
        return PetAnimationSet(
            idle: [idle],
            thinking: [thinking, idle],  // 2 帧动画
            coding: [idle],
            waiting: [idle],
            celebrating: [idle],
            error: [idle],
            compacting: [idle],
            sleeping: [idle]
        )
    }
}
