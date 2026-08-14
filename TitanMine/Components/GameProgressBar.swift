import SwiftUI

struct GameProgressBar: View {
    let value: Double
    let tint: Color
    let label: String
    var height: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(Color.black.opacity(0.72))
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.82), tint], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(max(0, min(1, value)))))
                Text(label)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2)
                    .frame(maxWidth: .infinity)
            }
            .overlay(RoundedRectangle(cornerRadius: height / 3).stroke(Color.white.opacity(0.32), lineWidth: 1.5))
        }
        .frame(height: height)
    }
}
