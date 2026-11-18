# Tach — Product Doc

<aside>
💡

**Tóm tắt một câu:** App ghi chi tiêu chung bằng cách **chụp ảnh** (camera-first, kiểu widget ảnh bạn bè), dành cho **phòng trọ ở ghép, nhóm bạn đi trip và gia đình**. Cuối tháng app tự tính ai nợ ai và tạo **mã VietQR** để trả ngay. Sau này mở rộng sang **chủ trọ**: báo điện nước, hóa đơn từng phòng.

</aside>

---

## 0. Thương hiệu

| Mục | Quyết định |
| --- | --- |
| Tên app | **Tach** |
| Cách đọc | "tách", như tiếng màn trập và "tách bill" |
| Ý nghĩa | Hai nghĩa: tiếng chụp ảnh "tách tách" + "tách bill" (chia tiền). Viết không dấu nên dùng được cho tên miền, App Store, mạng xã hội |
| Slogan | *Chụp là ghi, tách là xong.* |
| Logo (đang phác thảo) | Ống kính máy ảnh bị tách đôi, nền xanh bạc hà |
| Màu chính | **Xanh bạc hà** `#12A594`; chữ đậm `#0B5F55`; nhấn trên nền tối `#7EE0CF`; nền nhạt `#D5F5EF`; "Đã trả" dùng xanh dương `#185FA5` để không lẫn với màu chính |
| Vì sao xanh bạc hà | Tông lạnh, khác hẳn vàng của các app ảnh bạn bè; tránh liên tưởng cam của Shopee; gợi tiền và sự rõ ràng. Giữ đủ ngả xanh lơ để không giống xanh lá của Grab |
| Ngôn ngữ | Tên tiếng Anh/không dấu, toàn bộ nội dung trong app bằng tiếng Việt |

**Cần kiểm tra trước khi chốt:**

