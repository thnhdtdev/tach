# Supabase

Thư mục này chứa migration và cấu hình Supabase của Tach.

Supabase CLI chưa được cài. Khi cần làm backend:

```bash
brew install supabase/tap/supabase
supabase init
supabase start
```

Migration đặt trong `supabase/migrations/`.

Không commit khóa bí mật (service role key) hay file `.env`.
