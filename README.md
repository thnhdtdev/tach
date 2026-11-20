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
  [supabase/README.md](supabase/README.md)): đăng nhập bằng tài khoản khách,
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

Chưa có: đăng nhập Apple, Google, số điện thoại; thông báo đẩy; widget trên
Android. Trên máy không có camera (trình giả lập), bản debug cho chụp ảnh
mẫu.

Font chữ là Montserrat, giấy phép SIL Open Font License
(`assets/fonts/OFL.txt`).

Ảnh minh họa ở màn giới thiệu (`assets/images/onboarding/`) thuộc phạm vi công
cộng, giấy phép [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/),
đã cắt vuông:

- `eggs.jpg`: [rawpixel](https://www.rawpixel.com/image/5920771/photo-image-background-public-domain-food)
- `hotpot.jpg`: "Hot pot" của clvs7 trên
  [Flickr](https://www.flickr.com/photos/182866455@N04/54448305782)

## Chạy app

```bash
flutter pub get
flutter run
```

Chạy test:

```bash
flutter test
```