- [ ]  App Store / Google Play: đã có app nào tên "Tach" chưa
- [ ]  Tra cứu nhãn hiệu tại Cục Sở hữu trí tuệ (nhóm 9 phần mềm, nhóm 36 tài chính)
- [ ]  Tên miền: [tach.app](http://tach.app), [tach.vn](http://tach.vn), [gettach.app](http://gettach.app), [tachapp.vn](http://tachapp.vn)
- [ ]  Tài khoản TikTok / Facebook / Instagram
- [ ]  Đọc thử cho 5–10 sinh viên xem họ đọc đúng "tách" không

## 1. Vấn đề

- Sinh viên ở trọ (ở một mình, ở với bạn, ở ghép người lạ) mua đồ dùng chung: người mua cái này, người mua cái kia. Cuối tháng **không ai nhớ ai đã mua gì** nếu không ghi chép.
- Gia đình cũng vậy: đi chợ bao nhiêu, điện nước bao nhiêu, ai đã chi gì trong tháng.
- Nhóm bạn đi chơi: người trả món này, người trả món kia, cuối chuyến tính toán rất rối.
- **Đòi tiền ngại**, nhớ ai đã trả hay chưa cũng khó. Đây là nguồn gốc của nhiều mâu thuẫn.

Cách người Việt đang làm hiện nay: ghi chú điện thoại, nhóm Zalo, Google Sheet, hoặc… không làm gì cả. **Đây mới là đối thủ thật**: miễn phí, quen tay, không cần cài.

## 2. Đối thủ & thị trường

| App | Điểm mạnh | Điểm yếu với người Việt |
| --- | --- | --- |
| Splitwise | Nổi tiếng nhất, tối ưu nợ | Tiếng Anh, bản miễn phí giới hạn số khoản ghi mỗi ngày |
| Tricount, Settle Up, Splid | Đơn giản, hợp đi du lịch | Không tiếng Việt, không gắn với chuyển khoản ở VN |
| MoMo (quỹ nhóm, chia tiền) | Ai cũng có, trả tiền ngay | Thiên về thanh toán, không theo dõi chi tiêu lâu dài |
| Money Lover, Misa Sổ thu chi | Quản lý chi tiêu cá nhân tốt | Không xoay quanh chia tiền nhóm |
| Các app quản lý nhà trọ | Phục vụ chủ trọ | Không có phần chia tiền giữa người ở chung |

**Khoảng trống:** chưa có app chia tiền lớn nào lấy **camera làm trung tâm**, và chưa có app nào **bản địa hóa sâu** cho phòng trọ Việt Nam (điện nước theo số, VietQR, quỹ chung).

## 3. Định vị & điểm khác biệt

1. **Camera-first:** mở app là vào camera, chụp ảnh món đồ hoặc hóa đơn, nhập số tiền, gửi. Cả luồng **dưới 5 giây**.
2. **Widget màn hình chính:** hiện "Minh vừa mua trứng 30k" kèm ảnh. Mọi người thấy chi tiêu chung theo thời gian thực, mở app mỗi ngày.
3. **Ảnh là bằng chứng:** giảm nghi ngờ, giảm cãi nhau.
4. **Thanh toán bằng VietQR:** tạo sẵn mã QR đúng số tiền, đúng người nhận. Không giữ tiền hộ.
5. **Tự xác nhận đã trả:** đọc giao dịch ngân hàng qua dịch vụ như SePay/Casso, khớp nội dung chuyển khoản, tự đánh dấu "đã trả".
6. **Hai chế độ nhóm:** *Quỹ chung* (góp đầu tháng, chi từ quỹ) và *Chia hóa đơn* (ai trả gì, ai nợ ai).
7. **Tổng kết tháng dạng ảnh ghép** để chia sẻ lên TikTok/story → lan truyền miễn phí.

<aside>
⚠️

Học cách làm của các app widget ảnh, nhưng **đặt tên, nhận diện và phong cách riêng**. Không dùng tên hay thương hiệu của app khác.

</aside>

## 4. Người dùng mục tiêu

| Nhóm | Bối cảnh | Chế độ phù hợp | Ưu tiên |
| --- | --- | --- | --- |
| Phòng trọ ở ghép | 2–5 người, chi tiêu đều đặn hàng tháng, điện nước | Quỹ chung hoặc chia hóa đơn | **Ngách đầu tiên** |
| Nhóm bạn đi trip | Ngắn ngày, nhiều khoản, nhiều người trả | Chia hóa đơn + tối ưu nợ | Giai đoạn 1–2 |
| Gia đình | Đi chợ, điện nước, theo dõi tổng chi | Quỹ chung | Giai đoạn 1–2 |
| Chủ trọ (dãy trọ) | Ghi điện nước, thu tiền nhiều phòng | Hóa đơn phòng | **Giai đoạn sau** |

## 5. Luồng chính

### 5.0 Lần đầu mở app

1. **3 màn giới thiệu** (chỉ hiện lần đầu): "Chụp là ghi" → "Tự tách, tự tính" → "Trả bằng VietQR". Có nút "Bỏ qua"; màn cuối nút đổi thành "Bắt đầu".
2. **Đăng nhập**: Apple, Google hoặc số điện thoại. Có dòng "Có mã mời nhóm? Nhập mã" để vào thẳng nhóm.
3. Những lần sau mở app là vào thẳng camera.

### 5.1 Ghi một khoản chi

1. Mở app → camera (màn chính).
2. Chụp món đồ / hóa đơn / công tơ.
3. Bàn phím số bật lên ngay, **số tiền hiện thẳng trên ảnh**: gõ "30" → 30.000đ. Có hàng gợi ý nhanh (15k, 20k, 50k) và ô ghi chú trên ảnh. Không có màn nhập tiền riêng. (Sau này: AI đọc hóa đơn và điền sẵn.)
4. Bấm "Xong" → nút chụp biến thành nút gửi. Mặc định chia đều cả nhóm, chạm avatar để bỏ bớt người; nút hóa đơn để chia không đều.
5. Gửi → báo nhỏ "Đã gửi" rồi quay lại camera; khoản chi lên bảng tin + widget, số dư tự cập nhật.

Nhanh nhất 4 thao tác: **chụp → gõ số → Xong → Gửi**.

Khoản không chụp được (tiền phòng, wifi, chuyển khoản online): cho phép **ghi không cần ảnh** hoặc tạo **khoản cố định hàng tháng**.

### 5.1b Xem bảng tin và bình luận

1. Từ camera **vuốt lên** → bảng tin toàn màn hình, mỗi màn một khoản chi; vuốt tiếp để xem khoản trước.
2. Dưới mỗi ảnh: người trả, thời gian và dòng "Bạn nợ 7.500đ · chia 4".
3. Thả cảm xúc nhanh ngay trên ô bình luận.
4. **Bình luận cả nhóm cùng thấy**, trả lời theo luồng (chạm "Trả lời" dưới bình luận của từng người).
5. Thanh dưới: nút lưới (xem cả tháng), nút tròn (về camera), nút ví (Số dư).

### 5.2 Cuối tháng / cuối chuyến

1. App tính số dư từng người và **tối ưu nợ** (A nợ B 50k, B nợ C 50k → A trả thẳng C 50k).
2. Mỗi người nợ nhận mã **VietQR** có nội dung riêng, ví dụ `TRO12 MINH T11`.
3. Tiền về đúng nội dung → app tự đánh dấu đã trả và báo cả nhóm. Hoặc người nhận bấm xác nhận tay.
4. App tạo **tổng kết tháng dạng ảnh ghép** để chia sẻ.

### 5.3 Mời vào nhóm

- Gửi link mời qua Zalo/Messenger.
- Người chưa cài app vẫn mở link trên web để **xem tổng kết và quét VietQR trả tiền**. Không bắt cả nhóm cài ngay từ ngày đầu.

## 6. Phạm vi MVP

**Có trong MVP:**

- [ ]  3 màn giới thiệu (chỉ lần đầu mở app)
- [ ]  Đăng nhập: Apple, Google, số điện thoại; nhập mã mời nhóm
- [ ]  Tạo nhóm (phòng trọ / trip / gia đình), mời bằng link
- [ ]  Camera → gõ số tiền ngay trên ảnh → chọn người chia → gửi
- [ ]  Ghi khoản không cần ảnh, khoản cố định hàng tháng
- [ ]  Bảng tin vuốt lên từ camera: thả cảm xúc, bình luận cả nhóm cùng thấy, trả lời theo luồng
- [ ]  Lưới ảnh cả tháng, lọc "Của tôi" / "Có bình luận"
- [ ]  Widget màn hình chính hiện khoản chi mới nhất (iOS trước)
- [ ]  Số dư ai nợ ai + tối ưu nợ
- [ ]  Trả bằng VietQR, xác nhận tay
- [ ]  Tổng kết tháng dạng ảnh ghép
- [ ]  Trang web nhẹ cho người chưa cài app

**Chưa làm trong MVP:** AI đọc hóa đơn, tự xác nhận qua ngân hàng, quỹ chung nâng cao, tính năng chủ trọ, nhiều loại tiền tệ.

### 6.1 Giao diện MVP

[tach-ui-mvp.html](Tach%20%E2%80%94%20Product%20Doc/tach-ui-mvp.html)

**Điều hướng:** camera là màn chính → vuốt lên là bảng tin → thanh dưới có nút lưới (cả tháng), nút tròn (về camera), nút ví (Số dư).

| Màn | Nội dung chính |
| --- | --- |
| Giới thiệu 1–3 | Chụp là ghi / Tự tách, tự tính / Trả bằng VietQR; nút Bỏ qua, chấm trang, nút Tiếp theo → Bắt đầu |
| Đăng nhập | Logo, slogan; Apple, Google, số điện thoại; nhập mã mời nhóm; điều khoản |
| Camera | Mở app là chụp được ngay; chọn nhóm ở trên cùng |
| A. Vừa chụp xong | Bàn phím số bật lên, số tiền và ghi chú hiện trên ảnh, gợi ý nhanh 15k/20k/50k |
| B. Chọn người và gửi | Nút chụp thành nút gửi; mặc định cả nhóm, chạm avatar để bỏ bớt |
| C. Gửi xong | Báo nhỏ kèm số người khác nợ bạn, tự quay lại camera |
| D. Bảng tin | Mỗi màn một khoản chi, dòng "Bạn nợ …", ô bình luận + thả cảm xúc |
| E. Bình luận | Cả nhóm cùng thấy, trả lời theo luồng |
| F. Lưới cả tháng | Tất cả ảnh kèm số tiền, bộ lọc, thẻ "Bạn cần trả" |
| Số dư | Bạn cần trả ai bao nhiêu, nút "Trả" từng người, đã gộp nợ |
| Trả bằng VietQR | Bảng trượt lên: mã QR, nội dung chuyển khoản riêng, mở app ngân hàng |
| Widget | Cỡ nhỏ: ảnh khoản chi mới nhất; cỡ vừa: số tiền bạn đang nợ |

**Quyết định đã chốt:**

- Camera là màn chính; không có màn nhập tiền riêng.
- Bình luận **cả nhóm cùng thấy** (minh bạch, tránh hiểu lầm về tiền), không gửi riêng người chụp.
- Xanh bạc hà `#12A594` chỉ dùng cho nút bấm, số tiền và điểm nhấn; viền nút chụp không dùng màu vàng.
- "Đã trả" dùng xanh dương `#185FA5` với dấu tích đôi.
- Màn giới thiệu chỉ hiện ở lần mở app đầu tiên.

**Chưa vẽ:** tạo nhóm và mời qua link Zalo; tổng kết tháng dạng ảnh ghép; nhấn giữ một khoản chi (Sửa số tiền, Không phải phần mình, Xem lịch sử sửa); cài tài khoản ngân hàng; nhập mã OTP số điện thoại.

Thiết kế chỉ lưu trong Notion, không đưa vào repo code.

## 7. Kiến trúc kỹ thuật

| Thành phần | Lựa chọn | Ghi chú |
| --- | --- | --- |
| App | Flutter (iOS + Android) | Sinh viên VN phần lớn dùng Android, đừng chỉ làm iOS |
| Widget màn hình chính | Package `home_widget`  • **Swift (WidgetKit)** cho iOS, **Kotlin** cho Android | Phần tốn công nhất về kỹ thuật |
| Camera | Package `camera` | Nén ảnh 100–200KB, tạo ảnh thu nhỏ cho widget |
| Backend | **Supabase (Postgres)** — đã chốt | Dữ liệu tiền có quan hệ chặt → SQL rất hợp |
| Lưu ảnh | Cloudflare R2 hoặc storage của Supabase/Firebase | R2 thường rẻ hơn khi người dùng tải ảnh nhiều |
| Thông báo | FCM / APNs | Nhắc nợ, khoản chi mới |
| VietQR | Tạo mã theo chuẩn VietQR (NAPAS) | Chỉ tạo mã, **không giữ tiền** |
| Tự xác nhận chuyển khoản | SePay / Casso (webhook) | Giai đoạn sau |
| Trang web cho người chưa cài | Flutter Web hoặc trang web nhẹ | Xem tổng kết + quét QR |

**Nguyên tắc:**

- Lưu tiền bằng **số nguyên (VND)**, không dùng `double`.
- Mọi chỉnh sửa khoản chi đều có **lịch sử** và **thông báo** cho nhóm.
- Phân quyền (security rules / RLS) chặt: chỉ thành viên nhóm mới thấy ảnh và số liệu.

## 8. Mô hình dữ liệu

Thiết kế sẵn để **sau này thêm chủ trọ mà không phải làm lại**: nhóm có loại, nhóm lồng nhau, thành viên có vai trò, khoản chi có nguồn.

### 8.1 Bảng chính (MVP)

| Bảng | Trường chính |
| --- | --- |
| `users` | id, name, avatar, phone, bank_bin, bank_account (mã hóa), created_at |
| `groups` | id, **type** (room / trip / family / *building*), **parent_group_id** (null; dùng cho dãy trọ sau này), name, **mode** (fund / split), cover, created_by |
| `group_members` | group_id, user_id, **role** (owner / admin / member / *landlord* / guest), joined_at, left_at |
| `expenses` | id, group_id, payer_id, amount (int), note, category, photo_url, thumb_url, **source** (member / recurring / *bill*), split_type (equal / exact / shares / percent), created_by, created_at, updated_at |
| `expense_splits` | expense_id, user_id, amount (int) |
| `expense_history` | expense_id, changed_by, before (json), after (json), changed_at |
| `recurring_templates` | id, group_id, name, amount, day_of_month, split_rule |
| `settlements` | id, group_id, from_user, to_user, amount, method (vietqr / cash), transfer_code, status (pending / confirmed), confirmed_by (manual / auto), created_at |
| `reactions` | expense_id, user_id, emoji, created_at |
| `comments` | id, expense_id, user_id, **parent_id** (null; dùng cho trả lời theo luồng), text, created_at, edited_at, deleted_at. Cả nhóm cùng thấy |
| `group_invites` | code, group_id, created_by, expires_at |

### 8.2 Bảng cho giai đoạn chủ trọ (chưa làm, chỉ chừa chỗ)

| Bảng | Trường chính |
| --- | --- |
| `meter_readings` | id, room_group_id, kind (electric / water), value, photo_url, period, read_by |
| `room_bills` | id, room_group_id, period, items (json: phòng, điện, nước, wifi, rác), total, status, transfer_code |
| `announcements` | id, building_group_id, title, body, created_by, created_at |
| `announcement_reads` | announcement_id, user_id, read_at |
| `maintenance_requests` | id, room_group_id, photo_url, description, status (new / in_progress / done), created_by |
| `bill_comments` | bill_id, user_id, text, created_at |

Hóa đơn phòng (`room_bills`) khi tạo xong sẽ đổ vào nhóm chia tiền của phòng thành một `expense` có `source = bill`.

### 8.3 Tối ưu nợ

1. Tính số dư ròng mỗi người = tổng đã trả − tổng phần phải chịu.
2. Tách hai danh sách: người dương (được nhận) và người âm (phải trả).
3. Lặp: ghép người nợ nhiều nhất với người được nhận nhiều nhất, chuyển `min(nợ, nhận)`, cập nhật, lặp đến khi hết.

Cách tham lam này cho số lần chuyển khoản ≤ n − 1, đủ tốt cho nhóm nhỏ.

## 9. Tính năng chủ trọ (giai đoạn sau)

### 9.1 Báo điện nước — rất khả thi, nên làm

1. Chủ trọ hoặc người thuê **chụp ảnh công tơ** từng phòng.
2. AI đọc số, người chụp xác nhận.
3. App tính (số mới − số cũ) × đơn giá + tiền phòng, wifi, rác → **hóa đơn từng phòng**.
4. Gửi hóa đơn kèm **ảnh công tơ** và **VietQR**.
5. Tiền về đúng nội dung → tự đánh dấu đã trả.
6. Hóa đơn tự đổ vào nhóm chia tiền của người ở chung.

Mô hình B2B2C: **một chủ trọ mang đến 10–50 người dùng**, và chủ trọ là người có khả năng trả phí.

<aside>
⚖️

Có quy định về giá điện bán cho người thuê trọ. App làm mọi thứ minh bạch có thể khiến một số chủ trọ ngại dùng. **Cần tìm hiểu kỹ quy định hiện hành** trước khi làm phần này, và biến sự minh bạch thành lợi thế ("khu trọ minh bạch, dễ cho thuê").

</aside>

### 9.2 Nhóm chat — không làm, thay bằng giao tiếp có cấu trúc

Không xây chat chung vì sẽ cạnh tranh với Zalo, nơi người dùng đã quen; chat cũng là sản phẩm tốn kém nhất để làm tốt (thông báo, đã đọc, media, offline, kiểm duyệt).

| Thay bằng | Vì sao tốt hơn chat |
| --- | --- |
| Thông báo của chủ trọ, có hiển thị ai đã xem | Tin quan trọng không bị trôi |
| Báo hỏng hóc: chụp ảnh, theo dõi trạng thái *đã nhận → đang sửa → xong* | Có lịch sử, không bị quên |
| Bình luận dưới từng hóa đơn | Thắc mắc gắn đúng hóa đơn |
| Nút chia sẻ sang Zalo | Tận dụng Zalo thay vì đối đầu |

## 10. Lộ trình

| Giai đoạn | Thời gian | Mục tiêu | Việc chính |
| --- | --- | --- | --- |
| 0. Kiểm chứng | 2–3 tuần | Biết người dùng có thật sự cần không | 5–10 phòng trọ dùng Google Sheet + nhóm Zalo do mình vận hành tay; tổng kết + QR cuối tháng |
| 1. MVP | 6–8 tuần | Ra app cho đúng ngách sinh viên ở ghép | Các mục ở phần 6 |
| 2. Mở rộng | Sau khi giữ chân tốt | Trip, gia đình, tăng tốc ghi chép | AI đọc hóa đơn, quỹ chung, tự xác nhận chuyển khoản |
| 3. Chủ trọ | Khi có nền người dùng | B2B2C, doanh thu | Điện nước, hóa đơn phòng, thông báo, báo hỏng |

## 11. Đo lường

- **Chỉ số chính:** % nhóm còn ghi chi tiêu sau 4 tuần.
- Thời gian trung bình để ghi một khoản (mục tiêu < 5 giây).
- Số khoản ghi / nhóm / tuần.
- % khoản nợ được thanh toán qua VietQR.
- Số lượt chia sẻ tổng kết tháng, số người mới đến từ link mời.

## 12. Tiếp cận người dùng

- Video TikTok/Reels: "cuối tháng ở ghép cãi nhau vì tiền điện".
- Group tìm phòng trọ, group sinh viên của từng trường trên Facebook.
- Đại sứ ở ký túc xá, khu trọ (đổi lại dùng bản trả phí miễn phí).
- Tổng kết tháng dạng ảnh ghép để người dùng tự khoe.

## 13. Kiếm tiền

- **Freemium:** AI đọc hóa đơn, xuất báo cáo, lưu ảnh lâu hơn, nhiều nhóm hơn → trả phí.
- **Chủ trọ trả phí** theo số phòng (giai đoạn 3).
- Quảng cáo nhẹ (cân nhắc, tránh làm hỏng trải nghiệm).

## 14. Rủi ro & cách giảm

| Rủi ro | Cách giảm |
| --- | --- |
| Hiệu ứng mạng lưới: một người không cài là cả nhóm bỏ | Link mời + trang web cho người chưa cài |
| Người dùng lười ghi chép | Camera-first, bàn phím số to, widget, mặc định chia đều |
| Ảnh không cho biết giá | Bước nhập tiền cực nhanh; AI đọc hóa đơn ở giai đoạn 2 |
| Mâu thuẫn khi sửa khoản của người khác | Lịch sử chỉnh sửa + thông báo |
| Chi phí lưu ảnh | Nén mạnh, ảnh thu nhỏ, chỉ giữ ảnh gốc 3–6 tháng, dùng R2 |
| Đồng bộ, offline, sửa cùng lúc | Ghi offline rồi đồng bộ; xung đột giải bằng lịch sử |
| Widget phải viết native | Làm iOS trước, Android sau |
| Pháp lý thanh toán | **Không giữ tiền hộ**; chỉ tạo VietQR để chuyển trực tiếp |
| Dữ liệu cá nhân | Mã hóa số tài khoản, ảnh chỉ trong nhóm; tìm hiểu Nghị định 13/2023 về bảo vệ dữ liệu cá nhân |

## 15. Câu hỏi còn mở

- [x]  Tên app: **Tach** (logo và nhận diện đang phác thảo)
- [x]  Backend: **Supabase**
- [x]  Đăng nhập: Apple, Google và số điện thoại (số điện thoại tốn phí SMS OTP, có thể bật sau)
- [x]  Màu chính: **xanh bạc hà** `#12A594`
- [ ]  Quỹ chung có cần ngay trong MVP cho phòng trọ không? (kiểm chứng ở giai đoạn 0)
- [ ]  Ảnh có bắt buộc không, hay chỉ khuyến khích?
- [ ]  Giới hạn bản miễn phí ở đâu cho hợp lý?
- [ ]  Quy định hiện hành về giá điện cho người thuê trọ?