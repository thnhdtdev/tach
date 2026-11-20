-- Người ghi khoản chi sửa được số tiền, ghi chú và phần chia của khoản đó.
-- `edited_at` để cả nhóm biết khoản đã bị sửa sau khi gửi.
alter table public.expenses add column edited_at timestamptz;

create function public.update_expense(
  p_id uuid,
  p_amount integer,
  p_note text,
  p_splits jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group uuid;
  v_total bigint;
begin
  select e.group_id into v_group
  from public.expenses e
  where e.id = p_id and e.payer_id = auth.uid();
  if v_group is null or not public.is_group_member(v_group) then
    raise exception 'not_the_payer';
  end if;
  if p_splits is null or jsonb_typeof(p_splits) <> 'object'
    or p_splits = '{}'::jsonb then
    raise exception 'no_splits';
  end if;

  -- Người được chia phải đang ở trong nhóm, hoặc đã có phần trong khoản này
  -- từ trước (người đã rời nhóm vẫn giữ phần của mình).
  if exists (
    select 1
    from jsonb_each_text(p_splits) s
    where not exists (
      select 1
      from public.group_members m
      where m.group_id = v_group
        and m.user_id = public.try_uuid(s.key)
        and m.left_at is null
    )
    and not exists (
      select 1
      from public.expense_splits x
      where x.expense_id = p_id
        and x.user_id = public.try_uuid(s.key)
    )
  ) then
    raise exception 'split_not_a_member';
  end if;

  select sum(s.value::bigint) into v_total from jsonb_each_text(p_splits) s;
  if v_total <> p_amount then
    raise exception 'splits_do_not_add_up';
  end if;

  update public.expenses
  set amount = p_amount,
      note = btrim(coalesce(p_note, '')),
      edited_at = now()
  where id = p_id;

  delete from public.expense_splits where expense_id = p_id;
  insert into public.expense_splits (expense_id, user_id, amount)
  select p_id, s.key::uuid, s.value::integer
  from jsonb_each_text(p_splits) s;
end;
$$;

revoke execute on function public.update_expense(uuid, integer, text, jsonb)
  from public, anon;
grant execute on function public.update_expense(uuid, integer, text, jsonb)
  to authenticated;
