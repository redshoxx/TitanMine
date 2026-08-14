import SwiftUI

/// Fully code-drawn battle scene so the project builds without external binary art assets.
/// The visual language mirrors the Titan Mine concept: saturated ocean blues, a grassy
/// floating voxel island, glowing crystals, a blocky crystal titan and a mining beam.
struct VoxelBossScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.50, blue: 0.86), Color(red: 0.00, green: 0.18, blue: 0.43)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                oceanHighlights(width: w, height: h)

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.74, blue: 0.08), Color(red: 0.12, green: 0.34, blue: 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * 0.90, height: h * 0.62)
                    .rotationEffect(.degrees(-2))
                    .offset(y: h * 0.13)
                    .shadow(color: .black.opacity(0.65), radius: 18, y: 18)

                voxelGrid(width: w, height: h)
                    .offset(y: h * 0.14)
                    .opacity(0.35)

                crystals(width: w, height: h)

                titan(width: w, height: h)
                    .offset(x: w * 0.10, y: -h * 0.02)

                miner(width: w, height: h)
                    .offset(x: -w * 0.28, y: h * 0.24)

                miningBeam(width: w, height: h)

                loot(width: w, height: h)
            }
            .drawingGroup()
        }
        .background(Color.black)
    }

    private func oceanHighlights(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            for row in 0..<12 {
                for col in 0..<8 {
                    let x = CGFloat(col) * size.width / 7.0 + CGFloat(row % 2) * 13
                    let y = CGFloat(row) * size.height / 11.0
                    var path = Path()
                    path.move(to: CGPoint(x: x - 16, y: y))
                    path.addQuadCurve(
                        to: CGPoint(x: x + 16, y: y),
                        control: CGPoint(x: x, y: y - 7)
                    )
                    context.stroke(path, with: .color(.white.opacity(0.13)), lineWidth: 1.5)
                }
            }
        }
    }

    private func voxelGrid(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let step: CGFloat = 26
            for x in stride(from: 0 as CGFloat, through: size.width, by: step) {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(p, with: .color(.black.opacity(0.3)), lineWidth: 1)
            }
            for y in stride(from: 0 as CGFloat, through: size.height, by: step) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(p, with: .color(.black.opacity(0.3)), lineWidth: 1)
            }
        }
        .frame(width: width * 0.86, height: height * 0.56)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func titan(width: CGFloat, height: CGFloat) -> some View {
        let body = min(width * 0.45, height * 0.34)
        return ZStack {
            RoundedRectangle(cornerRadius: body * 0.14)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.58), Color(white: 0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: body, height: body * 0.86)
                .overlay(
                    RoundedRectangle(cornerRadius: body * 0.14)
                        .stroke(.black.opacity(0.8), lineWidth: 4)
                )
                .shadow(color: .cyan.opacity(0.6), radius: 14)

            HStack(spacing: body * 0.27) {
                eye(size: body * 0.12)
                eye(size: body * 0.12)
            }
            .offset(y: body * 0.10)

            crystalCluster(scale: body / 170)
                .offset(y: -body * 0.49)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.30))
                .frame(width: body * 0.29, height: body * 0.52)
                .rotationEffect(.degrees(20))
                .offset(x: -body * 0.60, y: body * 0.10)
                .overlay(
                    crystalShard(size: body * 0.16)
                        .offset(x: -body * 0.60, y: body * 0.04)
                )

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.28))
                .frame(width: body * 0.29, height: body * 0.52)
                .rotationEffect(.degrees(-20))
                .offset(x: body * 0.60, y: body * 0.10)

            HStack(spacing: body * 0.45) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.24))
                    .frame(width: body * 0.28, height: body * 0.30)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.24))
                    .frame(width: body * 0.28, height: body * 0.30)
            }
            .offset(y: body * 0.52)
        }
    }

    private func eye(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.white)
            .frame(width: size * 1.35, height: size * 0.68)
            .shadow(color: .cyan, radius: 9)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cyan.opacity(0.65))
                    .padding(2)
            )
    }

    private func crystalCluster(scale: CGFloat) -> some View {
        ZStack {
            crystalShard(size: 72 * scale).offset(x: 0, y: -18 * scale)
            crystalShard(size: 50 * scale).offset(x: -43 * scale, y: 4 * scale).rotationEffect(.degrees(-18))
            crystalShard(size: 48 * scale).offset(x: 42 * scale, y: 8 * scale).rotationEffect(.degrees(19))
            crystalShard(size: 35 * scale).offset(x: -17 * scale, y: 17 * scale)
            crystalShard(size: 32 * scale).offset(x: 22 * scale, y: 18 * scale)
        }
    }

    private func crystalShard(size: CGFloat) -> some View {
        DiamondShape()
            .fill(
                LinearGradient(
                    colors: [.white, Color.cyan, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.66, height: size)
            .overlay(DiamondShape().stroke(.white.opacity(0.75), lineWidth: 1.5))
            .shadow(color: .cyan.opacity(0.9), radius: 9)
    }

    private func crystals(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            crystalShard(size: 35).position(x: width * 0.18, y: height * 0.58)
            crystalShard(size: 27).position(x: width * 0.34, y: height * 0.66)
            crystalShard(size: 32).position(x: width * 0.70, y: height * 0.60)
            crystalShard(size: 25).position(x: width * 0.82, y: height * 0.72)
            crystalShard(size: 22).position(x: width * 0.58, y: height * 0.77)
        }
    }

    private func miner(width: CGFloat, height: CGFloat) -> some View {
        let s = min(width, height) * 0.11
        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(red: 0.08, green: 0.18, blue: 0.31))
                .frame(width: s * 0.78, height: s * 0.92)
                .offset(y: s * 0.42)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.91, green: 0.65, blue: 0.36))
                .frame(width: s * 0.66, height: s * 0.55)
                .offset(y: -s * 0.18)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.97, green: 0.71, blue: 0.12))
                .frame(width: s * 0.82, height: s * 0.18)
                .offset(y: -s * 0.48)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.09, green: 0.33, blue: 0.66))
                .frame(width: s * 0.78, height: s * 0.32)
                .rotationEffect(.degrees(-24))
                .offset(x: s * 0.50, y: s * 0.16)
                .shadow(color: .cyan, radius: 6)
        }
    }

    private func miningBeam(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let start = CGPoint(x: size.width * 0.30, y: size.height * 0.77)
            let end = CGPoint(x: size.width * 0.56, y: size.height * 0.49)
            var beam = Path()
            beam.move(to: start)
            beam.addLine(to: end)
            context.stroke(beam, with: .color(.purple.opacity(0.45)), lineWidth: 16)
            context.stroke(beam, with: .color(.cyan.opacity(0.75)), lineWidth: 8)
            context.stroke(beam, with: .color(.white), lineWidth: 3)

            for i in 0..<8 {
                let t = CGFloat(i) / 7
                let x = start.x + (end.x - start.x) * t
                let y = start.y + (end.y - start.y) * t
                let r = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: r), with: .color(.yellow.opacity(0.9)))
            }
        }
    }

    private func loot(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, .yellow, .orange],
                            center: .center,
                            startRadius: 0,
                            endRadius: 12
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                    .position(
                        x: width * (0.37 + CGFloat(i % 4) * 0.12),
                        y: height * (0.69 + CGFloat(i / 4) * 0.09)
                    )
            }
        }
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.93))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY * 0.93))
        p.closeSubpath()
        return p
    }
}
