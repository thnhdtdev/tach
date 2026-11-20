import SwiftUI
import WidgetKit

private let appGroup = "group.vn.tachapp.tach"

struct TachEntry: TimelineEntry {
  let date: Date
  let content: TachWidgetContent?
  let photo: UIImage?
  let avatar: UIImage?

  static let sample = TachEntry(
    date: Date(),
    content: TachWidgetContent(
      group: "Trọ 12",
      payerInitial: "M",
      payerTone: "F6C0A8",
      note: "Trứng",
      amountShort: "30k",
      amountFull: "30.000đ",
      balanceLabel: "Bạn cần trả",
      balanceAmount: "7.500đ",
      balanceTone: "owe"
    ),
    photo: nil,
    avatar: nil
  )

  static func stored() -> TachEntry {
    let defaults = UserDefaults(suiteName: appGroup)
    let content = defaults?.string(forKey: "content")
      .flatMap { $0.data(using: .utf8) }
      .flatMap { try? JSONDecoder().decode(TachWidgetContent.self, from: $0) }
    let photo = defaults?.data(forKey: "photo").flatMap { UIImage(data: $0) }
    let avatar = defaults?.data(forKey: "avatar").flatMap { UIImage(data: $0) }
    return TachEntry(date: Date(), content: content, photo: photo, avatar: avatar)
  }
}

struct TachProvider: TimelineProvider {
  func placeholder(in context: Context) -> TachEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (TachEntry) -> Void) {
    completion(context.isPreview ? .sample : .stored())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TachEntry>) -> Void) {
    // App gọi tải lại mỗi khi dữ liệu đổi, nên widget không tự hẹn giờ.
    completion(Timeline(entries: [.stored()], policy: .never))
  }
}

struct TachWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: TachEntry

  var body: some View {
    let size: TachWidgetSize = family == .systemMedium ? .medium : .small
    let photo = entry.photo.map { Image(uiImage: $0) }
    let face = TachWidgetFace(
      size: size,
      content: entry.content,
      photo: photo,
      avatar: entry.avatar.map { Image(uiImage: $0) }
    )
    let backdrop = TachWidgetBackdrop(size: size, content: entry.content, photo: photo)

    if #available(iOS 17.0, *) {
      face.containerBackground(for: .widget) { backdrop }
    } else {
      // Trước iOS 17 widget không tự chừa lề.
      face.padding(16).background(backdrop)
    }
  }
}

@main
struct TachWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TachWidget", provider: TachProvider()) { entry in
      TachWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Tach")
    .description("Khoản chi mới nhất của nhóm và số tiền bạn cần trả.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
