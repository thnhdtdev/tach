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
   **Allow anonymous sign-ins** (app hiện đăng nhập bằng tài khoản khách).
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
