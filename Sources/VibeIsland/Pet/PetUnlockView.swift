import SwiftUI

// MARK: - 宠物解锁弹窗

/// 宠物解锁时的视觉反馈视图
struct PetUnlockView: View {
    let notification: PetUnlockNotification

    var body: some View {
        VStack(spacing: 16) {
            // 解锁图标
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .scaleEffect(1.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: true)

            // 宠物预览
            PetView(petId: notification.pet.rawValue, scale: 6.0)
                .frame(width: 80, height: 80)

            // 解锁文本
            VStack(spacing: 4) {
                Text("🎉 宠物解锁！")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(notification.pet.displayName)
                    .font(.headline)
                    .foregroundStyle(.blue)

                Text("通过累计编码时长解锁")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            // 确认按钮
            Button("开始使用") {
                // 关闭弹窗
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(20)
    }
}

// MARK: - 宠物解锁动画视图

/// 在灵动岛上显示的解锁动画
struct PetUnlockAnimationView: View {
    let animation: PetUnlockAnimationManager.AnimationState

    var body: some View {
        VStack(spacing: 12) {
            // 脉冲光环
            Circle()
                .stroke(lineWidth: 2)
                .foregroundStyle(.yellow)
                .scaleEffect(1.0)
                .opacity(0.8)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)

            // 宠物图标
            Image(systemName: "cat.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            // 文本
            Text("🎉 宠物解锁")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
        )
        .padding(4)
    }
}

// MARK: - 预览
#Preview {
    PetUnlockView(notification: PetUnlockNotification(pet: .dog, unlockTime: Date()))
        .previewLayout(.fixed(width: 400, height: 300))
}
