-- Nhóm "Riêng tôi": chỉ có một mình người dùng, chứa các khoản chi riêng
-- (ăn sáng, xăng). Giá trị enum mới phải được ghi nhận xong mới dùng được,
-- nên phần dùng nó nằm ở migration kế tiếp.
alter type public.group_type add value 'personal';
