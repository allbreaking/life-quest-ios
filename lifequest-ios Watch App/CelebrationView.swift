
//
//  CelebrationView.swift
//  lifequest-ios Watch App
//

import SwiftUI

// MARK: - CelebrationView

struct CelebrationView: View {
    var body: some View {
        ZStack {
            // #FDEBD3 Cream → #FAF8F5 bgMain
            LinearGradient(
                colors: [
                    Color(red: 0.992, green: 0.922, blue: 0.827),
                    Color(red: 0.980, green: 0.973, blue: 0.961)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            FireworksView()
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("All Done!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.227, green: 0.180, blue: 0.149)) // Espresso #3A2E26
                Text("🎉")
                    .font(.largeTitle)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - FireworksView

struct FireworksView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let elapsed = now.truncatingRemainder(dividingBy: 2.0) // 2-second loop

                // Generate particles using seeded pseudo-random based on time bucket
                let bucket = Int(now / 2.0)
                var rng = SeededRNG(seed: UInt64(bitPattern: Int64(bucket)))

                let particleCount = 60
                let origin = CGPoint(x: size.width / 2, y: size.height)

                for _ in 0..<particleCount {
                    let angle = rng.nextDouble() * 2 * .pi
                    let speed = rng.nextDouble() * 80 + 40 // 40..120 pts/s
                    let colorIndex = Int(rng.nextDouble() * Double(fireworkColors.count))
                    let color = fireworkColors[colorIndex]
                    let size_pt = rng.nextDouble() * 3 + 2 // 2..5 pts

                    // Position: ballistic with gravity
                    let vx = cos(angle) * speed
                    let vy = sin(angle) * speed - 60 // initial upward bias
                    let gravity = 50.0
                    let x = origin.x + vx * elapsed
                    let y = origin.y + vy * elapsed + 0.5 * gravity * elapsed * elapsed

                    // Fade out over 2 seconds
                    let alpha = max(0, 1.0 - elapsed / 2.0)

                    let rect = CGRect(
                        x: x - size_pt / 2,
                        y: y - size_pt / 2,
                        width: size_pt,
                        height: size_pt
                    )

                    var ctx = context
                    ctx.opacity = alpha
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var fireworkColors: [Color] {
        [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .white, .mint]
    }
}

// MARK: - SeededRNG (simple LCG)

private struct SeededRNG {
    var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 6364136223846793005
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        let raw = nextUInt64()
        return Double(raw) / Double(UInt64.max)
    }
}

#Preview {
    CelebrationView()
}
