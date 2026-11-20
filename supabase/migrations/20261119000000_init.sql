-- Tach: bảng chính của MVP, quy tắc phân quyền và các hàm ghi dữ liệu.
--
-- Nguyên tắc:
--   * Tiền là số nguyên (đồng), không dùng số thực.
--   * Chỉ thành viên đang ở trong nhóm mới thấy số liệu và ảnh của nhóm.
--   * Việc nào đụng nhiều bảng hoặc cần kiểm tra chéo (tạo nhóm, vào nhóm, ghi
--     khoản chi, rời nhóm, xóa nhóm, xác nhận đã nhận tiền) đi qua hàm, app
--     không ghi thẳng vào bảng.

create type public.group_type as enum ('room', 'trip', 'family');
create type public.settlement_status as enum ('pending', 'confirmed');

-- ---------------------------------------------------------------------------
-- Bảng
-- ---------------------------------------------------------------------------

-- Hồ sơ người dùng, mỗi tài khoản đăng nhập một dòng.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '' check (char_length(name) <= 40),
  -- Đường dẫn ảnh đại diện trong kho `avatars`.
  avatar_path text,
  -- Tài khoản nhận tiền qua VietQR. Bốn trường cùng có hoặc cùng trống.
  bank_bin text,
  bank_name text,
  bank_account text,
  bank_holder text,
  created_at timestamptz not null default now(),
  constraint bank_all_or_none check (
    (bank_bin is null and bank_name is null
      and bank_account is null and bank_holder is null)
    or (bank_bin is not null and bank_name is not null
      and bank_account is not null and bank_holder is not null)
  )
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 40),
  -- Mã ngắn không dấu dùng trong nội dung chuyển khoản, ví dụ TRO12.
  code text not null check (code ~ '^[A-Z0-9]{1,8}$'),
  type public.group_type not null default 'room',
  -- Mã gửi cho người khác để họ vào nhóm.
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{6}$'),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  -- Người đã rời nhóm vẫn giữ dòng này để các khoản cũ còn hiện tên họ.
  left_at timestamptz,
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members (user_id);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  payer_id uuid not null references public.profiles (id),
  amount integer not null check (amount > 0),
  note text not null default '' check (char_length(note) <= 40),
  -- Đường dẫn ảnh trong kho `photos`; trống với khoản ghi không cần ảnh.
  photo_path text,
  created_at timestamptz not null default now()
);
create index expenses_group_idx on public.expenses (group_id, created_at desc);

-- Phần mỗi người phải chịu trong một khoản chi. Tổng bằng số tiền khoản chi.
create table public.expense_splits (
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  amount integer not null check (amount >= 0),
  primary key (expense_id, user_id)
);
create index expense_splits_user_idx on public.expense_splits (user_id);

-- Mỗi người một cảm xúc cho mỗi khoản chi.
create table public.reactions (
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (expense_id, user_id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  -- Bình luận gốc khi đây là một câu trả lời.
  parent_id uuid references public.comments (id) on delete cascade,
  text text not null check (char_length(btrim(text)) between 1 and 500),
  created_at timestamptz not null default now()
);
create index comments_expense_idx on public.comments (expense_id, created_at);

-- Một lần trả nợ: người nợ báo đã chuyển, người nhận xác nhận.
create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  from_user uuid not null references public.profiles (id),
  to_user uuid not null references public.profiles (id),
  amount integer not null check (amount > 0),
  transfer_code text not null check (char_length(transfer_code) <= 40),
  status public.settlement_status not null default 'pending',
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check (from_user <> to_user)
);
create index settlements_group_idx on public.settlements (group_id);

