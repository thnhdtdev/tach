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

Giao diện MVP đã dựng xong và chạy bằng dữ liệu mẫu trong bộ nhớ
(`lib/src/datasource/sample/`). Chưa nối: Supabase, camera thật, đăng nhập,
widget màn hình chính. Ảnh khoản chi đang là ảnh minh họa vẽ sẵn.

Font chữ là Be Vietnam Pro, giấy phép SIL Open Font License
(`assets/fonts/OFL.txt`).

## Chạy app

```bash
flutter pub get
flutter run
```

Chạy test:

```bash
flutter test
```
