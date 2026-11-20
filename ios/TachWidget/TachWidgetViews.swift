import SwiftUI
import WidgetKit

/// Nội dung app ghi sẵn cho widget. Số tiền và câu chữ đã được app định dạng,
/// widget chỉ việc hiện.
struct TachWidgetContent: Codable, Equatable {
  var group: String
  /// Chữ cái đầu tên và màu nền avatar của người ghi, dùng khi họ chưa đặt ảnh.
  var payerInitial: String?
  var payerTone: String?
  var note: String?
  var amountShort: String?
  var amountFull: String?
  var balanceLabel: String
  var balanceAmount: String?
  /// "owe" (bạn cần trả), "owed" (bạn được nhận) hoặc "even".
  var balanceTone: String

  var hasExpense: Bool { amountFull != nil }
}

enum TachWidgetSize {
  case small
  case medium
}

extension Color {
  static let tachMint = Color(red: 0x12 / 255, green: 0xA5 / 255, blue: 0x94 / 255)
  static let tachMintDeep = Color(red: 0x0B / 255, green: 0x5F / 255, blue: 0x55 / 255)
  static let tachMintLight = Color(red: 0x7E / 255, green: 0xE0 / 255, blue: 0xCF / 255)
  static let tachNight = Color(red: 0x0F / 255, green: 0x17 / 255, blue: 0x16 / 255)
  static let tachInk = Color(red: 0x14 / 255, green: 0x20 / 255, blue: 0x1E / 255)

  /// Màu dạng "RRGGBB".
  init?(tachHex: String?) {
    guard let tachHex, tachHex.count == 6, let value = UInt32(tachHex, radix: 16) else {
      return nil
    }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}

private let mintGradient = LinearGradient(
  colors: [.tachMint, .tachMintDeep],
  startPoint: .topLeading,
  endPoint: .bottomTrailing
)

/// Logo Tach: khung ngắm ôm đồng xu tách đôi, cùng tọa độ với bản vẽ trong app.
struct TachMarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    var corner = Path()
    corner.move(to: CGPoint(x: -28, y: -12))
    corner.addLine(to: CGPoint(x: -28, y: -20))
    corner.addArc(
      center: CGPoint(x: -20, y: -20), radius: 8,
      startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
    corner.addLine(to: CGPoint(x: -12, y: -28))

    var brackets = Path()
    for quarter in 0..<4 {
      brackets.addPath(
        corner.applying(CGAffineTransform(rotationAngle: .pi / 2 * CGFloat(quarter))))
    }
    var mark = brackets.strokedPath(StrokeStyle(lineWidth: 7, lineCap: .round))

    var coin = Path()
    coin.move(to: CGPoint(x: -3, y: -15))
    coin.addArc(
      center: CGPoint(x: -3, y: 0), radius: 15,
      startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
    coin.closeSubpath()
    coin.move(to: CGPoint(x: 3, y: -15))
    coin.addArc(
      center: CGPoint(x: 3, y: 0), radius: 15,
      startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
    coin.closeSubpath()
    mark.addPath(coin.applying(CGAffineTransform(rotationAngle: .pi / 4)))

    let scale = min(rect.width, rect.height) / 64
    return mark.applying(
      CGAffineTransform(translationX: rect.midX, y: rect.midY).scaledBy(x: scale, y: scale))
  }
}

private struct WidgetPhoto: View {
  let photo: Image

  var body: some View {
    // Ở chế độ icon nhuộm màu của iOS 18 trở lên, ảnh phải giữ nguyên màu.
    if #available(iOS 18.0, macOS 15.0, *) {
      photo.resizable().widgetAccentedRenderingMode(.fullColor).scaledToFill()
    } else {
      photo.resizable().scaledToFill()
    }
  }
}

/// Avatar của người ghi khoản chi: ảnh nếu có, không thì chữ cái đầu trên nền màu.
private struct PayerAvatar: View {
  let content: TachWidgetContent
  let avatar: Image?
  let side: CGFloat

  var body: some View {
    ZStack {
      if let avatar {
        WidgetPhoto(photo: avatar).frame(width: side, height: side)
      } else {
        Color(tachHex: content.payerTone) ?? .tachMintLight
        Text(content.payerInitial ?? "?")
          .font(.system(size: side * 0.44, weight: .semibold))
          .foregroundColor(.tachInk)
      }
    }
    .frame(width: side, height: side)
    .clipShape(Circle())
    .overlay(Circle().stroke(Color.white, lineWidth: 2))
  }
}

/// Lớp nền, phủ kín widget.
struct TachWidgetBackdrop: View {
  let size: TachWidgetSize
  let content: TachWidgetContent?
  let photo: Image?

  var body: some View {
    if size == .small, content?.hasExpense == true {
      if let photo {
        ZStack {
          Color.tachNight
          GeometryReader { box in
            WidgetPhoto(photo: photo)
              .frame(width: box.size.width, height: box.size.height)
              .clipped()
          }
          LinearGradient(
            colors: [.black.opacity(0), .black.opacity(0.7)],
            startPoint: .center,
            endPoint: .bottom
          )
        }
      } else {
        mintGradient
      }
    } else {
      Color.tachNight
    }
  }
}

/// Lớp nội dung, nằm trong lề của widget.
struct TachWidgetFace: View {
  let size: TachWidgetSize
  let content: TachWidgetContent?
  let photo: Image?
  let avatar: Image?

  var body: some View {
    switch size {
    case .small: small
    case .medium: medium
    }
  }

  @ViewBuilder private var small: some View {
    if let content, content.hasExpense {
      VStack(alignment: .leading, spacing: 1) {
        PayerAvatar(content: content, avatar: avatar, side: 32)
        Spacer(minLength: 0)
        Text(content.amountFull ?? "")
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        if let note = content.note, !note.isEmpty {
          Text(note)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        TachMarkShape().fill(Color.tachMintLight).frame(width: 34, height: 34)
        Spacer(minLength: 0)
        Text(emptyText)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(4)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var medium: some View {
    HStack(spacing: 14) {
      tile
      if let content {
        VStack(alignment: .leading, spacing: 0) {
          Text(content.group)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.tachMintLight)
            .lineLimit(1)
          Spacer(minLength: 4)
          Text(content.balanceLabel)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(2)
          if let amount = content.balanceAmount {
            Text(amount)
              .font(.system(size: 28, weight: .bold))
              .foregroundColor(content.balanceTone == "owed" ? .tachMintLight : .white)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          Spacer(minLength: 4)
          Text(latestLine(content))
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.6))
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      } else {
        Text(emptyText)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white.opacity(0.85))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var tile: some View {
    GeometryReader { box in
      let side = min(box.size.width, box.size.height)
      ZStack {
        if let photo, content?.hasExpense == true {
          WidgetPhoto(photo: photo).frame(width: side, height: side).clipped()
        } else {
          mintGradient
          TachMarkShape().fill(Color.white).frame(width: side * 0.46, height: side * 0.46)
        }
      }
      .frame(width: side, height: side)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(alignment: .bottomLeading) {
        if let content, content.hasExpense {
          PayerAvatar(content: content, avatar: avatar, side: 30).padding(8)
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private var emptyText: String {
    guard let content else { return "Mở Tach để bắt đầu ghi chi tiêu chung" }
    return "\(content.group) chưa có khoản chi nào"
  }

  private func latestLine(_ content: TachWidgetContent) -> String {
    guard content.hasExpense else { return "Chưa có khoản chi nào" }
    let note = content.note ?? ""
    return "\(note.isEmpty ? "Khoản mới nhất" : note) \(content.amountShort ?? "")"
  }
}
