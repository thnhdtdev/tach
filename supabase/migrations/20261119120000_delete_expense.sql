-- Người ghi khoản chi xóa được khoản của mình. Phần chia, cảm xúc và bình luận
-- mất theo; số dư của nhóm tự tính lại vì khoản đó không còn.
create function public.delete_expense(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Xóa lại một khoản đã mất thì coi như xong.
  if not exists (select 1 from public.expenses e where e.id = p_id) then
    return;
  end if;

  delete from public.expenses e
  where e.id = p_id
    and e.payer_id = auth.uid()
    and public.is_group_member(e.group_id);
  if not found then
    raise exception 'not_the_payer';
  end if;
end;
$$;

revoke execute on function public.delete_expense(uuid) from public, anon;
grant execute on function public.delete_expense(uuid) to authenticated;

create policy "photos: xóa ảnh mình tải lên"
on storage.objects for delete to authenticated
using (
  bucket_id = 'photos'
  and owner_id = (select auth.uid())::text
);
