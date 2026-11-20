-- Cập nhật tức thì: mỗi khi dữ liệu của một nhóm đổi, cơ sở dữ liệu phát tín
-- hiệu `changed` lên kênh riêng `group:<id nhóm>`. App đang mở nhận tín hiệu
-- rồi tự tải lại; tín hiệu không mang dữ liệu nên không lộ gì ra ngoài nhóm.

create function public.notify_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_group is null then
    return;
  end if;
  perform realtime.send('{}'::jsonb, 'changed', 'group:' || p_group::text, true);
exception when others then
  -- Tín hiệu chỉ để làm mới màn hình; không gửi được thì thay đổi vẫn phải lưu.
  null;
end;
$$;

create function public.broadcast_group_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_group uuid;
begin
  if tg_op = 'DELETE' then
    r := old;
  else
    r := new;
  end if;

  case tg_table_name
    when 'groups' then
      v_group := r.id;
    when 'reactions', 'comments' then
      -- Khoản chi đã bị xóa cùng lúc thì tín hiệu của chính nó là đủ.
      select e.group_id into v_group
      from public.expenses e
      where e.id = r.expense_id;
    when 'profiles' then
      -- Tên, ảnh đại diện, tài khoản nhận tiền hiện ở mọi nhóm của người đó.
      perform public.notify_group(m.group_id)
      from public.group_members m
      where m.user_id = r.id;
      return null;
    else
      v_group := r.group_id;
  end case;

  perform public.notify_group(v_group);
  return null;
end;
$$;

revoke execute on function public.notify_group(uuid)
  from public, anon, authenticated;
revoke execute on function public.broadcast_group_change()
  from public, anon, authenticated;

create trigger broadcast_change
after update or delete on public.groups
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after insert or update or delete on public.group_members
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after insert or update or delete on public.expenses
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after insert or update or delete on public.reactions
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after insert or update or delete on public.comments
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after insert or update or delete on public.settlements
for each row execute function public.broadcast_group_change();

create trigger broadcast_change
after update on public.profiles
for each row execute function public.broadcast_group_change();

create policy "group: thành viên nhận tín hiệu của nhóm"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and realtime.topic() like 'group:%'
  and public.is_group_member(
    public.try_uuid(split_part(realtime.topic(), ':', 2))
  )
);
