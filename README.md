# Tach

**Chụp là ghi, tách là xong.**

Tach là app ghi chi tiêu chung bằng cách chụp ảnh, dành cho phòng trọ ở ghép, nhóm bạn đi trip và gia đình. Mỗi khi mua gì cho cả nhóm, bạn chụp một tấm ảnh, nhập số tiền, và app tự tính ai nợ ai. Cuối tháng mỗi người nhận một mã VietQR để trả ngay.

## Tính năng MVP

- Ghi khoản chi bằng camera: chụp, nhập tiền, chọn người chia, gửi
- Bảng tin ảnh của nhóm và widget trên màn hình chính
- Số dư ai nợ ai, gộp các khoản nợ chéo
- Thanh toán bằng VietQR
- Tổng kết tháng dạng ảnh ghép

## Công nghệ

| Phần | Lựa chọn |
|---|---|
| App | Flutter (iOS, Android) |
| Backend | Supabase (Postgres, Auth, Storage) |
| Widget màn hình chính | `home_widget` + WidgetKit (iOS) / Kotlin (Android) |
| Thanh toán | VietQR (chỉ tạo mã, app không giữ tiền) |

## Cấu trúc thư mục

```
lib/        Mã nguồn Flutter
test/       Test
ios/        Project iOS (bundle id: vn.tachapp.tach)
android/    Project Android (applicationId: vn.tachapp.tach)
web/        Bản web (dự kiến cho trang xem tổng kết khi chưa cài app)
supabase/   Migration và cấu hình Supabase
docs/       Tài liệu sản phẩm và thương hiệu
```

Bên trong `lib/`:

```
lib/
├── main.dart          Điểm khởi chạy
└── src/
    ├── app.dart       Widget gốc (MaterialApp)
    ├── core/          Theme, hằng số, kiểu tiền VND, helper
    ├── datasource/    Truy cập dữ liệu Supabase (auth, nhóm, khoản chi, ảnh)
    ├── dependency/    Đăng ký dependency injection
    ├── domain/        Entity, interface repository, logic chia tiền
    ├── presentation/  Màn hình theo tính năng và state
    ├── routes/        Điều hướng
    └── services/      Widget màn hình chính, VietQR, camera
```

## Trạng thái hiện tại

Giao diện MVP đã dựng xong. App chạy theo hai cách:

- **Nối Supabase** (`--dart-define-from-file=.env`, xem
  [supabase/README.md](supabase/README.md)): đăng nhập bằng Apple, Google
  (trên iOS, sau khi cấu hình) hoặc tài khoản khách; tài khoản khách liên kết
  được sang Apple hoặc Google để giữ dữ liệu;
  dữ liệu nhóm, khoản chi, bình luận, cảm xúc, trả nợ và ảnh lưu trên máy chủ
  (`lib/src/datasource/supabase/`). Ảnh chụp được cắt vuông và nén trước khi
  tải lên. Người ghi sửa hoặc xóa được khoản chi của mình. Khi người khác
  trong nhóm thay đổi gì, app đang mở tự tải lại (Supabase Realtime).
- **Dữ liệu mẫu** (không truyền gì): mọi thứ chỉ sống trong bộ nhớ
  (`lib/src/datasource/sample/`), dùng cho test và để xem giao diện.

Widget màn hình chính có trên iOS (`ios/TachWidget/`): cỡ nhỏ hiện khoản chi
mới nhất kèm ảnh, cỡ vừa hiện số tiền bạn cần trả hoặc được nhận trong nhóm
đang mở. App ghi dữ liệu cho widget qua App Group `group.vn.tachapp.tach` mỗi
khi sổ thay đổi, nên widget chỉ mới lại khi app được mở; muốn widget tự đổi
lúc app đóng thì cần thông báo đẩy.

"Hũ của tôi" (mục 10.1 trong tài liệu sản phẩm): mỗi người đặt mức chi tiêu
tháng cho riêng mình, hũ chỉ trừ phần của họ trong mọi nhóm. Khoản chi riêng
ghi vào "Riêng tôi" (chọn ở ô đổi nhóm trên màn chụp), không ai khác thấy. Màn tháng có hai chế độ: "Lịch" là ảnh và phần tiền của mình theo từng
ngày trên mọi nhóm, "Lưới" là các khoản của nhóm đang mở. Chưa có thông báo
khi hũ chạm 80%; app chỉ nhắc ngay trên thẻ hũ.

Tổng kết tháng: ở chế độ "Lưới" của màn tháng có nút "Tổng kết tháng", dựng
một tấm ảnh dọc 1080×1920 của nhóm đang mở (ảnh các khoản nổi bật, tổng chi,
ba người trả nhiều nhất) để chia sẻ qua bảng chia sẻ của máy.

Điền tiền sau: chụp lúc chưa biết giá thì bấm "Điền tiền sau" ở bước nhập
tiền. Ảnh được giữ làm nháp trên máy (`lib/src/services/drafts/`), chưa gửi
cho nhóm; màn chụp nhắc "N khoản chờ điền tiền" để mở lại và điền giá.

Chưa có: đăng nhập bằng số điện thoại; đăng nhập Apple và Google trên
Android; thông báo đẩy; widget trên Android. Trên máy không có camera (trình giả lập), bản debug cho chụp ảnh
mẫu.

Font chữ là Montserrat, giấy phép SIL Open Font License
(`assets/fonts/OFL.txt`).

Ảnh minh họa ở màn giới thiệu nằm trong `assets/images/onboarding/`, đã cắt
vuông. Hai ảnh món ăn thuộc phạm vi công cộng, giấy phép
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/):

- `eggs.jpg`: [rawpixel](https://www.rawpixel.com/image/5920771/photo-image-background-public-domain-food)
- `hotpot.jpg`: "Hot pot" của clvs7 trên
  [Flickr](https://www.flickr.com/photos/182866455@N04/54448305782)

Bốn ảnh chân dung `mia.jpg`, `ben.jpg`, `ruby.jpg`, `leo.jpg` (256 điểm ảnh) là
avatar minh họa ở màn "Tự tách, tự tính". Nguồn và giấy phép của bốn ảnh này
chưa được ghi lại; cần xác nhận quyền sử dụng trước khi phát hành app.

## Chạy app

```bash
flutter pub get
flutter run
```

Chạy trên iPhone thật, nối Supabase theo `.env` (id là của máy đang dùng để
thử; máy khác thì lấy id bằng `flutter devices`):

```bash
flutter run -d 00008110-00167DD03AE1401E --dart-define-from-file=.env
flutter run --release -d 00008110-00167DD03AE1401E --dart-define-from-file=.env
```

Chạy test:

```bash
flutter test
```
