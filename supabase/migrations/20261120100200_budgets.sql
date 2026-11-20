-- "Hũ của tôi": mức chi tiêu mỗi tháng do từng người tự đặt. Chỉ chủ hũ đọc và
-- sửa được; nhóm không có hũ.
create table public.budgets (
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- Ngày đầu của tháng mà mức này bắt đầu áp dụng.
  period date not null check (extract(day from period) = 1),
  amount integer not null check (amount > 0),
  -- Có tính các khoản "Chỉ mình tôi" vào hũ hay không.
  include_personal boolean not null default true,
  -- Tự áp dụng cho các tháng sau cho tới khi có mức mới.
  repeats boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, period)
);

alter table public.budgets enable row level security;

revoke all on public.budgets from anon, authenticated;
grant select, insert, update, delete on public.budgets to authenticated;

create policy "budgets: chỉ chủ hũ"
on public.budgets for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
