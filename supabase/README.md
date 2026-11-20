# Supabase

Thư mục này chứa cấu hình và migration Supabase của Tach.

- `migrations/`: bảng, quy tắc phân quyền (RLS), các hàm ghi dữ liệu và kho ảnh.
- `config.toml`: cấu hình cho Supabase chạy trên máy (đã bật tài khoản khách).

## Nối app với project Supabase thật

1. Tạo project ở <https://supabase.com/dashboard>.
2. Đưa bảng lên project:

   ```bash
   supabase login
   supabase link --project-ref <mã project>
   supabase db push --remote
   ```

   Thiếu `--remote` thì lệnh chỉ đưa lên Supabase đang chạy trên máy.

3. Trong dashboard, vào Authentication → Sign In / Providers và bật
   **Allow anonymous sign-ins** (tài khoản khách để dùng thử; đăng nhập Apple
   và Google xem mục bên dưới).
4. Chép `.env.example` thành `.env` ở thư mục gốc, điền Project URL và
   khóa công khai (publishable key, hoặc anon key ở project cũ) lấy từ
   Project Settings → API Keys.
5. Chạy app:

   ```bash
   flutter run --dart-define-from-file=.env
   ```

   Trong VS Code chọn cấu hình chạy **Tach (Supabase)**. Không truyền file này
   thì app chạy bằng dữ liệu mẫu trong bộ nhớ.

`.env` không được commit. Tuyệt đối không đặt khóa bí mật (secret key,
service role key) vào app hay vào file này.

## Bật đăng nhập Apple và Google

App đăng nhập bằng bảng đăng nhập gốc của iOS rồi đưa token cho Supabase. Cách
nào chưa cấu hình thì nút của nó không hiện, app vẫn chạy với tài khoản khách.
Phần này mới làm cho iOS.

### Google

1. Vào <https://console.cloud.google.com/> → APIs & Services → Credentials,
   tạo hai OAuth client ID trong cùng một project:
   - loại **iOS**, Bundle ID `vn.tachapp.tach`;
   - loại **Web application** (Supabase kiểm tra token theo client này).
2. Trong dashboard Supabase: Authentication → Sign In / Providers → Google,
   bật lên, điền cả hai client ID vào ô **Client IDs** (client Web đứng trước,
   cách nhau bằng dấu phẩy, không có dấu cách) và Client Secret của client Web. Client Secret chỉ
   nằm ở dashboard, không đưa vào app hay `.env`.
3. Thêm vào `.env`:

   ```
   GOOGLE_IOS_CLIENT_ID=<client ID loại iOS>
   GOOGLE_WEB_CLIENT_ID=<client ID loại Web>
   ```

4. Thêm vào `ios/Runner/Info.plist` URL scheme của client iOS (Google Cloud
   ghi sẵn ở mục "iOS URL scheme", dạng `com.googleusercontent.apps.<số>-<chữ>`).
   Thiếu bước này app sẽ thoát khi bấm nút Google:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.XXXX</string>
       </array>
     </dict>
   </array>
   ```

### Apple

Cần tài khoản Apple Developer trả phí; tài khoản miễn phí không có quyền này.

1. Mở `ios/Runner.xcworkspace` bằng Xcode, chọn target Runner → Signing &
   Capabilities → **+ Capability** → **Sign in with Apple**.
2. Trong dashboard Supabase: Authentication → Sign In / Providers → Apple, bật
   lên và điền `vn.tachapp.tach` vào ô **Client IDs**.
3. Thêm `APPLE_SIGN_IN=true` vào `.env`.

Apple yêu cầu app nào có đăng nhập Google thì cũng phải có đăng nhập Apple khi
nộp App Store.

### Cho tài khoản khách liên kết sang Apple hoặc Google

Trong dashboard Supabase: Authentication → Sign In / Providers, bật **Allow
manual linking**. Khi đó người đang dùng tài khoản khách thấy thẻ "Giữ dữ liệu
của bạn" ở màn Hồ sơ và gắn được tài khoản thật mà không mất nhóm, khoản chi.

## Chạy Supabase trên máy để kiểm thử

Cần Docker đang chạy.

```bash
supabase start        # lần đầu tải image khá lâu
supabase status       # xem API URL và Publishable key
supabase db reset     # dựng lại cơ sở dữ liệu từ migrations/
supabase stop
```

Kiểm thử lớp dữ liệu của app với Supabase đang chạy trên máy:

```bash
flutter test test_supabase \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<Publishable key từ supabase status>
```

## Thêm thay đổi cho cơ sở dữ liệu

```bash
supabase migration new <tên_thay_đổi>
```

Viết SQL vào file vừa tạo, chạy `supabase db reset` để thử trên máy, rồi
`supabase db push --remote` để đưa lên project thật. Không sửa migration đã đưa lên.
