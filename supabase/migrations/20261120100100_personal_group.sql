-- Mỗi người chỉ có một nhóm riêng.
create unique index groups_one_personal_per_user
on public.groups (created_by)
where type = 'personal';

-- Nhóm riêng không vào được bằng mã mời.
create or replace function public.join_group(p_invite_code text)
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
  where g.invite_code = upper(btrim(p_invite_code))
    and g.type <> 'personal';

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