-- ---------------------------------------------------------------------------
-- Hồ sơ tự tạo khi có tài khoản mới
-- ---------------------------------------------------------------------------

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    left(
      coalesce(
        new.raw_user_meta_data ->> 'name',
        new.raw_user_meta_data ->> 'full_name',
        ''
      ),
      40
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Hàm kiểm tra quyền, dùng trong các quy tắc bên dưới
-- ---------------------------------------------------------------------------

-- Người gọi có đang ở trong nhóm này không.
create function public.is_group_member(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members m
    where m.group_id = p_group
      and m.user_id = (select auth.uid())
      and m.left_at is null
  );
$$;

-- Người gọi có đang ở chung nhóm nào với người kia không (kể cả khi người kia
-- đã rời, để tên họ còn hiện ở các khoản cũ).
create function public.shares_group_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = (select auth.uid())
      and mine.left_at is null
      and theirs.user_id = p_user
  );
$$;

-- Người gọi có thấy khoản chi này không.
create function public.can_see_expense(p_expense uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.expenses e
    where e.id = p_expense and public.is_group_member(e.group_id)
  );
$$;

-- Đổi chữ thành uuid, trả về null nếu chữ không phải uuid. Dùng cho tên thư
-- mục trong kho ảnh.
create function public.try_uuid(p_text text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p_text::uuid;
exception when others then
  return null;
end;
$$;

-- Số dư ròng của từng người trong nhóm: đã trả trừ phần phải chịu, cộng trừ
-- các lần trả nợ đã được xác nhận. Khớp với `netBalances` trong app.
create function public.group_net(p_group uuid)
returns table (user_id uuid, net bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select x.user_id, sum(x.delta)::bigint
  from (
    select e.payer_id as user_id, e.amount::bigint as delta
    from public.expenses e
    where e.group_id = p_group
    union all
    select s.user_id, -s.amount::bigint
    from public.expense_splits s
    join public.expenses e on e.id = s.expense_id
    where e.group_id = p_group
    union all
    select t.from_user, t.amount::bigint
    from public.settlements t
    where t.group_id = p_group and t.status = 'confirmed'
    union all
    select t.to_user, -t.amount::bigint
    from public.settlements t
    where t.group_id = p_group and t.status = 'confirmed'
  ) x
  group by x.user_id;
$$;

-- ---------------------------------------------------------------------------
-- Hàm ghi dữ liệu mà app gọi
-- ---------------------------------------------------------------------------

-- Tạo nhóm mới chỉ có người gọi. Id và mã mời do app sinh để nhóm hiện ngay
-- trên máy; mã mời trùng thì báo lỗi để app sinh mã khác.
create function public.create_group(
  p_id uuid,
  p_name text,
  p_code text,
  p_type public.group_type,
  p_invite_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;

  insert into public.groups (id, name, code, type, invite_code, created_by)
  values (p_id, btrim(p_name), p_code, p_type, p_invite_code, v_user);

  insert into public.group_members (group_id, user_id)
  values (p_id, v_user);
end;
$$;

-- Vào nhóm bằng mã mời. Trả về id nhóm. Người từng rời nhóm vào lại được.
create function public.join_group(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_group uuid;
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;

  select g.id into v_group
  from public.groups g
  where g.invite_code = upper(btrim(p_invite_code));

  if v_group is null then
    raise exception 'invite_not_found';
  end if;

  insert into public.group_members (group_id, user_id)
  values (v_group, v_user)
  on conflict (group_id, user_id)
  do update set left_at = null
  where public.group_members.left_at is not null;

  return v_group;
end;
$$;

-- Rời nhóm. Chỉ rời được khi không còn nợ ai và không ai còn nợ mình.
create function public.leave_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_net bigint;
  v_next uuid;
begin
  if not public.is_group_member(p_group) then
    raise exception 'not_a_member';
  end if;

  select n.net into v_net
  from public.group_net(p_group) n
  where n.user_id = v_user;

  if coalesce(v_net, 0) <> 0 then
    raise exception 'unsettled';
  end if;

  update public.group_members
  set left_at = now()
  where group_id = p_group and user_id = v_user;

  -- Người ở lại lâu nhất nhận quyền của người tạo; không còn ai thì xóa nhóm.
  select m.user_id into v_next
  from public.group_members m
  where m.group_id = p_group and m.left_at is null
  order by m.joined_at, m.user_id
  limit 1;

  if v_next is null then
    delete from public.groups where id = p_group;
  else
    update public.groups
    set created_by = v_next
    where id = p_group and created_by = v_user;
  end if;
end;
$$;

-- Xóa nhóm với mọi thành viên. Chỉ người tạo nhóm, và chỉ khi cả nhóm đã
-- sòng phẳng.
create function public.delete_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.groups g
    where g.id = p_group and g.created_by = auth.uid()
  ) or not public.is_group_member(p_group) then
    raise exception 'not_the_creator';
  end if;

  if exists (
    select 1 from public.group_net(p_group) n where n.net <> 0
  ) then
    raise exception 'unsettled';
  end if;

  delete from public.groups where id = p_group;
end;
$$;

-- Ghi một khoản chi do người gọi trả, kèm phần chia của từng người.
-- `p_splits` có dạng {"<id người dùng>": <số tiền>, ...}.
create function public.create_expense(
  p_id uuid,
  p_group uuid,
  p_amount integer,
  p_note text,
  p_photo_path text,
  p_splits jsonb
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_total bigint;
  v_created timestamptz;
begin
  if not public.is_group_member(p_group) then
    raise exception 'not_a_member';
  end if;
  if p_splits is null or jsonb_typeof(p_splits) <> 'object'
    or p_splits = '{}'::jsonb then
    raise exception 'no_splits';
  end if;

  -- Người được chia phải đang ở trong nhóm.
  if exists (
    select 1
    from jsonb_each_text(p_splits) s
    where not exists (
      select 1
      from public.group_members m
      where m.group_id = p_group
        and m.user_id = public.try_uuid(s.key)
        and m.left_at is null
    )
  ) then
    raise exception 'split_not_a_member';
  end if;

  select sum(s.value::bigint) into v_total from jsonb_each_text(p_splits) s;
  if v_total <> p_amount then
    raise exception 'splits_do_not_add_up';
  end if;

  -- Ảnh của khoản chi phải nằm trong thư mục của nhóm.
  if p_photo_path is not null
    and split_part(p_photo_path, '/', 1) <> p_group::text then
    raise exception 'photo_outside_group';
  end if;

  insert into public.expenses (id, group_id, payer_id, amount, note, photo_path)
  values (p_id, p_group, v_user, p_amount, btrim(coalesce(p_note, '')), p_photo_path)
  returning created_at into v_created;

  insert into public.expense_splits (expense_id, user_id, amount)
  select p_id, s.key::uuid, s.value::integer
  from jsonb_each_text(p_splits) s;

  return v_created;
end;
$$;

-- Người nhận xác nhận đã nhận tiền.
create function public.confirm_settlement(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.settlements
  set status = 'confirmed', confirmed_at = now()
  where id = p_id
    and to_user = auth.uid()
    and status = 'pending'
    and public.is_group_member(group_id);

  if not found then
    raise exception 'cannot_confirm';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi hàm
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;

grant execute on function
  public.is_group_member(uuid),
  public.shares_group_with(uuid),
  public.can_see_expense(uuid),
  public.try_uuid(text),
  public.create_group(uuid, text, text, public.group_type, text),
  public.join_group(text),
  public.leave_group(uuid),
  public.delete_group(uuid),
  public.create_expense(uuid, uuid, integer, text, text, jsonb),
  public.confirm_settlement(uuid)
to authenticated;

-- `group_net` và `handle_new_user` chỉ dùng nội bộ.
revoke execute on function public.group_net(uuid) from authenticated;
revoke execute on function public.handle_new_user() from authenticated;

-- ---------------------------------------------------------------------------
-- Quyền trên bảng và quy tắc theo từng dòng
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.reactions enable row level security;
alter table public.comments enable row level security;
alter table public.settlements enable row level security;

revoke all on all tables in schema public from anon, authenticated;

grant select on
  public.profiles,
  public.groups,
  public.group_members,
  public.expenses,
  public.expense_splits,
  public.reactions,
  public.comments,
  public.settlements
to authenticated;

-- Hồ sơ: thấy của mình và của người chung nhóm; chỉ sửa của mình.
grant update (name, avatar_path, bank_bin, bank_name, bank_account, bank_holder)
on public.profiles to authenticated;

create policy "profiles: xem của mình và người chung nhóm"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.shares_group_with(id));

create policy "profiles: sửa của mình"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Nhóm: thành viên thấy nhóm và đổi được tên nhóm.
grant update (name) on public.groups to authenticated;

create policy "groups: thành viên xem"
on public.groups for select to authenticated
using (public.is_group_member(id));

create policy "groups: thành viên đổi tên"
on public.groups for update to authenticated
using (public.is_group_member(id))
with check (public.is_group_member(id));

create policy "group_members: thành viên xem"
on public.group_members for select to authenticated
using (public.is_group_member(group_id));

create policy "expenses: thành viên xem"
on public.expenses for select to authenticated
using (public.is_group_member(group_id));

create policy "expense_splits: thành viên xem"
on public.expense_splits for select to authenticated
using (public.can_see_expense(expense_id));

-- Cảm xúc: thả, đổi, gỡ cảm xúc của chính mình.
grant insert, update, delete on public.reactions to authenticated;

create policy "reactions: thành viên xem"
on public.reactions for select to authenticated
using (public.can_see_expense(expense_id));

create policy "reactions: thả của mình"
on public.reactions for insert to authenticated
with check (
  user_id = (select auth.uid()) and public.can_see_expense(expense_id)
);

create policy "reactions: đổi của mình"
on public.reactions for update to authenticated
using (user_id = (select auth.uid()) and public.can_see_expense(expense_id))
with check (
  user_id = (select auth.uid()) and public.can_see_expense(expense_id)
);

create policy "reactions: gỡ của mình"
on public.reactions for delete to authenticated
using (user_id = (select auth.uid()));

-- Bình luận: cả nhóm cùng thấy, mỗi người viết dưới tên mình.
grant insert (id, expense_id, user_id, parent_id, text)
on public.comments to authenticated;

create policy "comments: thành viên xem"
on public.comments for select to authenticated
using (public.can_see_expense(expense_id));

create policy "comments: viết dưới tên mình"
on public.comments for insert to authenticated
with check (
  user_id = (select auth.uid()) and public.can_see_expense(expense_id)
);

-- Trả nợ: người nợ tự báo đã chuyển cho một người đang ở trong nhóm.
grant insert (id, group_id, from_user, to_user, amount, transfer_code)
on public.settlements to authenticated;

create policy "settlements: thành viên xem"
on public.settlements for select to authenticated
using (public.is_group_member(group_id));

create policy "settlements: người nợ báo đã chuyển"
on public.settlements for insert to authenticated
with check (
  from_user = (select auth.uid())
  and public.is_group_member(group_id)
  and exists (
    select 1
    from public.group_members m
    where m.group_id = settlements.group_id
      and m.user_id = settlements.to_user
      and m.left_at is null
  )
);

-- ---------------------------------------------------------------------------
-- Kho ảnh
-- ---------------------------------------------------------------------------

-- `photos/<id nhóm>/<id khoản chi>.jpg`: ảnh khoản chi, chỉ thành viên nhóm.
-- `avatars/<id người dùng>/<tên file>.jpg`: ảnh đại diện.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('photos', 'photos', false, 1048576, array['image/jpeg']),
  ('avatars', 'avatars', false, 1048576, array['image/jpeg']);

create policy "photos: thành viên nhóm xem"
on storage.objects for select to authenticated
using (
  bucket_id = 'photos'
  and public.is_group_member(public.try_uuid((storage.foldername(name))[1]))
);

create policy "photos: thành viên nhóm tải lên"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'photos'
  and public.is_group_member(public.try_uuid((storage.foldername(name))[1]))
);

create policy "avatars: xem của mình và người chung nhóm"
on storage.objects for select to authenticated
using (
  bucket_id = 'avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.shares_group_with(public.try_uuid((storage.foldername(name))[1]))
  )
);

create policy "avatars: tải lên thư mục của mình"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "avatars: xóa ảnh của mình"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
