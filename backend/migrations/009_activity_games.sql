-- =====================================================================
-- 009 – Kho hoạt động: 136 trò chơi cho trẻ 0-36 tháng (kèm ảnh)
-- Sinh tự động bởi scripts/activity-games/build.py từ games.jsonl. Không sửa tay.
-- Ảnh: backend/static/activities/gNNN/ (phục vụ ở /static/activities/...).
-- Trò chơi có ghi chú 'uncertain' (scan thiếu / sách in nhầm) để status = 'draft'.
-- =====================================================================

-- g001: Massage cho bé (trang PDF 37, 38)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'Massage cho bé', 'Kỹ năng phát triển: Khả năng nhận thức cơ thể, Kích thích xúc giác, Xoa dịu cảm xúc.', '**Kỹ năng phát triển:** Khả năng nhận thức cơ thể, Kích thích xúc giác, Xoa dịu cảm xúc

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ được massage luân phiên ở tư thế nằm ngửa và nằm sấp.
- **Đồ dùng:** Một chai sữa dưỡng thể cho bé.

## Các bước thực hiện
1. Sau khi tắm cho trẻ xong, bố mẹ đặt trẻ vào nôi. Thoa kem dưỡng ẩm lên cả hai tay, ôm đầu và từ từ xoa bóp da đầu, trán, mặt và mũi cho trẻ.
2. Giữ cánh tay của trẻ, sau đó massage nhẹ nhàng ở hai bên theo thứ tự từ vai đến ngón tay, từ ngoài cánh tay vào trong cánh tay. Thực hiện theo nguyên tắc tương tự đối với chân của trẻ, từ đùi đến ngón chân.
3. Từ từ chạm vào bụng trẻ từ trên xuống dưới và xoa bóp theo chiều kim đồng hồ.
4. Giữ đầu và giúp trẻ nằm sấp. Bắt đầu từ cổ, xoa bóp đến cột sống của trẻ từ trên xuống dưới. Sau đó, xoa lưng cho trẻ từ giữa sang hai bên.

## Hướng dẫn của chuyên gia
- Không nên thực hiện massage khi trẻ đói hoặc vừa mới bú xong.
- Làm ấm bàn tay của bạn trước khi chạm vào trẻ và dùng lực nhẹ nhàng. Có thể đồng thời massage, xoa, ấn nhẹ hoặc bất cứ hành động nào khiến trẻ thoải mái nhất.
- Các bộ phận trên cơ thể trẻ có độ nhạy cảm khác nhau khi chạm vào. Hãy chú ý đến phản ứng của trẻ khi massage. Khi biểu cảm của trẻ thoải mái hoặc trẻ mỉm cười, điều đó có nghĩa là trẻ thích sự vuốt ve của bố mẹ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi cảm giác._', 'play', 0, 3,
       'Một chai sữa dưỡng thể cho bé.', ARRAY['Một chai sữa dưỡng thể cho bé']::text[], '/static/activities/g001/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức cơ thể, Kích thích xúc giác, Xoa dịu cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 1, 'Sau khi tắm cho trẻ xong, bố mẹ đặt trẻ vào nôi. Thoa kem dưỡng ẩm lên cả hai tay, ôm đầu và từ từ xoa bóp da đầu, trán, mặt và mũi cho trẻ.', '/static/activities/g001/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 2, 'Giữ cánh tay của trẻ, sau đó massage nhẹ nhàng ở hai bên theo thứ tự từ vai đến ngón tay, từ ngoài cánh tay vào trong cánh tay. Thực hiện theo nguyên tắc tương tự đối với chân của trẻ, từ đùi đến ngón chân.', '/static/activities/g001/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 3, 'Từ từ chạm vào bụng trẻ từ trên xuống dưới và xoa bóp theo chiều kim đồng hồ.', '/static/activities/g001/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 4, 'Giữ đầu và giúp trẻ nằm sấp. Bắt đầu từ cổ, xoa bóp đến cột sống của trẻ từ trên xuống dưới. Sau đó, xoa lưng cho trẻ từ giữa sang hai bên.', '/static/activities/g001/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'image', '/static/activities/g001/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'image', '/static/activities/g001/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'image', '/static/activities/g001/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'image', '/static/activities/g001/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7bfcceca-66ba-5d97-91c6-a6cb31ee248c', 'image', '/static/activities/g001/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '7bfcceca-66ba-5d97-91c6-a6cb31ee248c', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g002: Đuổi bắt thẻ bài (trang PDF 39)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '110a56c8-7f7d-511a-81c2-bc0daa349b9f', 'Đuổi bắt thẻ bài', 'Bố mẹ có thể nhẹ nhàng gọi tên trẻ để thu hút sự chú ý của trẻ. Đồng thời, ngừng nói khi trẻ nhìn vào thẻ, để trẻ tập trung quan sát và nhìn theo.', '**Kỹ năng phát triển:** Năng lực quan sát, Khả năng theo dõi trực quan, Tính linh hoạt của chuyển động quay đầu

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một số thẻ trực quan (thẻ đen trắng, thẻ đỏ, thẻ vàng, thẻ xanh dương, thẻ xanh lá đều được chấp nhận).

## Các bước thực hiện
1. Khi trẻ được gần 1 tháng tuổi, có thể cho trẻ nằm trên giường. Bố mẹ đặt tấm thẻ đen trắng cách mắt bé từ 20 - 30 cm và lắc nhẹ để thu hút sự chú ý của bé.
2. Sau khi trẻ nhìn vào thẻ, bạn có thể từ từ di chuyển thẻ theo thứ tự: từ giữa → phải → giữa → trái → giữa và lặp lại vài lần như thế.

## Hướng dẫn của chuyên gia
- Lúc đầu, di chuyển thẻ theo chiều ngang từ trái sang phải một cách chậm rãi. Khi trẻ chú ý hơn đến các thẻ bài, bạn có thể thay đổi hướng đa dạng hơn, chẳng hạn như nhìn thẳng vào thẻ theo hướng lên xuống, nhìn thẻ theo hướng tròn,... và tăng dần độ khó.
- Đối với trẻ trên 3 tháng tuổi, bạn có thể dùng thẻ màu để phát triển khả năng nhận biết màu sắc của trẻ.

> Bố mẹ có thể nhẹ nhàng gọi tên trẻ để thu hút sự chú ý của trẻ. Đồng thời, ngừng nói khi trẻ nhìn vào thẻ, để trẻ tập trung quan sát và nhìn theo.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 0, 3,
       'Một số thẻ trực quan (thẻ đen trắng, thẻ đỏ, thẻ vàng, thẻ xanh dương, thẻ xanh lá đều được chấp nhận).', ARRAY['Một số thẻ trực quan (thẻ đen trắng', 'thẻ đỏ', 'thẻ vàng', 'thẻ xanh dương', 'thẻ xanh lá đều được chấp nhận)']::text[], '/static/activities/g002/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Năng lực quan sát, Khả năng theo dõi trực quan, Tính linh hoạt của chuyển động quay đầu.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('110a56c8-7f7d-511a-81c2-bc0daa349b9f', 1, 'Khi trẻ được gần 1 tháng tuổi, có thể cho trẻ nằm trên giường. Bố mẹ đặt tấm thẻ đen trắng cách mắt bé từ 20 - 30 cm và lắc nhẹ để thu hút sự chú ý của bé.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('110a56c8-7f7d-511a-81c2-bc0daa349b9f', 2, 'Sau khi trẻ nhìn vào thẻ, bạn có thể từ từ di chuyển thẻ theo thứ tự: từ giữa → phải → giữa → trái → giữa và lặp lại vài lần như thế.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('110a56c8-7f7d-511a-81c2-bc0daa349b9f', 'image', '/static/activities/g002/main.jpg', 'Bố mẹ có thể nhẹ nhàng gọi tên trẻ để thu hút sự chú ý của trẻ. Đồng thời, ngừng nói khi trẻ nhìn vào thẻ, để trẻ tập trung quan sát và nhìn theo.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '110a56c8-7f7d-511a-81c2-bc0daa349b9f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g003: Âm thanh đến từ đâu? (trang PDF 40)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'd4b18848-52fa-5f2a-84a0-1e28fc39f287', 'Âm thanh đến từ đâu?', 'Trẻ có thể đạt được khả năng tập trung thính giác khoảng một tháng sau khi sinh. Bố mẹ có thể nói chuyện với trẻ nhiều hơn để phát triển khả năng tập trung lắng nghe của trẻ.', '**Kỹ năng phát triển:** Khả năng nghe, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một chiếc lục lạc hoặc đồ chơi có nhạc.

## Các bước thực hiện
1. Khi trẻ nhìn bố mẹ, bố mẹ có thể nói chuyện với trẻ bằng những âm thanh yêu thương như “a” và “ô”... để trẻ làm quen với giọng nói của người thân yêu trong gia đình và tạo cảm giác vui vẻ, an toàn về mặt tâm lý. Hãy thì thầm vào tai trẻ để thu hút trẻ, giúp trẻ cảm nhận được âm thanh và hướng mà âm thanh phát ra.
2. Bố mẹ cũng có thể sử dụng lục lạc hoặc đồ chơi phát nhạc để tạo ra âm thanh, cách tai trẻ 10 - 20 cm để trẻ cảm nhận âm thanh và khi trẻ được khoảng 3 tháng tuổi, trẻ có thể quay đầu về phía nguồn âm thanh đó.
3. Nếu trẻ lần theo âm thanh và tìm thấy đồ chơi, bố mẹ hãy ngay lập tức mỉm cười và khẳng định với trẻ. Sau đó, đặt đồ chơi theo các hướng khác nhau và tạo ra âm thanh, để trẻ tiếp tục tìm kiếm nguồn phát ra âm thanh.

## Hướng dẫn của chuyên gia
- Nếu trẻ hoàn toàn không thể theo dõi được nguồn âm thanh, trước tiên bạn có thể cho trẻ nhìn mặt người nói hoặc đồ chơi phát ra âm thanh, sau đó từ từ di chuyển khuôn mặt hoặc đồ chơi đó để hướng dẫn trẻ quay đầu theo nguồn âm thanh.
- Khi trẻ đang ngủ, nếu đột ngột bị đánh thức bởi tiếng động và bắt đầu khóc, bố mẹ có thể dùng giọng nói nhẹ nhàng để xoa dịu cảm xúc của trẻ.

> Trẻ có thể đạt được khả năng tập trung thính giác khoảng một tháng sau khi sinh. Bố mẹ có thể nói chuyện với trẻ nhiều hơn để phát triển khả năng tập trung lắng nghe của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Một chiếc lục lạc hoặc đồ chơi có nhạc.', ARRAY['Một chiếc lục lạc hoặc đồ chơi có nhạc']::text[], '/static/activities/g003/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nghe, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d4b18848-52fa-5f2a-84a0-1e28fc39f287', 1, 'Khi trẻ nhìn bố mẹ, bố mẹ có thể nói chuyện với trẻ bằng những âm thanh yêu thương như “a” và “ô”... để trẻ làm quen với giọng nói của người thân yêu trong gia đình và tạo cảm giác vui vẻ, an toàn về mặt tâm lý. Hãy thì thầm vào tai trẻ để thu hút trẻ, giúp trẻ cảm nhận được âm thanh và hướng mà âm thanh phát ra.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d4b18848-52fa-5f2a-84a0-1e28fc39f287', 2, 'Bố mẹ cũng có thể sử dụng lục lạc hoặc đồ chơi phát nhạc để tạo ra âm thanh, cách tai trẻ 10 - 20 cm để trẻ cảm nhận âm thanh và khi trẻ được khoảng 3 tháng tuổi, trẻ có thể quay đầu về phía nguồn âm thanh đó.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d4b18848-52fa-5f2a-84a0-1e28fc39f287', 3, 'Nếu trẻ lần theo âm thanh và tìm thấy đồ chơi, bố mẹ hãy ngay lập tức mỉm cười và khẳng định với trẻ. Sau đó, đặt đồ chơi theo các hướng khác nhau và tạo ra âm thanh, để trẻ tiếp tục tìm kiếm nguồn phát ra âm thanh.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('d4b18848-52fa-5f2a-84a0-1e28fc39f287', 'image', '/static/activities/g003/main.jpg', 'Trẻ có thể đạt được khả năng tập trung thính giác khoảng một tháng sau khi sinh. Bố mẹ có thể nói chuyện với trẻ nhiều hơn để phát triển khả năng tập trung lắng nghe của trẻ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'd4b18848-52fa-5f2a-84a0-1e28fc39f287', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g004: Chiếc khăn hạnh phúc (trang PDF 41)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b32990cf-32c8-5f8b-99a3-26d4143374c5', 'Chiếc khăn hạnh phúc', 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Cảm giác an toàn.', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Cảm giác an toàn

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một khăn tắm lớn.

## Các bước thực hiện
1. Bố mẹ nắm lấy hai góc của chiếc khăn tắm và tạo thành một “chiếc võng”, đặt trẻ nằm ngửa ở giữa chiếc khăn, rồi nhẹ nhàng đu qua đu lại. Trong khi đu đưa, hãy tương tác với trẻ bằng một nụ cười để mang lại cho trẻ cảm giác an toàn vừa đủ.
2. Ngừng đu đưa, giữ yên một bên của chiếc khăn tắm, nâng bên còn lại lên và từ từ lật trẻ về tư thế nằm sấp, sau đó trở về tư thế nằm ngửa và lần lượt lật sang hai bên.

## Hướng dẫn của chuyên gia
- Khi đu đưa, chú ý điểm thấp nhất phải cách mặt đất khoảng 35 - 40 cm.
- Bố mẹ nên chú ý đến phản ứng của trẻ, không dùng lực quá mạnh hoặc lắc nhanh để tránh trẻ bị trượt.
- Khi trẻ căng thẳng hoặc quấy khóc, bố mẹ nên giảm cường độ lắc lư hoặc dừng lại để dỗ dành. Sau đó, bắt đầu đu đưa với biên độ nhỏ hơn để trẻ thích nghi dần dần.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Một khăn tắm lớn.', ARRAY['Một khăn tắm lớn']::text[], '/static/activities/g004/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Cảm giác an toàn.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b32990cf-32c8-5f8b-99a3-26d4143374c5', 1, 'Bố mẹ nắm lấy hai góc của chiếc khăn tắm và tạo thành một “chiếc võng”, đặt trẻ nằm ngửa ở giữa chiếc khăn, rồi nhẹ nhàng đu qua đu lại. Trong khi đu đưa, hãy tương tác với trẻ bằng một nụ cười để mang lại cho trẻ cảm giác an toàn vừa đủ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b32990cf-32c8-5f8b-99a3-26d4143374c5', 2, 'Ngừng đu đưa, giữ yên một bên của chiếc khăn tắm, nâng bên còn lại lên và từ từ lật trẻ về tư thế nằm sấp, sau đó trở về tư thế nằm ngửa và lần lượt lật sang hai bên.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b32990cf-32c8-5f8b-99a3-26d4143374c5', 'image', '/static/activities/g004/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b32990cf-32c8-5f8b-99a3-26d4143374c5', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g005: Tư thế nằm sấp mỗi ngày (trang PDF 42)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b5efa029-54b0-50ed-aa36-1a2b9efc06d9', 'Tư thế nằm sấp mỗi ngày', 'Hãy để trẻ nằm sấp mỗi ngày một lần và biến thời gian nằm sấp trở thành một phần thường xuyên trong cuộc sống.', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Cảm giác về không gian, Sức mạnh phần thân trên

## Chuẩn bị
- **Không gian:** Giường, ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một cái lục lạc.

## Các bước thực hiện
1. Bố mẹ dùng gối hoặc đệm để đỡ đầu, cổ, lưng và cho trẻ nằm sấp. Bố mẹ đỡ trẻ đối diện với mình để mang lại cho trẻ cảm giác an toàn vừa đủ.
2. Để trẻ nằm trong lòng bố mẹ, dùng tay chạm nhẹ vào lưng và mông của trẻ để trẻ cảm thấy bình tĩnh và thoải mái.
3. Dùng tay đỡ bụng và chân trẻ, để trẻ nằm trên tay bố mẹ và đu đưa trẻ nhẹ nhàng, nhịp nhàng.

## Hướng dẫn của chuyên gia
- Thời gian nằm sấp có thể được lồng ghép vào các hoạt động hằng ngày của bé như thay tã, tắm rửa, vui chơi.
- Khi trẻ lớn lên, thời gian nằm sấp có thể kéo dài từng chút một. Khả năng hoạt động của trẻ cũng sẽ ngày càng tốt hơn, đầu có thể dần dần được nâng lên và giữ lâu hơn. Một chiếc lục lạc cũng có thể đặt trước mặt trẻ để thu hút trẻ nhìn lên.

> Hãy để trẻ nằm sấp mỗi ngày một lần và biến thời gian nằm sấp trở thành một phần thường xuyên trong cuộc sống.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Một cái lục lạc.', ARRAY['Một cái lục lạc']::text[], '/static/activities/g005/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Cảm giác về không gian, Sức mạnh phần thân trên.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b5efa029-54b0-50ed-aa36-1a2b9efc06d9', 1, 'Bố mẹ dùng gối hoặc đệm để đỡ đầu, cổ, lưng và cho trẻ nằm sấp. Bố mẹ đỡ trẻ đối diện với mình để mang lại cho trẻ cảm giác an toàn vừa đủ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b5efa029-54b0-50ed-aa36-1a2b9efc06d9', 2, 'Để trẻ nằm trong lòng bố mẹ, dùng tay chạm nhẹ vào lưng và mông của trẻ để trẻ cảm thấy bình tĩnh và thoải mái.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b5efa029-54b0-50ed-aa36-1a2b9efc06d9', 3, 'Dùng tay đỡ bụng và chân trẻ, để trẻ nằm trên tay bố mẹ và đu đưa trẻ nhẹ nhàng, nhịp nhàng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b5efa029-54b0-50ed-aa36-1a2b9efc06d9', 'image', '/static/activities/g005/main.jpg', 'Hãy để trẻ nằm sấp mỗi ngày một lần và biến thời gian nằm sấp trở thành một phần thường xuyên trong cuộc sống.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b5efa029-54b0-50ed-aa36-1a2b9efc06d9', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g006: Hát cho con nghe (trang PDF 43)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '6c9a788a-d79b-5278-aaee-1f4b374c852e', 'Hát cho con nghe', 'Kỹ năng phát triển: Khả năng nghe, Khả năng cảm nhận nhịp điệu của âm thanh, Khả năng xúc giác, Kỹ năng xã hội.', '**Kỹ năng phát triển:** Khả năng nghe, Khả năng cảm nhận nhịp điệu của âm thanh, Khả năng xúc giác, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Nhẩm hát cho trẻ nghe một số bài hát thiếu nhi quen thuộc như “Một con vịt”, “Cả nhà thương nhau”,...
2. Trong khi hát, bạn vỗ nhẹ cơ thể trẻ theo nhịp của bài hát.

## Lời bài hát / đồng dao
Cả nhà thương nhau (Nhạc sỹ: Phan Văn Minh)
Ba thương con vì con giống mẹ
Mẹ thương con vì con giống cha
Cả nhà ta cùng thương yêu nhau
Xa là nhớ gần nhau là cười.

Lưu ý: Bố mẹ có thể hướng dẫn bé thực hiện một số động tác tương ứng theo lời bài hát. Ví dụ: Khi nghe “gần nhau là cười” thì bạn có thể mỉm cười với trẻ để trẻ cười theo.

## Hướng dẫn của chuyên gia
- Bố mẹ không nên hát quá to hoặc kéo dài quá lâu mỗi lần chơi trò hát cho con nghe.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Không có.', NULL, '/static/activities/g006/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nghe, Khả năng cảm nhận nhịp điệu của âm thanh, Khả năng xúc giác, Kỹ năng xã hội.', true, 'Cả nhà thương nhau (Nhạc sỹ: Phan Văn Minh)
Ba thương con vì con giống mẹ
Mẹ thương con vì con giống cha
Cả nhà ta cùng thương yêu nhau
Xa là nhớ gần nhau là cười.

Lưu ý: Bố mẹ có thể hướng dẫn bé thực hiện một số động tác tương ứng theo lời bài hát. Ví dụ: Khi nghe “gần nhau là cười” thì bạn có thể mỉm cười với trẻ để trẻ cười theo.';
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6c9a788a-d79b-5278-aaee-1f4b374c852e', 1, 'Nhẩm hát cho trẻ nghe một số bài hát thiếu nhi quen thuộc như “Một con vịt”, “Cả nhà thương nhau”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6c9a788a-d79b-5278-aaee-1f4b374c852e', 2, 'Trong khi hát, bạn vỗ nhẹ cơ thể trẻ theo nhịp của bài hát.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('6c9a788a-d79b-5278-aaee-1f4b374c852e', 'image', '/static/activities/g006/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '6c9a788a-d79b-5278-aaee-1f4b374c852e', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g007: Quả bóng lắc lư (trang PDF 44)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e3264e27-8bed-5cdf-9a80-452521c03e3d', 'Quả bóng lắc lư', 'Động tác lăn bóng phải nhẹ nhàng và chậm rãi. Bố mẹ phải luôn chú ý đến biểu cảm của trẻ, khi con cong mồi và khóc, bố mẹ nên ngừng chuyển động quả bóng hoặc bế trẻ lên để dỗ dành.', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Sức mạnh phần thân trên

## Chuẩn bị
- **Không gian:** Trên thảm trải sàn hoặc trên sàn nhà.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một quả bóng gai hoặc quả bóng thể dục.

## Các bước thực hiện
1. Để trẻ nằm trên quả bóng lớn, dùng hai tay giữ nách trẻ và dùng cẳng tay nhẹ nhàng ôm ngực trẻ.
2. Nhẹ nhàng ấn trẻ xuống để trẻ và quả bóng tiếp xúc sát với nhau, đồng thời lăn bé và quả bóng về phía trước, phía sau, qua trái, qua phải, khoảng 10 lần theo mỗi hướng.
3. Sau khi trẻ đã quen, bố mẹ có thể thử lăn quả bóng theo mọi hướng.

## Hướng dẫn của chuyên gia
- Bố mẹ cần luôn giữ nách trẻ và đảm bảo trẻ bám chặt vào quả bóng mà không bị trượt xuống.
- Chọn quả bóng có đường kính lớn nhưng chưa căng hết cỡ để giúp trẻ nằm thoải mái hơn.
- Không nên thực hiện hoạt động này trong vòng một giờ sau khi trẻ bú sữa, để tránh bị trớ.

> Động tác lăn bóng phải nhẹ nhàng và chậm rãi. Bố mẹ phải luôn chú ý đến biểu cảm của trẻ, khi con cong mồi và khóc, bố mẹ nên ngừng chuyển động quả bóng hoặc bế trẻ lên để dỗ dành.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Một quả bóng gai hoặc quả bóng thể dục.', ARRAY['Một quả bóng gai hoặc quả bóng thể dục']::text[], '/static/activities/g007/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Sức mạnh phần thân trên.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e3264e27-8bed-5cdf-9a80-452521c03e3d', 1, 'Để trẻ nằm trên quả bóng lớn, dùng hai tay giữ nách trẻ và dùng cẳng tay nhẹ nhàng ôm ngực trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e3264e27-8bed-5cdf-9a80-452521c03e3d', 2, 'Nhẹ nhàng ấn trẻ xuống để trẻ và quả bóng tiếp xúc sát với nhau, đồng thời lăn bé và quả bóng về phía trước, phía sau, qua trái, qua phải, khoảng 10 lần theo mỗi hướng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e3264e27-8bed-5cdf-9a80-452521c03e3d', 3, 'Sau khi trẻ đã quen, bố mẹ có thể thử lăn quả bóng theo mọi hướng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e3264e27-8bed-5cdf-9a80-452521c03e3d', 'image', '/static/activities/g007/main.jpg', 'Động tác lăn bóng phải nhẹ nhàng và chậm rãi. Bố mẹ phải luôn chú ý đến biểu cảm của trẻ, khi con cong mồi và khóc, bố mẹ nên ngừng chuyển động quả bóng hoặc bế trẻ lên để dỗ dành.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e3264e27-8bed-5cdf-9a80-452521c03e3d', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g008: Chiếc bình ma thuật (trang PDF 45)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'a9c48905-5c28-59f1-a79e-41c5f9b842a3', 'Chiếc bình ma thuật', 'Nếu trẻ thích thú khi nhìn vào chai đậu đỏ, bố mẹ có thể cho bé chạm tay vào chai và hướng dẫn trẻ mở bàn tay nhỏ bé của mình ra.', '**Kỹ năng phát triển:** Khả năng theo dõi trực quan, Khả năng nghe

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một chai nhựa trong suốt cỡ nhỏ, một nắm hạt đỗ (đậu).

## Các bước thực hiện
1. Rửa sạch và lau khô chai nhựa, đổ khoảng một nửa số hạt đỗ (đậu) vào chai và đậy nắp lại.
2. Giữ khoảng cách chai nhựa đỏ cách mắt trẻ khoảng 20 - 30 cm để thu hút sự chú ý của trẻ.
3. Sau khi trẻ nhìn vào chai, bố mẹ hãy từ từ xoay bình 360 độ để trẻ có thể quan sát những hạt đỗ (đậu) chuyển động chậm rãi trong bình.

## Hướng dẫn của chuyên gia
- Những hạt đỗ (đậu) trong chai có thể được thay thế bằng những vật dụng khác, nhưng số lượng cần được kiểm soát, để đảm bảo các vật dụng có thể di chuyển dễ dàng trong chai.

> Nếu trẻ thích thú khi nhìn vào chai đậu đỏ, bố mẹ có thể cho bé chạm tay vào chai và hướng dẫn trẻ mở bàn tay nhỏ bé của mình ra.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 0, 3,
       'Một chai nhựa trong suốt cỡ nhỏ, một nắm hạt đỗ (đậu).', ARRAY['Một chai nhựa trong suốt cỡ nhỏ', 'một nắm hạt đỗ (đậu)']::text[], '/static/activities/g008/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng theo dõi trực quan, Khả năng nghe.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9c48905-5c28-59f1-a79e-41c5f9b842a3', 1, 'Rửa sạch và lau khô chai nhựa, đổ khoảng một nửa số hạt đỗ (đậu) vào chai và đậy nắp lại.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9c48905-5c28-59f1-a79e-41c5f9b842a3', 2, 'Giữ khoảng cách chai nhựa đỏ cách mắt trẻ khoảng 20 - 30 cm để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9c48905-5c28-59f1-a79e-41c5f9b842a3', 3, 'Sau khi trẻ nhìn vào chai, bố mẹ hãy từ từ xoay bình 360 độ để trẻ có thể quan sát những hạt đỗ (đậu) chuyển động chậm rãi trong bình.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('a9c48905-5c28-59f1-a79e-41c5f9b842a3', 'image', '/static/activities/g008/main.jpg', 'Nếu trẻ thích thú khi nhìn vào chai đậu đỏ, bố mẹ có thể cho bé chạm tay vào chai và hướng dẫn trẻ mở bàn tay nhỏ bé của mình ra.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'a9c48905-5c28-59f1-a79e-41c5f9b842a3', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g009: Dùng chân đá, đá, đá... (trang PDF 46)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'eccde27a-f919-5c92-836b-7f43edf10c43', 'Dùng chân đá, đá, đá...', 'Chiều cao ban đầu khi nâng hoặc treo bóng bay nên thấp hơn để trẻ có thể dễ dàng với tới. Khi khả năng của trẻ phát triển, hãy tăng dần chiều cao của bóng bay.', '**Kỹ năng phát triển:** Khả năng vận động thô, Phối hợp giữa mắt và chân

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một quả bóng bay màu hồng, đỏ,...

## Các bước thực hiện
1. Thổi bóng và buộc nó bằng một sợi dây.
2. Dùng quả bóng chạm nhẹ vào chân trẻ, sau đó nhấc quả bóng lên và hướng dẫn trẻ đá vào quả bóng.
3. Nếu trẻ không đá được bóng bay, bố mẹ có thể treo quả bóng bay trên chân trẻ và cầm chân trẻ đá vào quả bóng bay. Sau khi lặp lại nhiều lần, hãy đợi trẻ tự mình đá quả bóng bay.

## Hướng dẫn của chuyên gia
- Bạn cần chọn những quả bóng có chất lượng tốt, khó vỡ để đảm bảo an toàn. Bạn cũng có thể chọn những quả bóng khác có âm thanh to và nhẹ.
- Bóng bay có thể treo ở nhiều vị trí khác nhau để hướng dẫn trẻ đá bóng từ các vị trí khác nhau. Nếu vị trí treo nằm trong tầm tay và bàn chân của trẻ, bạn có thể hướng dẫn tay và chân của trẻ hoạt động cùng lúc.

> Chiều cao ban đầu khi nâng hoặc treo bóng bay nên thấp hơn để trẻ có thể dễ dàng với tới. Khi khả năng của trẻ phát triển, hãy tăng dần chiều cao của bóng bay.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 0, 3,
       'Một quả bóng bay màu hồng, đỏ,...', ARRAY['Một quả bóng bay màu hồng', 'đỏ,']::text[], '/static/activities/g009/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng vận động thô, Phối hợp giữa mắt và chân.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eccde27a-f919-5c92-836b-7f43edf10c43', 1, 'Thổi bóng và buộc nó bằng một sợi dây.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eccde27a-f919-5c92-836b-7f43edf10c43', 2, 'Dùng quả bóng chạm nhẹ vào chân trẻ, sau đó nhấc quả bóng lên và hướng dẫn trẻ đá vào quả bóng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eccde27a-f919-5c92-836b-7f43edf10c43', 3, 'Nếu trẻ không đá được bóng bay, bố mẹ có thể treo quả bóng bay trên chân trẻ và cầm chân trẻ đá vào quả bóng bay. Sau khi lặp lại nhiều lần, hãy đợi trẻ tự mình đá quả bóng bay.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('eccde27a-f919-5c92-836b-7f43edf10c43', 'image', '/static/activities/g009/main.jpg', 'Chiều cao ban đầu khi nâng hoặc treo bóng bay nên thấp hơn để trẻ có thể dễ dàng với tới. Khi khả năng của trẻ phát triển, hãy tăng dần chiều cao của bóng bay.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'eccde27a-f919-5c92-836b-7f43edf10c43', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g010: Di chuyển bàn tay nhỏ bé (trang PDF 47)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3baf1128-345a-51eb-bed5-80a14ab5c391', 'Di chuyển bàn tay nhỏ bé', 'Kỹ năng phát triển: Khả năng nắm tay, Khả năng xúc giác.', '**Kỹ năng phát triển:** Khả năng nắm tay, Khả năng xúc giác

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một chiếc lục lạc, một bàn chải xúc giác.

## Các bước thực hiện
1. Dùng đầu ngón tay của bạn chà và xoa bóp mu bàn tay của bé từ đầu ngón tay đến cổ tay.
2. Vỗ nhẹ vào mu bàn tay của trẻ để khuyến khích lòng bàn tay của trẻ thả lỏng rồi từ từ mở ra. Nếu trẻ vẫn chưa thả lỏng được thì dùng bàn chải xúc giác chạm vào mu bàn tay của trẻ rồi nhẹ nhàng di chuyển về phía cổ tay.
3. Sau khi tay trẻ thả lỏng, bố mẹ nhẹ nhàng đặt lục lạc vào tay trẻ và nói: “Con yêu, nắm lấy nào!” Bạn hướng dẫn trẻ cầm tay cầm của chiếc lục lạc.

## Hướng dẫn của chuyên gia
- Trò chơi này có thể chơi khi bé được gần 2 tháng tuổi. Trong quá trình chơi, bố mẹ nên vuốt nhẹ mu bàn tay của trẻ, tập trung hướng dẫn trẻ mở và cầm, nắm.
- Trước khi cho trẻ cầm đồ chơi, bạn có thể xoay chiếc lục lạc cách mắt trẻ khoảng 25 cm để trẻ có thể nhìn và nghe thấy.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 0, 3,
       'Một chiếc lục lạc, một bàn chải xúc giác.', ARRAY['Một chiếc lục lạc', 'một bàn chải xúc giác']::text[], '/static/activities/g010/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng nắm tay, Khả năng xúc giác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3baf1128-345a-51eb-bed5-80a14ab5c391', 1, 'Dùng đầu ngón tay của bạn chà và xoa bóp mu bàn tay của bé từ đầu ngón tay đến cổ tay.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3baf1128-345a-51eb-bed5-80a14ab5c391', 2, 'Vỗ nhẹ vào mu bàn tay của trẻ để khuyến khích lòng bàn tay của trẻ thả lỏng rồi từ từ mở ra. Nếu trẻ vẫn chưa thả lỏng được thì dùng bàn chải xúc giác chạm vào mu bàn tay của trẻ rồi nhẹ nhàng di chuyển về phía cổ tay.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3baf1128-345a-51eb-bed5-80a14ab5c391', 3, 'Sau khi tay trẻ thả lỏng, bố mẹ nhẹ nhàng đặt lục lạc vào tay trẻ và nói: “Con yêu, nắm lấy nào!” Bạn hướng dẫn trẻ cầm tay cầm của chiếc lục lạc.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3baf1128-345a-51eb-bed5-80a14ab5c391', 'image', '/static/activities/g010/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3baf1128-345a-51eb-bed5-80a14ab5c391', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g011: Tập thể dục theo nhạc (trang PDF 48)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c50bf1ca-cc3e-5da6-9caa-74efb648c2e1', 'Tập thể dục theo nhạc', 'Kỹ năng phát triển: Khả năng vận động tay, Khả năng phối hợp thể chất, Khả năng nghe.', '**Kỹ năng phát triển:** Khả năng vận động tay, Khả năng phối hợp thể chất, Khả năng nghe

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ có thể gọi tên trẻ trước và nói nhẹ nhàng: “Con ơi, đến giờ tập thể dục rồi!”
2. Bố mẹ ôm trẻ và vỗ nhẹ trẻ theo bài đồng dao thiếu nhi “Tập tầm vông”, hướng dẫn trẻ giơ hai tay, đồng thời, bắt chéo hai tay trước ngực và cử động cả hai cổ tay.

## Lời bài hát / đồng dao
Cha mẹ có thể phỏng theo nội dung bài đồng dao:
Tập tầm vông
Tay không tay có
Tập tầm vó
Tay có tay không
Tay nào có
Tay nào không?

## Hướng dẫn của chuyên gia
- Khi tập thể dục, bố mẹ nên thả lỏng, cử động nhẹ nhàng, vừa thực hiện các bài tập cho trẻ, vừa ngâm nga các bài hát thiếu nhi. Nếu trẻ phản ứng lại thì không nên kéo mạnh.
- Điều chỉnh “bàn tay nhỏ” thành “bàn chân nhỏ”, điều này cũng có thể áp dụng khi thực hiện các bài tập với đôi chân. Bạn cũng có thể tự thực hiện các động tác của mình, miễn là chúng phù hợp với nhịp điệu và để cho các chi, khớp của trẻ có thể cử động được.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 0, 3,
       'Không có.', NULL, '/static/activities/g011/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng vận động tay, Khả năng phối hợp thể chất, Khả năng nghe.', true, 'Cha mẹ có thể phỏng theo nội dung bài đồng dao:
Tập tầm vông
Tay không tay có
Tập tầm vó
Tay có tay không
Tay nào có
Tay nào không?';
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c50bf1ca-cc3e-5da6-9caa-74efb648c2e1', 1, 'Bố mẹ có thể gọi tên trẻ trước và nói nhẹ nhàng: “Con ơi, đến giờ tập thể dục rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c50bf1ca-cc3e-5da6-9caa-74efb648c2e1', 2, 'Bố mẹ ôm trẻ và vỗ nhẹ trẻ theo bài đồng dao thiếu nhi “Tập tầm vông”, hướng dẫn trẻ giơ hai tay, đồng thời, bắt chéo hai tay trước ngực và cử động cả hai cổ tay.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c50bf1ca-cc3e-5da6-9caa-74efb648c2e1', 'image', '/static/activities/g011/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c50bf1ca-cc3e-5da6-9caa-74efb648c2e1', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g012: Bắt, bỏ chạy (trang PDF 49)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e4e9f695-c66d-5c03-bb6e-e788667d33e9', 'Bắt, bỏ chạy', 'Bố mẹ có thể giả vờ rút ngón tay không thành công nhiều lần, sau đó rút ngón tay ra và thêm các khẩu hiệu nhịp nhàng trong quá trình kéo ngón tay, chẳng hạn như “Kéo nào, kéo nào!” để trò chơi trở nên thú vị hơn.', '**Kỹ năng phát triển:** Khả năng nắm tay, Khả năng thị giác, Khả năng xúc giác

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ đặt hai tay gần bàn tay út của trẻ, vỗ nhẹ vào mu bàn tay của trẻ, hướng dẫn trẻ mở bàn tay nhỏ ra, sau đó đặt ngón trỏ của mình vào tay trẻ để dụ trẻ nắm lấy.
2. Sau khi trẻ nắm được, bố mẹ nói: “Bắt lấy!” rồi nhẹ nhàng đưa tay cùng với bàn tay của trẻ vào giữa cơ thể trẻ để trẻ có thể nhìn thấy và nắm lấy tay bố mẹ.
3. Bố mẹ rút ngón tay ra một cách nhẹ nhàng và từng chút một rồi nói: “Thoát được rồi!”
4. Lặp lại các bước trên.

## Hướng dẫn của chuyên gia
- Sau khi trẻ thấy mình nắm lấy tay người lớn, bố mẹ có thể gãi vào lòng bàn tay trẻ và lắc bàn tay nhỏ của trẻ để tăng sự tương tác với trẻ.
- Khi khả năng của trẻ được cải thiện, thời gian mở bàn tay của trẻ sẽ ngày càng dài hơn. Bố mẹ có thể đặt ngón trỏ vào lòng bàn tay của trẻ để chơi trò chơi này khi trẻ chủ động mở tay.

> Bố mẹ có thể giả vờ rút ngón tay không thành công nhiều lần, sau đó rút ngón tay ra và thêm các khẩu hiệu nhịp nhàng trong quá trình kéo ngón tay, chẳng hạn như “Kéo nào, kéo nào!” để trò chơi trở nên thú vị hơn.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 0, 3,
       'Không có.', NULL, '/static/activities/g012/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng nắm tay, Khả năng thị giác, Khả năng xúc giác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4e9f695-c66d-5c03-bb6e-e788667d33e9', 1, 'Bố mẹ đặt hai tay gần bàn tay út của trẻ, vỗ nhẹ vào mu bàn tay của trẻ, hướng dẫn trẻ mở bàn tay nhỏ ra, sau đó đặt ngón trỏ của mình vào tay trẻ để dụ trẻ nắm lấy.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4e9f695-c66d-5c03-bb6e-e788667d33e9', 2, 'Sau khi trẻ nắm được, bố mẹ nói: “Bắt lấy!” rồi nhẹ nhàng đưa tay cùng với bàn tay của trẻ vào giữa cơ thể trẻ để trẻ có thể nhìn thấy và nắm lấy tay bố mẹ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4e9f695-c66d-5c03-bb6e-e788667d33e9', 3, 'Bố mẹ rút ngón tay ra một cách nhẹ nhàng và từng chút một rồi nói: “Thoát được rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4e9f695-c66d-5c03-bb6e-e788667d33e9', 4, 'Lặp lại các bước trên.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e4e9f695-c66d-5c03-bb6e-e788667d33e9', 'image', '/static/activities/g012/main.jpg', 'Bố mẹ có thể giả vờ rút ngón tay không thành công nhiều lần, sau đó rút ngón tay ra và thêm các khẩu hiệu nhịp nhàng trong quá trình kéo ngón tay, chẳng hạn như “Kéo nào, kéo nào!” để trò chơi trở nên thú vị hơn.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e4e9f695-c66d-5c03-bb6e-e788667d33e9', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g013: Mẹ cho con vô vàn cảm xúc (trang PDF 50)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '42355f52-5764-562b-a165-e0df9e2d3985', 'Mẹ cho con vô vàn cảm xúc', 'Nhìn mẹ này!', '**Kỹ năng phát triển:** Khả năng thị giác, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Giường hoặc ghế sofa.
- **Tư thế:** Trẻ và bố mẹ mặt đối mặt.
- **Đồ dùng:** Vài chiếc mặt nạ hình con vật (hoặc những chiếc mặt nạ thú vị khác, những chiếc kính lạ).

## Các bước thực hiện
1. Người mẹ có ý thức thay đổi nét mặt hoặc cử động của mình để thu hút sự chú ý của trẻ như chớp mắt, lè lưỡi, mỉm cười, mím miệng,...
2. Người mẹ đeo mặt nạ hình con vật, chớp mắt nhìn ra ngoài mặt nạ và thay đổi giọng nói: “Mẹ đâu rồi?” để thu hút sự chú ý của trẻ.

## Hướng dẫn của chuyên gia
- Giữ khoảng cách giữa mẹ và trẻ thật thoải mái. Nếu mặt mẹ quá gần và mắt trẻ né tránh thì mẹ nên đứng xa hơn một chút. Trò chơi này cũng có thể được chơi bởi ông bà, anh chị em trong nhà.
- Khi làm mặt, hãy chú ý đến phản ứng của trẻ. Nếu trẻ có phản ứng không vui như cong môi thì bạn nên điều chỉnh hoặc dừng lại.

> Nhìn mẹ này!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi xã hội._', 'play', 0, 3,
       'Vài chiếc mặt nạ hình con vật (hoặc những chiếc mặt nạ thú vị khác, những chiếc kính lạ).', ARRAY['Vài chiếc mặt nạ hình con vật (hoặc những chiếc mặt nạ thú vị khác', 'những chiếc kính lạ)']::text[], '/static/activities/g013/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng thị giác, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42355f52-5764-562b-a165-e0df9e2d3985', 1, 'Người mẹ có ý thức thay đổi nét mặt hoặc cử động của mình để thu hút sự chú ý của trẻ như chớp mắt, lè lưỡi, mỉm cười, mím miệng,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42355f52-5764-562b-a165-e0df9e2d3985', 2, 'Người mẹ đeo mặt nạ hình con vật, chớp mắt nhìn ra ngoài mặt nạ và thay đổi giọng nói: “Mẹ đâu rồi?” để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42355f52-5764-562b-a165-e0df9e2d3985', 'image', '/static/activities/g013/main.jpg', 'Nhìn mẹ này!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '42355f52-5764-562b-a165-e0df9e2d3985', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g014: Nghe, nhìn những đồ vật màu sắc (trang PDF 51, 52)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '4a94801f-488d-5164-b373-42aa0607cd4d', 'Nghe, nhìn những đồ vật màu sắc', 'Kỹ năng phát triển: Khả năng quan sát, Khả năng tích hợp nghe, nhìn.', '**Kỹ năng phát triển:** Khả năng quan sát, Khả năng tích hợp nghe, nhìn

## Chuẩn bị
- **Không gian:** Mặt phẳng như giường, ghế sofa hoặc mặt bàn.
- **Tư thế:** Để trẻ ngồi thoải mái.
- **Đồ dùng:** Bộ đồ chơi xúc xắc nhiều màu sắc.

## Các bước thực hiện
1. Đặt trẻ nằm trên giường, bố mẹ cầm những đồ chơi có màu sắc rực rỡ trước mặt trẻ để thu hút sự chú ý của trẻ, sau đó lắc đồ chơi để tạo ra tiếng động, nhằm tăng sự hứng thú của trẻ với đồ chơi.
2. Ôm trẻ trên tay và từ từ di chuyển các đồ chơi trên bàn để thu hút trẻ nhìn theo chuyển động của đồ chơi.
3. Bố hoặc mẹ ngồi đối diện với trẻ, trên tay cầm một món đồ chơi nhiều màu sắc, di chuyển trái phải, lên xuống theo chuyển động tròn để thu hút, mắt trẻ sẽ di chuyển linh hoạt theo đồ vật.
4. Bố hoặc mẹ ngồi trước mặt và gọi tên trẻ, sử dụng âm lượng giọng nói cao và nét mặt cường điệu để thúc đẩy trẻ nhận thức về tên của chính mình.

## Hướng dẫn của chuyên gia
- Xúc xắc phải có màu sắc rực rỡ và phát ra âm thanh dễ chịu.
- Tên của trẻ phải được cố định và nên sử dụng cùng tên đó trong cuộc sống hằng ngày và trong trò chơi.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi đánh thức giác quan._', 'play', 3, 6,
       'Bộ đồ chơi xúc xắc nhiều màu sắc.', ARRAY['Bộ đồ chơi xúc xắc nhiều màu sắc']::text[], '/static/activities/g014/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng quan sát, Khả năng tích hợp nghe, nhìn.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 1, 'Đặt trẻ nằm trên giường, bố mẹ cầm những đồ chơi có màu sắc rực rỡ trước mặt trẻ để thu hút sự chú ý của trẻ, sau đó lắc đồ chơi để tạo ra tiếng động, nhằm tăng sự hứng thú của trẻ với đồ chơi.', '/static/activities/g014/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 2, 'Ôm trẻ trên tay và từ từ di chuyển các đồ chơi trên bàn để thu hút trẻ nhìn theo chuyển động của đồ chơi.', '/static/activities/g014/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 3, 'Bố hoặc mẹ ngồi đối diện với trẻ, trên tay cầm một món đồ chơi nhiều màu sắc, di chuyển trái phải, lên xuống theo chuyển động tròn để thu hút, mắt trẻ sẽ di chuyển linh hoạt theo đồ vật.', '/static/activities/g014/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 4, 'Bố hoặc mẹ ngồi trước mặt và gọi tên trẻ, sử dụng âm lượng giọng nói cao và nét mặt cường điệu để thúc đẩy trẻ nhận thức về tên của chính mình.', '/static/activities/g014/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 'image', '/static/activities/g014/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 'image', '/static/activities/g014/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 'image', '/static/activities/g014/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 'image', '/static/activities/g014/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4a94801f-488d-5164-b373-42aa0607cd4d', 'image', '/static/activities/g014/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '4a94801f-488d-5164-b373-42aa0607cd4d', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g015: Ánh đèn pin lấp lánh (trang PDF 53)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '988f008e-9371-5934-b712-1bf5012867b3', 'Ánh đèn pin lấp lánh', '“Bật đèn, Tắt đèn”', '**Kỹ năng phát triển:** Khả năng theo dõi trực quan, Khả năng quay đầu

## Chuẩn bị
- **Không gian:** Thảm lót sàn hoặc ghế sofa.
- **Tư thế:** Bế trẻ quay mặt vào tường trắng.
- **Đồ dùng:** Một chiếc đèn pin.

## Các bước thực hiện
1. Bố mẹ cầm đèn pin chiếu hướng lên tường. Bố mẹ có thể bật đèn để thu hút sự chú ý của trẻ.
2. Sau khi trẻ chú ý, bố mẹ lần lượt tắt và bật đèn pin, có thể nói thêm “bật đèn” và “tắt đèn” hoặc hát nhẹ nhàng “lấp lánh, lấp lánh, lấp lánh, bầu trời đầy sao nhỏ”.
3. Sau khi trẻ chú ý, bạn có thể từ từ di chuyển điểm sáng theo nhiều hướng khác nhau để thu hút sự chú ý của trẻ.

## Hướng dẫn của chuyên gia
- Trẻ nhỏ cũng có thể được bố mẹ khác bế để chơi trò chơi này. Trẻ trên 5 tháng tuổi có thể tập ngồi nhưng bố mẹ cần kê gối phía sau và hai bên để có thể hỗ trợ tốt hơn cho bé.
- Không chiếu đèn pin trực tiếp vào mắt trẻ và đừng để trẻ tự chơi với đèn pin.

> “Bật đèn, Tắt đèn”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 3, 6,
       'Một chiếc đèn pin.', ARRAY['Một chiếc đèn pin']::text[], '/static/activities/g015/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng theo dõi trực quan, Khả năng quay đầu.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('988f008e-9371-5934-b712-1bf5012867b3', 1, 'Bố mẹ cầm đèn pin chiếu hướng lên tường. Bố mẹ có thể bật đèn để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('988f008e-9371-5934-b712-1bf5012867b3', 2, 'Sau khi trẻ chú ý, bố mẹ lần lượt tắt và bật đèn pin, có thể nói thêm “bật đèn” và “tắt đèn” hoặc hát nhẹ nhàng “lấp lánh, lấp lánh, lấp lánh, bầu trời đầy sao nhỏ”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('988f008e-9371-5934-b712-1bf5012867b3', 3, 'Sau khi trẻ chú ý, bạn có thể từ từ di chuyển điểm sáng theo nhiều hướng khác nhau để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('988f008e-9371-5934-b712-1bf5012867b3', 'image', '/static/activities/g015/main.jpg', '“Bật đèn, Tắt đèn”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '988f008e-9371-5934-b712-1bf5012867b3', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g016: Phút vui vẻ với khăn tắm (trang PDF 54)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'dfd7945f-257b-500e-a9bd-87e9fb4f0209', 'Phút vui vẻ với khăn tắm', 'Mỗi lần bố mẹ lau một bộ phận trên cơ thể, có thể nói với trẻ như: “lau lau, lau tay”, “lau lau, lau chân”,...', '**Kỹ năng phát triển:** Khả năng xúc giác, Đa dạng cảm xúc

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Bé ở tư thế nằm ngửa và nằm sấp.
- **Đồ dùng:** Một khăn tắm mềm, một khăn tắm thô.

## Các bước thực hiện
1. Sau khi tắm xong, đặt trẻ trên khăn tắm mềm.
2. Bố mẹ lấy một chiếc khăn tắm mềm khác và kì cọ cơ thể trẻ, bắt đầu từ lưng, từ trên xuống dưới, từ giữa sang hai bên và cuối cùng là hai chân và hai tay trong vài phút.
3. Thực hiện theo trình tự trên và dùng khăn tắm thô để lau người cho trẻ trong vài phút.

## Hướng dẫn của chuyên gia
- Cần chú ý đến phản ứng của trẻ và điều chỉnh kịp thời cường độ, tần suất và vị trí lau trên người trẻ.
- Chú ý xem trẻ có bị dị ứng hay không, không dùng khăn tắm quá thô hoặc làm xước da trẻ.
- Bạn cũng có thể sử dụng bàn chải xúc giác để nhẹ nhàng chải hai tay, hai chân và lưng của trẻ để mang lại cho trẻ trải nghiệm xúc giác đa dạng hơn.

> Mỗi lần bố mẹ lau một bộ phận trên cơ thể, có thể nói với trẻ như: “lau lau, lau tay”, “lau lau, lau chân”,...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 3, 6,
       'Một khăn tắm mềm, một khăn tắm thô.', ARRAY['Một khăn tắm mềm', 'một khăn tắm thô']::text[], '/static/activities/g016/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng xúc giác, Đa dạng cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfd7945f-257b-500e-a9bd-87e9fb4f0209', 1, 'Sau khi tắm xong, đặt trẻ trên khăn tắm mềm.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfd7945f-257b-500e-a9bd-87e9fb4f0209', 2, 'Bố mẹ lấy một chiếc khăn tắm mềm khác và kì cọ cơ thể trẻ, bắt đầu từ lưng, từ trên xuống dưới, từ giữa sang hai bên và cuối cùng là hai chân và hai tay trong vài phút.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfd7945f-257b-500e-a9bd-87e9fb4f0209', 3, 'Thực hiện theo trình tự trên và dùng khăn tắm thô để lau người cho trẻ trong vài phút.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('dfd7945f-257b-500e-a9bd-87e9fb4f0209', 'image', '/static/activities/g016/main.jpg', 'Mỗi lần bố mẹ lau một bộ phận trên cơ thể, có thể nói với trẻ như: “lau lau, lau tay”, “lau lau, lau chân”,...', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'dfd7945f-257b-500e-a9bd-87e9fb4f0209', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g017: Cuộn lại nào, cuộn lại nào... (trang PDF 55, 56)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '42a4263b-01b1-52b6-a07b-03e80ba2a636', 'Cuộn lại nào, cuộn lại nào...', 'Kỹ năng phát triển: Khả năng nhận thức cơ thể, Khả năng tích hợp cảm giác.', '**Kỹ năng phát triển:** Khả năng nhận thức cơ thể, Khả năng tích hợp cảm giác

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một khăn tắm.

## Các bước thực hiện
1. Trải khăn tắm lên thảm trải sàn và đặt trẻ nằm thẳng đứng trên một đầu khăn tắm, đầu để lộ ra ngoài.
2. Lăn trẻ từ một đầu khăn tắm vào trong. Trong khi cuộn khăn tắm, hãy giúp trẻ cuộn tròn. Cuối cùng, bạn có thể quấn trẻ vào khăn tắm và hát những bài hát thiếu nhi trong khi lăn trẻ.
3. Sau khi cuộn lại, bạn có thể nhẹ nhàng giữ trẻ trong khăn tắm, hôn trẻ và để trẻ nằm nghỉ.
4. Kéo một đầu khăn và để trẻ lăn từ từ ra khỏi khăn.

## Hướng dẫn của chuyên gia
- Động tác của bố mẹ phải nhẹ nhàng, chậm rãi, cẩn thận, không làm bong gân tay, chân của trẻ. Thời gian và tần suất chơi có thể điều chỉnh theo phản ứng của trẻ, hãy dừng ngay lập tức khi trẻ bị mệt.
- Không nên thực hiện hoạt động này trong vòng 1 giờ sau khi trẻ bú để tránh bị trớ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 3, 6,
       'Một khăn tắm.', ARRAY['Một khăn tắm']::text[], '/static/activities/g017/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức cơ thể, Khả năng tích hợp cảm giác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 1, 'Trải khăn tắm lên thảm trải sàn và đặt trẻ nằm thẳng đứng trên một đầu khăn tắm, đầu để lộ ra ngoài.', '/static/activities/g017/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 2, 'Lăn trẻ từ một đầu khăn tắm vào trong. Trong khi cuộn khăn tắm, hãy giúp trẻ cuộn tròn. Cuối cùng, bạn có thể quấn trẻ vào khăn tắm và hát những bài hát thiếu nhi trong khi lăn trẻ.', '/static/activities/g017/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 3, 'Sau khi cuộn lại, bạn có thể nhẹ nhàng giữ trẻ trong khăn tắm, hôn trẻ và để trẻ nằm nghỉ.', '/static/activities/g017/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 4, 'Kéo một đầu khăn và để trẻ lăn từ từ ra khỏi khăn.', '/static/activities/g017/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 'image', '/static/activities/g017/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 'image', '/static/activities/g017/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 'image', '/static/activities/g017/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 'image', '/static/activities/g017/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('42a4263b-01b1-52b6-a07b-03e80ba2a636', 'image', '/static/activities/g017/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '42a4263b-01b1-52b6-a07b-03e80ba2a636', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g018: Em bé cưỡi ngựa (trang PDF 57)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '9e48968a-f50e-5834-bbf9-1c53ab52e37a', 'Em bé cưỡi ngựa', '“Con ngựa đang xuống dốc!”', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Sức mạnh cơ bắp, Trải nghiệm cảm xúc

## Chuẩn bị
- **Không gian:** Ghế sofa.
- **Tư thế:** Trẻ ngồi, mặt đối mặt với bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ ngồi trên sofa, hai chân duỗi thẳng, khép sát lại, cho trẻ ngồi trên hai chân, mặt hướng về phía mình. Bố mẹ nhẹ nhàng ôm lấy thân trẻ và để trẻ di chuyển lên xuống, trái phải, tiến lùi theo trình tự sự chuyển động của chân. Đồng thời, nhẹ nhàng nói với trẻ: “Cưỡi ngựa nào, lái đi nào, ngựa lên dốc, trườn bò, ngựa đi xuống dốc, gầm gừ, gầm gừ, chạy xuống”.
2. Khi bố mẹ nói “lái, lái, lái” thì lắc lư sang trái và phải với tốc độ không đổi; khi báo “ngựa lên dốc” thì di chuyển lên xuống lớn; tiến và lùi để trẻ chuyển từ tư thế ngồi sang tư thế nằm trên lưng người lớn.

## Hướng dẫn của chuyên gia
- Trò chơi này phù hợp cho trẻ 5 tháng tuổi khi cơ cổ của trẻ đã cứng và giữ vững được phần đầu.
- Trong quá trình chơi, hãy chú ý đến nét mặt của trẻ và tránh đung đưa trẻ đột ngột. Biên độ và tốc độ lắc phải được điều chỉnh theo phản ứng của trẻ. Khi đu đưa theo từng hướng, trẻ phải có đủ thời gian để giữ thăng bằng cơ thể và phải có sự hỗ trợ chân tay phù hợp để trẻ không bị ngã, sợ hãi.

> “Con ngựa đang xuống dốc!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức giác quan._', 'play', 3, 6,
       'Không có.', NULL, '/static/activities/g018/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Sức mạnh cơ bắp, Trải nghiệm cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('9e48968a-f50e-5834-bbf9-1c53ab52e37a', 1, 'Bố mẹ ngồi trên sofa, hai chân duỗi thẳng, khép sát lại, cho trẻ ngồi trên hai chân, mặt hướng về phía mình. Bố mẹ nhẹ nhàng ôm lấy thân trẻ và để trẻ di chuyển lên xuống, trái phải, tiến lùi theo trình tự sự chuyển động của chân. Đồng thời, nhẹ nhàng nói với trẻ: “Cưỡi ngựa nào, lái đi nào, ngựa lên dốc, trườn bò, ngựa đi xuống dốc, gầm gừ, gầm gừ, chạy xuống”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('9e48968a-f50e-5834-bbf9-1c53ab52e37a', 2, 'Khi bố mẹ nói “lái, lái, lái” thì lắc lư sang trái và phải với tốc độ không đổi; khi báo “ngựa lên dốc” thì di chuyển lên xuống lớn; tiến và lùi để trẻ chuyển từ tư thế ngồi sang tư thế nằm trên lưng người lớn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('9e48968a-f50e-5834-bbf9-1c53ab52e37a', 'image', '/static/activities/g018/main.jpg', '“Con ngựa đang xuống dốc!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '9e48968a-f50e-5834-bbf9-1c53ab52e37a', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g019: Lật trái, lật phải (trang PDF 58)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', 'Lật trái, lật phải', 'Con thật tuyệt vời!', '**Kỹ năng phát triển:** Khả năng phối hợp tay, chân, Khả năng thể thao tuyệt vời, Khả năng nhận thức cơ thể

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Bé nằm ngửa.
- **Đồ dùng:** Một món đồ chơi bé yêu thích, lục lạc hoặc xúc xắc.

## Các bước thực hiện
1. Nếu trẻ sẵn sàng và có dấu hiệu chủ động lật, bố mẹ có thể dùng đồ chơi mà trẻ yêu thích để hướng dẫn trẻ lật, hoặc nhẹ nhàng gọi tên trẻ ở bên cạnh để kích thích trẻ thích thú với việc lật. Sau khi trẻ tự lật, bố mẹ vỗ tay khen ngợi: “Con giỏi quá!” Lặp lại 5 - 10 lần.
2. Dùng cách tương tự để hướng dẫn trẻ lật người sang bên kia, lặp lại 5 - 10 lần.
3. Nếu lúc đầu trẻ không lật, bạn có thể cho trẻ nằm thẳng tay trên giường. Bố mẹ giữ hai chân trẻ, nhẹ nhàng nhấc chân phải của trẻ lên và đặt lên chân trái rồi hướng dẫn trẻ xoay cơ thể để lật. Nếu trẻ vẫn chưa lật được, bố mẹ nên dùng một tay ôm bắp chân phải của trẻ và giữ càng gần giường càng tốt, đồng thời dùng tay kia ấn nhẹ vào hông phải của trẻ và xoay sang trái để hướng dẫn trẻ lật.

## Hướng dẫn của chuyên gia
- Trong khi chơi, bố mẹ nên hướng dẫn hai tay và đầu, cổ của bé đẩy sang một bên, đồng thời nâng cao nhất có thể cánh tay đang bị ép bên dưới khi lật trẻ.
- Lật mình là một quá trình diễn ra từ từ. Bố mẹ có thể dành vài phút mỗi ngày để tập thể dục cho trẻ.

> Con thật tuyệt vời!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 3, 6,
       'Một món đồ chơi bé yêu thích, lục lạc hoặc xúc xắc.', ARRAY['Một món đồ chơi bé yêu thích', 'lục lạc hoặc xúc xắc']::text[], '/static/activities/g019/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, chân, Khả năng thể thao tuyệt vời, Khả năng nhận thức cơ thể.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', 1, 'Nếu trẻ sẵn sàng và có dấu hiệu chủ động lật, bố mẹ có thể dùng đồ chơi mà trẻ yêu thích để hướng dẫn trẻ lật, hoặc nhẹ nhàng gọi tên trẻ ở bên cạnh để kích thích trẻ thích thú với việc lật. Sau khi trẻ tự lật, bố mẹ vỗ tay khen ngợi: “Con giỏi quá!” Lặp lại 5 - 10 lần.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', 2, 'Dùng cách tương tự để hướng dẫn trẻ lật người sang bên kia, lặp lại 5 - 10 lần.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', 3, 'Nếu lúc đầu trẻ không lật, bạn có thể cho trẻ nằm thẳng tay trên giường. Bố mẹ giữ hai chân trẻ, nhẹ nhàng nhấc chân phải của trẻ lên và đặt lên chân trái rồi hướng dẫn trẻ xoay cơ thể để lật. Nếu trẻ vẫn chưa lật được, bố mẹ nên dùng một tay ôm bắp chân phải của trẻ và giữ càng gần giường càng tốt, đồng thời dùng tay kia ấn nhẹ vào hông phải của trẻ và xoay sang trái để hướng dẫn trẻ lật.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', 'image', '/static/activities/g019/main.jpg', 'Con thật tuyệt vời!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '7a06ef9f-dfe9-56d6-a9e3-ff0915156c91', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g020: Leo núi cùng bố (trang PDF 59)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '492a5367-f717-5c28-a12a-5cf8471f13a3', 'Leo núi cùng bố', '“Xuống núi”', '**Kỹ năng phát triển:** Sức mạnh cơ bắp, Phương hướng, Cảm xúc

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Bố gập đầu gối, trẻ ngồi trên đầu gối bố, quay mặt về phía bố.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Để trẻ quay mặt về phía bố, ngồi trên đùi bố (đỉnh núi), sau đó để trẻ trượt xuống bụng (xuống núi). Trong quá trình này, hãy nâng đỡ cơ thể trẻ để trẻ có cảm giác an toàn tuyệt đối.
2. Trẻ ngồi trên đầu gối của bố và trượt dọc theo bắp chân của bố đến mắt cá chân. Trong quá trình này, người bố hãy trò chuyện với trẻ để nói về các hành động “trượt xuống”, “quay lại”, “leo lên” và “lên đỉnh núi”.

## Hướng dẫn của chuyên gia
- Trò chơi này bố có thể chơi với trẻ. Trò chơi này nên được chơi khi trẻ từ 4 tháng tuổi, lúc trẻ đã có thể ngẩng đầu và ngồi thẳng.
- Chiều cao đầu gối của người bố có thể tăng dần và tốc độ trượt xuống có thể tăng từ chậm đến nhanh. Đầu tiên, nó chủ yếu hướng dẫn trẻ điều khiển đầu, sau đó hỗ trợ trẻ leo lên đỉnh núi, sau đó điều chỉnh tư thế cơ thể của trẻ bằng cách lắc nhẹ đầu gối từ trái sang phải.
- Trong suốt quá trình, người bố nên thay đổi giọng nói theo động tác và giao tiếp với trẻ.

> “Xuống núi”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 3, 6,
       'Không có.', NULL, '/static/activities/g020/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Sức mạnh cơ bắp, Phương hướng, Cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('492a5367-f717-5c28-a12a-5cf8471f13a3', 1, 'Để trẻ quay mặt về phía bố, ngồi trên đùi bố (đỉnh núi), sau đó để trẻ trượt xuống bụng (xuống núi). Trong quá trình này, hãy nâng đỡ cơ thể trẻ để trẻ có cảm giác an toàn tuyệt đối.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('492a5367-f717-5c28-a12a-5cf8471f13a3', 2, 'Trẻ ngồi trên đầu gối của bố và trượt dọc theo bắp chân của bố đến mắt cá chân. Trong quá trình này, người bố hãy trò chuyện với trẻ để nói về các hành động “trượt xuống”, “quay lại”, “leo lên” và “lên đỉnh núi”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('492a5367-f717-5c28-a12a-5cf8471f13a3', 'image', '/static/activities/g020/main.jpg', '“Xuống núi”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '492a5367-f717-5c28-a12a-5cf8471f13a3', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g021: Bé trượt tuyết (trang PDF 60)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '850fa4b8-0141-54a8-9198-3e70ff67e026', 'Bé trượt tuyết', 'Kỹ năng phát triển: Sức mạnh của đôi tay, Khả năng tích hợp giác quan.', '**Kỹ năng phát triển:** Sức mạnh của đôi tay, Khả năng tích hợp giác quan

## Chuẩn bị
- **Không gian:** Thảm hoặc sàn nhà.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một chiếc khăn hoặc một chiếc chăn.

## Các bước thực hiện
1. Đặt chăn hoặc khăn xuống đất và để trẻ nằm trên chăn hoặc khăn. Bố mẹ kéo góc chăn hoặc khăn ở một bên đầu trẻ rồi từ từ kéo chăn hoặc khăn để đẩy trẻ về phía trước.
2. Bố mẹ vừa chậm rãi kéo khăn hoặc chăn, vừa ngâm nga những bài hát thiếu nhi yêu thích cho trẻ nghe, vừa đi vừa dừng lại theo nhịp điệu của bài hát thiếu nhi.
3. Bố mẹ có thể kéo chăn hoặc khăn theo đường thẳng, theo vòng tròn chiều kim đồng hồ hoặc theo vòng tròn ngược chiều kim đồng hồ hoặc có thể lắc nhẹ chăn khăn lên xuống để làm phong phú thêm nội dung trò chơi.

## Hướng dẫn của chuyên gia
- Bố mẹ cần đi lùi trong khi chơi để đảm bảo có thể quan sát biểu cảm của trẻ mọi lúc, đồng thời quyết định tốc độ, phương pháp kéo cũng như có dừng lại hay không dựa trên biểu cảm của trẻ.
- Tốc độ kéo nên chậm hơn, đặc biệt là khi đổi hướng, để trẻ không bị sợ hãi.
- Không nên thực hiện hoạt động này trong vòng 1 giờ sau khi trẻ bú để tránh nôn trớ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 3, 6,
       'Một chiếc khăn hoặc một chiếc chăn.', ARRAY['Một chiếc khăn hoặc một chiếc chăn']::text[], '/static/activities/g021/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Sức mạnh của đôi tay, Khả năng tích hợp giác quan.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('850fa4b8-0141-54a8-9198-3e70ff67e026', 1, 'Đặt chăn hoặc khăn xuống đất và để trẻ nằm trên chăn hoặc khăn. Bố mẹ kéo góc chăn hoặc khăn ở một bên đầu trẻ rồi từ từ kéo chăn hoặc khăn để đẩy trẻ về phía trước.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('850fa4b8-0141-54a8-9198-3e70ff67e026', 2, 'Bố mẹ vừa chậm rãi kéo khăn hoặc chăn, vừa ngâm nga những bài hát thiếu nhi yêu thích cho trẻ nghe, vừa đi vừa dừng lại theo nhịp điệu của bài hát thiếu nhi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('850fa4b8-0141-54a8-9198-3e70ff67e026', 3, 'Bố mẹ có thể kéo chăn hoặc khăn theo đường thẳng, theo vòng tròn chiều kim đồng hồ hoặc theo vòng tròn ngược chiều kim đồng hồ hoặc có thể lắc nhẹ chăn khăn lên xuống để làm phong phú thêm nội dung trò chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('850fa4b8-0141-54a8-9198-3e70ff67e026', 'image', '/static/activities/g021/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '850fa4b8-0141-54a8-9198-3e70ff67e026', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g022: Cùng bắt gà (trang PDF 61)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '2a1d6453-610b-5798-aba2-7161b5c0d7b3', 'Cùng bắt gà', 'Kỹ năng phát triển: Khả năng nắm tay, Phối hợp tay mắt, Cảm giác về không gian.', '**Kỹ năng phát triển:** Khả năng nắm tay, Phối hợp tay mắt, Cảm giác về không gian

## Chuẩn bị
- **Không gian:** Ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một tờ giấy dán hình con gà.

## Các bước thực hiện
1. Trẻ ngồi trên mẹ, quay mặt về phía bố và dán một số tờ giấy ghi chú hình con gà vào ngực hoặc cánh tay của bố.
2. Mẹ chỉ vào tờ giấy dính, nói từ “con gà” cho trẻ nghe và hướng dẫn trẻ cách bắt con gà.
3. Hướng dẫn trẻ giơ tay xé tờ giấy dính. Đầu tiên, mẹ có thể nắm tay con và cùng con bắt con gà thành công, sau đó mẹ từ từ bỏ sự trợ giúp ra và để con một mình hoàn thành nhiệm vụ.

## Hướng dẫn của chuyên gia
- Trò chơi này phù hợp với những trẻ đã có thể chủ động cầm đồ.
- Quần áo trên người bố nên có màu trơn và có độ tương phản lớn với màu của giấy dính để trẻ dễ nhìn thấy con gà hơn.
- Ban đầu, tờ giấy dán có thể được dán ở vị trí thấp hơn, khi khả năng của trẻ tăng lên thì có thể dán dần dần lên cao hơn hoặc có thể thay đổi vị trí. Bố cũng có thể chủ động điều chỉnh vị trí của miếng dán theo khả năng của trẻ hoặc sử dụng những thay đổi về tư thế cơ thể để tăng độ khó và sự thú vị của trò chơi.
- Giấy dán có thể được thay thế bằng bất kỳ hình dạng nào hoặc bạn có thể tìm thứ gì đó tương tự để thay thế giấy dán.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 3, 6,
       'Một tờ giấy dán hình con gà.', ARRAY['Một tờ giấy dán hình con gà']::text[], '/static/activities/g022/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng nắm tay, Phối hợp tay mắt, Cảm giác về không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('2a1d6453-610b-5798-aba2-7161b5c0d7b3', 1, 'Trẻ ngồi trên mẹ, quay mặt về phía bố và dán một số tờ giấy ghi chú hình con gà vào ngực hoặc cánh tay của bố.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('2a1d6453-610b-5798-aba2-7161b5c0d7b3', 2, 'Mẹ chỉ vào tờ giấy dính, nói từ “con gà” cho trẻ nghe và hướng dẫn trẻ cách bắt con gà.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('2a1d6453-610b-5798-aba2-7161b5c0d7b3', 3, 'Hướng dẫn trẻ giơ tay xé tờ giấy dính. Đầu tiên, mẹ có thể nắm tay con và cùng con bắt con gà thành công, sau đó mẹ từ từ bỏ sự trợ giúp ra và để con một mình hoàn thành nhiệm vụ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('2a1d6453-610b-5798-aba2-7161b5c0d7b3', 'image', '/static/activities/g022/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '2a1d6453-610b-5798-aba2-7161b5c0d7b3', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g023: Rút khăn ra nào! (trang PDF 62)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8ad1c32e-7f46-5675-b8cc-094cbe860776', 'Rút khăn ra nào!', 'Sau khi lặp lại vài lần, trẻ sẽ có thể kéo khăn một cách liền mạch!', '**Kỹ năng phát triển:** Khả năng nắm tay, Phối hợp tay mắt

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Một ống lõi khăn giấy và một khăn lụa sáng màu.

## Các bước thực hiện
1. Nhét khăn vào ống lõi khăn giấy đã qua sử dụng và để lộ một góc.
2. Lắc góc khăn và để trẻ nắm lấy. Nếu trẻ không chủ động nắm lấy khăn, bạn có thể thọc góc khăn vào tay trẻ để dụ trẻ cầm lấy.
3. Sau khi trẻ nắm được góc khăn, bố mẹ cần đợi trẻ chủ động kéo khăn ra. Nếu trẻ không kéo, bố mẹ có thể kéo ống lõi khăn giấy để lộ ra chiếc khăn lụa.

## Hướng dẫn của chuyên gia
- Bạn cần chọn những chiếc khăn lụa mềm mại, dễ kéo ra, không nên nhét quá chặt vào ống lõi khăn giấy.
- Mỗi khi trẻ kéo ra thành công, bố mẹ có thể vỗ tay, cổ vũ cho trẻ để tăng thêm động lực vui chơi cho trẻ.

> Sau khi lặp lại vài lần, trẻ sẽ có thể kéo khăn một cách liền mạch!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 3, 6,
       'Một ống lõi khăn giấy và một khăn lụa sáng màu.', ARRAY['Một ống lõi khăn giấy và một khăn lụa sáng màu']::text[], '/static/activities/g023/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng nắm tay, Phối hợp tay mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8ad1c32e-7f46-5675-b8cc-094cbe860776', 1, 'Nhét khăn vào ống lõi khăn giấy đã qua sử dụng và để lộ một góc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8ad1c32e-7f46-5675-b8cc-094cbe860776', 2, 'Lắc góc khăn và để trẻ nắm lấy. Nếu trẻ không chủ động nắm lấy khăn, bạn có thể thọc góc khăn vào tay trẻ để dụ trẻ cầm lấy.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8ad1c32e-7f46-5675-b8cc-094cbe860776', 3, 'Sau khi trẻ nắm được góc khăn, bố mẹ cần đợi trẻ chủ động kéo khăn ra. Nếu trẻ không kéo, bố mẹ có thể kéo ống lõi khăn giấy để lộ ra chiếc khăn lụa.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8ad1c32e-7f46-5675-b8cc-094cbe860776', 'image', '/static/activities/g023/main.jpg', 'Sau khi lặp lại vài lần, trẻ sẽ có thể kéo khăn một cách liền mạch!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8ad1c32e-7f46-5675-b8cc-094cbe860776', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g024: Chơi với ống lõi khăn giấy (trang PDF 63)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3332f986-d73d-5725-b702-e6e9013776da', 'Chơi với ống lõi khăn giấy', 'Sau khi lặp đi lặp lại nhiều lần, bố mẹ không cần nắm bàn tay nhỏ bé của trẻ nữa. Trẻ có thể tự xoay ống khăn giấy để chơi.', '**Kỹ năng phát triển:** Phối hợp tay mắt, Sức mạnh phần thân trên

## Chuẩn bị
- **Không gian:** Giường, thảm trải sàn hoặc ghế sofa.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Ống lõi khăn giấy, sợi dây và bút màu.

## Các bước thực hiện
1. Bố mẹ dùng bút màu vẽ các họa tiết đơn giản hoặc dán các miếng dán lên các ống lõi khăn giấy khác nhau, xâu các ống khăn giấy vào một sợi dây rồi kéo hai đầu dây lên để các ống khăn giấy có thể xoay được dễ dàng.
2. Bố mẹ bế trẻ lại gần ống khăn giấy, búng nhẹ ống lõi khăn giấy cho trẻ xem và đợi trẻ rút ống lõi khăn giấy ra khỏi sợi dây. Nếu trẻ chưa chủ động rút ống lõi khăn giấy ra, bố mẹ có thể nắm tay trẻ để cùng rút.

## Hướng dẫn của chuyên gia
- Khi khả năng của trẻ được cải thiện, bố mẹ cần kịp thời loại bỏ sự hỗ trợ và để trẻ tự di chuyển ống lõi khăn giấy. Ống lõi khăn giấy cũng có thể được treo cao hơn để rèn luyện khả năng giơ tay của trẻ.
- Trò chơi này cũng có thể chơi khi trẻ nằm sấp. Treo ống khăn giấy cách trẻ không xa và đợi trẻ có thể nhấc một tay kéo ống lõi khăn giấy. Trò chơi này giúp trẻ rèn luyện khả năng phối hợp nhịp nhàng, khéo léo của bàn tay.
- Trò chơi này có thể chơi với bất kỳ đồ chơi nào có thể xâu chuỗi trên dây.

> Sau khi lặp đi lặp lại nhiều lần, bố mẹ không cần nắm bàn tay nhỏ bé của trẻ nữa. Trẻ có thể tự xoay ống khăn giấy để chơi.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 3, 6,
       'Ống lõi khăn giấy, sợi dây và bút màu.', ARRAY['Ống lõi khăn giấy', 'sợi dây và bút màu']::text[], '/static/activities/g024/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Phối hợp tay mắt, Sức mạnh phần thân trên.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3332f986-d73d-5725-b702-e6e9013776da', 1, 'Bố mẹ dùng bút màu vẽ các họa tiết đơn giản hoặc dán các miếng dán lên các ống lõi khăn giấy khác nhau, xâu các ống khăn giấy vào một sợi dây rồi kéo hai đầu dây lên để các ống khăn giấy có thể xoay được dễ dàng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3332f986-d73d-5725-b702-e6e9013776da', 2, 'Bố mẹ bế trẻ lại gần ống khăn giấy, búng nhẹ ống lõi khăn giấy cho trẻ xem và đợi trẻ rút ống lõi khăn giấy ra khỏi sợi dây. Nếu trẻ chưa chủ động rút ống lõi khăn giấy ra, bố mẹ có thể nắm tay trẻ để cùng rút.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3332f986-d73d-5725-b702-e6e9013776da', 'image', '/static/activities/g024/main.jpg', 'Sau khi lặp đi lặp lại nhiều lần, bố mẹ không cần nắm bàn tay nhỏ bé của trẻ nữa. Trẻ có thể tự xoay ống khăn giấy để chơi.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3332f986-d73d-5725-b702-e6e9013776da', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g025: Âm thanh dễ thương (trang PDF 64)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'f784e78d-ae83-561a-a7fe-b39bdbd1713f', 'Âm thanh dễ thương', '“Wow, wow...”', '**Kỹ năng phát triển:** Khả năng nắm tay, Phối hợp tay mắt

## Chuẩn bị
- **Không gian:** Trên giường.
- **Tư thế:** Trẻ nằm ngửa.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Khi trẻ phát ra âm “o”, bố mẹ kịp thời đưa tay lên miệng mình vỗ nhịp nhàng và phát ra âm “wow”.
2. Bố mẹ dùng tay vỗ nhẹ vào miệng mình và phát ra âm thanh “wow, wow, wah”, sau đó lại đặt tay lên miệng trẻ và nói “wow, wow, wah”, hy vọng trẻ cũng sẽ phát ra tiếng “wow, wow, wah” dưới sự vỗ nhẹ của bố mẹ.
3. Sau khi trẻ đã biết phát ra âm thanh “wow”, bố mẹ có thể thay phiên lần lượt chơi vỗ miệng như thế với trẻ.

## Hướng dẫn của chuyên gia
- Nếu trẻ có thể khéo léo phát ra âm thanh “wow, wow, wah” dưới sự vỗ nhẹ của bố mẹ, bố mẹ có thể thử nắm lấy bàn tay nhỏ của trẻ và vỗ nhẹ vào miệng mình sau khi lặp lại vài lần, đợi bé sẽ làm như vậy để tự mình phát ra âm thanh “wow, wow”.
- Làn da của trẻ rất mỏng manh nên hãy cẩn thận khi vỗ vào miệng trẻ.

> “Wow, wow...”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 3, 6,
       'Không có.', NULL, '/static/activities/g025/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng nắm tay, Phối hợp tay mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f784e78d-ae83-561a-a7fe-b39bdbd1713f', 1, 'Khi trẻ phát ra âm “o”, bố mẹ kịp thời đưa tay lên miệng mình vỗ nhịp nhàng và phát ra âm “wow”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f784e78d-ae83-561a-a7fe-b39bdbd1713f', 2, 'Bố mẹ dùng tay vỗ nhẹ vào miệng mình và phát ra âm thanh “wow, wow, wah”, sau đó lại đặt tay lên miệng trẻ và nói “wow, wow, wah”, hy vọng trẻ cũng sẽ phát ra tiếng “wow, wow, wah” dưới sự vỗ nhẹ của bố mẹ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f784e78d-ae83-561a-a7fe-b39bdbd1713f', 3, 'Sau khi trẻ đã biết phát ra âm thanh “wow”, bố mẹ có thể thay phiên lần lượt chơi vỗ miệng như thế với trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f784e78d-ae83-561a-a7fe-b39bdbd1713f', 'image', '/static/activities/g025/main.jpg', '“Wow, wow...”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'f784e78d-ae83-561a-a7fe-b39bdbd1713f', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g026: Nhìn vào gương (trang PDF 65)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', 'Nhìn vào gương', '“Ai đây nhỉ?”', '**Kỹ năng phát triển:** Kỹ năng thị giác, Kỹ năng xã hội, Cảm xúc

## Chuẩn bị
- **Không gian:** Trước gương.
- **Tư thế:** Nên bế trẻ ở tư thế đối diện với gương.
- **Đồ dùng:** Một tấm gương.

## Các bước thực hiện
1. Bố mẹ chỉ vào trong gương và nói “con”, sau đó vỗ về trẻ và chỉ vào trẻ, nói “con”. Bố mẹ chỉ vào mình trong gương và nói “mẹ (bố)”, sau đó chỉ vào mình và nói “mẹ (bố)”.
2. Hướng dẫn trẻ chạm, vỗ nhẹ vào gương để tạo sự tò mò, thích thú với bản thân và bố mẹ trong gương.
3. Khi trẻ khóc hoặc cười, bạn cũng có thể nhìn trẻ trong gương và để trẻ nhìn thấy biểu cảm của chính mình trong gương.

## Hướng dẫn của chuyên gia
- Trò chơi này phù hợp cho trẻ trên 4 tháng tuổi.
- Bố mẹ nên chú ý quan sát biểu hiện và cử động của trẻ bất cứ lúc nào. Nếu trẻ không vui thì dừng hoạt động hoặc tránh xa gương và tiến hành từng bước một.

> “Ai đây nhỉ?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 3, 6,
       'Một tấm gương.', ARRAY['Một tấm gương']::text[], '/static/activities/g026/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng thị giác, Kỹ năng xã hội, Cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', 1, 'Bố mẹ chỉ vào trong gương và nói “con”, sau đó vỗ về trẻ và chỉ vào trẻ, nói “con”. Bố mẹ chỉ vào mình trong gương và nói “mẹ (bố)”, sau đó chỉ vào mình và nói “mẹ (bố)”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', 2, 'Hướng dẫn trẻ chạm, vỗ nhẹ vào gương để tạo sự tò mò, thích thú với bản thân và bố mẹ trong gương.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', 3, 'Khi trẻ khóc hoặc cười, bạn cũng có thể nhìn trẻ trong gương và để trẻ nhìn thấy biểu cảm của chính mình trong gương.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', 'image', '/static/activities/g026/main.jpg', '“Ai đây nhỉ?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'a7fa0751-d1bd-520d-906d-2ddfbb1d8b31', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g027: Chạm và reo (trang PDF 66)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '27a4031c-27b6-5923-9938-ad674bff5814', 'Chạm và reo', 'Kỹ năng phát triển: Phối hợp tay mắt, Hiểu mối liên hệ giữa các sự vật.', '**Kỹ năng phát triển:** Phối hợp tay mắt, Hiểu mối liên hệ giữa các sự vật

## Chuẩn bị
- **Không gian:** Giường hoặc ghế sofa.
- **Tư thế:** Bố mẹ bế trẻ mặt đối mặt với bố mẹ.
- **Đồ dùng:** Một cái lục lạc và vài sợi dây.

## Các bước thực hiện
1. Bố mẹ buộc một sợi dây vào lục lạc, treo trước mặt trẻ, để lục lạc chạm vào tay trẻ nhằm khơi dậy sự thích thú của trẻ, đồng thời hướng dẫn trẻ tích cực vỗ và chạm vào lục lạc.
2. Sau khi trẻ chạm vào lục lạc và phát ra âm thanh, bố mẹ có thể mô tả cho trẻ biết là: “Ngay khi con chạm vào, lục lạc sẽ vang lên”.

## Hướng dẫn của chuyên gia
- Nên chọn lục lạc có màu sắc tươi sáng, âm thanh dễ chịu.
- Chiều cao và vị trí của lục lạc treo phải phù hợp để trẻ dễ dàng chạm vào.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 3, 6,
       'Một cái lục lạc và vài sợi dây.', ARRAY['Một cái lục lạc và vài sợi dây']::text[], '/static/activities/g027/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Phối hợp tay mắt, Hiểu mối liên hệ giữa các sự vật.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('27a4031c-27b6-5923-9938-ad674bff5814', 1, 'Bố mẹ buộc một sợi dây vào lục lạc, treo trước mặt trẻ, để lục lạc chạm vào tay trẻ nhằm khơi dậy sự thích thú của trẻ, đồng thời hướng dẫn trẻ tích cực vỗ và chạm vào lục lạc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('27a4031c-27b6-5923-9938-ad674bff5814', 2, 'Sau khi trẻ chạm vào lục lạc và phát ra âm thanh, bố mẹ có thể mô tả cho trẻ biết là: “Ngay khi con chạm vào, lục lạc sẽ vang lên”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('27a4031c-27b6-5923-9938-ad674bff5814', 'image', '/static/activities/g027/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '27a4031c-27b6-5923-9938-ad674bff5814', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g028: “Bạn lật đật” nhỏ (trang PDF 67, 68)
-- Cần duyệt: Bước 2 trong sách bị in nhầm từ trò “Vượt chướng ngại vật”; giữ nguyên theo sách, cần biên tập lại.
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '4f1a46a9-898b-590d-9f34-6bf63aaed40f', '“Bạn lật đật” nhỏ', '“Con yêu ơi, nhìn đồ chơi này”', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Sức mạnh phần thân trên, Khả năng quan sát trực quan

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** 3 đồ chơi mà trẻ yêu thích.

## Các bước thực hiện
1. Tùy theo khả năng ngồi của trẻ, bố mẹ nên ôm eo trẻ hoặc để trẻ tự ngồi. Đặt món đồ chơi mà trẻ yêu thích ở phía trước và phía trên rồi nói: “Con nhìn đồ chơi để cầm lấy nhé!” để hướng dẫn trẻ nhìn và nhặt đồ chơi.
2. Sau khi bé lấy được đồ chơi, ba mẹ hãy vỗ tay khen ngợi, khích lệ bé: “Con giỏi quá!”. Tiếp theo, mẹ đưa thêm yêu cầu: “Con hãy quay lại và mang đồ chơi về phía mẹ nhé.” Ba mẹ hướng dẫn bé bước qua chân ba một lần nữa từ phía bên kia và quay lại điểm xuất phát.

## Hướng dẫn của chuyên gia
- Trò chơi này phù hợp với những trẻ đã ngồi được.
- Trong quá trình chơi, bố mẹ cần chú ý quan sát và có biện pháp bảo vệ kịp thời khi trẻ có dấu hiệu mất thăng bằng. Khi trẻ chơi được thành thạo thì có thể tăng độ khó lên bằng cách đặt đồ chơi ở phía sau trẻ để phát triển khả năng giữ thăng bằng từ phía sau của trẻ.

> “Con yêu ơi, nhìn đồ chơi này”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       '3 đồ chơi mà trẻ yêu thích.', ARRAY['3 đồ chơi mà trẻ yêu thích']::text[], '/static/activities/g028/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Sức mạnh phần thân trên, Khả năng quan sát trực quan.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4f1a46a9-898b-590d-9f34-6bf63aaed40f', 1, 'Tùy theo khả năng ngồi của trẻ, bố mẹ nên ôm eo trẻ hoặc để trẻ tự ngồi. Đặt món đồ chơi mà trẻ yêu thích ở phía trước và phía trên rồi nói: “Con nhìn đồ chơi để cầm lấy nhé!” để hướng dẫn trẻ nhìn và nhặt đồ chơi.', '/static/activities/g028/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4f1a46a9-898b-590d-9f34-6bf63aaed40f', 2, 'Sau khi bé lấy được đồ chơi, ba mẹ hãy vỗ tay khen ngợi, khích lệ bé: “Con giỏi quá!”. Tiếp theo, mẹ đưa thêm yêu cầu: “Con hãy quay lại và mang đồ chơi về phía mẹ nhé.” Ba mẹ hướng dẫn bé bước qua chân ba một lần nữa từ phía bên kia và quay lại điểm xuất phát.', '/static/activities/g028/step-2.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4f1a46a9-898b-590d-9f34-6bf63aaed40f', 'image', '/static/activities/g028/main.jpg', '“Con yêu ơi, nhìn đồ chơi này”', 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4f1a46a9-898b-590d-9f34-6bf63aaed40f', 'image', '/static/activities/g028/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4f1a46a9-898b-590d-9f34-6bf63aaed40f', 'image', '/static/activities/g028/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '4f1a46a9-898b-590d-9f34-6bf63aaed40f', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g029: Đuổi theo bóng nào! (trang PDF 69)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8064e660-59a4-5e44-a77b-f947c1815eff', 'Đuổi theo bóng nào!', '“Con yêu, đuổi theo quả bóng nào!”', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, chân, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Bé nằm sấp.
- **Đồ dùng:** Một quả bóng cao su, một gối, một khăn tắm.

## Các bước thực hiện
1. Đặt quả bóng cách mặt trẻ khoảng 1 m và nói với trẻ: “Con ơi, đuổi theo quả bóng đi!”
2. Nếu trẻ biết bò bằng tay và đầu gối thì đặt một chiếc gối trước mặt trẻ và hướng dẫn trẻ với tay qua gối để lấy bóng; nếu trẻ không bò về phía trước thì bạn có thể gấp khăn tắm lại, chuyền cho trẻ qua ngực và bụng của trẻ và nâng thân mình lên để trẻ quỳ trên tay và đầu gối của bạn.
3. Bố mẹ nhấc khăn tắm lên và từ từ di chuyển theo hướng bóng, hướng dẫn tay và đầu gối của trẻ di chuyển về phía trước. Khi trẻ chạm hoặc cầm bóng, bố mẹ vỗ tay khen ngợi: “Con thật tuyệt vời!”

## Hướng dẫn của chuyên gia
- Hướng dẫn bé chủ động di chuyển về phía trước. Nếu bé không bò, khoảng cách giữa bóng và bé có thể được rút ngắn lại. Nếu bé chưa đủ vận động, có thể thay bóng bằng một món đồ chơi mà bé thích thú và hai bố mẹ có thể cùng nhau hướng dẫn.
- Khi bé có thể bò bằng tay và đầu gối, khoảng cách giữa bé và đồ chơi có thể tăng lên; khi bé bò khéo léo và đến gần bóng thì có thể lăn bóng từ từ để tăng khoảng cách hoặc vẫy sang một bên để hướng dẫn bé bò và tăng tốc độ bò hoặc tập bò.

> “Con yêu, đuổi theo quả bóng nào!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Một quả bóng cao su, một gối, một khăn tắm.', ARRAY['Một quả bóng cao su', 'một gối', 'một khăn tắm']::text[], '/static/activities/g029/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, chân, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8064e660-59a4-5e44-a77b-f947c1815eff', 1, 'Đặt quả bóng cách mặt trẻ khoảng 1 m và nói với trẻ: “Con ơi, đuổi theo quả bóng đi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8064e660-59a4-5e44-a77b-f947c1815eff', 2, 'Nếu trẻ biết bò bằng tay và đầu gối thì đặt một chiếc gối trước mặt trẻ và hướng dẫn trẻ với tay qua gối để lấy bóng; nếu trẻ không bò về phía trước thì bạn có thể gấp khăn tắm lại, chuyền cho trẻ qua ngực và bụng của trẻ và nâng thân mình lên để trẻ quỳ trên tay và đầu gối của bạn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8064e660-59a4-5e44-a77b-f947c1815eff', 3, 'Bố mẹ nhấc khăn tắm lên và từ từ di chuyển theo hướng bóng, hướng dẫn tay và đầu gối của trẻ di chuyển về phía trước. Khi trẻ chạm hoặc cầm bóng, bố mẹ vỗ tay khen ngợi: “Con thật tuyệt vời!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8064e660-59a4-5e44-a77b-f947c1815eff', 'image', '/static/activities/g029/main.jpg', '“Con yêu, đuổi theo quả bóng nào!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8064e660-59a4-5e44-a77b-f947c1815eff', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g030: Chèo thuyền (trang PDF 70)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', 'Chèo thuyền', '“Chúng ta hãy chèo thuyền nào!”', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Khả năng tương tác

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một khăn dài.

## Các bước thực hiện
1. Gấp một chiếc khăn dài rồi quấn quanh ngực và thắt lưng của trẻ từ phía sau, đồng thời kéo hai đầu khăn sao cho trẻ có vẻ như đang ngồi trên thuyền khăn tắm.
2. Kéo khăn và lắc nhẹ trẻ qua lại, đồng thời nói “lái thuyền nhẹ”, “lái tiến”, “lái lùi”, “rẽ trái”, “sang phải”,...
3. Đặt tay trẻ lên trên khăn và khuyến khích trẻ nắm khăn bằng cả hai tay để giữ thăng bằng.

## Hướng dẫn của chuyên gia
- Mỗi khi bố mẹ di chuyển trẻ về một hướng thì cần cho trẻ đủ thời gian giữ thăng bằng để trẻ không bị ngã và sợ hãi.
- Khăn cần được gấp đủ rộng để đỡ ngực và eo của trẻ; đồng thời không nhấc khăn lên quá cao để tránh làm căng mặt trẻ.

> “Chúng ta hãy chèo thuyền nào!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Một khăn dài.', ARRAY['Một khăn dài']::text[], '/static/activities/g030/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Khả năng tương tác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', 1, 'Gấp một chiếc khăn dài rồi quấn quanh ngực và thắt lưng của trẻ từ phía sau, đồng thời kéo hai đầu khăn sao cho trẻ có vẻ như đang ngồi trên thuyền khăn tắm.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', 2, 'Kéo khăn và lắc nhẹ trẻ qua lại, đồng thời nói “lái thuyền nhẹ”, “lái tiến”, “lái lùi”, “rẽ trái”, “sang phải”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', 3, 'Đặt tay trẻ lên trên khăn và khuyến khích trẻ nắm khăn bằng cả hai tay để giữ thăng bằng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', 'image', '/static/activities/g030/main.jpg', '“Chúng ta hãy chèo thuyền nào!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e47e37c8-a1ac-538e-baa4-e8ce00b76ef6', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g031: Đường hầm (trang PDF 71)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '362baf73-cd3d-51df-9190-b40f1357724e', 'Đường hầm', 'Sau khi trẻ vào đường hầm, trẻ có thể ở trong hộp một lúc để nhìn và chạm vào.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Cảm giác không gian, Khả năng nhận thức ngôn ngữ, Tăng cường cảm xúc

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Bé nằm sấp.
- **Đồ dùng:** Một hộp bìa cứng rỗng lớn hơn cơ thể trẻ, một món đồ chơi trẻ yêu thích.

## Các bước thực hiện
1. Sử dụng một hộp bìa cứng rỗng để tạo thành một đường hầm và đặt trước mặt trẻ.
2. Bố mẹ nằm phía bên kia đường hầm, gọi tên con và nói: “Con, bố mẹ ở đây, con bò qua đây nào!”
3. Sau khi trẻ bò tới, bố mẹ ôm hoặc hôn trẻ thật nồng nhiệt.

## Hướng dẫn của chuyên gia
- Nếu ban đầu trẻ chưa muốn bò qua, bố mẹ có thể hướng dẫn cách bò qua hoặc có thể kích thích trẻ bằng những món đồ chơi mà trẻ yêu thích.
- Bố mẹ có thể treo một số dây ruy băng vào hộp bìa cứng để trẻ tháo dây ruy băng ra để tiến về phía trước.
- Khi trẻ đã quen với trò chơi, bố mẹ có thể ghép nhiều hộp bìa cứng lại với nhau để tạo thành một đường hầm dài hơn.

> Sau khi trẻ vào đường hầm, trẻ có thể ở trong hộp một lúc để nhìn và chạm vào.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Một hộp bìa cứng rỗng lớn hơn cơ thể trẻ, một món đồ chơi trẻ yêu thích.', ARRAY['Một hộp bìa cứng rỗng lớn hơn cơ thể trẻ', 'một món đồ chơi trẻ yêu thích']::text[], '/static/activities/g031/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Cảm giác không gian, Khả năng nhận thức ngôn ngữ, Tăng cường cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('362baf73-cd3d-51df-9190-b40f1357724e', 1, 'Sử dụng một hộp bìa cứng rỗng để tạo thành một đường hầm và đặt trước mặt trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('362baf73-cd3d-51df-9190-b40f1357724e', 2, 'Bố mẹ nằm phía bên kia đường hầm, gọi tên con và nói: “Con, bố mẹ ở đây, con bò qua đây nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('362baf73-cd3d-51df-9190-b40f1357724e', 3, 'Sau khi trẻ bò tới, bố mẹ ôm hoặc hôn trẻ thật nồng nhiệt.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('362baf73-cd3d-51df-9190-b40f1357724e', 'image', '/static/activities/g031/main.jpg', 'Sau khi trẻ vào đường hầm, trẻ có thể ở trong hộp một lúc để nhìn và chạm vào.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '362baf73-cd3d-51df-9190-b40f1357724e', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g032: Miếng dán nhỏ (trang PDF 72)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8922b2be-76f2-5161-be81-31791007a92c', 'Miếng dán nhỏ', '“Con thật dễ thương!”', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, chân, Phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số miếng dán hình quả táo.

## Các bước thực hiện
1. Xé lớp dính phía sau của nhãn dán và đặt nó lên thảm trải sàn với mặt dính hướng lên trên.
2. Hướng đồ chơi trẻ yêu thích về phía miếng dán để khuyến khích trẻ lăn liên tục.
3. Sau khi trẻ có nhiều miếng dán dính trên người, hãy chỉ các miếng dán đó về phía trẻ và nói: “Nhìn này, quả táo đã dính vào con rồi”.

## Hướng dẫn của chuyên gia
- Khi chơi lại trò chơi này, bố mẹ có thể ngừng nhắc trẻ rằng trên người trẻ có các nhãn dán và xem liệu trẻ có thể tự mình tìm thấy các nhãn dán hay không.
- Sau khi chơi một vòng, bố mẹ không cần phải trêu chọc trẻ bằng đồ chơi nữa, trẻ sẽ tận hưởng niềm vui khi tự mình lăn và làm “táo”!
- Bố mẹ có thể cùng trẻ lăn và sau đó bóc miếng dán táo của nhau.

> “Con thật dễ thương!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Một số miếng dán hình quả táo.', ARRAY['Một số miếng dán hình quả táo']::text[], '/static/activities/g032/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, chân, Phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8922b2be-76f2-5161-be81-31791007a92c', 1, 'Xé lớp dính phía sau của nhãn dán và đặt nó lên thảm trải sàn với mặt dính hướng lên trên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8922b2be-76f2-5161-be81-31791007a92c', 2, 'Hướng đồ chơi trẻ yêu thích về phía miếng dán để khuyến khích trẻ lăn liên tục.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8922b2be-76f2-5161-be81-31791007a92c', 3, 'Sau khi trẻ có nhiều miếng dán dính trên người, hãy chỉ các miếng dán đó về phía trẻ và nói: “Nhìn này, quả táo đã dính vào con rồi”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8922b2be-76f2-5161-be81-31791007a92c', 'image', '/static/activities/g032/main.jpg', '“Con thật dễ thương!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8922b2be-76f2-5161-be81-31791007a92c', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g033: Tạo ra âm thanh (trang PDF 73)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '79aed92e-67db-5856-ac58-adb39b563807', 'Tạo ra âm thanh', 'Nếu trẻ không thực hiện được các động tác tay trên thì bố mẹ có thể nắm tay trẻ để thực hiện.', '**Kỹ năng phát triển:** Khả năng làm việc bằng cả hai tay, Cảm giác về nhịp điệu

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi, mặt đối mặt với bố mẹ.
- **Đồ dùng:** Có thể sử dụng 1 - 2 chiếc búa nhựa đồ chơi (hoặc lục lạc hay khối xây dựng, các đồ chơi khác mà trẻ có thể cầm trên tay).

## Các bước thực hiện
1. Bố mẹ mỗi tay cầm một chiếc maracas (đồ chơi dùng để lắc tạo ra âm thanh), ngân nga một bài hát thiếu nhi nhịp nhàng trong khi lắc những chiếc maracas bằng cả hai tay để tạo ra âm thanh.
2. Cho trẻ cầm búa nhựa đồ chơi ở mỗi tay và hướng dẫn trẻ lắc cả hai tay vào nhau.
3. Bố mẹ làm mẫu và hướng dẫn trẻ thử các động tác bằng cả hai tay, ví dụ như cầm búa bằng cả hai tay và đánh vào nhau, đổi búa từ tay trái sang tay phải rồi đổi búa từ tay phải sang tay trái, đổi tay qua lại,...

## Hướng dẫn của chuyên gia
- Sau khi bố mẹ lấy đồ chơi ra, trước tiên bố mẹ có thể cho trẻ chơi với đồ chơi một cách thoải mái và khám phá tự do.
- Các động tác trình diễn của bố mẹ phải chậm rãi, nhịp điệu nhịp nhàng, tạo ra âm thanh để thu hút trẻ chú ý đến động tác của bố mẹ và bắt chước.
- Bố mẹ cũng có thể hát những bài hát thiếu nhi nhịp nhàng theo nhịp gõ của trẻ, ví dụ hát bài hát tiếng Anh “Five Little Ducks”. Khi “Quack, Quack, Quack, Quack” trở thành “One Two Three Four”, hãy hướng dẫn trẻ lắc hoặc gõ đồ chơi theo nhịp nhạc. Khi trẻ điều khiển đồ chơi phát ra âm thanh bằng cách lắc tay sẽ càng kích thích trẻ thích thú khi chơi đồ chơi và mang lại cảm giác thỏa mãn trọn vẹn.

> Nếu trẻ không thực hiện được các động tác tay trên thì bố mẹ có thể nắm tay trẻ để thực hiện.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Có thể sử dụng 1 - 2 chiếc búa nhựa đồ chơi (hoặc lục lạc hay khối xây dựng, các đồ chơi khác mà trẻ có thể cầm trên tay).', ARRAY['Có thể sử dụng 1 - 2 chiếc búa nhựa đồ chơi (hoặc lục lạc hay khối xây dựng', 'các đồ chơi khác mà trẻ có thể cầm trên tay)']::text[], '/static/activities/g033/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng làm việc bằng cả hai tay, Cảm giác về nhịp điệu.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79aed92e-67db-5856-ac58-adb39b563807', 1, 'Bố mẹ mỗi tay cầm một chiếc maracas (đồ chơi dùng để lắc tạo ra âm thanh), ngân nga một bài hát thiếu nhi nhịp nhàng trong khi lắc những chiếc maracas bằng cả hai tay để tạo ra âm thanh.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79aed92e-67db-5856-ac58-adb39b563807', 2, 'Cho trẻ cầm búa nhựa đồ chơi ở mỗi tay và hướng dẫn trẻ lắc cả hai tay vào nhau.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79aed92e-67db-5856-ac58-adb39b563807', 3, 'Bố mẹ làm mẫu và hướng dẫn trẻ thử các động tác bằng cả hai tay, ví dụ như cầm búa bằng cả hai tay và đánh vào nhau, đổi búa từ tay trái sang tay phải rồi đổi búa từ tay phải sang tay trái, đổi tay qua lại,...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79aed92e-67db-5856-ac58-adb39b563807', 'image', '/static/activities/g033/main.jpg', 'Nếu trẻ không thực hiện được các động tác tay trên thì bố mẹ có thể nắm tay trẻ để thực hiện.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '79aed92e-67db-5856-ac58-adb39b563807', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g034: Kho báu trong lọ (trang PDF 74)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '10afa5d1-db1c-5b73-8de5-b533926d8e6a', 'Kho báu trong lọ', 'Bố mẹ có thể xem trẻ biểu diễn “nhổ củ cà rốt” trong khi hát một bài hát thiếu nhi nào đó cho phù hợp với hoạt động này của trẻ.', '**Kỹ năng phát triển:** Khả năng nắm tay, Khả năng phối hợp tay, mắt, Sức mạnh phần thân trên

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một hộp bìa cứng cỡ vừa, một dao đa năng, một kéo, hai bút màu và một đĩa,...

## Các bước thực hiện
1. Bố mẹ cắt nắp hộp, dùng kéo cắt giấy thành hình vài miếng cà rốt rồi dùng bút màu cam và xanh tô màu để tạo thành “củ cà rốt”. Tiếp theo, dùng dao cắt nhiều đường trên thành hộp bìa cứng. Chiều dài của khe hộp xấp xỉ bằng chiều rộng phần giữa của “củ cà rốt”, đảm bảo có thể nhét được một nửa số “củ cà rốt”.
2. Bố mẹ nhét tất cả các “củ cà rốt” vào hộp, đặt trước mặt trẻ và nói: “Con ơi, rút cà rốt ra nào!”
3. Nếu trẻ không chịu rút ra, trước tiên bố mẹ có thể làm mẫu bằng cách rút “củ cà rốt” ra và đặt lên cái đĩa gần đó, sau đó hướng dẫn trẻ rút củ cà rốt ra. Nếu trẻ cố gắng rút ra nhưng không được thì bố mẹ có thể rút ra; giúp trẻ kéo ra ngoài vài lần.

## Hướng dẫn của chuyên gia
- Ban đầu, thẻ cà rốt có thể được đưa nhẹ vào khe, giúp trẻ dễ dàng rút ra khi khả năng của trẻ được cải thiện. Sau này có thể yêu cầu trẻ nhét cà rốt vào để tăng độ khó cho trò chơi.
- Bố mẹ cần quan sát xem trẻ có thể giữ hộp bìa cứng bằng tay kia trong khi chơi hay không. Nếu trẻ không biết giữ, bố mẹ có thể giúp trẻ cách giữ hộp để tăng trải nghiệm thành công trong trò chơi cho trẻ. Nhưng đồng thời, cần dừng lại kịp thời sự trợ giúp của bố mẹ khi trẻ đã biết cách làm và khuyến khích trẻ tự hoàn thành.

> Bố mẹ có thể xem trẻ biểu diễn “nhổ củ cà rốt” trong khi hát một bài hát thiếu nhi nào đó cho phù hợp với hoạt động này của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 6, 9,
       'Một hộp bìa cứng cỡ vừa, một dao đa năng, một kéo, hai bút màu và một đĩa,...', ARRAY['Một hộp bìa cứng cỡ vừa', 'một dao đa năng', 'một kéo', 'hai bút màu và một đĩa,']::text[], '/static/activities/g034/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng nắm tay, Khả năng phối hợp tay, mắt, Sức mạnh phần thân trên.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('10afa5d1-db1c-5b73-8de5-b533926d8e6a', 1, 'Bố mẹ cắt nắp hộp, dùng kéo cắt giấy thành hình vài miếng cà rốt rồi dùng bút màu cam và xanh tô màu để tạo thành “củ cà rốt”. Tiếp theo, dùng dao cắt nhiều đường trên thành hộp bìa cứng. Chiều dài của khe hộp xấp xỉ bằng chiều rộng phần giữa của “củ cà rốt”, đảm bảo có thể nhét được một nửa số “củ cà rốt”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('10afa5d1-db1c-5b73-8de5-b533926d8e6a', 2, 'Bố mẹ nhét tất cả các “củ cà rốt” vào hộp, đặt trước mặt trẻ và nói: “Con ơi, rút cà rốt ra nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('10afa5d1-db1c-5b73-8de5-b533926d8e6a', 3, 'Nếu trẻ không chịu rút ra, trước tiên bố mẹ có thể làm mẫu bằng cách rút “củ cà rốt” ra và đặt lên cái đĩa gần đó, sau đó hướng dẫn trẻ rút củ cà rốt ra. Nếu trẻ cố gắng rút ra nhưng không được thì bố mẹ có thể rút ra; giúp trẻ kéo ra ngoài vài lần.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('10afa5d1-db1c-5b73-8de5-b533926d8e6a', 'image', '/static/activities/g034/main.jpg', 'Bố mẹ có thể xem trẻ biểu diễn “nhổ củ cà rốt” trong khi hát một bài hát thiếu nhi nào đó cho phù hợp với hoạt động này của trẻ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '10afa5d1-db1c-5b73-8de5-b533926d8e6a', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g035: Tìm kiếm đồ chơi (trang PDF 75)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e0e889f5-e5d9-52d6-8189-727f505ddaf7', 'Tìm kiếm đồ chơi', '“Đồ chơi của em ở trong hộp này!”', '**Kỹ năng phát triển:** Khả năng phối hợp tay, mắt, Khả năng nắm tay, Khả năng giải quyết vấn đề

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một số đồ chơi nhỏ mà trẻ yêu thích, một cuộn băng dính, một giỏ đựng đồ.

## Các bước thực hiện
1. Đặt những món đồ chơi yêu thích của trẻ vào một chiếc giỏ vuông, sau đó dùng băng dính thân thiện với môi trường dán một vài dải theo chiều ngang, chiều dọc và đường chéo lên trên mặt giỏ.
2. Bố mẹ đưa đồ chơi cho trẻ và nói: “Con ơi, đồ chơi ở trong giỏ này.” Trước tiên, bố mẹ có thể làm mẫu, sau đó hướng dẫn trẻ lấy đồ chơi ra.
3. Khi trẻ lấy đồ chơi ra, bố mẹ ngay lập tức khẳng định với trẻ: “Con thật tuyệt vời!”

## Hướng dẫn của chuyên gia
- Ban đầu, bạn có thể dán một vài miếng băng dính lên để trẻ lấy ra dễ dàng hơn. Khi khả năng của trẻ phát triển, bạn có thể tăng dần số lượng băng dính và giảm khoảng trống có thể lấy ra, mang đến cho trẻ những thử thách lớn hơn. Nhưng hãy đảm bảo có chỗ cho đồ chơi cho vào hoặc lấy ra.
- Ở giai đoạn sau, bạn cũng có thể sử dụng giỏ có lỗ và dây cao su đàn hồi để giảm thêm không gian có thể lấy ra và tăng độ khó khi lấy đồ chơi ra.

> “Đồ chơi của em ở trong hộp này!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 6, 9,
       'Một số đồ chơi nhỏ mà trẻ yêu thích, một cuộn băng dính, một giỏ đựng đồ.', ARRAY['Một số đồ chơi nhỏ mà trẻ yêu thích', 'một cuộn băng dính', 'một giỏ đựng đồ']::text[], '/static/activities/g035/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, mắt, Khả năng nắm tay, Khả năng giải quyết vấn đề.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e0e889f5-e5d9-52d6-8189-727f505ddaf7', 1, 'Đặt những món đồ chơi yêu thích của trẻ vào một chiếc giỏ vuông, sau đó dùng băng dính thân thiện với môi trường dán một vài dải theo chiều ngang, chiều dọc và đường chéo lên trên mặt giỏ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e0e889f5-e5d9-52d6-8189-727f505ddaf7', 2, 'Bố mẹ đưa đồ chơi cho trẻ và nói: “Con ơi, đồ chơi ở trong giỏ này.” Trước tiên, bố mẹ có thể làm mẫu, sau đó hướng dẫn trẻ lấy đồ chơi ra.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e0e889f5-e5d9-52d6-8189-727f505ddaf7', 3, 'Khi trẻ lấy đồ chơi ra, bố mẹ ngay lập tức khẳng định với trẻ: “Con thật tuyệt vời!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e0e889f5-e5d9-52d6-8189-727f505ddaf7', 'image', '/static/activities/g035/main.jpg', '“Đồ chơi của em ở trong hộp này!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e0e889f5-e5d9-52d6-8189-727f505ddaf7', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g036: Nhổ củ cà rốt (trang PDF 76)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '6e755d9a-ea4e-5970-b093-c29f90a94465', 'Nhổ củ cà rốt', 'Bố mẹ có thể chuẩn bị những chiếc lọ, cốc có kích cỡ khác nhau cũng như những đồ chơi nhỏ có kích thước, hình dạng và kết cấu khác nhau rồi cho vào lọ. Điều này không chỉ giúp tăng cường trải nghiệm xúc giác mà còn giúp trẻ học cách chơi nhiều hơn, chính xác hơn và phối hợp nhịp nhàng hơn thông qua những thay đổi liên tục trong trò chơi. Trẻ sẽ sử dụng bàn tay nhỏ để nắm bắt đồ vật.', '**Kỹ năng phát triển:** Khả năng phối hợp tay, mắt, Biết phân biệt kích thước và hình dạng, Sự trường tồn của đồ vật

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một hộp rỗng, vài ô tô đồ chơi, cốc, khối xếp hình, hạt cườm,...

## Các bước thực hiện
1. Chuẩn bị một chiếc hộp rỗng, cho chiếc ô tô đồ chơi mà trẻ yêu thích vào trong lọ, rồi nói với trẻ: “Xe mất rồi!” và “Con tìm nó nhé!”. Sau đó, để trẻ tìm cách lấy xe ra ngoài.
2. Lúc đầu, trẻ có thể lắc hộp và vô tình làm rung xe đẩy ra ngoài. Sau khi lặp lại nhiều lần, trẻ sẽ dần hiểu rằng mình có thể tìm thấy chiếc xe thông qua thao tác của chính tay mình.
3. Hướng dẫn trẻ thò tay vào trong hộp để lấy xe. Trẻ sẽ bắt đầu thấy hứng thú với không gian bên trong hộp.

## Hướng dẫn của chuyên gia
- Trẻ có thể sử dụng đồ chơi có nam châm bên trong với nhiều kích cỡ khác nhau để cảm nhận sự khác biệt về kích thước trong khi chơi, từ đó tạo thành sự tương phản về mặt thị giác.

> Bố mẹ có thể chuẩn bị những chiếc lọ, cốc có kích cỡ khác nhau cũng như những đồ chơi nhỏ có kích thước, hình dạng và kết cấu khác nhau rồi cho vào lọ. Điều này không chỉ giúp tăng cường trải nghiệm xúc giác mà còn giúp trẻ học cách chơi nhiều hơn, chính xác hơn và phối hợp nhịp nhàng hơn thông qua những thay đổi liên tục trong trò chơi. Trẻ sẽ sử dụng bàn tay nhỏ để nắm bắt đồ vật.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 6, 9,
       'Một hộp rỗng, vài ô tô đồ chơi, cốc, khối xếp hình, hạt cườm,...', ARRAY['Một hộp rỗng', 'vài ô tô đồ chơi', 'cốc', 'khối xếp hình', 'hạt cườm,']::text[], '/static/activities/g036/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, mắt, Biết phân biệt kích thước và hình dạng, Sự trường tồn của đồ vật.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6e755d9a-ea4e-5970-b093-c29f90a94465', 1, 'Chuẩn bị một chiếc hộp rỗng, cho chiếc ô tô đồ chơi mà trẻ yêu thích vào trong lọ, rồi nói với trẻ: “Xe mất rồi!” và “Con tìm nó nhé!”. Sau đó, để trẻ tìm cách lấy xe ra ngoài.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6e755d9a-ea4e-5970-b093-c29f90a94465', 2, 'Lúc đầu, trẻ có thể lắc hộp và vô tình làm rung xe đẩy ra ngoài. Sau khi lặp lại nhiều lần, trẻ sẽ dần hiểu rằng mình có thể tìm thấy chiếc xe thông qua thao tác của chính tay mình.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6e755d9a-ea4e-5970-b093-c29f90a94465', 3, 'Hướng dẫn trẻ thò tay vào trong hộp để lấy xe. Trẻ sẽ bắt đầu thấy hứng thú với không gian bên trong hộp.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('6e755d9a-ea4e-5970-b093-c29f90a94465', 'image', '/static/activities/g036/main.jpg', 'Bố mẹ có thể chuẩn bị những chiếc lọ, cốc có kích cỡ khác nhau cũng như những đồ chơi nhỏ có kích thước, hình dạng và kết cấu khác nhau rồi cho vào lọ. Điều này không chỉ giúp tăng cường trải nghiệm xúc giác mà còn giúp trẻ học cách chơi nhiều hơn, chính xác hơn và phối hợp nhịp nhàng hơn thông qua ', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '6e755d9a-ea4e-5970-b093-c29f90a94465', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g037: Đồ chơi biến mất rồi! (trang PDF 77)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '524eb5e4-c60a-5bcb-a8d4-b95bca04e147', 'Đồ chơi biến mất rồi!', 'Sau khi chơi trò chơi nhiều lần, trẻ sẽ nhớ rằng những thứ tồn tại sẽ không biến mất.', '**Kỹ năng phát triển:** Nhận thức về sự tồn tại của đối tượng, Khả năng phối hợp tay, mắt, Khả năng thị giác

## Chuẩn bị
- **Không gian:** Thảm lót sàn hoặc mặt bàn.
- **Tư thế:** Trẻ ngồi trên ghế sofa hoặc trong vòng tay của bố, quay mặt về phía mẹ.
- **Đồ dùng:** Một cái lục lạc và một chiếc khăn nhỏ.

## Các bước thực hiện
1. Rung tiếng lục lạc cách trẻ 1 - 2 m để thu hút sự chú ý của trẻ, đồng thời nói với trẻ: “lạch cạch”.
2. Lấy một chiếc khăn nhỏ ra, dùng khăn nhỏ che lục lạc lại và nói với giọng ngạc nhiên: “Ôi, đồ chơi mất rồi! Cái lục lạc đâu rồi?” Khuyến khích trẻ mở khăn tay ra và tìm tiếng lục lạc.
3. Nếu trẻ không phản ứng, bạn có thể nắm tay trẻ nhấc chiếc khăn nhỏ lên, tìm lục lạc và cho trẻ chơi một lúc.

## Hướng dẫn của chuyên gia
- Sau khi trẻ mở chiếc khăn nhỏ ra, trẻ phải nhìn đồ chơi hoặc đưa tay nhặt đồ chơi, điều này chứng tỏ trẻ đã hình thành khái niệm về sự tồn tại của đồ vật.

> Sau khi chơi trò chơi nhiều lần, trẻ sẽ nhớ rằng những thứ tồn tại sẽ không biến mất.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Một cái lục lạc và một chiếc khăn nhỏ.', ARRAY['Một cái lục lạc và một chiếc khăn nhỏ']::text[], '/static/activities/g037/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Nhận thức về sự tồn tại của đối tượng, Khả năng phối hợp tay, mắt, Khả năng thị giác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('524eb5e4-c60a-5bcb-a8d4-b95bca04e147', 1, 'Rung tiếng lục lạc cách trẻ 1 - 2 m để thu hút sự chú ý của trẻ, đồng thời nói với trẻ: “lạch cạch”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('524eb5e4-c60a-5bcb-a8d4-b95bca04e147', 2, 'Lấy một chiếc khăn nhỏ ra, dùng khăn nhỏ che lục lạc lại và nói với giọng ngạc nhiên: “Ôi, đồ chơi mất rồi! Cái lục lạc đâu rồi?” Khuyến khích trẻ mở khăn tay ra và tìm tiếng lục lạc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('524eb5e4-c60a-5bcb-a8d4-b95bca04e147', 3, 'Nếu trẻ không phản ứng, bạn có thể nắm tay trẻ nhấc chiếc khăn nhỏ lên, tìm lục lạc và cho trẻ chơi một lúc.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('524eb5e4-c60a-5bcb-a8d4-b95bca04e147', 'image', '/static/activities/g037/main.jpg', 'Sau khi chơi trò chơi nhiều lần, trẻ sẽ nhớ rằng những thứ tồn tại sẽ không biến mất.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '524eb5e4-c60a-5bcb-a8d4-b95bca04e147', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g038: Kéo vật bằng dây (trang PDF 78)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '91d4d697-83e9-5383-b352-d1855ecb970f', 'Kéo vật bằng dây', '“Con đã kéo con vịt qua. Tuyệt vời!”', '**Kỹ năng phát triển:** Hiểu mối quan hệ giữa các đồ vật, Khả năng quan sát, Phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Trẻ ngồi trong vòng tay bố, quay mặt về phía mẹ, mẹ ngồi phía bên kia bàn.
- **Đồ dùng:** Một con vịt đồ chơi có dây buộc và các đồ chơi có dây buộc khác.

## Các bước thực hiện
1. Mẹ lấy con vịt đồ chơi được buộc bằng dây ra và nói với trẻ một cách vui vẻ: “Con ơi, con nhìn này, đây là con vịt nhỏ”. Cho trẻ chơi với con vịt đồ chơi một lúc để khơi dậy sự thích thú của trẻ.
2. Mẹ đặt con vịt đồ chơi ở đầu kia của bàn để đảm bảo trẻ không thể với tới; đặt sợi dây ở vị trí mà trẻ có thể với tới.
3. Bố mẹ khuyến khích trẻ lấy con vịt đồ chơi và quan sát xem trẻ có thấy con vịt đồ chơi có thể bị kéo qua bằng cách kéo dây hay không. Nếu trẻ kéo con vịt qua bằng cách kéo dây, bố mẹ nên khen trẻ: “Con đã kéo được con vịt qua, thật tuyệt vời!”
4. Sau khi trẻ lấy được đồ chơi, trẻ có thể chơi một lúc. Khi trẻ không muốn chơi nữa, mẹ có thể đổi đồ chơi cho trẻ và thử lại.

## Hướng dẫn của chuyên gia
- Nếu ban đầu trẻ chưa biết cách thực hiện, bố mẹ có thể hỗ trợ một cách phù hợp để giảm độ khó của trò chơi.
- Nếu ở nhà không có con vịt đồ chơi có dây buộc, bạn có thể buộc đồ trang sức vào món đồ chơi yêu thích của trẻ.

> “Con đã kéo con vịt qua. Tuyệt vời!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Một con vịt đồ chơi có dây buộc và các đồ chơi có dây buộc khác.', ARRAY['Một con vịt đồ chơi có dây buộc và các đồ chơi có dây buộc khác']::text[], '/static/activities/g038/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Hiểu mối quan hệ giữa các đồ vật, Khả năng quan sát, Phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('91d4d697-83e9-5383-b352-d1855ecb970f', 1, 'Mẹ lấy con vịt đồ chơi được buộc bằng dây ra và nói với trẻ một cách vui vẻ: “Con ơi, con nhìn này, đây là con vịt nhỏ”. Cho trẻ chơi với con vịt đồ chơi một lúc để khơi dậy sự thích thú của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('91d4d697-83e9-5383-b352-d1855ecb970f', 2, 'Mẹ đặt con vịt đồ chơi ở đầu kia của bàn để đảm bảo trẻ không thể với tới; đặt sợi dây ở vị trí mà trẻ có thể với tới.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('91d4d697-83e9-5383-b352-d1855ecb970f', 3, 'Bố mẹ khuyến khích trẻ lấy con vịt đồ chơi và quan sát xem trẻ có thấy con vịt đồ chơi có thể bị kéo qua bằng cách kéo dây hay không. Nếu trẻ kéo con vịt qua bằng cách kéo dây, bố mẹ nên khen trẻ: “Con đã kéo được con vịt qua, thật tuyệt vời!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('91d4d697-83e9-5383-b352-d1855ecb970f', 4, 'Sau khi trẻ lấy được đồ chơi, trẻ có thể chơi một lúc. Khi trẻ không muốn chơi nữa, mẹ có thể đổi đồ chơi cho trẻ và thử lại.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('91d4d697-83e9-5383-b352-d1855ecb970f', 'image', '/static/activities/g038/main.jpg', '“Con đã kéo con vịt qua. Tuyệt vời!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '91d4d697-83e9-5383-b352-d1855ecb970f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g039: Bật công tắc đèn (trang PDF 79)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c4e7a3f5-6813-5398-a21f-e4cc5a17fb2f', 'Bật công tắc đèn', '“Tìm thấy công tắc rồi!”', '**Kỹ năng phát triển:** Hiểu mối quan hệ giữa các đồ vật, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Một căn phòng có đèn.
- **Tư thế:** Bố (mẹ) bế trẻ.
- **Đồ dùng:** Công tắc, đèn ở nhà.

## Các bước thực hiện
1. Bố mẹ bế trẻ, chỉ vào công tắc và nói: “Bật công tắc lên!”. Sau khi bật công tắc và đèn bật sáng, trẻ chỉ vào đèn và nói: “Đèn sáng rồi!”
2. Sau khi lặp lại vài lần, bạn có thể thử hỏi trẻ: “Đèn điện ở đâu con nhỉ?” Khuyến khích trẻ “tìm” đèn điện bằng mắt.

## Hướng dẫn của chuyên gia
- Bố mẹ cũng có thể giúp đôi tay nhỏ bé của trẻ bật công tắc đèn.
- Khi trẻ có thể tìm thấy ánh sáng bằng mắt thì khuyến khích trẻ chỉ vào công tắc bằng ngón tay.

> “Tìm thấy công tắc rồi!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Công tắc, đèn ở nhà.', ARRAY['Công tắc', 'đèn ở nhà']::text[], '/static/activities/g039/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Hiểu mối quan hệ giữa các đồ vật, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c4e7a3f5-6813-5398-a21f-e4cc5a17fb2f', 1, 'Bố mẹ bế trẻ, chỉ vào công tắc và nói: “Bật công tắc lên!”. Sau khi bật công tắc và đèn bật sáng, trẻ chỉ vào đèn và nói: “Đèn sáng rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c4e7a3f5-6813-5398-a21f-e4cc5a17fb2f', 2, 'Sau khi lặp lại vài lần, bạn có thể thử hỏi trẻ: “Đèn điện ở đâu con nhỉ?” Khuyến khích trẻ “tìm” đèn điện bằng mắt.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c4e7a3f5-6813-5398-a21f-e4cc5a17fb2f', 'image', '/static/activities/g039/main.jpg', '“Tìm thấy công tắc rồi!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c4e7a3f5-6813-5398-a21f-e4cc5a17fb2f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g040: Chạm vào cơ thể (trang PDF 80)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3858566c-6204-55bb-8aef-46379d45eca9', 'Chạm vào cơ thể', '“Cù lét”', '**Kỹ năng phát triển:** Khả năng xúc giác, Khả năng hiểu ngôn ngữ, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Giường, ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Trẻ ở tư thế nằm ngửa hoặc ngồi, quay mặt về phía bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ nói một cách thích thú: “Cù lét!” rồi đưa tay gãi vào người trẻ.
2. Sau khi gãi một lúc, dừng lại và quan sát phản ứng của trẻ. Nếu trẻ nhìn người lớn cười hoặc nhảy múa thì tiếp tục gãi cơ thể trẻ.
3. Trong khi bố mẹ gãi, trẻ nói: “Cù bụng!” “Cù chân!” Kết hợp các bộ phận cơ thể với lời nói.

## Hướng dẫn của chuyên gia
- Chú ý đến bộ phận nào của trẻ bị cù và mức độ cù như thế nào; điều này có thể thu hút sự chú ý của trẻ về phía bố mẹ.
- Đừng di chuyển động tác quá nhanh, nên có những khoảng dừng để bố mẹ và trẻ có cơ hội bắt đầu.

> “Cù lét”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Không có.', NULL, '/static/activities/g040/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng xúc giác, Khả năng hiểu ngôn ngữ, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3858566c-6204-55bb-8aef-46379d45eca9', 1, 'Bố mẹ nói một cách thích thú: “Cù lét!” rồi đưa tay gãi vào người trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3858566c-6204-55bb-8aef-46379d45eca9', 2, 'Sau khi gãi một lúc, dừng lại và quan sát phản ứng của trẻ. Nếu trẻ nhìn người lớn cười hoặc nhảy múa thì tiếp tục gãi cơ thể trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3858566c-6204-55bb-8aef-46379d45eca9', 3, 'Trong khi bố mẹ gãi, trẻ nói: “Cù bụng!” “Cù chân!” Kết hợp các bộ phận cơ thể với lời nói.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3858566c-6204-55bb-8aef-46379d45eca9', 'image', '/static/activities/g040/main.jpg', '“Cù lét”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3858566c-6204-55bb-8aef-46379d45eca9', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g041: Chơi bập bênh (trang PDF 81)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '82a5ce7e-ff35-5b96-9cfe-4553768c2538', 'Chơi bập bênh', 'Kỹ năng phát triển: Kỹ năng xã hội, Khả năng nghe, Sử dụng sức mạnh của cơ thể.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Khả năng nghe, Sử dụng sức mạnh của cơ thể

## Chuẩn bị
- **Không gian:** Sofa hoặc ghế.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ ngồi xuống và bắt chéo chân trẻ. Bố mẹ vừa giơ chân bắt chéo lên xuống vừa hát bài hát thiếu nhi nào đó.
2. Sau mỗi lượt chơi, hãy tạm dừng một lúc để xem phản ứng của trẻ. Nếu trẻ nhìn bố mẹ hoặc phát ra âm thanh “hmm”, nghĩa là bé muốn chơi lại và bố mẹ có thể tiếp tục chơi với trẻ.

## Lời bài hát / đồng dao
Bập bênh, bập bênh
Bập bênh, bập bênh
Nâng lên, hạ xuống
Vui thích quá đi!

## Hướng dẫn của chuyên gia
- Bố mẹ nên quan sát phản ứng của trẻ khi nâng và hạ thấp chân mình. Nếu trẻ lo lắng, hãy điều chỉnh mức độ một chút.
- Sau vòng chơi, nên có khoảng dừng để trẻ có cơ hội phản ứng, tương tác lại với bố mẹ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Không có.', NULL, '/static/activities/g041/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Khả năng nghe, Sử dụng sức mạnh của cơ thể.', true, 'Bập bênh, bập bênh
Bập bênh, bập bênh
Nâng lên, hạ xuống
Vui thích quá đi!';
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('82a5ce7e-ff35-5b96-9cfe-4553768c2538', 1, 'Bố mẹ ngồi xuống và bắt chéo chân trẻ. Bố mẹ vừa giơ chân bắt chéo lên xuống vừa hát bài hát thiếu nhi nào đó.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('82a5ce7e-ff35-5b96-9cfe-4553768c2538', 2, 'Sau mỗi lượt chơi, hãy tạm dừng một lúc để xem phản ứng của trẻ. Nếu trẻ nhìn bố mẹ hoặc phát ra âm thanh “hmm”, nghĩa là bé muốn chơi lại và bố mẹ có thể tiếp tục chơi với trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('82a5ce7e-ff35-5b96-9cfe-4553768c2538', 'image', '/static/activities/g041/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '82a5ce7e-ff35-5b96-9cfe-4553768c2538', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g042: Một, hai, ba, bay lên! (trang PDF 82)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'daeda74b-9aee-54ab-9a68-f32ecc9a651a', 'Một, hai, ba, bay lên!', 'Hãy tạm dừng mỗi lần bạn làm điều đó để trẻ có cơ hội phản ứng và tham gia tích cực.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Khả năng giữ thăng bằng, Khả năng tương tác

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Trẻ và bố mẹ mặt đối mặt.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ đối mặt với trẻ, đặt tay vào nách trẻ và bế trẻ lên.
2. Bố mẹ nói: “Một, hai, ba, bay lên!” Khi nói “bay lên”, hãy giơ hai tay lên cao và nhấc trẻ lên trên đầu.
3. Đặt trẻ xuống, đợi một lúc và quan sát phản ứng của trẻ. Khi trẻ nhìn người lớn cười hoặc nhảy múa có nghĩa là trẻ muốn làm lại và bố mẹ có thể bế trẻ lên lần nữa.

## Hướng dẫn của chuyên gia
- Trò chơi này thích hợp để các ông bố chơi cùng con.
- Khi nâng trẻ lên cao hơn, hãy quan sát độ cao mà trẻ thấy vui nhất. Nếu trẻ có vẻ lo lắng thì hãy hạ thấp độ cao.

> Hãy tạm dừng mỗi lần bạn làm điều đó để trẻ có cơ hội phản ứng và tham gia tích cực.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 6, 9,
       'Không có.', NULL, '/static/activities/g042/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Khả năng giữ thăng bằng, Khả năng tương tác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('daeda74b-9aee-54ab-9a68-f32ecc9a651a', 1, 'Bố mẹ đối mặt với trẻ, đặt tay vào nách trẻ và bế trẻ lên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('daeda74b-9aee-54ab-9a68-f32ecc9a651a', 2, 'Bố mẹ nói: “Một, hai, ba, bay lên!” Khi nói “bay lên”, hãy giơ hai tay lên cao và nhấc trẻ lên trên đầu.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('daeda74b-9aee-54ab-9a68-f32ecc9a651a', 3, 'Đặt trẻ xuống, đợi một lúc và quan sát phản ứng của trẻ. Khi trẻ nhìn người lớn cười hoặc nhảy múa có nghĩa là trẻ muốn làm lại và bố mẹ có thể bế trẻ lên lần nữa.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('daeda74b-9aee-54ab-9a68-f32ecc9a651a', 'image', '/static/activities/g042/main.jpg', 'Hãy tạm dừng mỗi lần bạn làm điều đó để trẻ có cơ hội phản ứng và tham gia tích cực.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'daeda74b-9aee-54ab-9a68-f32ecc9a651a', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g043: Trèo qua người (trang PDF 83)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '4bdce87f-1829-5bad-8c24-867d54723dc1', 'Trèo qua người', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Thể hiện cảm xúc.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một ô tô đồ chơi.

## Các bước thực hiện
1. Bố mẹ nằm ở giữa giường, trẻ nằm một bên người bố, mẹ nằm bên kia. Bố cầm chiếc ô tô đồ chơi bé yêu thích.
2. Mẹ dùng ô tô đồ chơi để trêu con và khuyến khích con bò về phía trên người bố.
3. Khi trẻ trèo qua người bố, mẹ vỗ tay khen “Con trèo được rồi” và thưởng cho trẻ một ô tô đồ chơi để chơi.

## Hướng dẫn của chuyên gia
- Trò chơi này nên chơi sau khi trẻ đã biết bò. Nếu trẻ đã thành thạo việc trườn qua người bố, bạn có thể để bụng cao hơn một chút.
- Trò chơi này sẽ rèn luyện cho trẻ phối hợp bò bằng tay và chân. Khi trẻ đã hoàn thành thành thạo các động tác, mẹ cũng có thể nằm cạnh bố, đặt đồ chơi sang phía bên kia của trẻ và hướng dẫn trẻ “trèo lên” qua lấy xe.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 9, 12,
       'Một ô tô đồ chơi.', ARRAY['Một ô tô đồ chơi']::text[], NULL, 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4bdce87f-1829-5bad-8c24-867d54723dc1', 1, 'Bố mẹ nằm ở giữa giường, trẻ nằm một bên người bố, mẹ nằm bên kia. Bố cầm chiếc ô tô đồ chơi bé yêu thích.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4bdce87f-1829-5bad-8c24-867d54723dc1', 2, 'Mẹ dùng ô tô đồ chơi để trêu con và khuyến khích con bò về phía trên người bố.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4bdce87f-1829-5bad-8c24-867d54723dc1', 3, 'Khi trẻ trèo qua người bố, mẹ vỗ tay khen “Con trèo được rồi” và thưởng cho trẻ một ô tô đồ chơi để chơi.', NULL);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '4bdce87f-1829-5bad-8c24-867d54723dc1', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g044: Đồ chơi trên ghế sofa (trang PDF 84)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c0f4aa82-5c13-512a-b26d-b11e1a52ad81', 'Đồ chơi trên ghế sofa', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng

## Chuẩn bị
- **Không gian:** Thảm trải sàn, ghế sofa.
- **Tư thế:** Trẻ bò, đứng.
- **Đồ dùng:** 2 món đồ chơi mà trẻ yêu thích.

## Các bước thực hiện
1. Dùng đồ chơi mà trẻ yêu thích để khuyến khích trẻ bò trên thảm trải sàn, dẫn bé đến ghế sofa, đặt đồ chơi lên ghế sofa và hướng dẫn trẻ lấy đồ chơi từ ghế sofa: “Con ơi, đến lấy đồ chơi đi nào!”
2. Khi trẻ bám vào ghế sofa đứng dậy, thưởng cho trẻ đứng cạnh ghế sofa chơi đồ chơi một lúc.
3. Đặt một món đồ chơi yêu thích khác của trẻ ở phía sau ghế sofa sao cho có thể nhìn thấy nhưng ngoài tầm với. Bố mẹ nói: “Con ơi, đến lấy đồ chơi đi nào!” Khuyến khích trẻ bò lên ghế sofa để lấy đồ chơi.

## Hướng dẫn của chuyên gia
- Khi trẻ bò đến ghế sofa, bố mẹ có thể nhấc đồ chơi lên và hướng dẫn bé đứng dậy lấy đồ chơi.
- Khi trẻ muốn trèo lên ghế sofa nhưng không thể làm được, bố mẹ có thể nhấc một chân của trẻ từ phía sau để giúp trẻ trèo lên ghế sofa. Đợi một lát, nếu trẻ vẫn chưa thể trèo lên ghế sofa hoàn toàn, bố mẹ có thể đẩy trẻ về phía trước và vỗ nhẹ vào mông trẻ để giúp trẻ trèo lên.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 9, 12,
       '2 món đồ chơi mà trẻ yêu thích.', ARRAY['2 món đồ chơi mà trẻ yêu thích']::text[], '/static/activities/g044/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c0f4aa82-5c13-512a-b26d-b11e1a52ad81', 1, 'Dùng đồ chơi mà trẻ yêu thích để khuyến khích trẻ bò trên thảm trải sàn, dẫn bé đến ghế sofa, đặt đồ chơi lên ghế sofa và hướng dẫn trẻ lấy đồ chơi từ ghế sofa: “Con ơi, đến lấy đồ chơi đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c0f4aa82-5c13-512a-b26d-b11e1a52ad81', 2, 'Khi trẻ bám vào ghế sofa đứng dậy, thưởng cho trẻ đứng cạnh ghế sofa chơi đồ chơi một lúc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c0f4aa82-5c13-512a-b26d-b11e1a52ad81', 3, 'Đặt một món đồ chơi yêu thích khác của trẻ ở phía sau ghế sofa sao cho có thể nhìn thấy nhưng ngoài tầm với. Bố mẹ nói: “Con ơi, đến lấy đồ chơi đi nào!” Khuyến khích trẻ bò lên ghế sofa để lấy đồ chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c0f4aa82-5c13-512a-b26d-b11e1a52ad81', 'image', '/static/activities/g044/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c0f4aa82-5c13-512a-b26d-b11e1a52ad81', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g045: Bé tập đứng (trang PDF 85)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c622b2be-9e2a-5606-832e-2573b40b0981', 'Bé tập đứng', '“Con ơi, hãy cầm lấy cốc!”', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Sức mạnh của đôi chân, Khả năng phối hợp tay với tay

## Chuẩn bị
- **Đồ dùng:** Cốc hoặc bình nhựa.

## Các bước thực hiện
1. Bố giữ mông trẻ bằng cả hai tay phía sau để giữ trẻ ở tư thế đứng. Mẹ cầm cốc hoặc bình nhựa trước mặt trẻ và nói: “Con cầm cốc đi!”. Trẻ cầm cốc bằng cả hai tay. Mẹ cũng cầm cốc.
2. Khi trẻ cầm cốc chắc chắn hơn, mẹ cố gắng thả tay ra và để trẻ tập đứng bằng tay để đảm bảo an toàn cho trẻ.
3. Sau khi trẻ đã đứng vững, bố có thể cố gắng thả tay ra, trong khi mẹ vỗ tay trước mặt khen ngợi: “Con thật tuyệt vời!” Nếu trẻ chưa vững hoặc sắp ngã, bố phải ngay lập tức ôm lấy trẻ và lặp lại nhiều lần trò chơi.

> “Con ơi, hãy cầm lấy cốc!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 9, 12,
       'Cốc hoặc bình nhựa.', ARRAY['Cốc hoặc bình nhựa']::text[], '/static/activities/g045/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Sức mạnh của đôi chân, Khả năng phối hợp tay với tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c622b2be-9e2a-5606-832e-2573b40b0981', 1, 'Bố giữ mông trẻ bằng cả hai tay phía sau để giữ trẻ ở tư thế đứng. Mẹ cầm cốc hoặc bình nhựa trước mặt trẻ và nói: “Con cầm cốc đi!”. Trẻ cầm cốc bằng cả hai tay. Mẹ cũng cầm cốc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c622b2be-9e2a-5606-832e-2573b40b0981', 2, 'Khi trẻ cầm cốc chắc chắn hơn, mẹ cố gắng thả tay ra và để trẻ tập đứng bằng tay để đảm bảo an toàn cho trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c622b2be-9e2a-5606-832e-2573b40b0981', 3, 'Sau khi trẻ đã đứng vững, bố có thể cố gắng thả tay ra, trong khi mẹ vỗ tay trước mặt khen ngợi: “Con thật tuyệt vời!” Nếu trẻ chưa vững hoặc sắp ngã, bố phải ngay lập tức ôm lấy trẻ và lặp lại nhiều lần trò chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c622b2be-9e2a-5606-832e-2573b40b0981', 'image', '/static/activities/g045/main.jpg', '“Con ơi, hãy cầm lấy cốc!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c622b2be-9e2a-5606-832e-2573b40b0981', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g046: “Con có thể lấy quả bóng!” (trang PDF 86)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '40b1e345-8fa1-5bee-bfa4-65aee08c1e54', '“Con có thể lấy quả bóng!”', '“Con đã đứng dậy được, thật tuyệt vời!”', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng

## Chuẩn bị
- **Không gian:** Bên tường.
- **Tư thế:** Trẻ ngồi quay mặt vào tường.
- **Đồ dùng:** Vài quả bóng bằng bông, một cuộn băng dính hai mặt và một giỏ nhỏ.

## Các bước thực hiện
1. Dùng băng dính hai mặt để dán một vài quả bóng bằng bông lên tường. Chiều cao phải vừa tầm với của trẻ khi ngồi. Khuyến khích trẻ đưa tay ra và nắm lấy quả bóng: “Con ơi, lấy quả bóng đi nào!”. Đặt giỏ nhỏ bên cạnh trẻ để trẻ thả quả bóng vào đó.
2. Bố mẹ nên dán những quả bóng bằng bông ở độ cao tương đương với chiều cao của trẻ.
3. Khi trẻ nhìn thấy quả bóng bằng bông ở trên cao, trước tiên bố mẹ nên quan sát xem trẻ có thể đứng vững bằng cách bám vào tường hay không, nếu trẻ không thể thì trẻ có thể nắm tay bố mẹ mà đứng lên.
4. Khuyến khích trẻ bắt quả bóng bằng bông và bỏ vào giỏ, nói: “Con có thể với được quả bóng, tuyệt vời! Hãy tiếp tục bắt quả bóng và bỏ vào giỏ nhé!”

## Hướng dẫn của chuyên gia
- Trong quá trình chơi, bố mẹ phải luôn chú ý bảo vệ trẻ để tránh bị ngã.
- Sau khi trẻ đứng dậy lần đầu và đã lấy xong các quả bóng bằng bông, bố mẹ có thể để trẻ chơi tự do với quả bóng.

> “Con đã đứng dậy được, thật tuyệt vời!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 9, 12,
       'Vài quả bóng bằng bông, một cuộn băng dính hai mặt và một giỏ nhỏ.', ARRAY['Vài quả bóng bằng bông', 'một cuộn băng dính hai mặt và một giỏ nhỏ']::text[], '/static/activities/g046/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('40b1e345-8fa1-5bee-bfa4-65aee08c1e54', 1, 'Dùng băng dính hai mặt để dán một vài quả bóng bằng bông lên tường. Chiều cao phải vừa tầm với của trẻ khi ngồi. Khuyến khích trẻ đưa tay ra và nắm lấy quả bóng: “Con ơi, lấy quả bóng đi nào!”. Đặt giỏ nhỏ bên cạnh trẻ để trẻ thả quả bóng vào đó.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('40b1e345-8fa1-5bee-bfa4-65aee08c1e54', 2, 'Bố mẹ nên dán những quả bóng bằng bông ở độ cao tương đương với chiều cao của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('40b1e345-8fa1-5bee-bfa4-65aee08c1e54', 3, 'Khi trẻ nhìn thấy quả bóng bằng bông ở trên cao, trước tiên bố mẹ nên quan sát xem trẻ có thể đứng vững bằng cách bám vào tường hay không, nếu trẻ không thể thì trẻ có thể nắm tay bố mẹ mà đứng lên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('40b1e345-8fa1-5bee-bfa4-65aee08c1e54', 4, 'Khuyến khích trẻ bắt quả bóng bằng bông và bỏ vào giỏ, nói: “Con có thể với được quả bóng, tuyệt vời! Hãy tiếp tục bắt quả bóng và bỏ vào giỏ nhé!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('40b1e345-8fa1-5bee-bfa4-65aee08c1e54', 'image', '/static/activities/g046/main.jpg', '“Con đã đứng dậy được, thật tuyệt vời!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '40b1e345-8fa1-5bee-bfa4-65aee08c1e54', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g047: Nhặt “hạt đậu” (trang PDF 87)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3130250d-d164-5a31-baca-5ba3f6841299', 'Nhặt “hạt đậu”', 'Lưu ý: Cả tay trái và tay phải của trẻ đều tham gia vào trò chơi này.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** 1 - 3 ống hút nhiều màu, 1 bát.

## Các bước thực hiện
1. Dùng kéo cắt ống hút thành từng đoạn nhỏ dài khoảng 1 cm, đặt lên bàn và hướng dẫn trẻ nhặt “hạt đậu”.
2. Sau khi trẻ dùng ngón tay nhặt “hạt đậu” lên, hãy hướng dẫn trẻ “đưa cho mẹ” và đặt “hạt đậu” vào bát do mẹ cầm.
3. Đặt vài “hạt đậu” lên bàn, hướng dẫn trẻ cầm bát bằng một tay và dùng tay kia đặt từng “hạt đậu” vào bát.

## Hướng dẫn của chuyên gia
- Trẻ ở độ tuổi này rất thích cho đồ chơi vào miệng để khám phá, vì vậy khi thực hiện hoạt động này, bố mẹ nên ngăn cấm trẻ đưa đồ chơi vào miệng.
- Ngoài việc sử dụng ống hút để làm “hạt đậu”, bố mẹ cũng có thể sử dụng các vật dụng khác trong cuộc sống hằng ngày để cho trẻ chơi.

> Lưu ý: Cả tay trái và tay phải của trẻ đều tham gia vào trò chơi này.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 9, 12,
       '1 - 3 ống hút nhiều màu, 1 bát.', ARRAY['1 - 3 ống hút nhiều màu', '1 bát']::text[], '/static/activities/g047/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3130250d-d164-5a31-baca-5ba3f6841299', 1, 'Dùng kéo cắt ống hút thành từng đoạn nhỏ dài khoảng 1 cm, đặt lên bàn và hướng dẫn trẻ nhặt “hạt đậu”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3130250d-d164-5a31-baca-5ba3f6841299', 2, 'Sau khi trẻ dùng ngón tay nhặt “hạt đậu” lên, hãy hướng dẫn trẻ “đưa cho mẹ” và đặt “hạt đậu” vào bát do mẹ cầm.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3130250d-d164-5a31-baca-5ba3f6841299', 3, 'Đặt vài “hạt đậu” lên bàn, hướng dẫn trẻ cầm bát bằng một tay và dùng tay kia đặt từng “hạt đậu” vào bát.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3130250d-d164-5a31-baca-5ba3f6841299', 'image', '/static/activities/g047/main.jpg', 'Lưu ý: Cả tay trái và tay phải của trẻ đều tham gia vào trò chơi này.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3130250d-d164-5a31-baca-5ba3f6841299', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g048: Đi tìm đồ chơi (trang PDF 88)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b05a097f-5348-521b-a1ab-9c63231836c8', 'Đi tìm đồ chơi', 'Sau khi trẻ tìm thấy đồ chơi, bố mẹ có thể gọi tên đồ chơi khi khen ngợi. Ví dụ, nếu trẻ tìm thấy bông tuyết, bố mẹ sẽ nói: “Con đã tìm thấy bông tuyết, thật tuyệt vời!”.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc ghế sofa.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một miếng cọ rửa, một chiếc kéo và một số đồ chơi nhỏ có thể nhét vào miếng cọ rửa.

## Các bước thực hiện
1. Dùng kéo cắt một vài đường trên miếng bọt biển của miếng cọ rửa rồi nhét những đồ chơi nhỏ vào đó như mô hình động vật nhỏ, nút áo, quả bóng nhỏ, hạt cườm, bông tuyết,... Một số đồ chơi lộ ra ngoài một chút để thu hút sự chú ý của trẻ.
2. Đưa miếng cọ rửa cho trẻ, chỉ vào các đồ chơi được nhét trong đó và khuyến khích trẻ tìm đồ chơi trong miếng bọt biển: “Có gì trong đó? Con hãy tìm nó nhé!”
3. Mỗi khi trẻ tìm được đồ chơi, hãy khen trẻ và lấy đồ chơi ra, để trẻ tiếp tục tìm kiếm cho đến khi tìm được hết đồ chơi.

## Hướng dẫn của chuyên gia
- Ban đầu, bố mẹ có thể giấu một số đồ chơi có kích thước lớn, chẳng hạn như mô hình động vật nhỏ, bông tuyết,... Khi khả năng của trẻ được cải thiện, đồ chơi có thể ngày càng nhỏ hơn.
- Trẻ cần có bố mẹ để cùng chơi trò chơi này và không nên sử dụng những đồ chơi quá nhỏ để trẻ tránh ăn nhầm.

> Sau khi trẻ tìm thấy đồ chơi, bố mẹ có thể gọi tên đồ chơi khi khen ngợi. Ví dụ, nếu trẻ tìm thấy bông tuyết, bố mẹ sẽ nói: “Con đã tìm thấy bông tuyết, thật tuyệt vời!”.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 9, 12,
       'Một miếng cọ rửa, một chiếc kéo và một số đồ chơi nhỏ có thể nhét vào miếng cọ rửa.', ARRAY['Một miếng cọ rửa', 'một chiếc kéo và một số đồ chơi nhỏ có thể nhét vào miếng cọ rửa']::text[], '/static/activities/g048/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b05a097f-5348-521b-a1ab-9c63231836c8', 1, 'Dùng kéo cắt một vài đường trên miếng bọt biển của miếng cọ rửa rồi nhét những đồ chơi nhỏ vào đó như mô hình động vật nhỏ, nút áo, quả bóng nhỏ, hạt cườm, bông tuyết,... Một số đồ chơi lộ ra ngoài một chút để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b05a097f-5348-521b-a1ab-9c63231836c8', 2, 'Đưa miếng cọ rửa cho trẻ, chỉ vào các đồ chơi được nhét trong đó và khuyến khích trẻ tìm đồ chơi trong miếng bọt biển: “Có gì trong đó? Con hãy tìm nó nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b05a097f-5348-521b-a1ab-9c63231836c8', 3, 'Mỗi khi trẻ tìm được đồ chơi, hãy khen trẻ và lấy đồ chơi ra, để trẻ tiếp tục tìm kiếm cho đến khi tìm được hết đồ chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b05a097f-5348-521b-a1ab-9c63231836c8', 'image', '/static/activities/g048/main.jpg', 'Sau khi trẻ tìm thấy đồ chơi, bố mẹ có thể gọi tên đồ chơi khi khen ngợi. Ví dụ, nếu trẻ tìm thấy bông tuyết, bố mẹ sẽ nói: “Con đã tìm thấy bông tuyết, thật tuyệt vời!”.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b05a097f-5348-521b-a1ab-9c63231836c8', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g049: Đôi tay khéo léo (trang PDF 89)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', 'Đôi tay khéo léo', '“Con hãy cho bông hoa giấy vào chai nhé!”', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay

## Chuẩn bị
- **Đồ dùng:** Giấy màu, một chai nước rỗng.

## Các bước thực hiện
1. Bố mẹ và trẻ cùng nhau xé tờ giấy thành các hình dạng và kích cỡ ngẫu nhiên.
2. Đưa chai nước cho bé và để bé tự khám phá, chơi với chai trước. Nếu trẻ không nhét hoa giấy vào bình, bố mẹ có thể hướng dẫn cách nhét hoa giấy vào bình và nói: “Mình cùng cho những bông hoa giấy vào chai nhé!”
3. Đưa chai cho trẻ và nói: “Con ơi, hãy cho hoa giấy vào bình nhé!” Hướng dẫn trẻ cho hoa giấy vào chai.

> “Con hãy cho bông hoa giấy vào chai nhé!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 9, 12,
       'Giấy màu, một chai nước rỗng.', ARRAY['Giấy màu', 'một chai nước rỗng']::text[], '/static/activities/g049/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', 1, 'Bố mẹ và trẻ cùng nhau xé tờ giấy thành các hình dạng và kích cỡ ngẫu nhiên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', 2, 'Đưa chai nước cho bé và để bé tự khám phá, chơi với chai trước. Nếu trẻ không nhét hoa giấy vào bình, bố mẹ có thể hướng dẫn cách nhét hoa giấy vào bình và nói: “Mình cùng cho những bông hoa giấy vào chai nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', 3, 'Đưa chai cho trẻ và nói: “Con ơi, hãy cho hoa giấy vào bình nhé!” Hướng dẫn trẻ cho hoa giấy vào chai.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', 'image', '/static/activities/g049/main.jpg', '“Con hãy cho bông hoa giấy vào chai nhé!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '05e5e8a5-f4dc-503e-a23d-9c2cf8423e57', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g050: Gọi tên đồ vật (trang PDF 90)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', 'Gọi tên đồ vật', '“Quả táo đây rồi!”', '**Kỹ năng phát triển:** Khả năng bắt chước ngôn ngữ, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi ở tư thế có thể nhìn thấy các đồ vật ngang tầm.
- **Đồ dùng:** Những đồ dùng thông thường trong gia đình như quả táo, quả bóng.

## Các bước thực hiện
1. Khi trẻ tập trung vào một đồ vật, bố mẹ có thể tận dụng cơ hội này để gọi tên chính xác đồ vật đó và cho trẻ sờ, chơi với đồ vật đó. Ví dụ, nếu trẻ nhìn một quả táo, bố mẹ sẽ nói “quả táo”, đưa quả táo cho trẻ và đồng thời nói “quả táo”. Sau khi trẻ lấy được quả táo, bố mẹ nói: “Quả táo, con lấy quả táo đi nào!”
2. Bố mẹ cũng có thể chỉ vào đồ vật, thu hút sự chú ý của trẻ rồi nói tên đồ vật đó.
3. Khi khả năng của trẻ phát triển, bố mẹ có thể hỏi trẻ các đồ vật thông dụng ở đâu, chẳng hạn như: “Quả bóng ở đâu con nhỉ?” và khuyến khích trẻ tìm ra.

## Hướng dẫn của chuyên gia
- Những món đồ bố mẹ lựa chọn là những món đồ thường thấy và sử dụng trong cuộc sống hằng ngày.
- Bố mẹ chỉ cần gọi tên món đồ hoặc mô tả ngắn gọn món đồ đó, ngôn ngữ nên ngắn gọn, chậm rãi và lặp lại.
- Bố mẹ nên đặt cho đồ vật những cái tên tương đối trang trọng, chẳng hạn như khi nhìn thấy một chú chó con, hãy nói “chú chó nhỏ” thay vì “cún cưng”.

> “Quả táo đây rồi!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 9, 12,
       'Những đồ dùng thông thường trong gia đình như quả táo, quả bóng.', ARRAY['Những đồ dùng thông thường trong gia đình như quả táo', 'quả bóng']::text[], '/static/activities/g050/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng bắt chước ngôn ngữ, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', 1, 'Khi trẻ tập trung vào một đồ vật, bố mẹ có thể tận dụng cơ hội này để gọi tên chính xác đồ vật đó và cho trẻ sờ, chơi với đồ vật đó. Ví dụ, nếu trẻ nhìn một quả táo, bố mẹ sẽ nói “quả táo”, đưa quả táo cho trẻ và đồng thời nói “quả táo”. Sau khi trẻ lấy được quả táo, bố mẹ nói: “Quả táo, con lấy quả táo đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', 2, 'Bố mẹ cũng có thể chỉ vào đồ vật, thu hút sự chú ý của trẻ rồi nói tên đồ vật đó.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', 3, 'Khi khả năng của trẻ phát triển, bố mẹ có thể hỏi trẻ các đồ vật thông dụng ở đâu, chẳng hạn như: “Quả bóng ở đâu con nhỉ?” và khuyến khích trẻ tìm ra.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', 'image', '/static/activities/g050/main.jpg', '“Quả táo đây rồi!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '29d0982b-23c1-5b7a-936b-f2a9c9aa9f2f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g051: Vỗ nhẹ bàn tay (trang PDF 91)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '491ce9ab-5420-5337-8252-208608dc95fc', 'Vỗ nhẹ bàn tay', 'Bạn có thể thực hành “tạm biệt” và “chúc mừng” theo cách tương tự.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Bố bế trẻ từ phía sau, mẹ ngồi đối diện với trẻ, mắt ngang tầm với trẻ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Mẹ vỗ tay và nói với trẻ: “Chào mừng, chào mừng.” Sau khi thực hiện vài lần, mẹ dừng lại và chờ trẻ bắt chước. Nếu trẻ không bắt chước, bố có thể nắm tay trẻ và bắt chước động tác vỗ tay của mẹ.
2. Sau khi tập vài lần, trẻ sẽ có ý thức bắt chước động tác vỗ tay và bạn có thể để trẻ tự mình thực hiện động tác vỗ tay.

## Hướng dẫn của chuyên gia
- Khi mẹ vỗ tay, động tác của mẹ phải nhịp nhàng để thu hút sự chú ý của trẻ.
- Nếu lúc đầu trẻ chưa biết thực hiện, bố có thể hỗ trợ. Sau khi thấy khả năng của trẻ tăng dần thì để tự trẻ bắt chước động tác vỗ tay của mẹ.

> Bạn có thể thực hành “tạm biệt” và “chúc mừng” theo cách tương tự.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 9, 12,
       'Không có.', NULL, '/static/activities/g051/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('491ce9ab-5420-5337-8252-208608dc95fc', 1, 'Mẹ vỗ tay và nói với trẻ: “Chào mừng, chào mừng.” Sau khi thực hiện vài lần, mẹ dừng lại và chờ trẻ bắt chước. Nếu trẻ không bắt chước, bố có thể nắm tay trẻ và bắt chước động tác vỗ tay của mẹ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('491ce9ab-5420-5337-8252-208608dc95fc', 2, 'Sau khi tập vài lần, trẻ sẽ có ý thức bắt chước động tác vỗ tay và bạn có thể để trẻ tự mình thực hiện động tác vỗ tay.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('491ce9ab-5420-5337-8252-208608dc95fc', 'image', '/static/activities/g051/main.jpg', 'Bạn có thể thực hành “tạm biệt” và “chúc mừng” theo cách tương tự.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '491ce9ab-5420-5337-8252-208608dc95fc', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g052: Gọi điện thoại (trang PDF 92)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '2f13d12c-b203-5e61-8036-3792225f8044', 'Gọi điện thoại', '“Alo, ai đang nghe máy vậy ạ?”', '**Kỹ năng phát triển:** Khả năng quan sát, Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động

## Chuẩn bị
- **Không gian:** Ghế sofa, thảm trải sàn hoặc mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** 2 điện thoại đồ chơi.

## Các bước thực hiện
1. Bố mẹ lấy điện thoại đồ chơi và đưa cho trẻ một chiếc, nói: “Điện thoại”. Bố mẹ nhấc điện thoại lên, áp vào tai trẻ và nói: “Điện thoại, xin chào!” Sau đó đợi trẻ bắt chước. Nếu trẻ không bắt chước, bạn có thể nắm tay trẻ và áp tai nghe điện thoại vào tai trẻ.
2. Sau khi chơi vài lần, trẻ có thể nhấc điện thoại lên và chơi với bố mẹ. Lúc này, bố mẹ có thể thêm âm thanh, chẳng hạn khi trẻ phát ra âm thanh “bíp” vào tai nghe điện thoại, mẹ cũng bắt chước giọng nói của trẻ rồi tạm dừng, chờ trẻ phát ra âm thanh tiếp theo.

## Hướng dẫn của chuyên gia
- Khi bố mẹ “gọi điện thoại”, động tác phải nhịp nhàng để thu hút sự chú ý của trẻ.
- Khi các âm thanh được phát ra từ trẻ, bố mẹ nên phản hồi để tạo thành vòng tròn giao tiếp qua lại với trẻ.
- Khi bố mẹ gọi điện thoại, có thể hướng dẫn trẻ quan sát cử động, nét mặt và giọng nói của người lớn.

> “Alo, ai đang nghe máy vậy ạ?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 9, 12,
       '2 điện thoại đồ chơi.', ARRAY['2 điện thoại đồ chơi']::text[], '/static/activities/g052/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng quan sát, Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('2f13d12c-b203-5e61-8036-3792225f8044', 1, 'Bố mẹ lấy điện thoại đồ chơi và đưa cho trẻ một chiếc, nói: “Điện thoại”. Bố mẹ nhấc điện thoại lên, áp vào tai trẻ và nói: “Điện thoại, xin chào!” Sau đó đợi trẻ bắt chước. Nếu trẻ không bắt chước, bạn có thể nắm tay trẻ và áp tai nghe điện thoại vào tai trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('2f13d12c-b203-5e61-8036-3792225f8044', 2, 'Sau khi chơi vài lần, trẻ có thể nhấc điện thoại lên và chơi với bố mẹ. Lúc này, bố mẹ có thể thêm âm thanh, chẳng hạn khi trẻ phát ra âm thanh “bíp” vào tai nghe điện thoại, mẹ cũng bắt chước giọng nói của trẻ rồi tạm dừng, chờ trẻ phát ra âm thanh tiếp theo.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('2f13d12c-b203-5e61-8036-3792225f8044', 'image', '/static/activities/g052/main.jpg', '“Alo, ai đang nghe máy vậy ạ?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '2f13d12c-b203-5e61-8036-3792225f8044', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g053: Năm ngón tay ngoan (trang PDF 93)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0d45012b-989a-58fc-a16a-ca47c7ef2750', 'Năm ngón tay ngoan', '“Xòe bàn tay đếm ngón tay...”', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ nắm tay trẻ bằng một tay và duỗi ngón trỏ của tay kia ra. Bố mẹ chạm vào ngón trỏ của bé, rồi từ đầu ngón tay này đến đầu ngón tay khác. Đồng thời hát bài hát thiếu nhi “Năm ngón tay ngoan”.
2. Sau khi lặp lại nhiều lần, trẻ có thể tự duỗi ngón trỏ của bàn tay phải bằng ngón trỏ của bàn tay trái.

## Hướng dẫn của chuyên gia
- Khi bố mẹ đưa ngón trỏ ra để chỉ, động tác của họ nên nhịp nhàng để thu hút sự chú ý của trẻ.
- Nếu ban đầu trẻ chưa biết làm, bố mẹ khác có thể giúp. Khi khả năng của trẻ tăng lên, bố mẹ sẽ giảm dần sự hỗ trợ và để trẻ tự mình bắt chước.

> “Xòe bàn tay đếm ngón tay...”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 9, 12,
       'Không có.', NULL, '/static/activities/g053/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước chuyển động, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0d45012b-989a-58fc-a16a-ca47c7ef2750', 1, 'Bố mẹ nắm tay trẻ bằng một tay và duỗi ngón trỏ của tay kia ra. Bố mẹ chạm vào ngón trỏ của bé, rồi từ đầu ngón tay này đến đầu ngón tay khác. Đồng thời hát bài hát thiếu nhi “Năm ngón tay ngoan”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0d45012b-989a-58fc-a16a-ca47c7ef2750', 2, 'Sau khi lặp lại nhiều lần, trẻ có thể tự duỗi ngón trỏ của bàn tay phải bằng ngón trỏ của bàn tay trái.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0d45012b-989a-58fc-a16a-ca47c7ef2750', 'image', '/static/activities/g053/main.jpg', '“Xòe bàn tay đếm ngón tay...”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0d45012b-989a-58fc-a16a-ca47c7ef2750', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g054: Cái miệng xinh xắn (trang PDF 94)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '21dc0c68-75f3-5cfe-bb7e-28da17a6ebad', 'Cái miệng xinh xắn', 'Khi bố mẹ tạo nhiều hình dạng miệng khác nhau, cử động của họ phải nhịp nhàng để thu hút sự chú ý của trẻ.', '**Kỹ năng phát triển:** Khả năng bắt chước chuyển động, Sức mạnh cơ miệng

## Chuẩn bị
- **Không gian:** Ghế sofa hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ tạo nhiều hình dạng miệng khác nhau như mút miệng, mím môi, lè lưỡi và liếm môi,...
2. Mỗi khi tạo hình miệng, hãy tạm dừng một lúc và chờ trẻ bắt chước.

## Hướng dẫn của chuyên gia
- Sau khi tạo hình miệng, bố mẹ nên cho trẻ thời gian để bắt chước. Nếu lúc đó trẻ không bắt chước thì không cần lo lắng. Sau một thời gian dài tập luyện, trẻ sẽ tự nhiên bắt chước được.

> Khi bố mẹ tạo nhiều hình dạng miệng khác nhau, cử động của họ phải nhịp nhàng để thu hút sự chú ý của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 9, 12,
       'Không có.', NULL, '/static/activities/g054/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng bắt chước chuyển động, Sức mạnh cơ miệng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('21dc0c68-75f3-5cfe-bb7e-28da17a6ebad', 1, 'Bố mẹ tạo nhiều hình dạng miệng khác nhau như mút miệng, mím môi, lè lưỡi và liếm môi,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('21dc0c68-75f3-5cfe-bb7e-28da17a6ebad', 2, 'Mỗi khi tạo hình miệng, hãy tạm dừng một lúc và chờ trẻ bắt chước.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('21dc0c68-75f3-5cfe-bb7e-28da17a6ebad', 'image', '/static/activities/g054/main.jpg', 'Khi bố mẹ tạo nhiều hình dạng miệng khác nhau, cử động của họ phải nhịp nhàng để thu hút sự chú ý của trẻ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '21dc0c68-75f3-5cfe-bb7e-28da17a6ebad', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g055: Đi nhặt trái cây (trang PDF 95, 96)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '79e756ac-e5ab-5d74-a900-be4657b95e5a', 'Đi nhặt trái cây', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, mắt, Khả năng quan sát.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, mắt, Khả năng quan sát

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một số loại trái cây (táo, chuối, lê, cam, thanh long,...).

## Các bước thực hiện
1. Bố đặt 5 - 10 loại trái cây rải rác trên mặt đất trong phạm vi từ 1 đến 3 m trước mặt trẻ, còn mẹ đứng bên cạnh trẻ.
2. Mẹ chỉ vào quả chuối trước mặt và nói: “Con đi lấy quả chuối đi nào!”
3. Sau khi trẻ nhặt được quả chuối, trẻ quay lại và đưa cho mẹ. Mẹ nên khen ngợi: “Con ngoan quá!” Sau khi mẹ nhận được quả chuối, mẹ có thể làm động tác ngửi và ăn một cách vui vẻ rồi nói: “Chuối có mùi thơm quá!” hoặc “Thật là thơm!”. Mẹ có thể đưa cho trẻ ngửi và hỏi trẻ: “Có mùi thơm không con?” để mở rộng nội dung trò chơi.
4. Mẹ chỉ vào quả táo trước mặt và nói: “Nhìn kìa, quả gì kia con nhỉ?”, và trẻ đi lấy. Và cứ như vậy cho đến khi hái hết số trái cây.

## Hướng dẫn của chuyên gia
- Trò chơi này nên chơi khi trẻ đã có thể tự đứng và đi lại.
- Nếu trẻ không thể tự mình ngồi xổm và nhặt đồ vật, bố mẹ có thể hỗ trợ, nhưng nên giảm dần mức độ hỗ trợ.
- Các loại trái cây không nên để quá xa trẻ, bạn có thể đặt khoảng cách các loại trái cây từ gần đến xa.
- Trước khi bắt đầu hoạt động, hãy dạy trẻ nhận biết các loại trái cây khác nhau và chọn những loại trái cây mà trẻ nhận biết và làm quen để luyện tập.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 12, 15,
       'Một số loại trái cây (táo, chuối, lê, cam, thanh long,...).', ARRAY['Một số loại trái cây (táo', 'chuối', 'lê', 'cam', 'thanh long,...)']::text[], '/static/activities/g055/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp tay, mắt, Khả năng quan sát.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 1, 'Bố đặt 5 - 10 loại trái cây rải rác trên mặt đất trong phạm vi từ 1 đến 3 m trước mặt trẻ, còn mẹ đứng bên cạnh trẻ.', '/static/activities/g055/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 2, 'Mẹ chỉ vào quả chuối trước mặt và nói: “Con đi lấy quả chuối đi nào!”', '/static/activities/g055/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 3, 'Sau khi trẻ nhặt được quả chuối, trẻ quay lại và đưa cho mẹ. Mẹ nên khen ngợi: “Con ngoan quá!” Sau khi mẹ nhận được quả chuối, mẹ có thể làm động tác ngửi và ăn một cách vui vẻ rồi nói: “Chuối có mùi thơm quá!” hoặc “Thật là thơm!”. Mẹ có thể đưa cho trẻ ngửi và hỏi trẻ: “Có mùi thơm không con?” để mở rộng nội dung trò chơi.', '/static/activities/g055/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 4, 'Mẹ chỉ vào quả táo trước mặt và nói: “Nhìn kìa, quả gì kia con nhỉ?”, và trẻ đi lấy. Và cứ như vậy cho đến khi hái hết số trái cây.', '/static/activities/g055/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 'image', '/static/activities/g055/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 'image', '/static/activities/g055/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 'image', '/static/activities/g055/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 'image', '/static/activities/g055/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('79e756ac-e5ab-5d74-a900-be4657b95e5a', 'image', '/static/activities/g055/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '79e756ac-e5ab-5d74-a900-be4657b95e5a', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g056: Đường đi thú vị (trang PDF 97)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '7124c711-8601-5ea0-ad14-b79e0964c704', 'Đường đi thú vị', 'Hãy bắt đầu với khoảng cách gần, khoảng 1 - 2 chiếc gối hoặc đệm. Hãy tăng dần số lượng khi trẻ đã thành thạo và tiến bộ.', '**Kỹ năng phát triển:** Rèn luyện thể thao, Khả năng giữ thăng bằng, Khả năng kết hợp giác quan

## Chuẩn bị
- **Không gian:** Sàn nhà hoặc thảm trải sàn.
- **Tư thế:** Trẻ đứng, sẵn sàng di chuyển.
- **Đồ dùng:** Vài chiếc gối, vài chiếc đệm ngồi và một món đồ chơi nhỏ mà trẻ yêu thích.

## Các bước thực hiện
1. Đặt đệm và gối cách nhau một khoảng trên mặt đất để tạo thành đường đi, đặt đồ chơi yêu thích của trẻ ở cuối đường.
2. Bố mẹ dắt tay trẻ đi dọc con đường, vừa đi vừa nói: “Con hãy đến lấy đồ chơi của con đi nào!”
3. Khi trẻ đã quen, bố mẹ hãy để trẻ tự đi. Bố mẹ đứng bên cổ vũ và nhắc nhở trẻ “Mặt đất cứng lắm, con bước lên gối đi!”

## Hướng dẫn của chuyên gia
- Bạn có thể chọn đệm ngồi rộng hơn và gối cao hơn. Vị trí so le sẽ khiến trò chơi này trở nên thú vị và thử thách hơn.
- Nếu lúc đầu trẻ chưa vững, bố mẹ có thể cho trẻ cầm một tay, khi khả năng của trẻ phát triển, bố mẹ có thể dần dần cho trẻ cầm một ngón tay, cuối cùng cho trẻ tự đi.
- Bố mẹ cần luôn chú ý bảo vệ trẻ khỏi bị ngã.

> Hãy bắt đầu với khoảng cách gần, khoảng 1 - 2 chiếc gối hoặc đệm. Hãy tăng dần số lượng khi trẻ đã thành thạo và tiến bộ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 12, 15,
       'Vài chiếc gối, vài chiếc đệm ngồi và một món đồ chơi nhỏ mà trẻ yêu thích.', ARRAY['Vài chiếc gối', 'vài chiếc đệm ngồi và một món đồ chơi nhỏ mà trẻ yêu thích']::text[], '/static/activities/g056/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Rèn luyện thể thao, Khả năng giữ thăng bằng, Khả năng kết hợp giác quan.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7124c711-8601-5ea0-ad14-b79e0964c704', 1, 'Đặt đệm và gối cách nhau một khoảng trên mặt đất để tạo thành đường đi, đặt đồ chơi yêu thích của trẻ ở cuối đường.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7124c711-8601-5ea0-ad14-b79e0964c704', 2, 'Bố mẹ dắt tay trẻ đi dọc con đường, vừa đi vừa nói: “Con hãy đến lấy đồ chơi của con đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7124c711-8601-5ea0-ad14-b79e0964c704', 3, 'Khi trẻ đã quen, bố mẹ hãy để trẻ tự đi. Bố mẹ đứng bên cổ vũ và nhắc nhở trẻ “Mặt đất cứng lắm, con bước lên gối đi!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7124c711-8601-5ea0-ad14-b79e0964c704', 'image', '/static/activities/g056/main.jpg', 'Hãy bắt đầu với khoảng cách gần, khoảng 1 - 2 chiếc gối hoặc đệm. Hãy tăng dần số lượng khi trẻ đã thành thạo và tiến bộ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '7124c711-8601-5ea0-ad14-b79e0964c704', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g057: Kiến trúc sư tương lai (trang PDF 98)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'bcb67b6d-2f99-59a8-b27a-be0efce12b0d', 'Kiến trúc sư tương lai', 'Lúc đầu, bạn có thể xây dựng một lớp, sau đó đổ nó xuống và xây dựng lại. Trẻ đã thành thạo kỹ năng xây dựng độ cao và có thể xây hai hoặc ba tầng.', '**Kỹ năng phát triển:** Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh, Cảm giác về không gian

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Hộp quà nhỏ, hộp khăn giấy, bát, khối xếp hình,...

## Các bước thực hiện
1. Đặt ngẫu nhiên các đồ vật có kích thước khác nhau lên bàn và cùng trẻ chơi trò chơi xây nhà cao tầng.
2. Hướng dẫn trẻ đặt từng đồ vật lên.
3. Khi khả năng vận động của trẻ được cải thiện, có thể cung cấp cho trẻ các khối xây dựng với nhiều kích cỡ, hình dạng và màu sắc khác nhau để khuyến khích trẻ tự do xây dựng.

## Hướng dẫn của chuyên gia
- Tránh sử dụng hộp đựng quá cứng để dựng lên độ cao, tránh trường hợp hộp đựng bị đổ và va vào trẻ.
- Bố mẹ có thể động viên trẻ sau mỗi lần thử, như: “Con thật tuyệt vời!”
- Khi khả năng giải quyết vấn đề của trẻ được cải thiện, bố mẹ có thể tặng trẻ sách và các đồ chơi nhỏ khác để khuyến khích trẻ hợp tác hơn nữa.

> Lúc đầu, bạn có thể xây dựng một lớp, sau đó đổ nó xuống và xây dựng lại. Trẻ đã thành thạo kỹ năng xây dựng độ cao và có thể xây hai hoặc ba tầng.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 12, 15,
       'Hộp quà nhỏ, hộp khăn giấy, bát, khối xếp hình,...', ARRAY['Hộp quà nhỏ', 'hộp khăn giấy', 'bát', 'khối xếp hình,']::text[], '/static/activities/g057/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh, Cảm giác về không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bcb67b6d-2f99-59a8-b27a-be0efce12b0d', 1, 'Đặt ngẫu nhiên các đồ vật có kích thước khác nhau lên bàn và cùng trẻ chơi trò chơi xây nhà cao tầng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bcb67b6d-2f99-59a8-b27a-be0efce12b0d', 2, 'Hướng dẫn trẻ đặt từng đồ vật lên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bcb67b6d-2f99-59a8-b27a-be0efce12b0d', 3, 'Khi khả năng vận động của trẻ được cải thiện, có thể cung cấp cho trẻ các khối xây dựng với nhiều kích cỡ, hình dạng và màu sắc khác nhau để khuyến khích trẻ tự do xây dựng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bcb67b6d-2f99-59a8-b27a-be0efce12b0d', 'image', '/static/activities/g057/main.jpg', 'Lúc đầu, bạn có thể xây dựng một lớp, sau đó đổ nó xuống và xây dựng lại. Trẻ đã thành thạo kỹ năng xây dựng độ cao và có thể xây hai hoặc ba tầng.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'bcb67b6d-2f99-59a8-b27a-be0efce12b0d', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g058: Lái xe (trang PDF 99)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'af172e2f-8fa0-5765-9aec-ee9d55d2ff84', 'Lái xe', 'Đi vào đường hầm!', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Hiểu mối quan hệ giữa các đồ vật, Trí tưởng tượng

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Ô tô, tàu hoả đồ chơi, một số hộp giấy và lõi giấy cuộn với nhiều kích cỡ và chất liệu khác nhau.

## Các bước thực hiện
1. Bố mẹ và trẻ mỗi người có một ô tô đồ chơi, vừa đẩy và kéo ô tô đồ chơi.
2. Dùng hộp giấy làm ngọn đồi, gara, lõi cuộn giấy làm đường hầm để hướng dẫn trẻ “lái xe” ra ngoài chơi.
3. Trước tiên, bố mẹ có thể thể hiện việc lái xe qua “đường hầm”, leo lên “đồi”, cuối cùng là đỗ xe vào “gara”, sau đó, cho trẻ bắt chước. Nhắc trẻ chú ý lái xe an toàn.

## Hướng dẫn của chuyên gia
- Lúc đầu, bố mẹ và trẻ có thể đặt một chiếc ô tô đồ chơi rồi kéo, đẩy trên bàn, giúp trẻ có cơ hội thành thạo các kỹ năng vận động tay như đẩy, kéo.
- Sau khi trẻ đã thành thạo các động tác, bố mẹ có thể dùng tay giả làm các hang động để trẻ tham gia trò chơi và hướng dẫn trẻ kiểm soát tốt hơn lực và hướng đẩy, kéo đồ chơi, điều này cũng làm cho trò chơi trở nên thú vị hơn.

> Đi vào đường hầm!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 12, 15,
       'Ô tô, tàu hoả đồ chơi, một số hộp giấy và lõi giấy cuộn với nhiều kích cỡ và chất liệu khác nhau.', ARRAY['Ô tô', 'tàu hoả đồ chơi', 'một số hộp giấy và lõi giấy cuộn với nhiều kích cỡ và chất liệu khác nhau']::text[], '/static/activities/g058/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Hiểu mối quan hệ giữa các đồ vật, Trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('af172e2f-8fa0-5765-9aec-ee9d55d2ff84', 1, 'Bố mẹ và trẻ mỗi người có một ô tô đồ chơi, vừa đẩy và kéo ô tô đồ chơi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('af172e2f-8fa0-5765-9aec-ee9d55d2ff84', 2, 'Dùng hộp giấy làm ngọn đồi, gara, lõi cuộn giấy làm đường hầm để hướng dẫn trẻ “lái xe” ra ngoài chơi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('af172e2f-8fa0-5765-9aec-ee9d55d2ff84', 3, 'Trước tiên, bố mẹ có thể thể hiện việc lái xe qua “đường hầm”, leo lên “đồi”, cuối cùng là đỗ xe vào “gara”, sau đó, cho trẻ bắt chước. Nhắc trẻ chú ý lái xe an toàn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('af172e2f-8fa0-5765-9aec-ee9d55d2ff84', 'image', '/static/activities/g058/main.jpg', 'Đi vào đường hầm!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'af172e2f-8fa0-5765-9aec-ee9d55d2ff84', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g059: Đổ gạo vào cốc (trang PDF 100)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'f9b3e809-2fa4-5658-9228-b3eb4fb47e63', 'Đổ gạo vào cốc', 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp tay.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp tay

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Hai cốc nhựa, một nắp hộp, nửa cốc gạo.

## Các bước thực hiện
1. Đặt một nắp hộp trước mặt trẻ, đặt hai chiếc cốc lên nắp và đổ đầy nửa cốc gạo vào một cốc.
2. Trước tiên, hãy cho trẻ thời gian để tự do khám phá và xem trẻ chơi với những món đồ này như thế nào.
3. Nếu trẻ không có động tác rót gạo, bố mẹ có thể hướng dẫn cách đổ gạo từ cốc này sang cốc khác, sau đó khuyến khích trẻ bắt chước. Bố mẹ có thể nói: “Ồ, con đổ gạo vào đây nhé!”

## Hướng dẫn của chuyên gia
- Ngoài gạo, thì bạn có thể sử dụng hạt đậu, nước,... để chơi trò chơi này.
- Bố mẹ phải luôn chú ý trong quá trình chơi để tránh trẻ ăn nhầm. Nếu trẻ không thể hoàn thành hành động, bố mẹ có thể hỗ trợ ban đầu.
- Lúc đầu, trẻ sẽ có thể làm đổ đồ khi đổ. Bố mẹ có thể nhắc trẻ, nhưng đừng trách trẻ. Bố mẹ nhẹ nhàng yêu cầu trẻ để không làm mất đi hứng thú chơi của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 12, 15,
       'Hai cốc nhựa, một nắp hộp, nửa cốc gạo.', ARRAY['Hai cốc nhựa', 'một nắp hộp', 'nửa cốc gạo']::text[], '/static/activities/g059/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f9b3e809-2fa4-5658-9228-b3eb4fb47e63', 1, 'Đặt một nắp hộp trước mặt trẻ, đặt hai chiếc cốc lên nắp và đổ đầy nửa cốc gạo vào một cốc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f9b3e809-2fa4-5658-9228-b3eb4fb47e63', 2, 'Trước tiên, hãy cho trẻ thời gian để tự do khám phá và xem trẻ chơi với những món đồ này như thế nào.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f9b3e809-2fa4-5658-9228-b3eb4fb47e63', 3, 'Nếu trẻ không có động tác rót gạo, bố mẹ có thể hướng dẫn cách đổ gạo từ cốc này sang cốc khác, sau đó khuyến khích trẻ bắt chước. Bố mẹ có thể nói: “Ồ, con đổ gạo vào đây nhé!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f9b3e809-2fa4-5658-9228-b3eb4fb47e63', 'image', '/static/activities/g059/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'f9b3e809-2fa4-5658-9228-b3eb4fb47e63', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g060: Hình dán vui nhộn (trang PDF 101)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'fd8c38eb-27c7-5018-be3d-ef6d4575b20a', 'Hình dán vui nhộn', 'Khi thực hiện trò chơi, bố mẹ hãy giữ tâm trạng hào hứng, nhấn mạnh và nói to hơn những bộ phận cơ thể hình dán đi qua. Khi trẻ đã quen, trẻ sẽ dễ dàng nhắc lại những bộ phận cơ thể theo thứ tự giống bố mẹ nói. Từ đó, trẻ đã ghi nhớ và có cảm giác mong đợi, chủ động hỏi nơi dán. Lặp lại hoạt động nhiều lần để thấy kết quả.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước ngôn ngữ, Trí tưởng tượng

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Hình dán (sticker vui nhộn).

## Các bước thực hiện
1. Chọn hình dán (sticker) mà trẻ yêu thích. Họa tiết có thể là các loại hoa quả, động vật, nhân vật hoạt hình mà bé yêu thích,...
2. Bố mẹ dán các miếng dán lên đầu ngón tay và lần lượt dán chúng dọc theo cánh tay, vai, mặt, hai bên và môi của trẻ. Bố mẹ có thể vừa thực hiện vừa đọc tên các bộ phận mà hình dán đi qua.
3. Dán một miếng dán nhỏ lên mũi trẻ và hướng dẫn trẻ tìm và gỡ miếng dán ra khỏi cơ thể.

## Hướng dẫn của chuyên gia
- Lần đầu, bố mẹ nên chọn miếng dán kích thước lớn, khi khả năng của trẻ tiến bộ, hãy bắt đầu sử dụng hình dán nhỏ dần.
- Bố mẹ không cần làm mẫu. Nếu trẻ cố gắng tìm hình dán nhưng không thể tìm thấy chính xác, bố mẹ có thể đọc vị trí và khuyến khích trẻ thử lại, hoặc chạm vào hình dán vài lần để nhắc nhở trẻ.
- Đối với những trẻ nhạy cảm hoặc nghịch ngợm, bố mẹ hãy kiên nhẫn và thực hiện chậm rãi, không nên ép buộc trẻ làm theo.

> Khi thực hiện trò chơi, bố mẹ hãy giữ tâm trạng hào hứng, nhấn mạnh và nói to hơn những bộ phận cơ thể hình dán đi qua. Khi trẻ đã quen, trẻ sẽ dễ dàng nhắc lại những bộ phận cơ thể theo thứ tự giống bố mẹ nói. Từ đó, trẻ đã ghi nhớ và có cảm giác mong đợi, chủ động hỏi nơi dán. Lặp lại hoạt động nhiều lần để thấy kết quả.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 12, 15,
       'Hình dán (sticker vui nhộn).', ARRAY['Hình dán (sticker vui nhộn)']::text[], '/static/activities/g060/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước ngôn ngữ, Trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fd8c38eb-27c7-5018-be3d-ef6d4575b20a', 1, 'Chọn hình dán (sticker) mà trẻ yêu thích. Họa tiết có thể là các loại hoa quả, động vật, nhân vật hoạt hình mà bé yêu thích,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fd8c38eb-27c7-5018-be3d-ef6d4575b20a', 2, 'Bố mẹ dán các miếng dán lên đầu ngón tay và lần lượt dán chúng dọc theo cánh tay, vai, mặt, hai bên và môi của trẻ. Bố mẹ có thể vừa thực hiện vừa đọc tên các bộ phận mà hình dán đi qua.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fd8c38eb-27c7-5018-be3d-ef6d4575b20a', 3, 'Dán một miếng dán nhỏ lên mũi trẻ và hướng dẫn trẻ tìm và gỡ miếng dán ra khỏi cơ thể.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('fd8c38eb-27c7-5018-be3d-ef6d4575b20a', 'image', '/static/activities/g060/main.jpg', 'Khi thực hiện trò chơi, bố mẹ hãy giữ tâm trạng hào hứng, nhấn mạnh và nói to hơn những bộ phận cơ thể hình dán đi qua. Khi trẻ đã quen, trẻ sẽ dễ dàng nhắc lại những bộ phận cơ thể theo thứ tự giống bố mẹ nói. Từ đó, trẻ đã ghi nhớ và có cảm giác mong đợi, chủ động hỏi nơi dán. Lặp lại hoạt động nh', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'fd8c38eb-27c7-5018-be3d-ef6d4575b20a', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g061: Tiếng kêu của các loài động vật (trang PDF 102)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'f7a98908-fd5d-5864-8293-5ed5da90f02e', 'Tiếng kêu của các loài động vật', 'Nhà em có con gà trống, mèo con và cún con. Gà trống gáy o o o,...', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng diễn đạt ngôn ngữ

## Chuẩn bị
- **Không gian:** Thảm lót sàn hoặc ghế sofa.
- **Tư thế:** Trẻ ngồi đối diện bố mẹ.
- **Đồ dùng:** Những bức tranh vẽ gà con, mèo con, chó con và vịt (bắt đầu với những loài gần gũi với con người).

## Các bước thực hiện
1. Bố mẹ lấy hình con gà ra và lặp lại nhóm câu: “Đây là con gì?” “Ồ, đây là con gà, con gà kêu thế nào?” Nếu trẻ trả lời đúng, bố mẹ hãy khen trẻ giỏi, hoặc vỗ tay hoan hô. Nếu trẻ không nói được, bố mẹ hãy làm mẫu âm thanh: “Chíp, chíp”, sau đó lặp lại nhóm câu trên.
2. Sử dụng phương pháp tương tự để hướng dẫn trẻ nhận biết âm thanh của mèo con, chó con và vịt con.
3. Bố mẹ hát cho trẻ nghe những bài hát ngắn gọn, quen thuộc với trẻ như: “Một con vịt”, “Gà trống, mèo con và cún con”, “Rửa mặt như mèo”,..., trẻ sẽ hào hứng và ghi nhớ lâu hơn. Hãy nhớ khen khi trẻ thực hiện đúng, động viên trẻ khi trẻ chưa nói được, hoặc nói nhầm. Hãy kiên nhẫn và lặp lại hoạt động hằng ngày để thấy kết quả.

## Hướng dẫn của chuyên gia
- Trước khi chơi trò chơi, bố mẹ có thể cho trẻ quan sát mèo con, chó con, gà con, vịt và lắng nghe tiếng kêu của chúng để trẻ có cảm giác chân thực.
- Nếu trẻ bắt chước âm thanh sai, đừng chỉ trích, hãy kiên nhẫn hướng dẫn lại cho đến khi trẻ làm đúng.

> Nhà em có con gà trống, mèo con và cún con. Gà trống gáy o o o,...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 12, 15,
       'Những bức tranh vẽ gà con, mèo con, chó con và vịt (bắt đầu với những loài gần gũi với con người).', ARRAY['Những bức tranh vẽ gà con', 'mèo con', 'chó con và vịt (bắt đầu với những loài gần gũi với con người)']::text[], '/static/activities/g061/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng diễn đạt ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f7a98908-fd5d-5864-8293-5ed5da90f02e', 1, 'Bố mẹ lấy hình con gà ra và lặp lại nhóm câu: “Đây là con gì?” “Ồ, đây là con gà, con gà kêu thế nào?” Nếu trẻ trả lời đúng, bố mẹ hãy khen trẻ giỏi, hoặc vỗ tay hoan hô. Nếu trẻ không nói được, bố mẹ hãy làm mẫu âm thanh: “Chíp, chíp”, sau đó lặp lại nhóm câu trên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f7a98908-fd5d-5864-8293-5ed5da90f02e', 2, 'Sử dụng phương pháp tương tự để hướng dẫn trẻ nhận biết âm thanh của mèo con, chó con và vịt con.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f7a98908-fd5d-5864-8293-5ed5da90f02e', 3, 'Bố mẹ hát cho trẻ nghe những bài hát ngắn gọn, quen thuộc với trẻ như: “Một con vịt”, “Gà trống, mèo con và cún con”, “Rửa mặt như mèo”,..., trẻ sẽ hào hứng và ghi nhớ lâu hơn. Hãy nhớ khen khi trẻ thực hiện đúng, động viên trẻ khi trẻ chưa nói được, hoặc nói nhầm. Hãy kiên nhẫn và lặp lại hoạt động hằng ngày để thấy kết quả.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f7a98908-fd5d-5864-8293-5ed5da90f02e', 'image', '/static/activities/g061/main.jpg', 'Nhà em có con gà trống, mèo con và cún con. Gà trống gáy o o o,...', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'f7a98908-fd5d-5864-8293-5ed5da90f02e', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g062: Lắc đầu và gật đầu (trang PDF 103)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '78364687-b5d7-567d-8a73-2dca13921180', 'Lắc đầu và gật đầu', '“Vỗ tay và lắc đầu!”', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước hành động, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Thảm lót sàn hoặc ghế sofa.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ vừa đọc các bài hát cho trẻ vừa thể hiện các hành động: “vỗ tay”, “lắc đầu”, “vỗ tay” và “gật đầu” để thu hút sự chú ý của trẻ.
2. Bố mẹ khuyến khích trẻ bắt chước gật đầu và lắc đầu.
3. Khi trẻ đã biết gật và lắc đầu, bố mẹ không thực hiện bất kỳ động tác nào nữa và khuyến khích trẻ thực hiện các động tác tương ứng khi nghe thấy từ “gật đầu” hoặc “lắc đầu”.

## Hướng dẫn của chuyên gia
- Khi bố mẹ gật đầu và lắc đầu, động tác của họ phải nhịp nhàng và nhấn mạnh giọng điệu.
- Khi bố mẹ nói các từ “gật đầu” hoặc “lắc đầu”, hãy dừng lại một cách thích hợp và cho trẻ thời gian để đáp lại hướng dẫn.

> “Vỗ tay và lắc đầu!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 12, 15,
       'Không có.', NULL, '/static/activities/g062/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước hành động, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78364687-b5d7-567d-8a73-2dca13921180', 1, 'Bố mẹ vừa đọc các bài hát cho trẻ vừa thể hiện các hành động: “vỗ tay”, “lắc đầu”, “vỗ tay” và “gật đầu” để thu hút sự chú ý của trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78364687-b5d7-567d-8a73-2dca13921180', 2, 'Bố mẹ khuyến khích trẻ bắt chước gật đầu và lắc đầu.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78364687-b5d7-567d-8a73-2dca13921180', 3, 'Khi trẻ đã biết gật và lắc đầu, bố mẹ không thực hiện bất kỳ động tác nào nữa và khuyến khích trẻ thực hiện các động tác tương ứng khi nghe thấy từ “gật đầu” hoặc “lắc đầu”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('78364687-b5d7-567d-8a73-2dca13921180', 'image', '/static/activities/g062/main.jpg', '“Vỗ tay và lắc đầu!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '78364687-b5d7-567d-8a73-2dca13921180', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g063: Vật thật và hình ảnh (trang PDF 104)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b7afb09c-07a3-5258-8fda-ca99cca9842e', 'Vật thật và hình ảnh', '“Đâu là quả chuối?”', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng bắt chước ngôn ngữ

## Chuẩn bị
- **Không gian:** Thảm lót sàn hoặc ghế sofa.
- **Tư thế:** Trẻ ngồi đối diện bố mẹ.
- **Đồ dùng:** Một quả táo, một quả chuối, một hình quả táo và một hình quả chuối.

## Các bước thực hiện
1. Bố mẹ cầm quả chuối và nói với trẻ: “Quả chuối”. Sau đó, cầm hình quả chuối lên và nói với trẻ: “Quả chuối”. Quan sát ánh mắt và biểu cảm của trẻ để xem trẻ có hiểu được điều đó không. Vật thật và hình ảnh là cùng một đối tượng.
2. Nếu trẻ đã hiểu, bạn có thể thêm hình ảnh quả táo để trẻ phán đoán. Cho trẻ nhìn quả chuối thật trước, sau đó nhìn vào hình ảnh quả chuối và quả táo, rồi hỏi trẻ: “Quả chuối ở đâu?” Quan sát xem trẻ có nhận biết được quả chuối trong hai bức tranh khác nhau không.
3. Nếu trẻ nhận biết được quả chuối, bạn có thể tăng dần số lượng tranh, hoặc bạn có thể thử hỏi trẻ: “Đây là gì?” Khuyến khích trẻ gọi tên đồ vật thật và các đồ vật trong tranh.

## Hướng dẫn của chuyên gia
- Đồ vật sử dụng trong trò chơi này phải là những đồ vật quen thuộc và thông dụng với trẻ.
- Khi bố mẹ gọi tên đồ vật và hình ảnh, nên nói chậm để trẻ có thời gian phản ứng và quan sát lại phản ứng của trẻ.
- Bố mẹ cần chú ý đến độ khó của hình ảnh. Ảnh hoạt hình và ảnh đen trắng khó hơn.

> “Đâu là quả chuối?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 12, 15,
       'Một quả táo, một quả chuối, một hình quả táo và một hình quả chuối.', ARRAY['Một quả táo', 'một quả chuối', 'một hình quả táo và một hình quả chuối']::text[], '/static/activities/g063/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng bắt chước ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b7afb09c-07a3-5258-8fda-ca99cca9842e', 1, 'Bố mẹ cầm quả chuối và nói với trẻ: “Quả chuối”. Sau đó, cầm hình quả chuối lên và nói với trẻ: “Quả chuối”. Quan sát ánh mắt và biểu cảm của trẻ để xem trẻ có hiểu được điều đó không. Vật thật và hình ảnh là cùng một đối tượng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b7afb09c-07a3-5258-8fda-ca99cca9842e', 2, 'Nếu trẻ đã hiểu, bạn có thể thêm hình ảnh quả táo để trẻ phán đoán. Cho trẻ nhìn quả chuối thật trước, sau đó nhìn vào hình ảnh quả chuối và quả táo, rồi hỏi trẻ: “Quả chuối ở đâu?” Quan sát xem trẻ có nhận biết được quả chuối trong hai bức tranh khác nhau không.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b7afb09c-07a3-5258-8fda-ca99cca9842e', 3, 'Nếu trẻ nhận biết được quả chuối, bạn có thể tăng dần số lượng tranh, hoặc bạn có thể thử hỏi trẻ: “Đây là gì?” Khuyến khích trẻ gọi tên đồ vật thật và các đồ vật trong tranh.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b7afb09c-07a3-5258-8fda-ca99cca9842e', 'image', '/static/activities/g063/main.jpg', '“Đâu là quả chuối?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b7afb09c-07a3-5258-8fda-ca99cca9842e', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g064: Vượt qua hang động (trang PDF 105, 106)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '650567f6-6240-53e8-9cc0-30c6bc332d51', 'Vượt qua hang động', 'Kỹ năng phát triển: Kỹ năng xã hội, Khả năng phối hợp thể chất, Thể hiện cảm xúc.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Khả năng phối hợp thể chất, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ quỳ hoặc đứng.
- **Đồ dùng:** Đồ chơi hoặc đồ ăn mà trẻ yêu thích.

## Các bước thực hiện
1. Mẹ ngồi xổm trước mặt trẻ với đồ chơi hoặc thức ăn mà trẻ thích, tạo âm thanh và khuyến khích trẻ bò hoặc đi tới để lấy đồ chơi hoặc thức ăn đó.
2. Bố cúi xuống, quỳ xuống đất, dùng tay chống đỡ mặt đất tạo thành một cái hang (có thể dùng ghế). Khi trẻ sắp lấy được đồ chơi hoặc đồ ăn trẻ thích, mẹ biểu diễn bò qua hang, cầm những thứ trẻ muốn ở cửa hang để khuyến khích trẻ trèo qua hang.
3. Trong vòng chơi đầu tiên, bố đã thành công khi cho trẻ đi qua hang và lấy được đồ chơi hoặc thức ăn yêu thích. Sau vòng thứ hai, bố ôm con khi vào hang, nói: “Bắt con lại rồi!” và hôn vào trán con.
4. Nếu trẻ thích bị bắt, bạn không thể dùng đồ chơi hay thức ăn làm chất kích thích nữa mà hãy dùng việc bị bắt như một điểm thu hút.

## Hướng dẫn của chuyên gia
- Trong quá trình trẻ di chuyển về phía trước, bố mẹ không nên ở quá xa trẻ và nên thu hút sự chú ý của trẻ kịp thời khi trẻ bị phân tâm.
- Quá trình bố đón trẻ sẽ rất thú vị; sau khi hôn lên trán trẻ, cần giữ một khoảng cách nhất định với mặt trẻ để trẻ có thể giao tiếp bằng mắt với bố mẹ.
- Khi trẻ sử dụng các phương thức giao tiếp phi ngôn ngữ như ánh mắt, cử chỉ để bày tỏ nhu cầu, việc tương tác lại ngay lập tức có thể giúp trẻ sử dụng các phương thức giao tiếp chính xác.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 12, 15,
       'Đồ chơi hoặc đồ ăn mà trẻ yêu thích.', ARRAY['Đồ chơi hoặc đồ ăn mà trẻ yêu thích']::text[], '/static/activities/g064/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Khả năng phối hợp thể chất, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 1, 'Mẹ ngồi xổm trước mặt trẻ với đồ chơi hoặc thức ăn mà trẻ thích, tạo âm thanh và khuyến khích trẻ bò hoặc đi tới để lấy đồ chơi hoặc thức ăn đó.', '/static/activities/g064/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 2, 'Bố cúi xuống, quỳ xuống đất, dùng tay chống đỡ mặt đất tạo thành một cái hang (có thể dùng ghế). Khi trẻ sắp lấy được đồ chơi hoặc đồ ăn trẻ thích, mẹ biểu diễn bò qua hang, cầm những thứ trẻ muốn ở cửa hang để khuyến khích trẻ trèo qua hang.', '/static/activities/g064/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 3, 'Trong vòng chơi đầu tiên, bố đã thành công khi cho trẻ đi qua hang và lấy được đồ chơi hoặc thức ăn yêu thích. Sau vòng thứ hai, bố ôm con khi vào hang, nói: “Bắt con lại rồi!” và hôn vào trán con.', '/static/activities/g064/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 4, 'Nếu trẻ thích bị bắt, bạn không thể dùng đồ chơi hay thức ăn làm chất kích thích nữa mà hãy dùng việc bị bắt như một điểm thu hút.', '/static/activities/g064/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 'image', '/static/activities/g064/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 'image', '/static/activities/g064/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 'image', '/static/activities/g064/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 'image', '/static/activities/g064/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('650567f6-6240-53e8-9cc0-30c6bc332d51', 'image', '/static/activities/g064/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '650567f6-6240-53e8-9cc0-30c6bc332d51', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g065: Cho quần áo vào chậu (trang PDF 107)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e87a8711-ef9b-5c53-a1da-86fab101c922', 'Cho quần áo vào chậu', 'Khi bé ném quần áo vào chậu, bố mẹ hãy chú ý bảo vệ con từ phía sau để tránh trẻ bị trượt ngã.', '**Kỹ năng phát triển:** Sức mạnh cơ tay, Khả năng giữ thăng bằng cơ thể, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Phòng tắm.
- **Tư thế:** Trẻ ở tư thế thẳng đứng.
- **Đồ dùng:** Một chậu giặt.

## Các bước thực hiện
1. Trước khi tắm, bố mẹ và trẻ đứng cạnh chậu giặt. Mỗi lần bố mẹ giúp trẻ cởi một chiếc quần một chiếc áo, hãy đưa cho trẻ và để trẻ cho vào chậu giặt, có thể nói: “Con cho quần áo bẩn vào chậu nhé!” Mỗi lần con cho một chiếc quần áo vào chậu, bố mẹ hãy khen trẻ: “Con thật khéo léo khi cho quần áo vào chậu!”
2. Di chuyển chậu ra xa khoảng 10 cm và để trẻ ném quần áo bẩn vào chậu. Khi đạt đến một khoảng cách nhất định, trẻ sẽ khó ném vào chậu một cách dễ dàng. Bạn có thể giữ chậu ở khoảng cách này và tập cho trẻ thêm.

## Hướng dẫn của chuyên gia
- Trẻ ở độ tuổi này bắt đầu thích giúp đỡ người lớn làm việc gì đó, vì vậy bạn cũng có thể bảo trẻ cho quần áo bẩn của bố mẹ vào chậu để trẻ củng cố việc tập luyện.
- Tung bóng cũng là một trò chơi hay.

> Khi bé ném quần áo vào chậu, bố mẹ hãy chú ý bảo vệ con từ phía sau để tránh trẻ bị trượt ngã.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 15, 18,
       'Một chậu giặt.', ARRAY['Một chậu giặt']::text[], NULL, 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Sức mạnh cơ tay, Khả năng giữ thăng bằng cơ thể, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e87a8711-ef9b-5c53-a1da-86fab101c922', 1, 'Trước khi tắm, bố mẹ và trẻ đứng cạnh chậu giặt. Mỗi lần bố mẹ giúp trẻ cởi một chiếc quần một chiếc áo, hãy đưa cho trẻ và để trẻ cho vào chậu giặt, có thể nói: “Con cho quần áo bẩn vào chậu nhé!” Mỗi lần con cho một chiếc quần áo vào chậu, bố mẹ hãy khen trẻ: “Con thật khéo léo khi cho quần áo vào chậu!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e87a8711-ef9b-5c53-a1da-86fab101c922', 2, 'Di chuyển chậu ra xa khoảng 10 cm và để trẻ ném quần áo bẩn vào chậu. Khi đạt đến một khoảng cách nhất định, trẻ sẽ khó ném vào chậu một cách dễ dàng. Bạn có thể giữ chậu ở khoảng cách này và tập cho trẻ thêm.', NULL);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e87a8711-ef9b-5c53-a1da-86fab101c922', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g066: Leo dốc (trang PDF 108)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '7a5bbd0a-c843-518e-a160-591f8a3fbc07', 'Leo dốc', 'Khi lên dốc, hãy động viên trẻ: “Con lên dốc và lấy bóng nào!” Khi xuống dốc, hãy nhắc trẻ: “Con ơi, đi xuống thôi nào!” Khi đến cuối, hãy khen ngợi: “Con thật tuyệt vời!”', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng

## Chuẩn bị
- **Không gian:** Đường dốc không rào cản.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Một quả bóng cao su hoặc đồ chơi trẻ yêu thích.

## Các bước thực hiện
1. Bố và trẻ cùng nhau đi lên đoạn đường dốc. Bố ở phía sau trẻ, mẹ dùng quả bóng đồ chơi để dẫn trẻ đi phía trước và nói với trẻ: “Con leo lên lấy bóng đi!”
2. Sau khi trẻ lên đến bục ở cuối dốc, mẹ nhắc nhở bằng lời nói và cử động cơ thể: “Con ơi, xuống đi nào!”
3. Khi trẻ xuống dốc, mẹ lại quay mặt về phía trẻ và cầm đồ chơi dẫn trẻ xuống. Bố chú ý bảo vệ trẻ ở bên cạnh, khi trẻ đến cuối mặt đất, kịp thời khen ngợi: “Con thật tuyệt vời!” và đưa quả bóng cho trẻ chơi.

## Hướng dẫn của chuyên gia
- Nên chơi trò chơi này sau khi trẻ đã có thể đi một mình trên mặt đất bằng phẳng.
- Lên dốc dễ hơn xuống dốc. Các trẻ lần đầu tập leo dốc có thể lên dốc trước. Nếu trẻ sợ hãi, bố có thể nắm một tay của trẻ để đi lên hoặc xuống dốc. Sau một thời gian cố gắng, có thể khuyến khích trẻ tự đi về phía trước, nhưng chú ý tốc độ chậm hơn.
- Nếu trẻ có khả năng tốt, bạn có thể cho trẻ cầm mỗi tay một túi đồ nhỏ hoặc cầm một quả bóng bằng cả hai tay trước ngực trước khi chơi trò chơi.

> Khi lên dốc, hãy động viên trẻ: “Con lên dốc và lấy bóng nào!” Khi xuống dốc, hãy nhắc trẻ: “Con ơi, đi xuống thôi nào!” Khi đến cuối, hãy khen ngợi: “Con thật tuyệt vời!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 15, 18,
       'Một quả bóng cao su hoặc đồ chơi trẻ yêu thích.', ARRAY['Một quả bóng cao su hoặc đồ chơi trẻ yêu thích']::text[], '/static/activities/g066/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Sức mạnh của đôi chân, Khả năng giữ thăng bằng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a5bbd0a-c843-518e-a160-591f8a3fbc07', 1, 'Bố và trẻ cùng nhau đi lên đoạn đường dốc. Bố ở phía sau trẻ, mẹ dùng quả bóng đồ chơi để dẫn trẻ đi phía trước và nói với trẻ: “Con leo lên lấy bóng đi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a5bbd0a-c843-518e-a160-591f8a3fbc07', 2, 'Sau khi trẻ lên đến bục ở cuối dốc, mẹ nhắc nhở bằng lời nói và cử động cơ thể: “Con ơi, xuống đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7a5bbd0a-c843-518e-a160-591f8a3fbc07', 3, 'Khi trẻ xuống dốc, mẹ lại quay mặt về phía trẻ và cầm đồ chơi dẫn trẻ xuống. Bố chú ý bảo vệ trẻ ở bên cạnh, khi trẻ đến cuối mặt đất, kịp thời khen ngợi: “Con thật tuyệt vời!” và đưa quả bóng cho trẻ chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7a5bbd0a-c843-518e-a160-591f8a3fbc07', 'image', '/static/activities/g066/main.jpg', 'Khi lên dốc, hãy động viên trẻ: “Con lên dốc và lấy bóng nào!” Khi xuống dốc, hãy nhắc trẻ: “Con ơi, đi xuống thôi nào!” Khi đến cuối, hãy khen ngợi: “Con thật tuyệt vời!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '7a5bbd0a-c843-518e-a160-591f8a3fbc07', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g067: Cùng leo cầu thang (trang PDF 109)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', 'Cùng leo cầu thang', 'Bố mẹ nên cố gắng hướng dẫn trẻ bám vào lan can hoặc tường.', '**Kỹ năng phát triển:** Khả năng phối hợp cơ thể, Sức mạnh của đôi chân

## Chuẩn bị
- **Không gian:** Cầu thang có tay vịn.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Một món đồ chơi mà trẻ yêu thích.

## Các bước thực hiện
1. Mẹ đặt những món đồ chơi trẻ yêu thích lên tầng trên cùng của cầu thang và hướng dẫn trẻ: “Con ơi, đến lấy đồ chơi đi nào!”
2. Trẻ bám vào tường hoặc lan can và bước lên từng bậc thang. Bố bảo vệ trẻ từ phía sau. Nếu trẻ không thể tự mình bước lên, bố có thể nắm một tay trẻ để trẻ từ từ đi lên.
3. Nếu trẻ sợ leo cầu thang, mẹ có thể hướng dẫn trẻ cầm tay vịn để đi lên cầu thang trước mặt. Sau đó, bố nắm tay trẻ hướng lên trên và động viên: “Con yêu, lấy đồ chơi đi nào!” Sau khi trẻ cố gắng leo lên các bậc thang lần nữa, bố mẹ liền khen ngợi: “Con thật tuyệt vời!”

## Hướng dẫn của chuyên gia
- Trò chơi này nên được chơi sau khi trẻ đã có thể đi lại tự do trên mặt đất bằng phẳng.
- Nếu trẻ cần bố mẹ nắm tay khi bước lên cầu thang, bố mẹ có thể lặp lại bước này vài lần và đổi tay cho nhau.
- Nếu trẻ có thể hoàn thành các bước sử dụng tay vịn, bạn có thể đặt các đồ chơi yêu thích khác lên các bậc thang trước mặt và khuyến khích trẻ bước đến lấy.

> Bố mẹ nên cố gắng hướng dẫn trẻ bám vào lan can hoặc tường.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 15, 18,
       'Một món đồ chơi mà trẻ yêu thích.', ARRAY['Một món đồ chơi mà trẻ yêu thích']::text[], '/static/activities/g067/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng phối hợp cơ thể, Sức mạnh của đôi chân.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', 1, 'Mẹ đặt những món đồ chơi trẻ yêu thích lên tầng trên cùng của cầu thang và hướng dẫn trẻ: “Con ơi, đến lấy đồ chơi đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', 2, 'Trẻ bám vào tường hoặc lan can và bước lên từng bậc thang. Bố bảo vệ trẻ từ phía sau. Nếu trẻ không thể tự mình bước lên, bố có thể nắm một tay trẻ để trẻ từ từ đi lên.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', 3, 'Nếu trẻ sợ leo cầu thang, mẹ có thể hướng dẫn trẻ cầm tay vịn để đi lên cầu thang trước mặt. Sau đó, bố nắm tay trẻ hướng lên trên và động viên: “Con yêu, lấy đồ chơi đi nào!” Sau khi trẻ cố gắng leo lên các bậc thang lần nữa, bố mẹ liền khen ngợi: “Con thật tuyệt vời!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', 'image', '/static/activities/g067/main.jpg', 'Bố mẹ nên cố gắng hướng dẫn trẻ bám vào lan can hoặc tường.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3a46931a-61c3-5bdd-bdf6-83a2a43fc30a', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g068: Dắt “heo con” (trang PDF 110)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c7d6daff-c8a7-5513-a0f4-f822b5454760', 'Dắt “heo con”', 'Trò chơi này cần được chơi dưới sự giám sát của bố mẹ và cần đặc biệt chú ý đến sự an toàn khi sử dụng gậy nhỏ.', '**Kỹ năng phát triển:** Khả năng giữ thăng bằng, Khả năng phối hợp tay, mắt, Kích thích trí tưởng tượng

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Bé đứng.
- **Đồ dùng:** Một gậy nhỏ, một lon sữa bột rỗng, vài tờ giấy màu hồng, một bút dạ, một vòng lắc.

## Các bước thực hiện
1. Bố mẹ dùng giấy màu hồng bọc lon sữa bột rỗng, sau đó dùng bút vẽ mũi, mắt, tai và đuôi của một chú “heo con”.
2. Bố mẹ đưa cho trẻ một cái gậy nhỏ và yêu cầu trẻ đưa “heo con” về nhà và nói: “Con ơi, dùng gậy để đẩy “heo con”, hãy đưa heo con về nhà nhé!”. Nếu trẻ không làm được, bố mẹ có thể làm mẫu một lần.
3. Khi khả năng vận động của trẻ được cải thiện, có thể cung cấp cho trẻ các khối xây dựng với nhiều kích cỡ, hình dạng và màu sắc khác nhau để khuyến khích trẻ tự do xây dựng.

## Hướng dẫn của chuyên gia
- Cây gậy nhỏ được chọn để chơi cần có bề mặt nhẵn, không có gai, không quá mỏng, quá ngắn hoặc quá dài, từ 50 - 80 cm là phù hợp.
- Khi “heo con” đi chệch khỏi lộ trình lúc đang di chuyển về phía trước, bố mẹ có thể giúp trẻ kịp thời dẫn “heo con” trở lại đường thẳng.
- Khi khả năng của trẻ phát triển, bạn có thể chơi trò chơi bắt những quả bóng nhỏ với trẻ. Trò chơi này sẽ khó khăn hơn!

> Trò chơi này cần được chơi dưới sự giám sát của bố mẹ và cần đặc biệt chú ý đến sự an toàn khi sử dụng gậy nhỏ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 15, 18,
       'Một gậy nhỏ, một lon sữa bột rỗng, vài tờ giấy màu hồng, một bút dạ, một vòng lắc.', ARRAY['Một gậy nhỏ', 'một lon sữa bột rỗng', 'vài tờ giấy màu hồng', 'một bút dạ', 'một vòng lắc']::text[], '/static/activities/g068/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng giữ thăng bằng, Khả năng phối hợp tay, mắt, Kích thích trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c7d6daff-c8a7-5513-a0f4-f822b5454760', 1, 'Bố mẹ dùng giấy màu hồng bọc lon sữa bột rỗng, sau đó dùng bút vẽ mũi, mắt, tai và đuôi của một chú “heo con”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c7d6daff-c8a7-5513-a0f4-f822b5454760', 2, 'Bố mẹ đưa cho trẻ một cái gậy nhỏ và yêu cầu trẻ đưa “heo con” về nhà và nói: “Con ơi, dùng gậy để đẩy “heo con”, hãy đưa heo con về nhà nhé!”. Nếu trẻ không làm được, bố mẹ có thể làm mẫu một lần.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c7d6daff-c8a7-5513-a0f4-f822b5454760', 3, 'Khi khả năng vận động của trẻ được cải thiện, có thể cung cấp cho trẻ các khối xây dựng với nhiều kích cỡ, hình dạng và màu sắc khác nhau để khuyến khích trẻ tự do xây dựng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c7d6daff-c8a7-5513-a0f4-f822b5454760', 'image', '/static/activities/g068/main.jpg', 'Trò chơi này cần được chơi dưới sự giám sát của bố mẹ và cần đặc biệt chú ý đến sự an toàn khi sử dụng gậy nhỏ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c7d6daff-c8a7-5513-a0f4-f822b5454760', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g069: Những ngón tay khéo léo (trang PDF 111, 112)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'f04449ad-d057-5bbb-8055-176513176408', 'Những ngón tay khéo léo', 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng nhận thức.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ và bố mẹ mặt đối mặt.
- **Đồ dùng:** Bàn tay của bố mẹ.

## Các bước thực hiện
1. Bố mẹ giơ tay lên, đặt trước mặt trẻ và nói với trẻ: “Con ơi, chúng ta cùng tập ngón tay nhé!”
2. Bố mẹ làm mẫu động tác tay cho trẻ và để trẻ bắt chước.
3. Động tác 1: Duỗi hai ngón tay cái của hai bàn tay, hướng vào nhau, uốn cong hai lần và nói: “Ngón cái, hãy gật đầu khi chúng ta gặp nhau!”
4. Động tác 2: Duỗi ngón trỏ của cả hai tay, hướng vào nhau và uốn cong hai lần và nói “Ngón trỏ, hãy cúi xuống khi gặp nhau!”
5. Động tác 3: Duỗi ngón giữa của cả hai tay, chạm vào nhau hai lần và nói: “Ngón giữa, hãy chạm vào mặt khi chúng ta gặp nhau!”
6. Động tác 4: Duỗi các ngón út của cả hai tay và móc các ngón út lại với nhau và nói “Ngón út, chúng ta sẽ móc tay khi gặp nhau!”
7. Động tác 5: Ngón cái và ngón trỏ của 2 bàn tay chạm vào nhau, 3 ngón còn lại uốn cong và chụm lại tạo thành hình mỏ gà, mổ lên xuống và nói “Gà ríu rít, ríu rít, ăn sâu ăn cơm”.
8. Động tác 6: Dùng lòng bàn tay phải che mu bàn tay trái, quạt lên xuống và nói: “Vịt con, quạc, quạc, biết bơi thì bắt được cá”.
9. Động tác 7: Đặt hai tay lên trên đầu, duỗi ngón cái và ngón trỏ, các ngón còn lại nắm tay và nói “Con cừu nhỏ, be be, be be, be be, trèo lên sườn đồi ăn cỏ”.
10. Động tác 8: Mở ngón tay ra, đưa về phía trước và nói: “Con hổ nhỏ, thích ăn thịt lợn rừng và thỏ”.

## Hướng dẫn của chuyên gia
- Khi bố mẹ thực hiện động tác tay, nên đặt tay trước mặt trẻ. Sau khi trẻ chú ý đến tay bố mẹ, hãy từ từ thực hiện động tác tay và nói trong khi thực hiện. Nếu trẻ không bắt chước được, bố mẹ có thể hỗ trợ để giúp trẻ cử động ngón tay.
- Khi trẻ học các bài tập ngón tay, bố mẹ chỉ cần đọc lại các lời nói và để trẻ thực hiện các động tác tương ứng mà không cần trợ giúp trẻ thêm.
- Bố mẹ cũng có thể thay đổi thứ tự các bài tập ngón tay hoặc thay đổi tốc độ đọc thuộc lòng các lời nói để rèn luyện sự linh hoạt trong các cử động tay của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 15, 18,
       'Bàn tay của bố mẹ.', ARRAY['Bàn tay của bố mẹ']::text[], '/static/activities/g069/step-3.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 1, 'Bố mẹ giơ tay lên, đặt trước mặt trẻ và nói với trẻ: “Con ơi, chúng ta cùng tập ngón tay nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 2, 'Bố mẹ làm mẫu động tác tay cho trẻ và để trẻ bắt chước.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 3, 'Động tác 1: Duỗi hai ngón tay cái của hai bàn tay, hướng vào nhau, uốn cong hai lần và nói: “Ngón cái, hãy gật đầu khi chúng ta gặp nhau!”', '/static/activities/g069/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 4, 'Động tác 2: Duỗi ngón trỏ của cả hai tay, hướng vào nhau và uốn cong hai lần và nói “Ngón trỏ, hãy cúi xuống khi gặp nhau!”', '/static/activities/g069/step-4.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 5, 'Động tác 3: Duỗi ngón giữa của cả hai tay, chạm vào nhau hai lần và nói: “Ngón giữa, hãy chạm vào mặt khi chúng ta gặp nhau!”', '/static/activities/g069/step-5.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 6, 'Động tác 4: Duỗi các ngón út của cả hai tay và móc các ngón út lại với nhau và nói “Ngón út, chúng ta sẽ móc tay khi gặp nhau!”', '/static/activities/g069/step-6.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 7, 'Động tác 5: Ngón cái và ngón trỏ của 2 bàn tay chạm vào nhau, 3 ngón còn lại uốn cong và chụm lại tạo thành hình mỏ gà, mổ lên xuống và nói “Gà ríu rít, ríu rít, ăn sâu ăn cơm”.', '/static/activities/g069/step-7.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 8, 'Động tác 6: Dùng lòng bàn tay phải che mu bàn tay trái, quạt lên xuống và nói: “Vịt con, quạc, quạc, biết bơi thì bắt được cá”.', '/static/activities/g069/step-8.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 9, 'Động tác 7: Đặt hai tay lên trên đầu, duỗi ngón cái và ngón trỏ, các ngón còn lại nắm tay và nói “Con cừu nhỏ, be be, be be, be be, trèo lên sườn đồi ăn cỏ”.', '/static/activities/g069/step-9.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 10, 'Động tác 8: Mở ngón tay ra, đưa về phía trước và nói: “Con hổ nhỏ, thích ăn thịt lợn rừng và thỏ”.', '/static/activities/g069/step-10.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-3.jpg', 'Bước 3', 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-4.jpg', 'Bước 4', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-5.jpg', 'Bước 5', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-6.jpg', 'Bước 6', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-7.jpg', 'Bước 7', 4);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-8.jpg', 'Bước 8', 5);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-9.jpg', 'Bước 9', 6);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f04449ad-d057-5bbb-8055-176513176408', 'image', '/static/activities/g069/step-10.jpg', 'Bước 10', 7);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'f04449ad-d057-5bbb-8055-176513176408', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g070: Móc dây chun (trang PDF 113)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'fbb1c403-4d31-5384-b9f1-358e245aaef3', 'Móc dây chun', '“Nhắm vào cái lỗ tròn nhé!”', '**Kỹ năng phát triển:** Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh

## Chuẩn bị
- **Không gian:** Mặt đất hoặc mặt bàn.
- **Tư thế:** Trẻ ngồi.
- **Đồ dùng:** Vài dây chun, một chậu, 3 chiếc đũa và một chiếc đĩa trống.

## Các bước thực hiện
1. Bố mẹ đổ đầy nửa chậu nước và đổ dây chun vào đó.
2. Bố mẹ và trẻ mỗi người cầm một chiếc đũa. Bố mẹ làm mẫu bằng cách dùng đũa móc lên một sợi dây chun nổi trên mặt nước rồi đặt lên đĩa bên cạnh.
3. Bố mẹ hướng dẫn trẻ dùng đũa móc dây chun lên và nói: “Con yêu ơi, chơi móc dây chun nào!”
4. Bố mẹ và trẻ có thể chọn cùng lúc, thay phiên nhau hoặc thi đua nhau cùng móc.

## Hướng dẫn của chuyên gia
- Nếu lúc đầu trẻ không thể móc dây chun nhỏ được, bố mẹ có thể chọn dây chun lớn hơn để giảm bớt độ khó.
- Bố mẹ khuyến khích trẻ tự mình thử, nhưng nếu trẻ cố gắng nhiều lần mà vẫn không móc được thì bố mẹ cần giúp trẻ nhắm vào lỗ trước khi trẻ sắp bỏ cuộc để có thể làm được.

> “Nhắm vào cái lỗ tròn nhé!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 15, 18,
       'Vài dây chun, một chậu, 3 chiếc đũa và một chiếc đĩa trống.', ARRAY['Vài dây chun', 'một chậu', '3 chiếc đũa và một chiếc đĩa trống']::text[], '/static/activities/g070/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fbb1c403-4d31-5384-b9f1-358e245aaef3', 1, 'Bố mẹ đổ đầy nửa chậu nước và đổ dây chun vào đó.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fbb1c403-4d31-5384-b9f1-358e245aaef3', 2, 'Bố mẹ và trẻ mỗi người cầm một chiếc đũa. Bố mẹ làm mẫu bằng cách dùng đũa móc lên một sợi dây chun nổi trên mặt nước rồi đặt lên đĩa bên cạnh.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fbb1c403-4d31-5384-b9f1-358e245aaef3', 3, 'Bố mẹ hướng dẫn trẻ dùng đũa móc dây chun lên và nói: “Con yêu ơi, chơi móc dây chun nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('fbb1c403-4d31-5384-b9f1-358e245aaef3', 4, 'Bố mẹ và trẻ có thể chọn cùng lúc, thay phiên nhau hoặc thi đua nhau cùng móc.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('fbb1c403-4d31-5384-b9f1-358e245aaef3', 'image', '/static/activities/g070/main.jpg', '“Nhắm vào cái lỗ tròn nhé!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'fbb1c403-4d31-5384-b9f1-358e245aaef3', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g071: Đi bắt đồ chơi dây cót (trang PDF 114)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '71e841d7-5c98-50a3-b956-1d8b17fba121', 'Đi bắt đồ chơi dây cót', '“Con yêu bắt được nó! Con giỏi quá!”', '**Kỹ năng phát triển:** Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh, Kỹ năng phản hồi

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một đồ chơi lên dây cót, 2 cốc nhựa.

## Các bước thực hiện
1. Bố mẹ và trẻ mỗi người có một chiếc cốc. Bố mẹ cầm đồ chơi lên dây cót và đặt xuống thảm sàn để đồ chơi nhảy lên và nói: “Chúng ta sẽ bắt nó!” Sau đó, dùng cốc đậy lại đồ chơi lên dây cót. Sau khi đậy lại, bạn có thể cổ vũ và ăn mừng.
2. Bố mẹ vặn đồ chơi lên dây cót một lần nữa và khuyến khích trẻ chơi lại: “Con ơi, dùng cốc lại bắt nó đi!” Sau khi trẻ đậy lại, bố mẹ khen trẻ: “Con bắt được rồi! Con giỏi quá!”.
3. Bố mẹ và trẻ lần lượt chơi lại trò chơi.

## Hướng dẫn của chuyên gia
- Chiếc cốc bạn chọn cần phải lớn hơn đồ chơi lên dây cót, nhưng không quá lớn và trẻ có thể cầm được bằng một tay.
- Tốc độ nhảy lên của đồ chơi dây cót tương đối chậm. Sau khi trẻ đã quen với trò chơi, có thể thay thế bằng những quả bóng nhỏ. Bố mẹ có thể điều chỉnh độ khó của trò chơi bằng cách kiểm soát tốc độ lăn của quả bóng, tạo cho trẻ những thử thách mới.

> “Con yêu bắt được nó! Con giỏi quá!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 15, 18,
       'Một đồ chơi lên dây cót, 2 cốc nhựa.', ARRAY['Một đồ chơi lên dây cót', '2 cốc nhựa']::text[], '/static/activities/g071/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Khả năng phối hợp tay, mắt, Kỹ năng vận động tinh, Kỹ năng phản hồi.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('71e841d7-5c98-50a3-b956-1d8b17fba121', 1, 'Bố mẹ và trẻ mỗi người có một chiếc cốc. Bố mẹ cầm đồ chơi lên dây cót và đặt xuống thảm sàn để đồ chơi nhảy lên và nói: “Chúng ta sẽ bắt nó!” Sau đó, dùng cốc đậy lại đồ chơi lên dây cót. Sau khi đậy lại, bạn có thể cổ vũ và ăn mừng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('71e841d7-5c98-50a3-b956-1d8b17fba121', 2, 'Bố mẹ vặn đồ chơi lên dây cót một lần nữa và khuyến khích trẻ chơi lại: “Con ơi, dùng cốc lại bắt nó đi!” Sau khi trẻ đậy lại, bố mẹ khen trẻ: “Con bắt được rồi! Con giỏi quá!”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('71e841d7-5c98-50a3-b956-1d8b17fba121', 3, 'Bố mẹ và trẻ lần lượt chơi lại trò chơi.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('71e841d7-5c98-50a3-b956-1d8b17fba121', 'image', '/static/activities/g071/main.jpg', '“Con yêu bắt được nó! Con giỏi quá!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '71e841d7-5c98-50a3-b956-1d8b17fba121', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g072: Nhặt đậu vào bát (trang PDF 115)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0a572624-5602-5e7e-a856-82d1f68560e0', 'Nhặt đậu vào bát', 'Nếu trẻ chưa biết cách cho đậu (đỗ) vào bát, bố mẹ có thể làm mẫu trước rồi hướng dẫn trẻ hoàn thành.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp bằng cả hai tay, Cảm giác về không gian

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một nắm hạt đậu (đỗ) hai màu, một đĩa và hai bát nhựa nhỏ.

## Các bước thực hiện
1. Trộn hai loại đậu (đỗ) với nhau và cho vào đĩa, đặt hai bát nhựa cạnh đĩa và hướng dẫn trẻ xếp riêng các loại đậu (đỗ) có màu sắc khác nhau vào hai bát nhựa.
2. Bố mẹ cũng có thể rải đậu (đỗ) ở các vị trí khác nhau trên bàn, khuyến khích trẻ dùng mắt tìm đậu, sau đó đưa tay nhặt và cho vào bát.

## Hướng dẫn của chuyên gia
- Trong quá trình chơi, bố mẹ cần hết sức chú ý đến trẻ và cẩn thận để trẻ không vô tình nuốt phải đậu (đỗ).
- Bố mẹ cũng có thể dùng những hạt khác và các thực phẩm khác thay cho đậu (đỗ). Bố mẹ cũng có thể thay phiên nhau cho đậu vào bát nhỏ cùng trẻ để tăng hứng thú của trẻ vào trò chơi. Bố mẹ cũng có thể giúp trẻ hình thành khái niệm thay phiên nhau trong trò chơi.
- Trò chơi này có thể chơi ở các tư thế khác nhau, kết hợp các bài tập vận động tinh và vận động thô.

> Nếu trẻ chưa biết cách cho đậu (đỗ) vào bát, bố mẹ có thể làm mẫu trước rồi hướng dẫn trẻ hoàn thành.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 15, 18,
       'Một nắm hạt đậu (đỗ) hai màu, một đĩa và hai bát nhựa nhỏ.', ARRAY['Một nắm hạt đậu (đỗ) hai màu', 'một đĩa và hai bát nhựa nhỏ']::text[], '/static/activities/g072/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp bằng cả hai tay, Cảm giác về không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0a572624-5602-5e7e-a856-82d1f68560e0', 1, 'Trộn hai loại đậu (đỗ) với nhau và cho vào đĩa, đặt hai bát nhựa cạnh đĩa và hướng dẫn trẻ xếp riêng các loại đậu (đỗ) có màu sắc khác nhau vào hai bát nhựa.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0a572624-5602-5e7e-a856-82d1f68560e0', 2, 'Bố mẹ cũng có thể rải đậu (đỗ) ở các vị trí khác nhau trên bàn, khuyến khích trẻ dùng mắt tìm đậu, sau đó đưa tay nhặt và cho vào bát.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0a572624-5602-5e7e-a856-82d1f68560e0', 'image', '/static/activities/g072/main.jpg', 'Nếu trẻ chưa biết cách cho đậu (đỗ) vào bát, bố mẹ có thể làm mẫu trước rồi hướng dẫn trẻ hoàn thành.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0a572624-5602-5e7e-a856-82d1f68560e0', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g073: Nào cùng nhảy nhé! (trang PDF 116)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0e57938a-659c-534b-be3f-2c7b8e8df14a', 'Nào cùng nhảy nhé!', '“Chúng ta hãy cùng học cách nhảy nhé!”', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ và bố mẹ mặt đối mặt.
- **Đồ dùng:** Một số hình ảnh các nhân vật đang hoạt động.

## Các bước thực hiện
1. Bố mẹ lấy ra những bức tranh có các nhân vật hành động và đặt lên bàn và nói: “Con ơi, ai đang nhảy vậy?” Nếu trẻ chỉ vào bức tranh tương ứng hoặc trả lời tên nhân vật, chẳng hạn như “anh trai” thì bố mẹ sẽ khen ngợi con rồi nói: “Đúng rồi, anh trai đang nhảy, chúng ta cùng học cách nhảy nhé!” Bố mẹ dẫn tay trẻ cùng nhảy.
2. Sau đó, bố mẹ hỏi: “Con ơi, ai đang chơi bóng đá?” Trẻ chỉ vào bức tranh tương ứng hoặc trả lời bằng lời. Mẹ nói: “Đúng rồi, chú đang chơi bóng đá”. Sau đó, bố mẹ làm động tác chơi bóng với trẻ.
3. Nếu trẻ trả lời sai thì không sao cả. Bố mẹ chỉ ra bức tranh đúng và nói lại câu trả lời đúng.

## Hướng dẫn của chuyên gia
- Bố mẹ có thể hướng dẫn trẻ quan sát các hành động khác nhau của con người trong cuộc sống hằng ngày và mô tả tên các hành động đó.
- Chú ý nâng cao trải nghiệm của trẻ khi thực hiện các hành động khác nhau trong cuộc sống.

> “Chúng ta hãy cùng học cách nhảy nhé!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 15, 18,
       'Một số hình ảnh các nhân vật đang hoạt động.', ARRAY['Một số hình ảnh các nhân vật đang hoạt động']::text[], '/static/activities/g073/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0e57938a-659c-534b-be3f-2c7b8e8df14a', 1, 'Bố mẹ lấy ra những bức tranh có các nhân vật hành động và đặt lên bàn và nói: “Con ơi, ai đang nhảy vậy?” Nếu trẻ chỉ vào bức tranh tương ứng hoặc trả lời tên nhân vật, chẳng hạn như “anh trai” thì bố mẹ sẽ khen ngợi con rồi nói: “Đúng rồi, anh trai đang nhảy, chúng ta cùng học cách nhảy nhé!” Bố mẹ dẫn tay trẻ cùng nhảy.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0e57938a-659c-534b-be3f-2c7b8e8df14a', 2, 'Sau đó, bố mẹ hỏi: “Con ơi, ai đang chơi bóng đá?” Trẻ chỉ vào bức tranh tương ứng hoặc trả lời bằng lời. Mẹ nói: “Đúng rồi, chú đang chơi bóng đá”. Sau đó, bố mẹ làm động tác chơi bóng với trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0e57938a-659c-534b-be3f-2c7b8e8df14a', 3, 'Nếu trẻ trả lời sai thì không sao cả. Bố mẹ chỉ ra bức tranh đúng và nói lại câu trả lời đúng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0e57938a-659c-534b-be3f-2c7b8e8df14a', 'image', '/static/activities/g073/main.jpg', '“Chúng ta hãy cùng học cách nhảy nhé!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0e57938a-659c-534b-be3f-2c7b8e8df14a', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g074: Đồ vật nhỏ, công dụng lớn (trang PDF 117)
-- Cần duyệt: Tiêu đề và nhóm trò chơi bị cắt khi scan; chỉ đọc được “..., công dụng lớn”.
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b41e43ad-b8b4-5fe2-a89f-759f34956579', 'Đồ vật nhỏ, công dụng lớn', 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp bằng cả hai tay, Cảm giác về không gian.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp bằng cả hai tay, Cảm giác về không gian

## Chuẩn bị
- **Không gian:** Mặt bàn.
- **Tư thế:** Bé ngồi mặt đối mặt với bố mẹ.
- **Đồ dùng:** Một cốc, một thìa.

## Các bước thực hiện
1. Khi trẻ cầm cốc, bố mẹ nói với trẻ: “Đây là cốc, con dùng uống nước nhé!” Bố mẹ cầm cốc lên, làm động tác uống nước và nói: “Cốc là để uống nước”. Trên bàn đặt cốc, thìa, khuyến khích trẻ chỉ ra cái nào dùng để uống nước.
2. Khi trẻ cầm bút, bố mẹ bảo trẻ: “Bút này, con vẽ đi nào!” Bố mẹ cầm bút lên, làm động tác vẽ và nói: “Bút là để vẽ”. Sau đó, bố mẹ đặt bút, cốc, thìa lên bàn và khuyến khích trẻ chỉ ra những vật nào dùng để vẽ.
3. Dạy trẻ cách sử dụng những đồ dùng thông thường hằng ngày theo cách tương tự.

## Hướng dẫn của chuyên gia
- Trong cuộc sống, hãy cho trẻ nhìn đồ vật và cách sử dụng của đồ vật đó. Bố mẹ có thể cho trẻ biết tên và công dụng của đồ vật đó.
- Trong quá trình chơi trò chơi, trước tiên bạn có thể để trẻ nhận biết và sau đó cố gắng diễn đạt bằng lời.
- Nếu trẻ kể tên được các đồ vật, bố mẹ có thể hỏi: “Con có thể dùng gì để uống nước?” “Con có thể dùng gì để ăn cơm?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Một cốc, một thìa.', ARRAY['Một cốc', 'một thìa']::text[], '/static/activities/g074/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp bằng cả hai tay, Cảm giác về không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b41e43ad-b8b4-5fe2-a89f-759f34956579', 1, 'Khi trẻ cầm cốc, bố mẹ nói với trẻ: “Đây là cốc, con dùng uống nước nhé!” Bố mẹ cầm cốc lên, làm động tác uống nước và nói: “Cốc là để uống nước”. Trên bàn đặt cốc, thìa, khuyến khích trẻ chỉ ra cái nào dùng để uống nước.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b41e43ad-b8b4-5fe2-a89f-759f34956579', 2, 'Khi trẻ cầm bút, bố mẹ bảo trẻ: “Bút này, con vẽ đi nào!” Bố mẹ cầm bút lên, làm động tác vẽ và nói: “Bút là để vẽ”. Sau đó, bố mẹ đặt bút, cốc, thìa lên bàn và khuyến khích trẻ chỉ ra những vật nào dùng để vẽ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b41e43ad-b8b4-5fe2-a89f-759f34956579', 3, 'Dạy trẻ cách sử dụng những đồ dùng thông thường hằng ngày theo cách tương tự.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b41e43ad-b8b4-5fe2-a89f-759f34956579', 'image', '/static/activities/g074/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b41e43ad-b8b4-5fe2-a89f-759f34956579', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g075: Đọc sách cùng con (trang PDF 118)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'f19babaf-bd1f-57af-891c-e84ae4a14e34', 'Đọc sách cùng con', 'Bố mẹ nên biểu cảm sinh động khi kể chuyện, không nên chỉ đọc lời trong sách.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Kỹ năng diễn đạt ngôn ngữ, Rèn luyện thói quen đọc sách

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi, bố mẹ ngồi nghiêng về bên phải của trẻ, tạo thành tư thế ngồi hình chữ “L”.
- **Đồ dùng:** Một số sách tranh.

## Các bước thực hiện
1. Bố mẹ lấy ra một vài cuốn sách tranh, để trẻ chọn một cuốn mà trẻ thích, sau đó cất những cuốn sách tranh khác đi.
2. Đọc to tên các đồ vật hoặc con vật trong sách, sau đó thực hiện một số hành động giống như trong sách thể hiện. Ví dụ, chỉ vào con cá nhỏ trong sách và nói “con cá nhỏ” và thực hiện động tác bơi giống như con cá nhỏ, nói “bơi, bơi”.
3. Bố mẹ chỉ vào các hình ảnh trong sách, mô tả các tình tiết chính trong sách và đợi trẻ chú ý và bắt chước.
4. Hướng dẫn trẻ chỉ ra các đồ vật, con vật trong sách. Ví dụ, bạn có thể hỏi: “Con cá nhỏ là con nào?” “Con gà trống lớn gáy như thế nào?”, “Con rùa nhỏ có bò không?”

## Hướng dẫn của chuyên gia
- Bố mẹ nên dành thời gian thường xuyên để đọc sách cùng con mỗi ngày.
- Bạn có thể chọn một số truyện tranh nhận thức cho trẻ ở giai đoạn này như tranh về trái cây, tranh động vật,... Bạn cũng có thể chọn một số truyện tranh có tranh lớn, ít chữ, nội dung xoay quanh cuộc sống của trẻ.

> Bố mẹ nên biểu cảm sinh động khi kể chuyện, không nên chỉ đọc lời trong sách.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Một số sách tranh.', ARRAY['Một số sách tranh']::text[], '/static/activities/g075/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Kỹ năng diễn đạt ngôn ngữ, Rèn luyện thói quen đọc sách.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f19babaf-bd1f-57af-891c-e84ae4a14e34', 1, 'Bố mẹ lấy ra một vài cuốn sách tranh, để trẻ chọn một cuốn mà trẻ thích, sau đó cất những cuốn sách tranh khác đi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f19babaf-bd1f-57af-891c-e84ae4a14e34', 2, 'Đọc to tên các đồ vật hoặc con vật trong sách, sau đó thực hiện một số hành động giống như trong sách thể hiện. Ví dụ, chỉ vào con cá nhỏ trong sách và nói “con cá nhỏ” và thực hiện động tác bơi giống như con cá nhỏ, nói “bơi, bơi”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f19babaf-bd1f-57af-891c-e84ae4a14e34', 3, 'Bố mẹ chỉ vào các hình ảnh trong sách, mô tả các tình tiết chính trong sách và đợi trẻ chú ý và bắt chước.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('f19babaf-bd1f-57af-891c-e84ae4a14e34', 4, 'Hướng dẫn trẻ chỉ ra các đồ vật, con vật trong sách. Ví dụ, bạn có thể hỏi: “Con cá nhỏ là con nào?” “Con gà trống lớn gáy như thế nào?”, “Con rùa nhỏ có bò không?”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('f19babaf-bd1f-57af-891c-e84ae4a14e34', 'image', '/static/activities/g075/main.jpg', 'Bố mẹ nên biểu cảm sinh động khi kể chuyện, không nên chỉ đọc lời trong sách.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'f19babaf-bd1f-57af-891c-e84ae4a14e34', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g076: Gia đình nhỏ (trang PDF 119)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '96a6c541-def5-584e-bb6d-f1382ad0a6a3', 'Gia đình nhỏ', '“Đây là ai?”', '**Kỹ năng phát triển:** Khả năng nhận thức, Kỹ năng diễn đạt ngôn ngữ, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Bé ngồi mặt đối mặt với bố mẹ.
- **Đồ dùng:** Một album ảnh gia đình.

## Các bước thực hiện
1. Mở album ảnh gia đình, chỉ vào người trong ảnh và hỏi trẻ: “Đây là ai?” Nếu trẻ trả lời đúng, hãy khen ngợi trẻ: “Đúng rồi, đây là mẹ”.
2. Sử dụng phương pháp tương tự để hướng dẫn trẻ nhận biết tên các thành viên khác trong gia đình.
3. Sau một vài lần, bạn có thể hỏi trẻ: “Ai là...?” Nếu trẻ trả lời đúng thì nói với trẻ “Đúng rồi, là bố đây”...

## Hướng dẫn của chuyên gia
- Khi xem album ảnh, bố mẹ cũng có thể miêu tả đặc điểm của các thành viên trong gia đình như: bố cao, bà nội tóc bạc,...
- Trước tiên, hãy cố gắng cùng trẻ tìm hiểu tên của các thành viên trong gia đình mà trẻ sống cùng.

> “Đây là ai?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Một album ảnh gia đình.', ARRAY['Một album ảnh gia đình']::text[], '/static/activities/g076/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Kỹ năng diễn đạt ngôn ngữ, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('96a6c541-def5-584e-bb6d-f1382ad0a6a3', 1, 'Mở album ảnh gia đình, chỉ vào người trong ảnh và hỏi trẻ: “Đây là ai?” Nếu trẻ trả lời đúng, hãy khen ngợi trẻ: “Đúng rồi, đây là mẹ”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('96a6c541-def5-584e-bb6d-f1382ad0a6a3', 2, 'Sử dụng phương pháp tương tự để hướng dẫn trẻ nhận biết tên các thành viên khác trong gia đình.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('96a6c541-def5-584e-bb6d-f1382ad0a6a3', 3, 'Sau một vài lần, bạn có thể hỏi trẻ: “Ai là...?” Nếu trẻ trả lời đúng thì nói với trẻ “Đúng rồi, là bố đây”...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('96a6c541-def5-584e-bb6d-f1382ad0a6a3', 'image', '/static/activities/g076/main.jpg', '“Đây là ai?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '96a6c541-def5-584e-bb6d-f1382ad0a6a3', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g077: Đặt trái cây vào đĩa (trang PDF 120)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e7c0c96e-adce-5592-bb64-38e9aa83157b', 'Đặt trái cây vào đĩa', 'Táo và táo đều giống nhau', '**Kỹ năng phát triển:** Khả năng phân loại đơn giản, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Vài quả cam, quả táo, 2 đĩa đựng trái cây.

## Các bước thực hiện
1. Đặt một số cam và táo vào hai đĩa và đặt lên bàn.
2. Lấy một quả táo cho vào một đĩa đựng trái cây và lấy một quả cam cho vào một đĩa đựng trái cây khác.
3. Đưa cho trẻ một quả táo khác và hỏi: “Quả táo ở đâu?” Nếu trẻ có thể đặt quả táo vào đĩa trái cây nơi đặt quả táo, hãy khen ngợi: “Con giỏi quá, táo và táo đều giống nhau”. Nếu trẻ đặt quả táo sai, bố mẹ nên lấy táo ra và nói: “Con cho táo vào đĩa táo nhé vì chúng giống nhau”.
4. Đưa cho trẻ một quả cam khác và hỏi: “Con để quả cam ở đâu?” Nếu trẻ đặt đúng thì khen ngợi trẻ.

## Hướng dẫn của chuyên gia
- Lúc đầu, bạn chỉ nên lấy hai loại đồ vật ra để phân loại, sau đó tăng dần số lượng để nâng cao khả năng nhận thức của trẻ.
- Khi khả năng của trẻ phát triển, bạn có thể thêm các loại đồ vật khác được phân loại như đồ chơi, đồ ăn,...

> Táo và táo đều giống nhau

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Vài quả cam, quả táo, 2 đĩa đựng trái cây.', ARRAY['Vài quả cam', 'quả táo', '2 đĩa đựng trái cây']::text[], '/static/activities/g077/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng phân loại đơn giản, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e7c0c96e-adce-5592-bb64-38e9aa83157b', 1, 'Đặt một số cam và táo vào hai đĩa và đặt lên bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e7c0c96e-adce-5592-bb64-38e9aa83157b', 2, 'Lấy một quả táo cho vào một đĩa đựng trái cây và lấy một quả cam cho vào một đĩa đựng trái cây khác.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e7c0c96e-adce-5592-bb64-38e9aa83157b', 3, 'Đưa cho trẻ một quả táo khác và hỏi: “Quả táo ở đâu?” Nếu trẻ có thể đặt quả táo vào đĩa trái cây nơi đặt quả táo, hãy khen ngợi: “Con giỏi quá, táo và táo đều giống nhau”. Nếu trẻ đặt quả táo sai, bố mẹ nên lấy táo ra và nói: “Con cho táo vào đĩa táo nhé vì chúng giống nhau”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e7c0c96e-adce-5592-bb64-38e9aa83157b', 4, 'Đưa cho trẻ một quả cam khác và hỏi: “Con để quả cam ở đâu?” Nếu trẻ đặt đúng thì khen ngợi trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e7c0c96e-adce-5592-bb64-38e9aa83157b', 'image', '/static/activities/g077/main.jpg', 'Táo và táo đều giống nhau', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e7c0c96e-adce-5592-bb64-38e9aa83157b', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g078: Trốn tìm (trang PDF 121)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0c0b47af-2573-5913-ae5e-8d78d99135f1', 'Trốn tìm', 'Trong trò chơi, bố mẹ mô tả tình huống bằng một giọng điệu ngắn gọn và sinh động.', '**Kỹ năng phát triển:** Khả năng nhận thức, Cảm giác không gian, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Trong nhà.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Bàn, tủ, giường và các đồ dùng có kích thước lớn khác.

## Các bước thực hiện
1. Bố nói với trẻ: “Hôm nay, chúng ta sẽ chơi một trò chơi rất vui tên là “trốn tìm”. Mẹ trốn, còn bố và con nhắm mắt lại và đếm “một, hai, ba”, sau đó tìm kiếm mẹ khi đếm đến ba.
2. Bố cùng con đi tìm mẹ và nói: “Mẹ đâu rồi?”, sau đó nhìn xuống gầm bàn, sau cửa, bên trong tủ,... cùng con. Trong khi bố đang tìm thì bố tiếp tục nói những câu như: “Không có gì dưới gầm bàn cả”. Khi mẹ sắp được tìm thấy, mẹ có thể nhảy ra, mỉm cười nhìn con và nói: “Tìm thấy rồi! Con đã tìm thấy mẹ rồi!” Sau đó khen ngợi, ôm hôn con.
3. Bố nấp cùng con, nói chuyện nhẹ nhàng với con, nhắc nhở con không được nói to, tạo không khí căng thẳng, phấn khởi.
4. Trong khi mẹ đang tìm kiếm, mẹ sẽ nói: “Con tôi đâu rồi? Con tôi đi đâu rồi?” Mẹ mô tả quá trình bằng những câu nói như “Không có gì dưới gầm bàn”, “Không có gì đằng sau cánh cửa”,...
5. Khi tìm thấy trẻ, mẹ có thể nói: “Tìm thấy rồi” và ôm, hôn hoặc bế trẻ để thể hiện niềm vui, sự phấn khích.

## Hướng dẫn của chuyên gia
- Khi chơi trò chơi này lần đầu tiên, nơi bố mẹ trốn phải tương đối dễ tìm để trẻ có thể nhanh chóng tìm thấy.
- Bố mẹ có thể đổi vai và chơi với các thành viên khác trong gia đình như ông bà. Sau khi trẻ đã quen với quy trình và luật chơi, trẻ có thể chơi trò chơi này một mình với bố mẹ.
- Chú ý đến sự an toàn của trẻ trong khi chơi.

> Trong trò chơi, bố mẹ mô tả tình huống bằng một giọng điệu ngắn gọn và sinh động.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Bàn, tủ, giường và các đồ dùng có kích thước lớn khác.', ARRAY['Bàn', 'tủ', 'giường và các đồ dùng có kích thước lớn khác']::text[], NULL, 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Cảm giác không gian, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0c0b47af-2573-5913-ae5e-8d78d99135f1', 1, 'Bố nói với trẻ: “Hôm nay, chúng ta sẽ chơi một trò chơi rất vui tên là “trốn tìm”. Mẹ trốn, còn bố và con nhắm mắt lại và đếm “một, hai, ba”, sau đó tìm kiếm mẹ khi đếm đến ba.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0c0b47af-2573-5913-ae5e-8d78d99135f1', 2, 'Bố cùng con đi tìm mẹ và nói: “Mẹ đâu rồi?”, sau đó nhìn xuống gầm bàn, sau cửa, bên trong tủ,... cùng con. Trong khi bố đang tìm thì bố tiếp tục nói những câu như: “Không có gì dưới gầm bàn cả”. Khi mẹ sắp được tìm thấy, mẹ có thể nhảy ra, mỉm cười nhìn con và nói: “Tìm thấy rồi! Con đã tìm thấy mẹ rồi!” Sau đó khen ngợi, ôm hôn con.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0c0b47af-2573-5913-ae5e-8d78d99135f1', 3, 'Bố nấp cùng con, nói chuyện nhẹ nhàng với con, nhắc nhở con không được nói to, tạo không khí căng thẳng, phấn khởi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0c0b47af-2573-5913-ae5e-8d78d99135f1', 4, 'Trong khi mẹ đang tìm kiếm, mẹ sẽ nói: “Con tôi đâu rồi? Con tôi đi đâu rồi?” Mẹ mô tả quá trình bằng những câu nói như “Không có gì dưới gầm bàn”, “Không có gì đằng sau cánh cửa”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0c0b47af-2573-5913-ae5e-8d78d99135f1', 5, 'Khi tìm thấy trẻ, mẹ có thể nói: “Tìm thấy rồi” và ôm, hôn hoặc bế trẻ để thể hiện niềm vui, sự phấn khích.', NULL);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0c0b47af-2573-5913-ae5e-8d78d99135f1', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g079: Cả nhà cùng ăn salad (trang PDF 122)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '47341a10-39ce-514b-8d4e-68714f99ee00', 'Cả nhà cùng ăn salad', 'Ngon quá!', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một đĩa salad hoa quả và một thìa nhỏ.

## Các bước thực hiện
1. Cả nhà ngồi quanh một chiếc bàn nhỏ với đĩa salad trái cây trên bàn.
2. Mẹ nói: “Chúng ta cùng ăn salad trái cây nhé!” Sau khi bé ăn hai miếng, mẹ sờ bụng và nói: “Mẹ cũng muốn ăn trái cây đó”, rồi mẹ làm động tác nhai: “Măm, măm, ngon quá, cảm ơn con!”
3. Bố mở miệng và chỉ vào miệng mình, ra hiệu cho trẻ biết rằng mình cũng muốn ăn. Bố hướng dẫn trẻ hiểu cách giao tiếp không lời của bố, sau đó trẻ đút thức ăn cho bố. Bố sẽ nói: “Cảm ơn con yêu!”

## Hướng dẫn của chuyên gia
- Bố mẹ có thể sử dụng các biểu cảm khuôn mặt và cử động phong phú để giao tiếp với con mình.
- Khi khả năng nhận thức của trẻ tăng lên, một số thay đổi cũng có thể được thêm vào. Ví dụ, khi trẻ chuẩn bị đưa cho bố một miếng chuối, bố có thể lắc đầu và nói: “Bố muốn ăn một miếng táo”. Sau đó, chờ phản ứng của trẻ.

> Ngon quá!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Một đĩa salad hoa quả và một thìa nhỏ.', ARRAY['Một đĩa salad hoa quả và một thìa nhỏ']::text[], '/static/activities/g079/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('47341a10-39ce-514b-8d4e-68714f99ee00', 1, 'Cả nhà ngồi quanh một chiếc bàn nhỏ với đĩa salad trái cây trên bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('47341a10-39ce-514b-8d4e-68714f99ee00', 2, 'Mẹ nói: “Chúng ta cùng ăn salad trái cây nhé!” Sau khi bé ăn hai miếng, mẹ sờ bụng và nói: “Mẹ cũng muốn ăn trái cây đó”, rồi mẹ làm động tác nhai: “Măm, măm, ngon quá, cảm ơn con!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('47341a10-39ce-514b-8d4e-68714f99ee00', 3, 'Bố mở miệng và chỉ vào miệng mình, ra hiệu cho trẻ biết rằng mình cũng muốn ăn. Bố hướng dẫn trẻ hiểu cách giao tiếp không lời của bố, sau đó trẻ đút thức ăn cho bố. Bố sẽ nói: “Cảm ơn con yêu!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('47341a10-39ce-514b-8d4e-68714f99ee00', 'image', '/static/activities/g079/main.jpg', 'Ngon quá!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '47341a10-39ce-514b-8d4e-68714f99ee00', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g080: Cởi tất nào (trang PDF 123)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0555b8db-e666-555f-94d7-53f5df7a7c74', 'Cởi tất nào', '“Chúng ta cần phải cởi tất ra!”', '**Kỹ năng phát triển:** Khả năng tự lập, Khả năng phối hợp tay và mắt

## Chuẩn bị
- **Không gian:** Giường hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi đối diện bố mẹ.
- **Đồ dùng:** Một vài đôi tất.

## Các bước thực hiện
1. Bố mẹ nói với trẻ: “Cởi tất ra nào!”. Sau đó làm mẫu thật chậm cho trẻ: vén gấu quần lên, thọc ngón tay cái vào tất, dùng tay cố định tất, mở rộng và kéo xuống. Khi kéo tới giữa lòng bàn chân, dùng tay còn lại kéo phần đầu tất và cởi hẳn ra.
2. Động viên để trẻ bắt chước các động tác và tự cởi tất trên chân. Nếu trẻ gặp khó khăn trong quá trình thực hiện, bố mẹ hãy hỗ trợ trẻ, nhưng không nên làm hộ.
3. Sau khi trẻ cởi tất ra, bố mẹ khen ngợi trẻ: “Hoan hô! Con tự cởi được tất rồi!”

## Hướng dẫn của chuyên gia
- Ban đầu, bạn có thể giúp trẻ nâng lòng bàn chân và để trẻ kéo tất ra.
- Cho trẻ nhiều cơ hội vận động hơn trong cuộc sống hằng ngày.

> “Chúng ta cần phải cởi tất ra!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi tự lập._', 'play', 15, 18,
       'Một vài đôi tất.', ARRAY['Một vài đôi tất']::text[], '/static/activities/g080/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng tự lập, Khả năng phối hợp tay và mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0555b8db-e666-555f-94d7-53f5df7a7c74', 1, 'Bố mẹ nói với trẻ: “Cởi tất ra nào!”. Sau đó làm mẫu thật chậm cho trẻ: vén gấu quần lên, thọc ngón tay cái vào tất, dùng tay cố định tất, mở rộng và kéo xuống. Khi kéo tới giữa lòng bàn chân, dùng tay còn lại kéo phần đầu tất và cởi hẳn ra.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0555b8db-e666-555f-94d7-53f5df7a7c74', 2, 'Động viên để trẻ bắt chước các động tác và tự cởi tất trên chân. Nếu trẻ gặp khó khăn trong quá trình thực hiện, bố mẹ hãy hỗ trợ trẻ, nhưng không nên làm hộ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0555b8db-e666-555f-94d7-53f5df7a7c74', 3, 'Sau khi trẻ cởi tất ra, bố mẹ khen ngợi trẻ: “Hoan hô! Con tự cởi được tất rồi!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0555b8db-e666-555f-94d7-53f5df7a7c74', 'image', '/static/activities/g080/main.jpg', '“Chúng ta cần phải cởi tất ra!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0555b8db-e666-555f-94d7-53f5df7a7c74', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g081: Lau miệng thật sạch (trang PDF 124)
-- Cần duyệt: Sách in nhầm phần “Các bước thực hiện” của trò “Cả nhà cùng ăn salad”; các bước dưới đây được giữ nguyên theo sách, cần biên tập lại.
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '4955989e-67aa-50b8-a7f8-0f582197d01b', 'Lau miệng thật sạch', '“Lau mặt nào!”', '**Kỹ năng phát triển:** Khả năng tự lập, Kỹ năng vận động tinh, Thói quen vệ sinh cá nhân

## Chuẩn bị
- **Không gian:** Bàn ăn riêng của trẻ hoặc bàn ăn gia đình.
- **Tư thế:** Trẻ ngồi ghế riêng.
- **Đồ dùng:** Một bát nhỏ, một thìa, vài miếng thanh long hoặc rau củ xay nhuyễn, vài chiếc khăn giấy, một chiếc gương.

## Các bước thực hiện
1. Cả nhà ngồi quanh một chiếc bàn nhỏ với đĩa salad trái cây trên bàn.
2. Mẹ nói: “Chúng ta cùng ăn salad trái cây nhé!” Sau khi bé ăn hai miếng, mẹ sờ bụng và nói: “Mẹ cũng muốn ăn trái cây đó”, rồi mẹ làm động tác nhai: “Măm, măm, ngon quá, cảm ơn con!”
3. Bố mở miệng và chỉ vào miệng mình, ra hiệu cho trẻ biết rằng mình cũng muốn ăn. Bố hướng dẫn trẻ hiểu cách giao tiếp không lời của bố, sau đó trẻ đút thức ăn cho bố. Bố sẽ nói: “Cảm ơn con yêu!”

## Hướng dẫn của chuyên gia
- Sau mỗi bữa ăn, bố mẹ cần cho trẻ thời gian để tập tự lau miệng.
- Mỗi khi trẻ lau miệng, trước tiên đừng dùng gương, hãy để trẻ sờ thấy thức ăn thừa trên mặt. Nếu trẻ không cảm nhận được, hãy dùng gương để nhìn.

> “Lau mặt nào!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 15, 18,
       'Một bát nhỏ, một thìa, vài miếng thanh long hoặc rau củ xay nhuyễn, vài chiếc khăn giấy, một chiếc gương.', ARRAY['Một bát nhỏ', 'một thìa', 'vài miếng thanh long hoặc rau củ xay nhuyễn', 'vài chiếc khăn giấy', 'một chiếc gương']::text[], '/static/activities/g081/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng tự lập, Kỹ năng vận động tinh, Thói quen vệ sinh cá nhân.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4955989e-67aa-50b8-a7f8-0f582197d01b', 1, 'Cả nhà ngồi quanh một chiếc bàn nhỏ với đĩa salad trái cây trên bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4955989e-67aa-50b8-a7f8-0f582197d01b', 2, 'Mẹ nói: “Chúng ta cùng ăn salad trái cây nhé!” Sau khi bé ăn hai miếng, mẹ sờ bụng và nói: “Mẹ cũng muốn ăn trái cây đó”, rồi mẹ làm động tác nhai: “Măm, măm, ngon quá, cảm ơn con!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('4955989e-67aa-50b8-a7f8-0f582197d01b', 3, 'Bố mở miệng và chỉ vào miệng mình, ra hiệu cho trẻ biết rằng mình cũng muốn ăn. Bố hướng dẫn trẻ hiểu cách giao tiếp không lời của bố, sau đó trẻ đút thức ăn cho bố. Bố sẽ nói: “Cảm ơn con yêu!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('4955989e-67aa-50b8-a7f8-0f582197d01b', 'image', '/static/activities/g081/main.jpg', '“Lau mặt nào!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '4955989e-67aa-50b8-a7f8-0f582197d01b', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g082: Vượt chướng ngại vật (trang PDF 127, 128)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0691cb42-e11a-5858-af96-09c08be1b7b8', 'Vượt chướng ngại vật', 'Kỹ năng phát triển: Tăng cường sức lực của cơ chân và phần dưới cơ thể, Phát triển khả năng vận động, Nâng cao khả năng phối hợp giữa các bộ phận trên cơ thể.', '**Kỹ năng phát triển:** Tăng cường sức lực của cơ chân và phần dưới cơ thể, Phát triển khả năng vận động, Nâng cao khả năng phối hợp giữa các bộ phận trên cơ thể

## Chuẩn bị
- **Không gian:** Bố (mẹ) cho trẻ chơi ở khoảng không gian rộng rãi như: giường ở phòng ngủ, thảm ở phòng khách,...
- **Tư thế:** Trẻ ở tư thế đứng thẳng.
- **Đồ dùng:** Một món đồ chơi mà trẻ thích nhất.

## Các bước thực hiện
1. Ba ngồi thẳng lưng, dang rộng hai chân. Đặt đồ chơi yêu thích của bé ở hướng đối diện so với vị trí bé đứng. Mẹ sẽ đứng phía sau lưng của bé và chỉ vào đồ chơi, nói: “Con hãy bước qua chân ba và lấy đồ chơi kia nhé!”
2. Khi bé bước tới lấy đồ chơi, mẹ hãy quan sát và hỗ trợ bé (nếu cần).
3. Sau khi bé lấy được đồ chơi, ba mẹ hãy vỗ tay khen ngợi, khích lệ bé: “Con giỏi quá!”. Tiếp theo, mẹ đưa thêm yêu cầu: “Con hãy quay lại và mang đồ chơi về phía mẹ nhé.” Ba mẹ hướng dẫn bé bước qua chân ba một lần nữa từ phía bên kia và quay lại điểm xuất phát.

## Hướng dẫn của chuyên gia
- Nếu trẻ không nhấc cao được chân để vượt qua các chướng ngại vật, bố (mẹ) hãy cầm tay trẻ, giúp trẻ bước qua.
- Nếu trẻ có thể dễ dàng bước qua, bố (mẹ) có thể kê thêm gối phía dưới để nâng độ cao của chướng ngại vật.
- Mẹ có thể ngồi nối tiếp thành hàng với bố để tạo thành các chướng ngại vật liên tiếp. Sau đó, bố (mẹ) yêu cầu trẻ hãy vượt qua.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 18, 21,
       'Một món đồ chơi mà trẻ thích nhất.', ARRAY['Một món đồ chơi mà trẻ thích nhất']::text[], '/static/activities/g082/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Tăng cường sức lực của cơ chân và phần dưới cơ thể, Phát triển khả năng vận động, Nâng cao khả năng phối hợp giữa các bộ phận trên cơ thể.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 1, 'Ba ngồi thẳng lưng, dang rộng hai chân. Đặt đồ chơi yêu thích của bé ở hướng đối diện so với vị trí bé đứng. Mẹ sẽ đứng phía sau lưng của bé và chỉ vào đồ chơi, nói: “Con hãy bước qua chân ba và lấy đồ chơi kia nhé!”', '/static/activities/g082/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 2, 'Khi bé bước tới lấy đồ chơi, mẹ hãy quan sát và hỗ trợ bé (nếu cần).', '/static/activities/g082/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 3, 'Sau khi bé lấy được đồ chơi, ba mẹ hãy vỗ tay khen ngợi, khích lệ bé: “Con giỏi quá!”. Tiếp theo, mẹ đưa thêm yêu cầu: “Con hãy quay lại và mang đồ chơi về phía mẹ nhé.” Ba mẹ hướng dẫn bé bước qua chân ba một lần nữa từ phía bên kia và quay lại điểm xuất phát.', '/static/activities/g082/step-3.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 'image', '/static/activities/g082/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 'image', '/static/activities/g082/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 'image', '/static/activities/g082/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0691cb42-e11a-5858-af96-09c08be1b7b8', 'image', '/static/activities/g082/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0691cb42-e11a-5858-af96-09c08be1b7b8', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g083: Tiến về phía trước (trang PDF 129)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'a6613ff7-3b8d-5dfe-bff3-b945f642abd7', 'Tiến về phía trước', 'Khi hướng dẫn trẻ chủ động đưa tay về phía trước, bố mẹ cần theo nhịp chuyển động về phía trước của trẻ.', '**Kỹ năng phát triển:** Sức mạnh của đôi tay và thân mình, Khả năng phối hợp thể chất, Phối hợp tay - mắt

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ nằm sấp.
- **Đồ dùng:** Một ô tô đồ chơi (hoặc đồ chơi bé yêu thích).

## Các bước thực hiện
1. Đặt ô tô đồ chơi cách trẻ khoảng 2 m.
2. Bố mẹ nhấc chân trẻ lên, để trẻ đỡ cơ thể bằng hai chi trên và nói với trẻ: “Con trèo về phía trước, chúng ta lái xe đi!” Hướng dẫn trẻ bò bằng cả hai tay nếu trẻ không thể đỡ được cả hai tay, rồi nghỉ ngơi một lúc trước khi tiếp tục và không ngừng động viên: “Cố lên con yêu!”
3. Hỗ trợ trẻ bò về phía trước cho đến khi đạt đến điểm cuối và khen ngợi: “Con thật tuyệt vời!”.

## Hướng dẫn của chuyên gia
- Nếu trẻ kiểm soát cơ thể tốt, bố mẹ có thể ôm cổ chân trẻ và vỗ về trẻ; nếu trẻ khó nâng vật nặng, bố mẹ có thể đỡ đùi trẻ để giảm trọng lượng.
- Nếu trẻ có thể hoàn thành tốt các hoạt động của trò chơi, bạn có thể tăng khoảng cách bò hoặc đặt các chướng ngại vật như gối, vật hút nhiệt trên đường đi để tăng độ khó.

> Khi hướng dẫn trẻ chủ động đưa tay về phía trước, bố mẹ cần theo nhịp chuyển động về phía trước của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 18, 21,
       'Một ô tô đồ chơi (hoặc đồ chơi bé yêu thích).', ARRAY['Một ô tô đồ chơi (hoặc đồ chơi bé yêu thích)']::text[], '/static/activities/g083/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Sức mạnh của đôi tay và thân mình, Khả năng phối hợp thể chất, Phối hợp tay - mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a6613ff7-3b8d-5dfe-bff3-b945f642abd7', 1, 'Đặt ô tô đồ chơi cách trẻ khoảng 2 m.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a6613ff7-3b8d-5dfe-bff3-b945f642abd7', 2, 'Bố mẹ nhấc chân trẻ lên, để trẻ đỡ cơ thể bằng hai chi trên và nói với trẻ: “Con trèo về phía trước, chúng ta lái xe đi!” Hướng dẫn trẻ bò bằng cả hai tay nếu trẻ không thể đỡ được cả hai tay, rồi nghỉ ngơi một lúc trước khi tiếp tục và không ngừng động viên: “Cố lên con yêu!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a6613ff7-3b8d-5dfe-bff3-b945f642abd7', 3, 'Hỗ trợ trẻ bò về phía trước cho đến khi đạt đến điểm cuối và khen ngợi: “Con thật tuyệt vời!”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('a6613ff7-3b8d-5dfe-bff3-b945f642abd7', 'image', '/static/activities/g083/main.jpg', 'Khi hướng dẫn trẻ chủ động đưa tay về phía trước, bố mẹ cần theo nhịp chuyển động về phía trước của trẻ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'a6613ff7-3b8d-5dfe-bff3-b945f642abd7', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g084: Đi bên trái, đi bên phải (trang PDF 130)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '6f46d768-e53a-5773-8d64-63bcc513bce3', 'Đi bên trái, đi bên phải', '“Bên trái”', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Ý thức định hướng

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc mặt đất.
- **Tư thế:** Trẻ đứng thẳng, nằm cạnh bố mẹ. Bố mẹ ở bên trái và trẻ ở bên phải.
- **Đồ dùng:** Một sợi dây dài, dày và hai đồ chơi khác nhau.

## Các bước thực hiện
1. Bố mẹ buộc sợi dây dài bằng nút thắt ở hai đầu để tạo thành hình tròn.
2. Bố mẹ và trẻ đứng cạnh nhau thành vòng tròn, bố mẹ ở bên trái và trẻ ở bên phải. Một con vịt nhỏ và một quả bóng lớn đặt ở xa bên phải. Trẻ và bố mẹ lần lượt giữ sợi dây bằng cả hai tay, bố mẹ bước đi cho đến khi dây thẳng.
3. Bố mẹ bế trẻ sang trái cho đến khi đến gần vịt con, trẻ có thể vừa đi vừa nói: “Bên trái, bên trái, có con vịt nhỏ ở bên trái”.
4. Sau một lúc, hãy dừng lại, bố mẹ bước đến bên phải trẻ và bế trẻ sang bên phải cho đến khi trẻ chạm được quả bóng lớn, vừa đi vừa nói: “Đi bên phải, đi bên phải, có một quả bóng lớn. Quả bóng lớn bên phải.” Sau khi chơi vài lần, trẻ sẽ hiểu luật chơi, bố mẹ không cần thay đổi vị trí mà có thể đợi trẻ dẫn bố mẹ tiến về phía trước.

## Hướng dẫn của chuyên gia
- Trẻ chưa hiểu trái, phải nhưng sẽ sớm hiểu luật chơi. Vì vậy, sau mỗi buổi học, bố mẹ có thể chờ đợi và hy vọng trẻ sẽ chủ động đưa người lớn đi chơi.
- Khi đi ngang, tốc độ không nên quá nhanh để tránh trẻ bị ngã. Khi chuyển hướng, hãy đợi trẻ đứng lên rồi mới bắt đầu.

> “Bên trái”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 18, 21,
       'Một sợi dây dài, dày và hai đồ chơi khác nhau.', ARRAY['Một sợi dây dài', 'dày và hai đồ chơi khác nhau']::text[], '/static/activities/g084/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Ý thức định hướng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6f46d768-e53a-5773-8d64-63bcc513bce3', 1, 'Bố mẹ buộc sợi dây dài bằng nút thắt ở hai đầu để tạo thành hình tròn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6f46d768-e53a-5773-8d64-63bcc513bce3', 2, 'Bố mẹ và trẻ đứng cạnh nhau thành vòng tròn, bố mẹ ở bên trái và trẻ ở bên phải. Một con vịt nhỏ và một quả bóng lớn đặt ở xa bên phải. Trẻ và bố mẹ lần lượt giữ sợi dây bằng cả hai tay, bố mẹ bước đi cho đến khi dây thẳng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6f46d768-e53a-5773-8d64-63bcc513bce3', 3, 'Bố mẹ bế trẻ sang trái cho đến khi đến gần vịt con, trẻ có thể vừa đi vừa nói: “Bên trái, bên trái, có con vịt nhỏ ở bên trái”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6f46d768-e53a-5773-8d64-63bcc513bce3', 4, 'Sau một lúc, hãy dừng lại, bố mẹ bước đến bên phải trẻ và bế trẻ sang bên phải cho đến khi trẻ chạm được quả bóng lớn, vừa đi vừa nói: “Đi bên phải, đi bên phải, có một quả bóng lớn. Quả bóng lớn bên phải.” Sau khi chơi vài lần, trẻ sẽ hiểu luật chơi, bố mẹ không cần thay đổi vị trí mà có thể đợi trẻ dẫn bố mẹ tiến về phía trước.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('6f46d768-e53a-5773-8d64-63bcc513bce3', 'image', '/static/activities/g084/main.jpg', '“Bên trái”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '6f46d768-e53a-5773-8d64-63bcc513bce3', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g085: Tập lái xe ô tô (trang PDF 131)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', 'Tập lái xe ô tô', 'Khi trẻ tiến về phía trước, bố mẹ cần ở phía trước để bảo vệ trẻ. Khi trẻ lùi lại, bố mẹ nên bảo vệ trẻ từ phía sau để tránh trẻ bị ngã.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Cảm giác về không gian

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Một hộp bìa cứng cỡ vừa (chiều rộng của hộp bìa cứng có thể rộng hơn một chút so với tay trái và tay phải của trẻ), một bút đánh dấu và một chiếc kéo.

## Các bước thực hiện
1. Cắt bỏ phần trên và dưới của hộp bìa cứng và giữ nguyên bốn cạnh; dùng bút đánh dấu vẽ mặt trước là đầu ô tô; tạo hai lỗ ở hai bên mặt trước để thò tay ra ngoài.
2. Đặt hộp bìa cứng lên người trẻ và để trẻ duỗi tay ra khỏi lỗ; trẻ sẽ trở thành người lái xe nhỏ.
3. Hướng dẫn trẻ đi về phía trước: “Xe đang nổ máy, bíp, bíp, bíp, tiến về phía trước”. Sau khi trẻ đã thành thạo việc điều khiển hộp bìa cứng, bố mẹ có thể hướng dẫn trẻ đi lùi: “Xe sắp lùi, hãy chú ý khi lùi xe nhé!”

## Hướng dẫn của chuyên gia
- Trò chơi này phải được chơi trên một mặt đất bằng phẳng và bố mẹ phải dọn trước các chướng ngại vật trên mặt đất.
- Cố gắng chọn loại hộp nhẹ, đồng thời chiều cao của hộp không nên quá cao để đảm bảo đầu của trẻ có thể di chuyển tự do sau khi đặt hộp lên.
- Phần cắt phải càng mịn càng tốt để tránh làm tổn thương da của trẻ.

> Khi trẻ tiến về phía trước, bố mẹ cần ở phía trước để bảo vệ trẻ. Khi trẻ lùi lại, bố mẹ nên bảo vệ trẻ từ phía sau để tránh trẻ bị ngã.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 18, 21,
       'Một hộp bìa cứng cỡ vừa (chiều rộng của hộp bìa cứng có thể rộng hơn một chút so với tay trái và tay phải của trẻ), một bút đánh dấu và một chiếc kéo.', ARRAY['Một hộp bìa cứng cỡ vừa (chiều rộng của hộp bìa cứng có thể rộng hơn một chút so với tay trái và tay phải của trẻ)', 'một bút đánh dấu và một chiếc kéo']::text[], '/static/activities/g085/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Cảm giác về không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', 1, 'Cắt bỏ phần trên và dưới của hộp bìa cứng và giữ nguyên bốn cạnh; dùng bút đánh dấu vẽ mặt trước là đầu ô tô; tạo hai lỗ ở hai bên mặt trước để thò tay ra ngoài.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', 2, 'Đặt hộp bìa cứng lên người trẻ và để trẻ duỗi tay ra khỏi lỗ; trẻ sẽ trở thành người lái xe nhỏ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', 3, 'Hướng dẫn trẻ đi về phía trước: “Xe đang nổ máy, bíp, bíp, bíp, tiến về phía trước”. Sau khi trẻ đã thành thạo việc điều khiển hộp bìa cứng, bố mẹ có thể hướng dẫn trẻ đi lùi: “Xe sắp lùi, hãy chú ý khi lùi xe nhé!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', 'image', '/static/activities/g085/main.jpg', 'Khi trẻ tiến về phía trước, bố mẹ cần ở phía trước để bảo vệ trẻ. Khi trẻ lùi lại, bố mẹ nên bảo vệ trẻ từ phía sau để tránh trẻ bị ngã.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e2b30c80-5c06-5159-89e9-dff6c4cfd3a6', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g086: Họa sĩ tí hon (trang PDF 132)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '684bfa42-f522-5768-8c25-0478dafc6826', 'Họa sĩ tí hon', 'Bạn có thể sử dụng nhiều vật dụng khác nhau để phát triển khả năng viết nguệch ngoạc của trẻ và mang lại cho trẻ trải nghiệm đa giác quan. Ví dụ: Bạn có thể dùng bút viết bảng để vẽ lên bảng trắng, và bạn cũng có thể sử dụng ngón tay của bạn để vẽ trên cát...', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Trẻ ngồi hoặc đứng.
- **Đồ dùng:** Một số cây bút, một số giấy vẽ, 1 bút viết bảng trắng, 1 bảng trắng, một số thẻ rèn luyện nhận thức thị giác,...

## Các bước thực hiện
1. Chuẩn bị bàn ghế có chiều cao phù hợp để trẻ có thể vẽ nguệch ngoạc khi ngồi đúng tư thế.
2. Bố mẹ lấy bút màu hoặc bút màu nước và giấy vẽ rồi nói với trẻ: “Đã đến giờ vẽ rồi con yêu!” Khuyến khích trẻ dùng bút viết nguệch ngoạc lên giấy. Hầu hết các trẻ ở giai đoạn này đều sử dụng lòng bàn tay để cầm bút vẽ. Bố mẹ không cần yêu cầu trẻ phải có tư thế cầm bút chuẩn.
3. Khuyến khích trẻ vẽ nguệch ngoạc theo ý muốn. Sau khi trẻ vẽ thành thạo, bố mẹ có thể thực hiện các đường vẽ hoặc đồ họa đơn giản theo các hướng khác nhau và khuyến khích trẻ bắt chước. Bạn cũng có thể cho trẻ đứng và dùng bút viết bảng viết nguệch ngoạc lên bảng để tăng cường độ vững chắc cho thân và hai chân.

## Hướng dẫn của chuyên gia
- Trong giai đoạn đầu vẽ, bạn có thể sử dụng bút và giấy có màu sắc rực rỡ để tạo ấn tượng thị giác sâu sắc hơn.
- Trẻ có thể được hướng dẫn sử dụng các tư thế khác nhau để vẽ. Ngoài việc vẽ nguệch ngoạc trên giấy ở bàn, trẻ cũng có thể vẽ nguệch ngoạc trên bảng trắng khi đứng.
- Sau khi trẻ bắt đầu thành thạo việc bắt chước vẽ đường nét, bạn có thể sử dụng một số thẻ rèn luyện nhận thức thị giác để rèn luyện khả năng nhận thức thị giác, phối hợp tay, mắt của bé.

> Bạn có thể sử dụng nhiều vật dụng khác nhau để phát triển khả năng viết nguệch ngoạc của trẻ và mang lại cho trẻ trải nghiệm đa giác quan. Ví dụ: Bạn có thể dùng bút viết bảng để vẽ lên bảng trắng, và bạn cũng có thể sử dụng ngón tay của bạn để vẽ trên cát...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 18, 21,
       'Một số cây bút, một số giấy vẽ, 1 bút viết bảng trắng, 1 bảng trắng, một số thẻ rèn luyện nhận thức thị giác,...', ARRAY['Một số cây bút', 'một số giấy vẽ', '1 bút viết bảng trắng', '1 bảng trắng', 'một số thẻ rèn luyện nhận thức thị giác,']::text[], '/static/activities/g086/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('684bfa42-f522-5768-8c25-0478dafc6826', 1, 'Chuẩn bị bàn ghế có chiều cao phù hợp để trẻ có thể vẽ nguệch ngoạc khi ngồi đúng tư thế.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('684bfa42-f522-5768-8c25-0478dafc6826', 2, 'Bố mẹ lấy bút màu hoặc bút màu nước và giấy vẽ rồi nói với trẻ: “Đã đến giờ vẽ rồi con yêu!” Khuyến khích trẻ dùng bút viết nguệch ngoạc lên giấy. Hầu hết các trẻ ở giai đoạn này đều sử dụng lòng bàn tay để cầm bút vẽ. Bố mẹ không cần yêu cầu trẻ phải có tư thế cầm bút chuẩn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('684bfa42-f522-5768-8c25-0478dafc6826', 3, 'Khuyến khích trẻ vẽ nguệch ngoạc theo ý muốn. Sau khi trẻ vẽ thành thạo, bố mẹ có thể thực hiện các đường vẽ hoặc đồ họa đơn giản theo các hướng khác nhau và khuyến khích trẻ bắt chước. Bạn cũng có thể cho trẻ đứng và dùng bút viết bảng viết nguệch ngoạc lên bảng để tăng cường độ vững chắc cho thân và hai chân.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('684bfa42-f522-5768-8c25-0478dafc6826', 'image', '/static/activities/g086/main.jpg', 'Bạn có thể sử dụng nhiều vật dụng khác nhau để phát triển khả năng viết nguệch ngoạc của trẻ và mang lại cho trẻ trải nghiệm đa giác quan. Ví dụ: Bạn có thể dùng bút viết bảng để vẽ lên bảng trắng, và bạn cũng có thể sử dụng ngón tay của bạn để vẽ trên cát...', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '684bfa42-f522-5768-8c25-0478dafc6826', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g087: Tập gói kẹo (trang PDF 133)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '0f081e47-7513-5a85-99d2-b42b4c4e244d', 'Tập gói kẹo', 'Bố mẹ cần luôn chú ý đến những cử động của trẻ, nếu trẻ quên, người lớn có thể nhắc nhở bằng lời nói, nếu trẻ vẫn chưa làm được thì người lớn có thể hỗ trợ trẻ.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một số giấy gói kẹo sạch và một ít giấy.

## Các bước thực hiện
1. Bố mẹ cho trẻ xem những món đồ đã chuẩn bị sẵn và nói với trẻ: “Chúng ta hãy gói kẹo lại nhé!” Bố mẹ và trẻ xé giấy ra và cuộn thành từng quả bóng. Bố mẹ có thể nói khi thực hiện: “Hãy xé nó ra, vo lại và biến thành một viên kẹo nhỏ nhé con!”
2. Bố mẹ làm mẫu quy trình gói kẹo và nói: “Đầu tiên trải giấy gói kẹo ra, sau đó đặt viên bi giấy lên trên, sau đó dùng giấy gói kẹo bọc viên bi lại, cuối cùng xoắn hai đầu lại và viên kẹo sẽ được cuộn lại”.
3. Bố mẹ đưa giấy gói kẹo và quả bóng giấy cho trẻ và khuyến khích trẻ làm thử: “Con ơi, hãy gói kẹo nữa nhé!”
4. Bố mẹ cũng có thể cùng trẻ làm từng bước và làm lại khi bé quên.

## Hướng dẫn của chuyên gia
- Trong quá trình làm mẫu, bố mẹ cần vừa làm vừa nói, đồng thời quan sát xem trẻ có chú ý hay không, khi thấy trẻ mất tập trung thì có thể tăng âm lượng, giúp thu hút sự chú ý của trẻ.
- Thời điểm hỗ trợ của bố mẹ dành cho trẻ rất quan trọng. Trước tiên, bạn phải cho trẻ thời gian để nhớ lại. Trước khi trẻ bối rối hoặc sắp bỏ cuộc, bạn có thể làm mẫu hoặc hỗ trợ lại.
- Thời gian đầu, không cần kiểm soát chặt chẽ trẻ. Bố mẹ nên khuyến khích nhiều hơn và đòi hỏi ít hơn. Bạn có thể để trẻ giúp bố mẹ thực hiện các động tác xoắn hai đầu kẹo để tăng cơ hội tập luyện.

> Bố mẹ cần luôn chú ý đến những cử động của trẻ, nếu trẻ quên, người lớn có thể nhắc nhở bằng lời nói, nếu trẻ vẫn chưa làm được thì người lớn có thể hỗ trợ trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 18, 21,
       'Một số giấy gói kẹo sạch và một ít giấy.', ARRAY['Một số giấy gói kẹo sạch và một ít giấy']::text[], '/static/activities/g087/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0f081e47-7513-5a85-99d2-b42b4c4e244d', 1, 'Bố mẹ cho trẻ xem những món đồ đã chuẩn bị sẵn và nói với trẻ: “Chúng ta hãy gói kẹo lại nhé!” Bố mẹ và trẻ xé giấy ra và cuộn thành từng quả bóng. Bố mẹ có thể nói khi thực hiện: “Hãy xé nó ra, vo lại và biến thành một viên kẹo nhỏ nhé con!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0f081e47-7513-5a85-99d2-b42b4c4e244d', 2, 'Bố mẹ làm mẫu quy trình gói kẹo và nói: “Đầu tiên trải giấy gói kẹo ra, sau đó đặt viên bi giấy lên trên, sau đó dùng giấy gói kẹo bọc viên bi lại, cuối cùng xoắn hai đầu lại và viên kẹo sẽ được cuộn lại”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0f081e47-7513-5a85-99d2-b42b4c4e244d', 3, 'Bố mẹ đưa giấy gói kẹo và quả bóng giấy cho trẻ và khuyến khích trẻ làm thử: “Con ơi, hãy gói kẹo nữa nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('0f081e47-7513-5a85-99d2-b42b4c4e244d', 4, 'Bố mẹ cũng có thể cùng trẻ làm từng bước và làm lại khi bé quên.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('0f081e47-7513-5a85-99d2-b42b4c4e244d', 'image', '/static/activities/g087/main.jpg', 'Bố mẹ cần luôn chú ý đến những cử động của trẻ, nếu trẻ quên, người lớn có thể nhắc nhở bằng lời nói, nếu trẻ vẫn chưa làm được thì người lớn có thể hỗ trợ trẻ.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '0f081e47-7513-5a85-99d2-b42b4c4e244d', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g088: Rải hoa giấy (trang PDF 134)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'bfb37bc4-cee4-578a-9b91-b7a6e088360b', 'Rải hoa giấy', 'Khi bố mẹ xé tờ giấy ra, phải thực hiện thật nhanh và thêm âm thanh cười nói để trò chơi trở nên thú vị hơn.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Kỹ năng vận động tinh

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Trẻ đứng quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số giấy màu.

## Các bước thực hiện
1. Bố mẹ lấy một tờ giấy màu ra cho trẻ xem, có thể lắc nhẹ và tạo ra âm thanh để thu hút trẻ rồi nói: “Bố mẹ có một mảnh giấy đỏ, hôm nay con có muốn tạo ra nhiều bông hoa giấy nhỏ không?”
2. Bố mẹ cầm tờ giấy trước mặt trẻ, đếm “một, hai...” rồi nhanh chóng xé tờ giấy ra và nói: “Chà, nó bị xé ra rồi!” Tiếp tục nhiều lần cho đến khi tờ giấy bị xé thành từng mảnh nhỏ.
3. Bố mẹ cầm nhiều bông hoa giấy nhỏ trên tay, có thể nói: “nhiều bông hoa giấy nhỏ”, “những bông hoa giấy nhỏ”, rồi rải những bông hoa giấy đó vào người trẻ, nói: “bay lên đầu”, “bay lên cổ”,...
4. Bố mẹ và trẻ có thể cùng nhau nhặt những bông hoa giấy và tiếp tục trò chơi rải hoa.

## Hướng dẫn của chuyên gia
- Bạn có thể chọn giấy màu theo màu trẻ thích.
- Bố mẹ có thể so sánh những bông hoa giấy trên tay với trẻ để xem cái nào to hơn, cái nào nhỏ hơn, nhấn mạnh các tính từ như “nhiều hơn”, “ít hơn”, “lớn” và “nhỏ”.
- Một mảnh giấy có thể chơi theo nhiều cách, ngoài việc xé hoa giấy còn có thể dùng làm kính thiên văn, gấp các con vật, cuộn thành từng viên,... Bố mẹ cần quan sát và suy nghĩ kỹ hơn về những gì con mình làm, trẻ sẽ rất thích chơi.

> Khi bố mẹ xé tờ giấy ra, phải thực hiện thật nhanh và thêm âm thanh cười nói để trò chơi trở nên thú vị hơn.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 18, 21,
       'Một số giấy màu.', ARRAY['Một số giấy màu']::text[], '/static/activities/g088/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Kỹ năng vận động tinh.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bfb37bc4-cee4-578a-9b91-b7a6e088360b', 1, 'Bố mẹ lấy một tờ giấy màu ra cho trẻ xem, có thể lắc nhẹ và tạo ra âm thanh để thu hút trẻ rồi nói: “Bố mẹ có một mảnh giấy đỏ, hôm nay con có muốn tạo ra nhiều bông hoa giấy nhỏ không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bfb37bc4-cee4-578a-9b91-b7a6e088360b', 2, 'Bố mẹ cầm tờ giấy trước mặt trẻ, đếm “một, hai...” rồi nhanh chóng xé tờ giấy ra và nói: “Chà, nó bị xé ra rồi!” Tiếp tục nhiều lần cho đến khi tờ giấy bị xé thành từng mảnh nhỏ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bfb37bc4-cee4-578a-9b91-b7a6e088360b', 3, 'Bố mẹ cầm nhiều bông hoa giấy nhỏ trên tay, có thể nói: “nhiều bông hoa giấy nhỏ”, “những bông hoa giấy nhỏ”, rồi rải những bông hoa giấy đó vào người trẻ, nói: “bay lên đầu”, “bay lên cổ”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bfb37bc4-cee4-578a-9b91-b7a6e088360b', 4, 'Bố mẹ và trẻ có thể cùng nhau nhặt những bông hoa giấy và tiếp tục trò chơi rải hoa.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bfb37bc4-cee4-578a-9b91-b7a6e088360b', 'image', '/static/activities/g088/main.jpg', 'Khi bố mẹ xé tờ giấy ra, phải thực hiện thật nhanh và thêm âm thanh cười nói để trò chơi trở nên thú vị hơn.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'bfb37bc4-cee4-578a-9b91-b7a6e088360b', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g089: Chú mèo nhỏ sạch sẽ (trang PDF 135)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', 'Chú mèo nhỏ sạch sẽ', 'Trò chơi này có thể chơi sau khi bé đã ăn xong và có thức ăn dính vào môi bé. Đừng giúp bé ngay lập tức.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Trước gương.
- **Tư thế:** Trẻ đứng quay mặt về phía bố mẹ.
- **Đồ dùng:** Một hộp sữa chua hoặc hộp mứt, một gương.

## Các bước thực hiện
1. Bố mẹ bôi sữa chua hoặc mứt lên môi của mình và con, sau đó đưa con đi soi gương và nói: “Chúng ta đã trở thành một con mèo nhỏ” để hướng dẫn con chú ý đến thức ăn xung quanh môi.
2. Bố mẹ thể hiện khả năng của mình bằng cách dùng môi và lưỡi liếm thức ăn. Sau khi bố mẹ thực hiện hành động đó, quan sát xem trẻ có bắt chước được hay không.
3. Nếu trẻ có thể làm sạch miệng bằng bất kỳ phương pháp nào, bố mẹ có thể khen ngợi trẻ, chẳng hạn như: “Con đã liếm sạch sữa chua rồi, thật tuyệt vời!”
4. Nếu trẻ có thể dùng môi để liếm thức ăn, sau nhiều lần, bố mẹ có thể cho trẻ nói, phát âm các âm “b”, “p”, “m”, nếu trẻ biết dùng lưỡi liếm thức ăn, bố mẹ có thể tạo cho trẻ phát âm các âm “d”, “t”,... nhiều lần.

## Hướng dẫn của chuyên gia
- Nếu trẻ không thể bắt chước các động tác, bố mẹ có thể đưa thức ăn lên gần môi hơn một chút, có thể tập nhiều lần và không yêu cầu trẻ bắt chước hoàn hảo tất cả các động tác trong một trò chơi.

> Trò chơi này có thể chơi sau khi bé đã ăn xong và có thức ăn dính vào môi bé. Đừng giúp bé ngay lập tức.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 18, 21,
       'Một hộp sữa chua hoặc hộp mứt, một gương.', ARRAY['Một hộp sữa chua hoặc hộp mứt', 'một gương']::text[], NULL, 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', 1, 'Bố mẹ bôi sữa chua hoặc mứt lên môi của mình và con, sau đó đưa con đi soi gương và nói: “Chúng ta đã trở thành một con mèo nhỏ” để hướng dẫn con chú ý đến thức ăn xung quanh môi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', 2, 'Bố mẹ thể hiện khả năng của mình bằng cách dùng môi và lưỡi liếm thức ăn. Sau khi bố mẹ thực hiện hành động đó, quan sát xem trẻ có bắt chước được hay không.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', 3, 'Nếu trẻ có thể làm sạch miệng bằng bất kỳ phương pháp nào, bố mẹ có thể khen ngợi trẻ, chẳng hạn như: “Con đã liếm sạch sữa chua rồi, thật tuyệt vời!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', 4, 'Nếu trẻ có thể dùng môi để liếm thức ăn, sau nhiều lần, bố mẹ có thể cho trẻ nói, phát âm các âm “b”, “p”, “m”, nếu trẻ biết dùng lưỡi liếm thức ăn, bố mẹ có thể tạo cho trẻ phát âm các âm “d”, “t”,... nhiều lần.', NULL);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'a9f89f3f-b1ef-5068-98c0-cbe5c812c2f0', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g090: Quả bóng đâu rồi? (trang PDF 136)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'ea165f17-24a3-5203-b080-c8c19902c94d', 'Quả bóng đâu rồi?', '“Quả bóng đã đi đâu rồi nhỉ?”', '**Kỹ năng phát triển:** Khả năng hiểu mối quan hệ tương tác, Hiểu sự tồn tại của đồ vật

## Chuẩn bị
- **Không gian:** Thảm trải sàn, ghế sofa hoặc mặt bàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Hai ống giấy tròn và một quả bóng nhỏ.

## Các bước thực hiện
1. Dán hai ống giấy tròn lại với nhau để tạo thành một ống giấy dài.
2. Lấy một quả bóng nhỏ ra, hướng dẫn trẻ bỏ quả bóng vào lỗ trên ống giấy và hỏi trẻ: “Quả bóng đi đâu rồi con? Con có tìm thấy nó không?”
3. Nếu trẻ không hiểu câu hỏi của bạn, bạn có thể khuyến khích trẻ nhìn vào ống giấy để chú ý và tìm quả bóng nhỏ. Trẻ sẽ rất vui với phát hiện của mình. Bố mẹ có thể mô tả: “Con tìm thấy quả bóng và quả bóng lăn ra khỏi đó phải không?”

## Hướng dẫn của chuyên gia
- Bố mẹ nên khuyến khích trẻ tự mình tìm bóng thay vì vội vàng giúp đỡ, hướng dẫn trẻ.
- Trò chơi cũng có thể bao gồm những quả bóng nhỏ hơn và những đồ vật hình dạng khác nhau để hướng dẫn trẻ quan sát sự khác biệt trong trạng thái lăn của chúng.

> “Quả bóng đã đi đâu rồi nhỉ?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 18, 21,
       'Hai ống giấy tròn và một quả bóng nhỏ.', ARRAY['Hai ống giấy tròn và một quả bóng nhỏ']::text[], '/static/activities/g090/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng hiểu mối quan hệ tương tác, Hiểu sự tồn tại của đồ vật.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ea165f17-24a3-5203-b080-c8c19902c94d', 1, 'Dán hai ống giấy tròn lại với nhau để tạo thành một ống giấy dài.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ea165f17-24a3-5203-b080-c8c19902c94d', 2, 'Lấy một quả bóng nhỏ ra, hướng dẫn trẻ bỏ quả bóng vào lỗ trên ống giấy và hỏi trẻ: “Quả bóng đi đâu rồi con? Con có tìm thấy nó không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ea165f17-24a3-5203-b080-c8c19902c94d', 3, 'Nếu trẻ không hiểu câu hỏi của bạn, bạn có thể khuyến khích trẻ nhìn vào ống giấy để chú ý và tìm quả bóng nhỏ. Trẻ sẽ rất vui với phát hiện của mình. Bố mẹ có thể mô tả: “Con tìm thấy quả bóng và quả bóng lăn ra khỏi đó phải không?”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('ea165f17-24a3-5203-b080-c8c19902c94d', 'image', '/static/activities/g090/main.jpg', '“Quả bóng đã đi đâu rồi nhỉ?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'ea165f17-24a3-5203-b080-c8c19902c94d', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g091: Chơi bóng bay (trang PDF 137)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '31d014fe-1b9b-5636-9b54-6a4cee1047c7', 'Chơi bóng bay', 'Hãy sử dụng những lời thông báo trước khi thổi bong bóng: “Bố mẹ sẽ thổi bong bóng!” Hãy sử dụng những lời thông báo trước khi thả bóng bay: “Một, hai, ba, bay đi!”. Điều này giúp trẻ tập trung hơn vào hành động sắp xảy ra.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một quả bóng bay màu sắc.

## Các bước thực hiện
1. Bố mẹ lấy một quả bóng bay ra và nói: “Chúng ta cùng chơi bóng bay nhé!”
2. Nếu trẻ vẫn chú ý đến quả bóng bay, bố mẹ sẽ giơ quả bóng lên cao và nói: “Một, hai, ba, bay đi!”. Đợi trẻ chủ động nhặt bóng bay lên và yêu cầu bố mẹ tung bóng tiếp.
3. Nếu trẻ nhìn bố mẹ rồi đưa tay ra hoặc nhìn bố mẹ và nói “muốn” hoặc “có”, bố mẹ sẽ trả lời: “Con muốn một quả bóng bay phải không? Bố đưa quả bóng này cho con nhé!”.
4. Trò chơi có thể được lặp lại nhiều lần.

## Hướng dẫn của chuyên gia
- Bạn có thể chọn bóng bay có màu sắc mà trẻ yêu thích. Bong bóng không được quá nhỏ, nếu không, không khí sẽ thoát ra ngoài nhanh chóng.
- Bố mẹ không nên kiểm tra quả bóng bay ngay sau khi nó rơi xuống đất. Hãy chờ xem trẻ có chủ động nhặt nó lên không. Nếu trẻ làm được điều này, bạn có thể thổi bóng ngay khi trẻ đưa bóng cho bố mẹ để tăng cường tính chủ động của trẻ. Nếu đợi 3 giây mà trẻ không kiểm tra thì bố mẹ sẽ tự mình nhặt lên.
- Khi thổi bóng, bố mẹ cần để mắt đến trẻ. Khi trẻ mất tập trung thì ngay lập tức thả bóng ra để thu hút trẻ.

> Hãy sử dụng những lời thông báo trước khi thổi bong bóng: “Bố mẹ sẽ thổi bong bóng!” Hãy sử dụng những lời thông báo trước khi thả bóng bay: “Một, hai, ba, bay đi!”. Điều này giúp trẻ tập trung hơn vào hành động sắp xảy ra.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 18, 21,
       'Một quả bóng bay màu sắc.', ARRAY['Một quả bóng bay màu sắc']::text[], '/static/activities/g091/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('31d014fe-1b9b-5636-9b54-6a4cee1047c7', 1, 'Bố mẹ lấy một quả bóng bay ra và nói: “Chúng ta cùng chơi bóng bay nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('31d014fe-1b9b-5636-9b54-6a4cee1047c7', 2, 'Nếu trẻ vẫn chú ý đến quả bóng bay, bố mẹ sẽ giơ quả bóng lên cao và nói: “Một, hai, ba, bay đi!”. Đợi trẻ chủ động nhặt bóng bay lên và yêu cầu bố mẹ tung bóng tiếp.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('31d014fe-1b9b-5636-9b54-6a4cee1047c7', 3, 'Nếu trẻ nhìn bố mẹ rồi đưa tay ra hoặc nhìn bố mẹ và nói “muốn” hoặc “có”, bố mẹ sẽ trả lời: “Con muốn một quả bóng bay phải không? Bố đưa quả bóng này cho con nhé!”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('31d014fe-1b9b-5636-9b54-6a4cee1047c7', 4, 'Trò chơi có thể được lặp lại nhiều lần.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('31d014fe-1b9b-5636-9b54-6a4cee1047c7', 'image', '/static/activities/g091/main.jpg', 'Hãy sử dụng những lời thông báo trước khi thổi bong bóng: “Bố mẹ sẽ thổi bong bóng!” Hãy sử dụng những lời thông báo trước khi thả bóng bay: “Một, hai, ba, bay đi!”. Điều này giúp trẻ tập trung hơn vào hành động sắp xảy ra.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '31d014fe-1b9b-5636-9b54-6a4cee1047c7', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g092: Gửi đồ chơi về “nhà” (trang PDF 138)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'a8710acf-d747-5b11-8f26-28565b5a830f', 'Gửi đồ chơi về “nhà”', 'Đầu tiên, bố mẹ hướng dẫn trẻ cách cất đồ chơi, sau đó cùng trẻ dọn dẹp đồ chơi, sử dụng các gợi ý bằng lời nói để hướng dẫn trẻ tự nhặt đồ chơi và cất đi.', '**Kỹ năng phát triển:** Khả năng tự chăm sóc, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc mặt bàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Khối xếp hình, sách,...

## Các bước thực hiện
1. Trước khi chơi đồ chơi, hãy cho trẻ xem “nhà” của đồ chơi ở đâu.
2. Nếu trò chơi được chơi với các khối xây dựng, khi kết thúc trò chơi, bố mẹ nói với trẻ: “Bây giờ các khối xây dựng đang về nhà, chúng ta hãy gửi các khối xây dựng về nhà nhé! Nhà của khối gạch ở trong giỏ lớn kìa!”
3. Nếu trẻ đã đọc xong sách, hãy cùng trẻ cầm cuốn sách lên và dọn dẹp rồi nói với trẻ: “Sách đã được gửi về nhà! Nhà sách đã đến.”

## Hướng dẫn của chuyên gia
- Nên đánh dấu rõ ràng từng ngôi nhà của đồ chơi. Ví dụ: dán hình ảnh các khối xây dựng ở bên ngoài tòa nhà nơi lắp đặt các khối xây dựng.
- Khi trẻ lớn hơn, bạn có thể dán nhãn cho các hộp đựng đồ chơi và cất giữ đồ chơi theo từng danh mục.
- Sau mỗi trò chơi, hãy hướng dẫn trẻ đặt đồ chơi về vị trí ban đầu để hình thành thói quen tốt.

> Đầu tiên, bố mẹ hướng dẫn trẻ cách cất đồ chơi, sau đó cùng trẻ dọn dẹp đồ chơi, sử dụng các gợi ý bằng lời nói để hướng dẫn trẻ tự nhặt đồ chơi và cất đi.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi tự chăm sóc._', 'play', 18, 21,
       'Khối xếp hình, sách,...', ARRAY['Khối xếp hình', 'sách,']::text[], '/static/activities/g092/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng tự chăm sóc, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a8710acf-d747-5b11-8f26-28565b5a830f', 1, 'Trước khi chơi đồ chơi, hãy cho trẻ xem “nhà” của đồ chơi ở đâu.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a8710acf-d747-5b11-8f26-28565b5a830f', 2, 'Nếu trò chơi được chơi với các khối xây dựng, khi kết thúc trò chơi, bố mẹ nói với trẻ: “Bây giờ các khối xây dựng đang về nhà, chúng ta hãy gửi các khối xây dựng về nhà nhé! Nhà của khối gạch ở trong giỏ lớn kìa!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('a8710acf-d747-5b11-8f26-28565b5a830f', 3, 'Nếu trẻ đã đọc xong sách, hãy cùng trẻ cầm cuốn sách lên và dọn dẹp rồi nói với trẻ: “Sách đã được gửi về nhà! Nhà sách đã đến.”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('a8710acf-d747-5b11-8f26-28565b5a830f', 'image', '/static/activities/g092/main.jpg', 'Đầu tiên, bố mẹ hướng dẫn trẻ cách cất đồ chơi, sau đó cùng trẻ dọn dẹp đồ chơi, sử dụng các gợi ý bằng lời nói để hướng dẫn trẻ tự nhặt đồ chơi và cất đi.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'a8710acf-d747-5b11-8f26-28565b5a830f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g093: Nhảy cao và tung bóng bay (trang PDF 139, 140)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'bde33c6d-42c7-5c1c-b035-55c802df9b3e', 'Nhảy cao và tung bóng bay', 'Kỹ năng phát triển: Sức mạnh của đôi chân, Khả năng phối hợp thể chất, Khả năng phối hợp tay, mắt.', '**Kỹ năng phát triển:** Sức mạnh của đôi chân, Khả năng phối hợp thể chất, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ đứng quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số quả bóng bay.

## Các bước thực hiện
1. Bố mẹ vỗ nhẹ quả bóng bay lên trên và nói: “Tung bóng lên nào!” và thực hiện hành động, nhảy lên bằng cả hai chân và dùng lòng bàn tay vỗ nhẹ vào quả bóng bay lên trên để nó bay cao hơn.
2. Bố mẹ bắn quả bóng bay về phía trước và trên đầu trẻ, hướng dẫn trẻ thực hiện động tác tương tự và nhắc trẻ: “Con nhảy cao lên nhé!”
3. Sau khi trẻ được bóng, bố mẹ khuyến khích trẻ nhảy lên và đánh bóng lại: “Con đánh bóng đi nào!”

## Hướng dẫn của chuyên gia
- Bố mẹ cần làm mẫu nhiều lần và hỗ trợ trẻ phù hợp khi cần thiết, chẳng hạn như đỡ eo trẻ.
- Điều chỉnh độ cao của bóng bay kịp thời theo mức độ khả năng của trẻ để tăng trải nghiệm thành công.
- Nếu trẻ chưa nhảy được, hãy hướng dẫn trẻ nhấc ngón chân lên để tiếp cận bóng bay. Nếu trẻ đã thành thạo kỹ năng nhảy lên bắn bóng bay, bố mẹ có thể tăng số lượng bóng bay lên 2 hoặc 3 quả và cùng bé nhảy lên bắn bóng bay để tăng bài tập và trò chơi phối hợp tay mắt.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 21, 24,
       'Một số quả bóng bay.', ARRAY['Một số quả bóng bay']::text[], '/static/activities/g093/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Sức mạnh của đôi chân, Khả năng phối hợp thể chất, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 1, 'Bố mẹ vỗ nhẹ quả bóng bay lên trên và nói: “Tung bóng lên nào!” và thực hiện hành động, nhảy lên bằng cả hai chân và dùng lòng bàn tay vỗ nhẹ vào quả bóng bay lên trên để nó bay cao hơn.', '/static/activities/g093/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 2, 'Bố mẹ bắn quả bóng bay về phía trước và trên đầu trẻ, hướng dẫn trẻ thực hiện động tác tương tự và nhắc trẻ: “Con nhảy cao lên nhé!”', '/static/activities/g093/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 3, 'Sau khi trẻ được bóng, bố mẹ khuyến khích trẻ nhảy lên và đánh bóng lại: “Con đánh bóng đi nào!”', '/static/activities/g093/step-3.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 'image', '/static/activities/g093/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 'image', '/static/activities/g093/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 'image', '/static/activities/g093/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bde33c6d-42c7-5c1c-b035-55c802df9b3e', 'image', '/static/activities/g093/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'bde33c6d-42c7-5c1c-b035-55c802df9b3e', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g094: Đi vòng tròn (trang PDF 141)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3aae1994-edd8-53ab-9f37-7eefea94e306', 'Đi vòng tròn', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Khả năng hiểu ngôn ngữ.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Sàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ và trẻ cùng đứng thẳng hàng với nhau.
2. Bố mẹ và trẻ nắm tay nhau tạo thành vòng tròn. Mọi người di chuyển về một hướng, khi đi, bố mẹ và trẻ cần thực hiện các động tác tương ứng theo lời mẹ nói. Khi nghe lời “đi bộ” thì cùng nhau đi bộ; khi nghe lời “ngồi xổm” thì đồng thời ngồi xổm xuống; khi nghe lời “chạy” thì cùng nhau chạy;...

## Lời bài hát / đồng dao
Tạo một vòng tròn và đi vòng quanh, tạo một vòng tròn và đi vòng quanh, đi bộ, đi bộ, đi bộ, đi bộ, xem ai có thể ngồi xổm xuống trước. Tạo một vòng tròn và chạy, tạo một vòng tròn và chạy, chạy, chạy, chạy, xem ai đứng trước.

## Hướng dẫn của chuyên gia
- Khi mẹ nói những từ khóa như: “đi”, “chạy”, “ngồi xổm”, “dừng lại” thì nên nói chậm và to hơn để đảm bảo trẻ có thể nghe rõ.
- Khi bố mẹ chơi trò chơi với con, ban đầu bố mẹ có thể phản ứng nhanh hơn trẻ và làm gương cho trẻ. Khi trẻ đã quen với trò chơi, bố mẹ nên giảm tốc độ phản ứng của trẻ và chờ trẻ thực hiện đầu tiên.
- Bạn có thể mời những người khác trong gia đình mình tham gia trò chơi. Càng nhiều người chơi, trò chơi sẽ càng thú vị!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 21, 24,
       'Không có.', NULL, '/static/activities/g094/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng phối hợp thể chất, Khả năng hiểu ngôn ngữ.', true, 'Tạo một vòng tròn và đi vòng quanh, tạo một vòng tròn và đi vòng quanh, đi bộ, đi bộ, đi bộ, đi bộ, xem ai có thể ngồi xổm xuống trước. Tạo một vòng tròn và chạy, tạo một vòng tròn và chạy, chạy, chạy, chạy, xem ai đứng trước.';
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3aae1994-edd8-53ab-9f37-7eefea94e306', 1, 'Bố mẹ và trẻ cùng đứng thẳng hàng với nhau.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3aae1994-edd8-53ab-9f37-7eefea94e306', 2, 'Bố mẹ và trẻ nắm tay nhau tạo thành vòng tròn. Mọi người di chuyển về một hướng, khi đi, bố mẹ và trẻ cần thực hiện các động tác tương ứng theo lời mẹ nói. Khi nghe lời “đi bộ” thì cùng nhau đi bộ; khi nghe lời “ngồi xổm” thì đồng thời ngồi xổm xuống; khi nghe lời “chạy” thì cùng nhau chạy;...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3aae1994-edd8-53ab-9f37-7eefea94e306', 'image', '/static/activities/g094/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3aae1994-edd8-53ab-9f37-7eefea94e306', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g095: Cùng lật trang sách (trang PDF 142)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'eea1c1a2-39aa-5e43-b42e-db20a83b4382', 'Cùng lật trang sách', 'Khi đọc sách mỗi ngày, bố mẹ luôn tạo cơ hội cho trẻ tự mình lật từng trang sách. Sau một thời gian, trẻ sẽ học cách lật từng trang sách.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Rèn luyện thói quen đọc sách

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi, bố mẹ ngồi nghiêng về bên phải của trẻ, tạo thành tư thế ngồi hình chữ “L”.
- **Đồ dùng:** Một cuốn sách mà trẻ yêu thích.

## Các bước thực hiện
1. Bố mẹ và bé cùng đọc một cuốn sách tranh mà trẻ yêu thích. Đọc xong mỗi trang, bố mẹ đợi vài giây, hy vọng trẻ sẽ chủ động lật sang trang tiếp theo.
2. Nếu trẻ không chủ động lật trang, bố mẹ có thể giúp trẻ lật trang và khuyến khích trẻ tự lật sách: “Con yêu lật trang sách đi nào!”
3. Nếu trẻ chủ động lật trang nhưng lật nhiều trang một lúc, trước tiên bố mẹ có thể khen trẻ: “Con có thể tự lật sách rồi này!” Sau đó, bố mẹ có thể thực hiện động tác lật từng trang sách bằng ngón tay cái và ngón trỏ. Làm chậm rãi, vừa nói vừa làm và hy vọng rằng lần sau con có thể lật sách tốt hơn.

## Hướng dẫn của chuyên gia
- Trẻ có thể bắt đầu lật trang sách từ rất sớm, nhưng trẻ ở giai đoạn này nên tập trung vào việc trẻ có thể lật trang sách một cách có ý thức và lật từng trang một hay không.
- Bạn có thể chọn một cuốn sách thú vị hơn dành cho trẻ, chẳng hạn như trong sách có các trang có thể xoay, bóc và dán để kích thích trẻ thích đọc sách.

> Khi đọc sách mỗi ngày, bố mẹ luôn tạo cơ hội cho trẻ tự mình lật từng trang sách. Sau một thời gian, trẻ sẽ học cách lật từng trang sách.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 21, 24,
       'Một cuốn sách mà trẻ yêu thích.', ARRAY['Một cuốn sách mà trẻ yêu thích']::text[], '/static/activities/g095/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Rèn luyện thói quen đọc sách.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eea1c1a2-39aa-5e43-b42e-db20a83b4382', 1, 'Bố mẹ và bé cùng đọc một cuốn sách tranh mà trẻ yêu thích. Đọc xong mỗi trang, bố mẹ đợi vài giây, hy vọng trẻ sẽ chủ động lật sang trang tiếp theo.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eea1c1a2-39aa-5e43-b42e-db20a83b4382', 2, 'Nếu trẻ không chủ động lật trang, bố mẹ có thể giúp trẻ lật trang và khuyến khích trẻ tự lật sách: “Con yêu lật trang sách đi nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('eea1c1a2-39aa-5e43-b42e-db20a83b4382', 3, 'Nếu trẻ chủ động lật trang nhưng lật nhiều trang một lúc, trước tiên bố mẹ có thể khen trẻ: “Con có thể tự lật sách rồi này!” Sau đó, bố mẹ có thể thực hiện động tác lật từng trang sách bằng ngón tay cái và ngón trỏ. Làm chậm rãi, vừa nói vừa làm và hy vọng rằng lần sau con có thể lật sách tốt hơn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('eea1c1a2-39aa-5e43-b42e-db20a83b4382', 'image', '/static/activities/g095/main.jpg', 'Khi đọc sách mỗi ngày, bố mẹ luôn tạo cơ hội cho trẻ tự mình lật từng trang sách. Sau một thời gian, trẻ sẽ học cách lật từng trang sách.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'eea1c1a2-39aa-5e43-b42e-db20a83b4382', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g096: Đồng xu tiết kiệm (trang PDF 143)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '315da117-2f96-566f-a22e-d2d1a19cd611', 'Đồng xu tiết kiệm', 'Sau khi bố mẹ lấy con heo đất và đồng xu đã chuẩn bị sẵn ra, nói với trẻ: “Chúng ta hãy bỏ những đồng xu vào heo nhé!”. Khi trẻ bỏ vào một đồng xu, hãy khuyến khích trẻ: “Con ngoan lắm, chúng ta hãy bỏ vào một đồng xu khác nhé!”', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp tay

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một hộp giấy có nắp và một số đồng xu bằng giấy.

## Các bước thực hiện
1. Bố mẹ biến hộp giấy có nắp thành con heo, dùng kéo khoét một lỗ đồng xu ở giữa nắp giấy, sau đó cắt ra nhiều miếng bìa cứng hình tròn để sử dụng như những đồng xu.
2. Bố mẹ làm mẫu bằng cách cầm ống heo bằng một tay và dùng 3 ngón đầu tiên (ngón cái, ngón trỏ, ngón giữa) của tay kia nhặt một đồng xu nhét vào lỗ đồng xu, sau đó khuyến khích trẻ bắt chước việc chèn đồng xu.

## Hướng dẫn của chuyên gia
- Khi làm đồ chơi, xin lưu ý rằng đường kính của đồng xu phải phù hợp với đường kính của lỗ đồng xu. Bố mẹ có thể làm một số con heo và đồng xu với các kích cỡ lỗ khác nhau để tăng độ khó cho trò chơi.
- Ban đầu, khe đựng đồng xu có thể được đặt theo chiều ngang. Khi kỹ năng vận hành của trẻ được cải thiện, bạn có thể dần dần biến khe xu ở vị trí khó hơn để trò chơi trở nên thú vị hơn.

> Sau khi bố mẹ lấy con heo đất và đồng xu đã chuẩn bị sẵn ra, nói với trẻ: “Chúng ta hãy bỏ những đồng xu vào heo nhé!”. Khi trẻ bỏ vào một đồng xu, hãy khuyến khích trẻ: “Con ngoan lắm, chúng ta hãy bỏ vào một đồng xu khác nhé!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 21, 24,
       'Một hộp giấy có nắp và một số đồng xu bằng giấy.', ARRAY['Một hộp giấy có nắp và một số đồng xu bằng giấy']::text[], '/static/activities/g096/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('315da117-2f96-566f-a22e-d2d1a19cd611', 1, 'Bố mẹ biến hộp giấy có nắp thành con heo, dùng kéo khoét một lỗ đồng xu ở giữa nắp giấy, sau đó cắt ra nhiều miếng bìa cứng hình tròn để sử dụng như những đồng xu.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('315da117-2f96-566f-a22e-d2d1a19cd611', 2, 'Bố mẹ làm mẫu bằng cách cầm ống heo bằng một tay và dùng 3 ngón đầu tiên (ngón cái, ngón trỏ, ngón giữa) của tay kia nhặt một đồng xu nhét vào lỗ đồng xu, sau đó khuyến khích trẻ bắt chước việc chèn đồng xu.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('315da117-2f96-566f-a22e-d2d1a19cd611', 'image', '/static/activities/g096/main.jpg', 'Sau khi bố mẹ lấy con heo đất và đồng xu đã chuẩn bị sẵn ra, nói với trẻ: “Chúng ta hãy bỏ những đồng xu vào heo nhé!”. Khi trẻ bỏ vào một đồng xu, hãy khuyến khích trẻ: “Con ngoan lắm, chúng ta hãy bỏ vào một đồng xu khác nhé!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '315da117-2f96-566f-a22e-d2d1a19cd611', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g097: Xâu chuỗi hạt (trang PDF 144)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c195990b-c031-5e2e-9d30-5b3e386b27fc', 'Xâu chuỗi hạt', 'Trong khi thực hiện xâu chuỗi hạt, bố mẹ giải thích các bước: “một tay giữ sợi dây và tay kia giữ hạt”, “tìm lỗ nhỏ”, “xỏ dây qua lỗ”, “Kéo dây”.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Các hạt có đường kính lỗ khác nhau (3 cm, 2 cm, 1 cm), một số sợi dây dày có độ dài khác nhau.

## Các bước thực hiện
1. Bố mẹ đặt một số hạt và một sợi dây lên bàn trước mặt trẻ và nói với trẻ: “Chúng ta hãy làm một chiếc vòng cổ nhé!” Bố mẹ lấy các hạt bằng một tay và tay kia lấy sợi dây rồi xâu hạt vào dây.
2. Đưa sợi dây cho trẻ và nói: “Đến lượt con nào!” rồi để trẻ thử xâu chuỗi hạt.

## Hướng dẫn của chuyên gia
- Khi trẻ mới tập xâu chuỗi hạt, bạn có thể chọn những sợi dây và hạt cứng hơn, dày hơn, dễ cầm và có lỗ lớn hơn. Khi khả năng phối hợp tay và mắt của trẻ được cải thiện, dây mềm mỏng và hạt có lỗ nhỏ có thể được sử dụng.
- Bạn có thể chọn các vật dụng khác nhau để làm hạt, chẳng hạn như ống hút cắt thành từng miếng nhỏ,...; bạn có thể chọn dây có chất liệu khác nhau, chẳng hạn như dây giày, dây câu cá,...
- Cho phép trẻ sử dụng khả năng sáng tạo của mình để biến các hạt thành các vật dụng khác nhau, chẳng hạn như dây chuyền, vòng tay,... Trò chơi này có thể được mở rộng cho lứa tuổi 2 - 6.

> Trong khi thực hiện xâu chuỗi hạt, bố mẹ giải thích các bước: “một tay giữ sợi dây và tay kia giữ hạt”, “tìm lỗ nhỏ”, “xỏ dây qua lỗ”, “Kéo dây”.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 21, 24,
       'Các hạt có đường kính lỗ khác nhau (3 cm, 2 cm, 1 cm), một số sợi dây dày có độ dài khác nhau.', ARRAY['Các hạt có đường kính lỗ khác nhau (3 cm', '2 cm', '1 cm)', 'một số sợi dây dày có độ dài khác nhau']::text[], '/static/activities/g097/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, mắt, Khả năng phối hợp bằng cả hai tay.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c195990b-c031-5e2e-9d30-5b3e386b27fc', 1, 'Bố mẹ đặt một số hạt và một sợi dây lên bàn trước mặt trẻ và nói với trẻ: “Chúng ta hãy làm một chiếc vòng cổ nhé!” Bố mẹ lấy các hạt bằng một tay và tay kia lấy sợi dây rồi xâu hạt vào dây.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c195990b-c031-5e2e-9d30-5b3e386b27fc', 2, 'Đưa sợi dây cho trẻ và nói: “Đến lượt con nào!” rồi để trẻ thử xâu chuỗi hạt.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c195990b-c031-5e2e-9d30-5b3e386b27fc', 'image', '/static/activities/g097/main.jpg', 'Trong khi thực hiện xâu chuỗi hạt, bố mẹ giải thích các bước: “một tay giữ sợi dây và tay kia giữ hạt”, “tìm lỗ nhỏ”, “xỏ dây qua lỗ”, “Kéo dây”.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c195990b-c031-5e2e-9d30-5b3e386b27fc', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g098: Thức ăn của động vật (trang PDF 145)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c5decbac-8dba-5dc6-a933-a503ea100774', 'Thức ăn của động vật', 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Hình ảnh con khỉ và các động vật khác, một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật.

## Các bước thực hiện
1. Đầu tiên, bố mẹ lấy hình con khỉ ra và hỏi trẻ: “Khỉ thích ăn gì?” Chờ trẻ trả lời, bố mẹ nói chậm rãi và rõ ràng: “Ăn chuối”. Bé trả lời “chuối”, bố mẹ đáp “Khỉ thích ăn chuối”, giúp bé kéo dài câu nói, sau đó cho đồ chơi hình quả chuối vào miệng khỉ cho ăn và nói: “Khỉ con ăn chuối đi!”
2. Làm tương tự với các động vật khác. Sau khi cho trẻ chơi hết với số động vật và thức ăn của nó, bố mẹ có thể giả làm các con vật và cảm ơn trẻ.

## Hướng dẫn của chuyên gia
- Các con vật được chọn cho trò chơi nên quen thuộc hoặc được trẻ yêu thích.
- Khi bố mẹ giúp trẻ kéo dài độ dài câu, đừng kéo dài quá lâu.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 21, 24,
       'Hình ảnh con khỉ và các động vật khác, một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật.', ARRAY['Hình ảnh con khỉ và các động vật khác', 'một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật']::text[], '/static/activities/g098/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c5decbac-8dba-5dc6-a933-a503ea100774', 1, 'Đầu tiên, bố mẹ lấy hình con khỉ ra và hỏi trẻ: “Khỉ thích ăn gì?” Chờ trẻ trả lời, bố mẹ nói chậm rãi và rõ ràng: “Ăn chuối”. Bé trả lời “chuối”, bố mẹ đáp “Khỉ thích ăn chuối”, giúp bé kéo dài câu nói, sau đó cho đồ chơi hình quả chuối vào miệng khỉ cho ăn và nói: “Khỉ con ăn chuối đi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c5decbac-8dba-5dc6-a933-a503ea100774', 2, 'Làm tương tự với các động vật khác. Sau khi cho trẻ chơi hết với số động vật và thức ăn của nó, bố mẹ có thể giả làm các con vật và cảm ơn trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c5decbac-8dba-5dc6-a933-a503ea100774', 'image', '/static/activities/g098/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c5decbac-8dba-5dc6-a933-a503ea100774', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g099: Mô tả đồ vật và tìm kiếm (trang PDF 146)
-- Cần duyệt: Mục “Đồ dùng” trong sách bị in nhầm từ trò “Thức ăn của động vật”; nội dung trò chơi cần một chiếc hộp, khăn/vải che và vài đồ vật có hình dạng, chất liệu khác nhau.
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c025486d-41e8-5fca-a73b-9cb46bb3850e', 'Mô tả đồ vật và tìm kiếm', 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng xúc giác.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng xúc giác

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Hình ảnh con khỉ và các động vật khác, một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật.

## Các bước thực hiện
1. Bố mẹ khuyến khích trẻ mở hộp, chạm vào đồ vật và cảm nhận hình dáng, cấu tạo của đồ vật. Bố mẹ mô tả đồ vật như: “Đây là một cục bông, mềm” hoặc “Đây là một mảnh giấy bóng”,...
2. Bố mẹ cho trẻ đủ thời gian để khám phá, sau đó dùng khăn hoặc vải che hộp lại và khuyến khích trẻ cho tay vào hộp để tìm đồ vật: “Con có thể tìm được một quả bóng tròn, nhẵn không?”
3. Sau khi chơi vài lần, trẻ sẽ dần dần và có ý thức chọn ra được những món đồ mà bố mẹ mong muốn.

## Hướng dẫn của chuyên gia
- Trọng tâm của lời bố mẹ nói là cho biết hình dạng, cấu tạo của đồ vật và không cần thiết phải nói tên đồ vật. Ví dụ: “Con có thể tìm thứ gì đó để kéo không?”
- Khi khả năng của trẻ tăng lên, bạn cũng có thể để trẻ miêu tả và để người lớn tìm kiếm. Khuyến khích trẻ sử dụng nhiều từ vựng hơn để mô tả đồ vật.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 21, 24,
       'Hình ảnh con khỉ và các động vật khác, một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật.', ARRAY['Hình ảnh con khỉ và các động vật khác', 'một số đồ chơi hoặc hình ảnh các loại thức ăn yêu thích của động vật']::text[], '/static/activities/g099/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng xúc giác.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c025486d-41e8-5fca-a73b-9cb46bb3850e', 1, 'Bố mẹ khuyến khích trẻ mở hộp, chạm vào đồ vật và cảm nhận hình dáng, cấu tạo của đồ vật. Bố mẹ mô tả đồ vật như: “Đây là một cục bông, mềm” hoặc “Đây là một mảnh giấy bóng”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c025486d-41e8-5fca-a73b-9cb46bb3850e', 2, 'Bố mẹ cho trẻ đủ thời gian để khám phá, sau đó dùng khăn hoặc vải che hộp lại và khuyến khích trẻ cho tay vào hộp để tìm đồ vật: “Con có thể tìm được một quả bóng tròn, nhẵn không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c025486d-41e8-5fca-a73b-9cb46bb3850e', 3, 'Sau khi chơi vài lần, trẻ sẽ dần dần và có ý thức chọn ra được những món đồ mà bố mẹ mong muốn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c025486d-41e8-5fca-a73b-9cb46bb3850e', 'image', '/static/activities/g099/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c025486d-41e8-5fca-a73b-9cb46bb3850e', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g100: Bên trong, bên ngoài chiếc hộp (trang PDF 147)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8fd100d0-d127-5663-a77e-e39be65251ab', 'Bên trong, bên ngoài chiếc hộp', 'Khi mô tả, bố mẹ sử dụng các từ chỉ không gian như “bên trong”, “bên ngoài”.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Kỹ năng diễn đạt ngôn ngữ, Cảm giác không gian

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ bò hoặc ngồi.
- **Đồ dùng:** Một hộp bìa cứng lớn.

## Các bước thực hiện
1. Bố mẹ đặt hộp bìa cứng lớn xuống đất và mở hai đầu hộp.
2. Khuyến khích trẻ vào trong. Khi trẻ chui vào hộp, bố mẹ mô tả bằng lời: “Vào ra, con đã ở trong hộp” hoặc: “Bò ra ngoài nào em bé ở ngoài hộp đi!”
3. Sau một vài lần, bạn có thể để trẻ điền vào chỗ trống trong câu nói của mình. Ví dụ, khi trẻ ở trong hộp, bố mẹ nói: “Con ở ...” và đợi trẻ nói “trong hộp”.

## Hướng dẫn của chuyên gia
- Bố mẹ cũng có thể sử dụng hộp bìa cứng để chơi trò chơi trốn tìm hoặc sắp xếp hộp bìa cứng vào một căn phòng nhỏ.
- Trong cuộc sống hằng ngày, bố mẹ nên sử dụng từ ngữ về không gian càng nhiều càng tốt.

> Khi mô tả, bố mẹ sử dụng các từ chỉ không gian như “bên trong”, “bên ngoài”.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 21, 24,
       'Một hộp bìa cứng lớn.', ARRAY['Một hộp bìa cứng lớn']::text[], '/static/activities/g100/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Kỹ năng diễn đạt ngôn ngữ, Cảm giác không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8fd100d0-d127-5663-a77e-e39be65251ab', 1, 'Bố mẹ đặt hộp bìa cứng lớn xuống đất và mở hai đầu hộp.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8fd100d0-d127-5663-a77e-e39be65251ab', 2, 'Khuyến khích trẻ vào trong. Khi trẻ chui vào hộp, bố mẹ mô tả bằng lời: “Vào ra, con đã ở trong hộp” hoặc: “Bò ra ngoài nào em bé ở ngoài hộp đi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8fd100d0-d127-5663-a77e-e39be65251ab', 3, 'Sau một vài lần, bạn có thể để trẻ điền vào chỗ trống trong câu nói của mình. Ví dụ, khi trẻ ở trong hộp, bố mẹ nói: “Con ở ...” và đợi trẻ nói “trong hộp”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8fd100d0-d127-5663-a77e-e39be65251ab', 'image', '/static/activities/g100/main.jpg', 'Khi mô tả, bố mẹ sử dụng các từ chỉ không gian như “bên trong”, “bên ngoài”.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8fd100d0-d127-5663-a77e-e39be65251ab', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g101: Hình dạng khác nhau của đồ vật (trang PDF 148)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8f02a929-bce5-539a-b4ed-54341cad7056', 'Hình dạng khác nhau của đồ vật', 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng hiểu ngôn ngữ.', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Hai khối xây dựng hình tròn màu đỏ, hai khối xây dựng hình vuông màu đỏ.

## Các bước thực hiện
1. Bố mẹ lấy ra hai khối hình tròn màu đỏ và nói: “Chúng đều nhẵn và có màu đỏ.” Sau đó ghép chúng lại với nhau. Bố mẹ lấy ra một khối xây dựng hình vuông màu đỏ khác và mô tả: “Đây là khối xây dựng hình vuông”.
2. Bố mẹ lấy ra một trong các khối xây dựng hình tròn màu đỏ và hỏi trẻ: “Con có thể tìm được khối giống nhau không?” Nếu trẻ tìm được khối xây dựng đúng và ghép hai khối lại với nhau, bố mẹ sẽ nhiệt tình khen ngợi trẻ: “Đúng rồi!”
3. Nếu trẻ nhặt nhầm, bố mẹ cũng động viên: “Con tìm cái khác đi, cái kia cũng giống cái này. Nhìn xem này, nó hình tròn đấy”.

## Hướng dẫn của chuyên gia
- Ngay cả khi trẻ lựa chọn sai, bố mẹ cũng không nên chỉ trích mà hãy động viên trẻ nhiều nhất có thể.
- Bố mẹ cũng có thể chọn hình dạng phù hợp của đồ vật, chẳng hạn như thìa, quả bóng,...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 21, 24,
       'Hai khối xây dựng hình tròn màu đỏ, hai khối xây dựng hình vuông màu đỏ.', ARRAY['Hai khối xây dựng hình tròn màu đỏ', 'hai khối xây dựng hình vuông màu đỏ']::text[], '/static/activities/g101/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8f02a929-bce5-539a-b4ed-54341cad7056', 1, 'Bố mẹ lấy ra hai khối hình tròn màu đỏ và nói: “Chúng đều nhẵn và có màu đỏ.” Sau đó ghép chúng lại với nhau. Bố mẹ lấy ra một khối xây dựng hình vuông màu đỏ khác và mô tả: “Đây là khối xây dựng hình vuông”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8f02a929-bce5-539a-b4ed-54341cad7056', 2, 'Bố mẹ lấy ra một trong các khối xây dựng hình tròn màu đỏ và hỏi trẻ: “Con có thể tìm được khối giống nhau không?” Nếu trẻ tìm được khối xây dựng đúng và ghép hai khối lại với nhau, bố mẹ sẽ nhiệt tình khen ngợi trẻ: “Đúng rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8f02a929-bce5-539a-b4ed-54341cad7056', 3, 'Nếu trẻ nhặt nhầm, bố mẹ cũng động viên: “Con tìm cái khác đi, cái kia cũng giống cái này. Nhìn xem này, nó hình tròn đấy”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8f02a929-bce5-539a-b4ed-54341cad7056', 'image', '/static/activities/g101/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8f02a929-bce5-539a-b4ed-54341cad7056', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g102: Phân loại đồ chơi (trang PDF 149)
-- Cần duyệt: Trang scan bị cắt mất nửa trái (phần Chuẩn bị, Hướng dẫn chuyên gia). Đồ dùng được suy ra từ các bước.
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'cad5665d-4d62-5745-a3d8-8fc9866669d9', 'Phân loại đồ chơi', 'Các loại đồ chơi hoặc vật dụng được chọn có thể thiên về nội dung mà trẻ đang khám phá. Ví dụ, nếu gần đây trẻ đang tìm hiểu về động vật, bạn có thể mua thêm đồ chơi hình động vật.', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng hiểu ngôn ngữ

## Chuẩn bị
- **Đồ dùng:** Đồ chơi trái cây, đồ chơi động vật, hai khay nhựa.

## Các bước thực hiện
1. Bố mẹ lần lượt đặt một đồ chơi trái cây và một đồ chơi động vật vào hai khay nhựa rồi nói với trẻ: “Khay nhỏ này đựng đầy trái cây, còn khay này đựng đầy các con vật. Chúng ta cùng chơi trò chơi phân loại nhé!”
2. Khi trẻ cầm một món đồ chơi lên, bố mẹ nói: “Đây là...” rồi đợi trẻ gọi tên đồ chơi đó. Sau khi đợi 3 giây, nếu trẻ chưa phân biệt được thì bố mẹ nên cho biết tên và loại đồ chơi, sau đó đặt đồ chơi vào giỏ nhỏ tương ứng cùng trẻ; nếu trẻ không phân biệt được loại, bố mẹ có thể hỗ trợ trẻ. Ví dụ, nếu trẻ đang ôm một con chó con, bố mẹ sẽ nói: “Đây là...” và đợi trẻ nói “cún con”. Nếu trẻ không gọi tên được thì bố mẹ sẽ nói: “Đây là một chú chó con”, “cún con”, “đó là một con vật”. Khi trẻ dần quen với nội dung trò chơi, bố mẹ không hỗ trợ trẻ nữa.
3. Sau khi trẻ đã xếp hết đồ chơi vào các khay nhựa tương ứng, bố mẹ có thể cùng trẻ đếm đồ chơi và mô tả chúng trong khi đếm. Ví dụ: Khi đếm khay chứa các con vật, hãy nói: “Trong đó có chó con, mèo con,... Đó là những con vật”.

> Các loại đồ chơi hoặc vật dụng được chọn có thể thiên về nội dung mà trẻ đang khám phá. Ví dụ, nếu gần đây trẻ đang tìm hiểu về động vật, bạn có thể mua thêm đồ chơi hình động vật.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 21, 24,
       'Đồ chơi trái cây, đồ chơi động vật, hai khay nhựa.', ARRAY['Đồ chơi trái cây', 'đồ chơi động vật', 'hai khay nhựa']::text[], '/static/activities/g102/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng hiểu ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('cad5665d-4d62-5745-a3d8-8fc9866669d9', 1, 'Bố mẹ lần lượt đặt một đồ chơi trái cây và một đồ chơi động vật vào hai khay nhựa rồi nói với trẻ: “Khay nhỏ này đựng đầy trái cây, còn khay này đựng đầy các con vật. Chúng ta cùng chơi trò chơi phân loại nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('cad5665d-4d62-5745-a3d8-8fc9866669d9', 2, 'Khi trẻ cầm một món đồ chơi lên, bố mẹ nói: “Đây là...” rồi đợi trẻ gọi tên đồ chơi đó. Sau khi đợi 3 giây, nếu trẻ chưa phân biệt được thì bố mẹ nên cho biết tên và loại đồ chơi, sau đó đặt đồ chơi vào giỏ nhỏ tương ứng cùng trẻ; nếu trẻ không phân biệt được loại, bố mẹ có thể hỗ trợ trẻ. Ví dụ, nếu trẻ đang ôm một con chó con, bố mẹ sẽ nói: “Đây là...” và đợi trẻ nói “cún con”. Nếu trẻ không gọi tên được thì bố mẹ sẽ nói: “Đây là một chú chó con”, “cún con”, “đó là một con vật”. Khi trẻ dần quen với nội dung trò chơi, bố mẹ không hỗ trợ trẻ nữa.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('cad5665d-4d62-5745-a3d8-8fc9866669d9', 3, 'Sau khi trẻ đã xếp hết đồ chơi vào các khay nhựa tương ứng, bố mẹ có thể cùng trẻ đếm đồ chơi và mô tả chúng trong khi đếm. Ví dụ: Khi đếm khay chứa các con vật, hãy nói: “Trong đó có chó con, mèo con,... Đó là những con vật”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('cad5665d-4d62-5745-a3d8-8fc9866669d9', 'image', '/static/activities/g102/main.jpg', 'Các loại đồ chơi hoặc vật dụng được chọn có thể thiên về nội dung mà trẻ đang khám phá. Ví dụ, nếu gần đây trẻ đang tìm hiểu về động vật, bạn có thể mua thêm đồ chơi hình động vật.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'cad5665d-4d62-5745-a3d8-8fc9866669d9', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g103: Tìm nắp chai đúng (trang PDF 150)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '61cace45-44ee-5d47-b456-74ae3cdd1db0', 'Tìm nắp chai đúng', 'Trong quá trình chơi, bố mẹ hướng dẫn và cho trẻ nhiều thời gian để khám phá.', '**Kỹ năng phát triển:** Khả năng quan sát, Khả năng phối hợp tay mắt

## Chuẩn bị
- **Không gian:** Mặt bàn.
- **Tư thế:** Trẻ ngồi đối diện với bố mẹ.
- **Đồ dùng:** Các loại chai lọ có nắp đậy, kích cỡ khác nhau.

## Các bước thực hiện
1. Bố mẹ nói với trẻ: “Cả nhà mình cùng chơi trò chơi tìm nắp chai nhé!”. Bố mẹ đặt các chai và nắp riêng biệt trước mặt trẻ và hỏi: “Con có thể tìm thấy nắp của các chai này không?”
2. Hướng dẫn trẻ tìm một chiếc nắp phù hợp thông qua việc thử từng chiếc trên một chai. Kết hợp mô tả bằng lời: “Cái nắp này có đúng không? Ồ, không đúng rồi, hãy thử cái khác nhé!”
3. Sau khi trẻ đã tìm được đúng tất cả nắp chai, bố mẹ hãy đập tay và khen: “Đúng hết rồi, con giỏi quá!”

## Hướng dẫn của chuyên gia
- Ban đầu, bố mẹ chỉ nên dùng 2 - 3 loại chai có nắp khác nhau. Khi khả năng của trẻ phát triển, hãy tăng số lượng chai lên.

> Trong quá trình chơi, bố mẹ hướng dẫn và cho trẻ nhiều thời gian để khám phá.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 21, 24,
       'Các loại chai lọ có nắp đậy, kích cỡ khác nhau.', ARRAY['Các loại chai lọ có nắp đậy', 'kích cỡ khác nhau']::text[], '/static/activities/g103/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng quan sát, Khả năng phối hợp tay mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('61cace45-44ee-5d47-b456-74ae3cdd1db0', 1, 'Bố mẹ nói với trẻ: “Cả nhà mình cùng chơi trò chơi tìm nắp chai nhé!”. Bố mẹ đặt các chai và nắp riêng biệt trước mặt trẻ và hỏi: “Con có thể tìm thấy nắp của các chai này không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('61cace45-44ee-5d47-b456-74ae3cdd1db0', 2, 'Hướng dẫn trẻ tìm một chiếc nắp phù hợp thông qua việc thử từng chiếc trên một chai. Kết hợp mô tả bằng lời: “Cái nắp này có đúng không? Ồ, không đúng rồi, hãy thử cái khác nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('61cace45-44ee-5d47-b456-74ae3cdd1db0', 3, 'Sau khi trẻ đã tìm được đúng tất cả nắp chai, bố mẹ hãy đập tay và khen: “Đúng hết rồi, con giỏi quá!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('61cace45-44ee-5d47-b456-74ae3cdd1db0', 'image', '/static/activities/g103/main.jpg', 'Trong quá trình chơi, bố mẹ hướng dẫn và cho trẻ nhiều thời gian để khám phá.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '61cace45-44ee-5d47-b456-74ae3cdd1db0', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g104: Chia sẻ đồ chơi (trang PDF 151)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c5a71418-a6a6-5948-a330-8f2559a9379f', 'Chia sẻ đồ chơi', 'Chia sẻ là niềm vui!', '**Kỹ năng phát triển:** Kỹ năng xã hội, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Hai ô tô đồ chơi.

## Các bước thực hiện
1. Trẻ cùng tuổi đến nhà chơi. Bố mẹ lấy hai ô tô đồ chơi, và nói rằng một ô tô là của con và một ô tô là của bạn. Bố mẹ khuyến khích trẻ chia sẻ đồ chơi với bạn, nói mẫu cho trẻ: “Ở đây có hai chiếc xe, một cho tớ, một cho cậu”.
2. Nếu trẻ làm được, bố mẹ khen trẻ: “Ồ, con đã đưa chiếc xe kia cho bạn, tuyệt quá! Cả hai bạn đều có ô tô để chơi”.
3. Khi trẻ muốn chơi chiếc xe ô tô của bạn, bố mẹ hướng dẫn trẻ đổi xe với bạn.

## Hướng dẫn của chuyên gia
- Đừng ép trẻ chia sẻ mà hãy tập chia sẻ trong những tình huống thoải mái để trẻ cảm thấy chia sẻ là một trải nghiệm rất vui vẻ.
- Trong cuộc sống, bố mẹ có thể tạo nhiều cơ hội hơn để chia sẻ với con.

> Chia sẻ là niềm vui!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 21, 24,
       'Hai ô tô đồ chơi.', ARRAY['Hai ô tô đồ chơi']::text[], '/static/activities/g104/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c5a71418-a6a6-5948-a330-8f2559a9379f', 1, 'Trẻ cùng tuổi đến nhà chơi. Bố mẹ lấy hai ô tô đồ chơi, và nói rằng một ô tô là của con và một ô tô là của bạn. Bố mẹ khuyến khích trẻ chia sẻ đồ chơi với bạn, nói mẫu cho trẻ: “Ở đây có hai chiếc xe, một cho tớ, một cho cậu”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c5a71418-a6a6-5948-a330-8f2559a9379f', 2, 'Nếu trẻ làm được, bố mẹ khen trẻ: “Ồ, con đã đưa chiếc xe kia cho bạn, tuyệt quá! Cả hai bạn đều có ô tô để chơi”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c5a71418-a6a6-5948-a330-8f2559a9379f', 3, 'Khi trẻ muốn chơi chiếc xe ô tô của bạn, bố mẹ hướng dẫn trẻ đổi xe với bạn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c5a71418-a6a6-5948-a330-8f2559a9379f', 'image', '/static/activities/g104/main.jpg', 'Chia sẻ là niềm vui!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c5a71418-a6a6-5948-a330-8f2559a9379f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g105: Dùng lưới bắt cá (trang PDF 152)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '6064599a-e6c6-5846-9a0e-93044096fd34', 'Dùng lưới bắt cá', 'Lúc đầu, bố mẹ cùng nói “câu cá, câu cá”; khi bắt bé thì nói “Bắt được cá rồi”. Khi bé diễn đạt “lại đây” bằng cử động, cách diễn đạt hoặc cách phát âm, mẹ có thể giúp bé nói thành lời: “Ồ, tôi vẫn muốn chơi.”', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Kỹ năng hoạt động tập thể, Phát triển trí tưởng tượng

## Chuẩn bị
- **Không gian:** Sàn nhà hoặc thảm trải sàn.
- **Tư thế:** Trẻ đứng, bố mẹ cầm khăn đứng hai bên.
- **Đồ dùng:** Hai khăn tắm.

## Các bước thực hiện
1. Bố mẹ đóng vai “ngư dân”, cầm hai đầu khăn tắm, vừa vẫy vừa nói: “Bắt cá, bắt cá”. Khi trùm được khăn tắm vào trẻ, bố mẹ cười và nói: “Bắt được cá rồi!”
2. Lặp lại nhiều lần để trẻ hiểu thứ tự của trò chơi và đợi bé yêu cầu: “nữa” hoặc “con muốn chơi lại” bằng cách kết hợp câu nói, hành động và ánh mắt.
3. Thêm một chút thay đổi cho trò chơi. Bố mẹ vừa nói vừa vẫy khăn tắm: “Một lưới không bắt được cá, hai lưới không bắt được cá, ba lưới sẽ bắt được cá. Có lưới sẽ bắt được cá”. Kéo dài thời gian chờ đợi của trẻ khiến trẻ hào hứng và chủ động yêu cầu hơn nữa.
4. Tiếp theo, bố và trẻ có thể đóng vai “ngư dân” và kéo “lưới” để bắt “cá mẹ”. Đổi vai linh động để trẻ không bị chán.

## Hướng dẫn của chuyên gia
- Nên tạm dừng sau mỗi lượt chơi để khuyến khích trẻ nói (yêu cầu chơi tiếp), giúp phát triển giao tiếp kết hợp biểu cảm và ánh mắt để tương tác với người lớn.
- Bố mẹ lưu ý điều chỉnh độ khó của ngôn ngữ tùy theo mức độ hiểu và phản ứng của trẻ.

> Lúc đầu, bố mẹ cùng nói “câu cá, câu cá”; khi bắt bé thì nói “Bắt được cá rồi”. Khi bé diễn đạt “lại đây” bằng cử động, cách diễn đạt hoặc cách phát âm, mẹ có thể giúp bé nói thành lời: “Ồ, tôi vẫn muốn chơi.”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 21, 24,
       'Hai khăn tắm.', ARRAY['Hai khăn tắm']::text[], '/static/activities/g105/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Kỹ năng hoạt động tập thể, Phát triển trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6064599a-e6c6-5846-9a0e-93044096fd34', 1, 'Bố mẹ đóng vai “ngư dân”, cầm hai đầu khăn tắm, vừa vẫy vừa nói: “Bắt cá, bắt cá”. Khi trùm được khăn tắm vào trẻ, bố mẹ cười và nói: “Bắt được cá rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6064599a-e6c6-5846-9a0e-93044096fd34', 2, 'Lặp lại nhiều lần để trẻ hiểu thứ tự của trò chơi và đợi bé yêu cầu: “nữa” hoặc “con muốn chơi lại” bằng cách kết hợp câu nói, hành động và ánh mắt.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6064599a-e6c6-5846-9a0e-93044096fd34', 3, 'Thêm một chút thay đổi cho trò chơi. Bố mẹ vừa nói vừa vẫy khăn tắm: “Một lưới không bắt được cá, hai lưới không bắt được cá, ba lưới sẽ bắt được cá. Có lưới sẽ bắt được cá”. Kéo dài thời gian chờ đợi của trẻ khiến trẻ hào hứng và chủ động yêu cầu hơn nữa.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('6064599a-e6c6-5846-9a0e-93044096fd34', 4, 'Tiếp theo, bố và trẻ có thể đóng vai “ngư dân” và kéo “lưới” để bắt “cá mẹ”. Đổi vai linh động để trẻ không bị chán.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('6064599a-e6c6-5846-9a0e-93044096fd34', 'image', '/static/activities/g105/main.jpg', 'Lúc đầu, bố mẹ cùng nói “câu cá, câu cá”; khi bắt bé thì nói “Bắt được cá rồi”. Khi bé diễn đạt “lại đây” bằng cử động, cách diễn đạt hoặc cách phát âm, mẹ có thể giúp bé nói thành lời: “Ồ, tôi vẫn muốn chơi.”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '6064599a-e6c6-5846-9a0e-93044096fd34', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g106: Đeo giày (trang PDF 153)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', 'Đeo giày', '“Đôi giày nhỏ nhắn, dễ thương quá! Hãy xỏ chân vào và nhấc gót lên.”', '**Kỹ năng phát triển:** Khả năng tự chăm sóc, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Trong gia đình.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một đôi giày.

## Các bước thực hiện
1. “Chúng ta phải đi giày khi ra ngoài!” Bố mẹ thể hiện hành động: xỏ chân trẻ vào giày, sau đó dùng tay nhấc lên và cuối cùng cài khóa vào.
2. Khuyến khích trẻ bắt chước hành động của bố mẹ và mang chiếc giày còn lại vào. Nếu gặp khó khăn trong quá trình này, bố mẹ có thể hỗ trợ một chút.
3. Sau khi trẻ tự đi giày, bố mẹ nên khen ngợi: “Con tự mình đi giày, giỏi quá!”.

## Hướng dẫn của chuyên gia
- Mỗi lần ra ngoài là một cơ hội để trẻ được rèn luyện nhiều hơn. Bố mẹ nên khuyến khích chứ không nên chỉ trích.
- Trẻ ở giai đoạn này hơi khó phân biệt trái, phải. Bố mẹ có thể giúp trẻ xếp giày trước hoặc dùng một mảnh giấy cắt làm đôi và đặt lên giày của trẻ để nhắc nhở.

> “Đôi giày nhỏ nhắn, dễ thương quá! Hãy xỏ chân vào và nhấc gót lên.”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi tự chăm sóc._', 'play', 21, 24,
       'Một đôi giày.', ARRAY['Một đôi giày']::text[], '/static/activities/g106/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng tự chăm sóc, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', 1, '“Chúng ta phải đi giày khi ra ngoài!” Bố mẹ thể hiện hành động: xỏ chân trẻ vào giày, sau đó dùng tay nhấc lên và cuối cùng cài khóa vào.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', 2, 'Khuyến khích trẻ bắt chước hành động của bố mẹ và mang chiếc giày còn lại vào. Nếu gặp khó khăn trong quá trình này, bố mẹ có thể hỗ trợ một chút.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', 3, 'Sau khi trẻ tự đi giày, bố mẹ nên khen ngợi: “Con tự mình đi giày, giỏi quá!”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', 'image', '/static/activities/g106/main.jpg', '“Đôi giày nhỏ nhắn, dễ thương quá! Hãy xỏ chân vào và nhấc gót lên.”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '1cc5abbf-d460-51a8-bdd9-44e945d8e5cd', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g107: Nhảy xa (trang PDF 154, 155)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3a96a5d1-367b-54ac-9318-be3812c69dc9', 'Nhảy xa', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng giữ thăng bằng cơ thể, Khả năng nhận thức.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Khả năng giữ thăng bằng cơ thể, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Phòng ngủ hoặc phòng khách.
- **Tư thế:** Trẻ đứng thẳng.
- **Đồ dùng:** Một số hình ảnh con vật.

## Các bước thực hiện
1. Dán hình ảnh các con vật xuống đất. Bố mẹ bảo trẻ: “Con nhảy đến chỗ chú chó con nhé!” Thực hiện bước nhảy xa bằng cả hai chân, đồng thời nói: “Hãy nhảy giống bố mẹ nhé” và chỉ vào hình ảnh con chó con trước mặt bạn.
2. Bố mẹ hướng dẫn trẻ nhảy về phía trước, nếu trẻ không thể hoàn thành, bố mẹ có thể dùng tay đối diện với trẻ để hướng dẫn trẻ cúi người về phía trước và co chân để nhảy về phía trước.
3. Nếu trẻ nhảy thành công đến ô đầu tiên, bố mẹ nên vỗ tay hoặc khen ngợi, sau đó khuyến khích trẻ tiếp tục nhảy về phía các con vật khác. Sau khi hoàn thành động tác, bố mẹ cũng nên vỗ tay hoặc khen ngợi trẻ.

## Hướng dẫn của chuyên gia
- Tùy theo khả năng của trẻ, bạn có thể nhảy về phía trước, sau đó nhảy sang trái và phải, nhảy bằng một chân,... Hãy bắt đầu bằng những hành động đơn giản và lặp lại nhiều lần để tăng trải nghiệm thành công cho trẻ.
- Bố mẹ cần làm mẫu nhiều lần và đưa ra sự hỗ trợ phù hợp khi cần thiết, chẳng hạn như nắm tay trẻ mặt đối mặt.
- Bố mẹ có thể thay đổi hướng dẫn theo nội dung mẫu, vị trí các hình con vật có thể điều chỉnh linh hoạt tùy theo khả năng điều khiển của trẻ.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 24, 30,
       'Một số hình ảnh con vật.', ARRAY['Một số hình ảnh con vật']::text[], '/static/activities/g107/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Khả năng giữ thăng bằng cơ thể, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 1, 'Dán hình ảnh các con vật xuống đất. Bố mẹ bảo trẻ: “Con nhảy đến chỗ chú chó con nhé!” Thực hiện bước nhảy xa bằng cả hai chân, đồng thời nói: “Hãy nhảy giống bố mẹ nhé” và chỉ vào hình ảnh con chó con trước mặt bạn.', '/static/activities/g107/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 2, 'Bố mẹ hướng dẫn trẻ nhảy về phía trước, nếu trẻ không thể hoàn thành, bố mẹ có thể dùng tay đối diện với trẻ để hướng dẫn trẻ cúi người về phía trước và co chân để nhảy về phía trước.', '/static/activities/g107/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 3, 'Nếu trẻ nhảy thành công đến ô đầu tiên, bố mẹ nên vỗ tay hoặc khen ngợi, sau đó khuyến khích trẻ tiếp tục nhảy về phía các con vật khác. Sau khi hoàn thành động tác, bố mẹ cũng nên vỗ tay hoặc khen ngợi trẻ.', '/static/activities/g107/step-3.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 'image', '/static/activities/g107/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 'image', '/static/activities/g107/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 'image', '/static/activities/g107/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3a96a5d1-367b-54ac-9318-be3812c69dc9', 'image', '/static/activities/g107/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3a96a5d1-367b-54ac-9318-be3812c69dc9', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g108: Qua sông hái quả (trang PDF 156)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'd8c36b57-6ff6-5f27-968a-c941a79654fb', 'Qua sông hái quả', 'Kỹ năng phát triển: Rèn luyện khả năng thể thao, Khả năng giữ thăng bằng cơ thể.', '**Kỹ năng phát triển:** Rèn luyện khả năng thể thao, Khả năng giữ thăng bằng cơ thể

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc sàn.
- **Tư thế:** Trẻ đứng thẳng, sẵn sàng di chuyển.
- **Đồ dùng:** Một cuộn băng dính màu, một số loại hoa quả mà trẻ thích ăn.

## Các bước thực hiện
1. Bố mẹ dùng băng dính màu dán những đường thẳng song song tạo thành một cây cầu trên mặt đất, dài khoảng 3 cm và rộng 15 cm. Đặt một loại quả trẻ thích ăn ở một đầu cầu.
2. Bố mẹ và trẻ đang đứng ở đầu cầu bên kia và nói với trẻ: “Bên kia sông có rất nhiều loại quả mà con thích ăn. Bố mẹ đã xây một cây cầu nhỏ. Con hãy đi qua cầu để lấy quả ăn nhé!”
3. Bố mẹ dắt trẻ đi, hướng dẫn trẻ đặt gót chân xuống đất rồi mới đến ngón chân, nhắc nhở trẻ không được chạm vạch.
4. Mỗi khi trẻ qua cầu, bố mẹ sẽ thưởng cho trẻ một miếng trái cây và khen trẻ: “Con giỏi quá, con đã biết đi qua cầu rồi. Hoan hô!”

## Hướng dẫn của chuyên gia
- Bố mẹ cần có mặt để bảo vệ trẻ trong trường hợp trẻ bị ngã. Khi trẻ tìm kiếm sự hỗ trợ, bố mẹ có thể nắm tay trẻ một lúc rồi buông ra sau khi trẻ đã ổn định lại. Bố mẹ có thể dạy trẻ giơ cả hai tay lên để giúp giữ thăng bằng.
- Nhìn vào sự phát triển khả năng của trẻ, bạn có thể giảm dần chiều rộng của cầu từ 15 cm xuống 10 cm. Ngoài các đường thẳng, bạn cũng có thể biến thành hình con cá để tăng thêm sự thú vị.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 24, 30,
       'Một cuộn băng dính màu, một số loại hoa quả mà trẻ thích ăn.', ARRAY['Một cuộn băng dính màu', 'một số loại hoa quả mà trẻ thích ăn']::text[], '/static/activities/g108/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Rèn luyện khả năng thể thao, Khả năng giữ thăng bằng cơ thể.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d8c36b57-6ff6-5f27-968a-c941a79654fb', 1, 'Bố mẹ dùng băng dính màu dán những đường thẳng song song tạo thành một cây cầu trên mặt đất, dài khoảng 3 cm và rộng 15 cm. Đặt một loại quả trẻ thích ăn ở một đầu cầu.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d8c36b57-6ff6-5f27-968a-c941a79654fb', 2, 'Bố mẹ và trẻ đang đứng ở đầu cầu bên kia và nói với trẻ: “Bên kia sông có rất nhiều loại quả mà con thích ăn. Bố mẹ đã xây một cây cầu nhỏ. Con hãy đi qua cầu để lấy quả ăn nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d8c36b57-6ff6-5f27-968a-c941a79654fb', 3, 'Bố mẹ dắt trẻ đi, hướng dẫn trẻ đặt gót chân xuống đất rồi mới đến ngón chân, nhắc nhở trẻ không được chạm vạch.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d8c36b57-6ff6-5f27-968a-c941a79654fb', 4, 'Mỗi khi trẻ qua cầu, bố mẹ sẽ thưởng cho trẻ một miếng trái cây và khen trẻ: “Con giỏi quá, con đã biết đi qua cầu rồi. Hoan hô!”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('d8c36b57-6ff6-5f27-968a-c941a79654fb', 'image', '/static/activities/g108/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'd8c36b57-6ff6-5f27-968a-c941a79654fb', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g109: Khéo léo nhặt que tính (trang PDF 157)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '7dc6d64e-7384-58ef-9043-e0d8960ff51b', 'Khéo léo nhặt que tính', 'Trong trò chơi, bố mẹ có thể đẩy các que tính ra xa nhau hơn. Khi trẻ đã thành thạo, bố mẹ có thể đẩy các que tính lại gần nhau hơn để tăng độ khó, hoặc đổi thành những loại que mỏng hơn.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Phối hợp tay, mắt, Năng lực tập trung

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi ghế đối diện bố mẹ.
- **Đồ dùng:** Một bộ que tính, hoặc que kem nhiều màu sắc.

## Các bước thực hiện
1. Bố mẹ cầm cả bộ que tính, đặt thẳng đứng trên bàn rồi buông ra, que tính sẽ vương vãi trên bàn.
2. Bố mẹ hướng dẫn trẻ nhặt từng que tính lên: “Con nhặt que tính lên, nhưng không được chạm vào các que khác nhé!” Sau khi nhặt thành công một que tính, bố mẹ có thể đập tay và khen trẻ để khích lệ trẻ thực hiện tiếp.
3. Bố mẹ tiếp tục khuyến khích con nhặt que tính cho đến hết, đồng thời nói với trẻ: “Đến lượt con rồi. Hãy cầm từng chiếc lên, đừng chạm vào chiếc bên cạnh nhé!”
4. Bố mẹ và trẻ lần lượt nhặt và thi xem ai nhặt được nhiều hơn.

## Hướng dẫn của chuyên gia
- Bố mẹ cần bảo vệ trẻ khi chơi để tránh que tính bắn vào mắt hoặc mũi.
- Nếu không có que tính, bạn cũng có thể sử dụng ổ khóa để thay thế.
- Để trò chơi trở nên thú vị hơn, bố mẹ có thể dùng sơn để sơn các que với nhiều màu sắc khác nhau.

> Trong trò chơi, bố mẹ có thể đẩy các que tính ra xa nhau hơn. Khi trẻ đã thành thạo, bố mẹ có thể đẩy các que tính lại gần nhau hơn để tăng độ khó, hoặc đổi thành những loại que mỏng hơn.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 24, 30,
       'Một bộ que tính, hoặc que kem nhiều màu sắc.', ARRAY['Một bộ que tính', 'hoặc que kem nhiều màu sắc']::text[], '/static/activities/g109/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Phối hợp tay, mắt, Năng lực tập trung.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7dc6d64e-7384-58ef-9043-e0d8960ff51b', 1, 'Bố mẹ cầm cả bộ que tính, đặt thẳng đứng trên bàn rồi buông ra, que tính sẽ vương vãi trên bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7dc6d64e-7384-58ef-9043-e0d8960ff51b', 2, 'Bố mẹ hướng dẫn trẻ nhặt từng que tính lên: “Con nhặt que tính lên, nhưng không được chạm vào các que khác nhé!” Sau khi nhặt thành công một que tính, bố mẹ có thể đập tay và khen trẻ để khích lệ trẻ thực hiện tiếp.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7dc6d64e-7384-58ef-9043-e0d8960ff51b', 3, 'Bố mẹ tiếp tục khuyến khích con nhặt que tính cho đến hết, đồng thời nói với trẻ: “Đến lượt con rồi. Hãy cầm từng chiếc lên, đừng chạm vào chiếc bên cạnh nhé!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('7dc6d64e-7384-58ef-9043-e0d8960ff51b', 4, 'Bố mẹ và trẻ lần lượt nhặt và thi xem ai nhặt được nhiều hơn.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('7dc6d64e-7384-58ef-9043-e0d8960ff51b', 'image', '/static/activities/g109/main.jpg', 'Trong trò chơi, bố mẹ có thể đẩy các que tính ra xa nhau hơn. Khi trẻ đã thành thạo, bố mẹ có thể đẩy các que tính lại gần nhau hơn để tăng độ khó, hoặc đổi thành những loại que mỏng hơn.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '7dc6d64e-7384-58ef-9043-e0d8960ff51b', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g110: Nói ra nhu cầu của bản thân (trang PDF 158)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e34e0071-a2b6-55a2-b0a2-343f1e60c26b', 'Nói ra nhu cầu của bản thân', 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Kỹ năng xã hội.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Kỹ năng xã hội

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi.
- **Đồ dùng:** Những chiếc bánh nhỏ đựng trong hộp, một bình sữa, vài chiếc cốc và thìa.

## Các bước thực hiện
1. Cả nhà đang ngồi quanh bàn chuẩn bị bữa ăn nhẹ. Trên bàn có những chiếc bánh nhỏ, sữa, đĩa và cốc.
2. Mẹ giơ cốc trước mặt bố và nói: “Chúng ta cần một ít sữa”. Bố rót sữa cho mẹ, sau đó đưa cốc rỗng cho trẻ và đợi trẻ chủ động hỏi. Nếu trẻ thể hiện thành công nhu cầu của mình, bố nên khen ngợi kịp thời.
3. Sử dụng phương pháp tương tự để luyện tập thể hiện nhu cầu về bánh, thìa,...

## Hướng dẫn của chuyên gia
- Nếu có sự tham gia của các thành viên khác trong gia đình, khi thể hiện ngôn ngữ, bạn có thể linh hoạt hơn và không sử dụng mẫu câu giống nhau.
- Bố mẹ có thể mở rộng sang các tình huống khác trong cuộc sống và khuyến khích trẻ tích cực thể hiện nhu cầu của mình bằng câu nói.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 24, 30,
       'Những chiếc bánh nhỏ đựng trong hộp, một bình sữa, vài chiếc cốc và thìa.', ARRAY['Những chiếc bánh nhỏ đựng trong hộp', 'một bình sữa', 'vài chiếc cốc và thìa']::text[], '/static/activities/g110/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Kỹ năng xã hội.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e34e0071-a2b6-55a2-b0a2-343f1e60c26b', 1, 'Cả nhà đang ngồi quanh bàn chuẩn bị bữa ăn nhẹ. Trên bàn có những chiếc bánh nhỏ, sữa, đĩa và cốc.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e34e0071-a2b6-55a2-b0a2-343f1e60c26b', 2, 'Mẹ giơ cốc trước mặt bố và nói: “Chúng ta cần một ít sữa”. Bố rót sữa cho mẹ, sau đó đưa cốc rỗng cho trẻ và đợi trẻ chủ động hỏi. Nếu trẻ thể hiện thành công nhu cầu của mình, bố nên khen ngợi kịp thời.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e34e0071-a2b6-55a2-b0a2-343f1e60c26b', 3, 'Sử dụng phương pháp tương tự để luyện tập thể hiện nhu cầu về bánh, thìa,...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e34e0071-a2b6-55a2-b0a2-343f1e60c26b', 'image', '/static/activities/g110/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e34e0071-a2b6-55a2-b0a2-343f1e60c26b', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g111: Đi siêu thị (trang PDF 159)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '22d04655-d492-5078-8929-82448ee1328e', 'Đi siêu thị', 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Tranh ảnh hoặc mô hình các mặt hàng thông dụng trong siêu thị (rau, trái cây, giỏ đựng hàng...).

## Các bước thực hiện
1. Bố mẹ đặt giỏ hàng lên bàn.
2. Bố mẹ lấy một bức tranh hoặc mô hình quả táo cho vào giỏ hàng và nói: “Mẹ đã mua một quả táo”. Sau đó nói với trẻ: “Đến lượt con mua nó rồi!”
3. Bố mẹ và trẻ lần lượt chọn đồ vật và luyện tập mẫu câu khi chọn: “Con đã mua...”
4. Sau khi đã chọn xong tất cả các mặt hàng, bố mẹ có thể cùng trẻ đếm các mặt hàng trong giỏ hàng và luyện tập cấu trúc câu: “Có... trong giỏ hàng”.
5. Bố mẹ có thể tăng dần độ khó tùy theo khả năng diễn đạt của trẻ, chẳng hạn như: “Màu gì...? Mùi vị thế nào? Dùng để làm gì?”

## Hướng dẫn của chuyên gia
- Bố mẹ có thể mua rau, trái cây và giỏ mô phỏng để tăng thêm sự thú vị cho trò chơi.
- Khi mua đồ, bạn có thể bắt đầu với những món đồ mà trẻ quen thuộc và dần dần giới thiệu những món đồ mới mẻ.
- Bố mẹ thường xuyên có thể đưa trẻ đến siêu thị để mua sắm trong cuộc sống hằng ngày, đồng thời tạo cơ hội cho trẻ tìm hiểu về các mặt hàng khác nhau và công dụng của chúng.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 24, 30,
       'Tranh ảnh hoặc mô hình các mặt hàng thông dụng trong siêu thị (rau, trái cây, giỏ đựng hàng...).', ARRAY['Tranh ảnh hoặc mô hình các mặt hàng thông dụng trong siêu thị (rau', 'trái cây', 'giỏ đựng hàng...)']::text[], '/static/activities/g111/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 1, 'Bố mẹ đặt giỏ hàng lên bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 2, 'Bố mẹ lấy một bức tranh hoặc mô hình quả táo cho vào giỏ hàng và nói: “Mẹ đã mua một quả táo”. Sau đó nói với trẻ: “Đến lượt con mua nó rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 3, 'Bố mẹ và trẻ lần lượt chọn đồ vật và luyện tập mẫu câu khi chọn: “Con đã mua...”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 4, 'Sau khi đã chọn xong tất cả các mặt hàng, bố mẹ có thể cùng trẻ đếm các mặt hàng trong giỏ hàng và luyện tập cấu trúc câu: “Có... trong giỏ hàng”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 5, 'Bố mẹ có thể tăng dần độ khó tùy theo khả năng diễn đạt của trẻ, chẳng hạn như: “Màu gì...? Mùi vị thế nào? Dùng để làm gì?”', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('22d04655-d492-5078-8929-82448ee1328e', 'image', '/static/activities/g111/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '22d04655-d492-5078-8929-82448ee1328e', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g112: Gà ăn kẹo (trang PDF 160)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '54361dff-9765-561d-9b92-8a270102084e', 'Gà ăn kẹo', 'Trong khi chơi, bố mẹ nên tăng cường giọng điệu khi diễn đạt “con” và “tớ” và liên tục lặp lại khi nói “con” và “tớ”, có thể dùng cử chỉ để giúp trẻ hiểu.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước hành động, Tăng cường trí tưởng tượng

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một đồ chơi hình gà trống và nhiều viên kẹo màu sắc.

## Các bước thực hiện
1. Bố mẹ lấy ra một con gà trống đồ chơi và nhiều viên kẹo màu sắc và nói: “Ò ó o, tớ là một chú gà trống to lớn. Tớ thích ăn kẹo nhất. Bạn có thể cho tớ ăn được không?”
2. Bố mẹ đặt gà trống trước mặt trẻ, làm mẫu cho gà ăn kẹo và nói: “Tớ cho gà ăn kẹo!”
3. Bố mẹ đưa cho trẻ một viên kẹo và nói: “Đến lượt con cho gà trống ăn!” Khi trẻ cho gà trống ăn, trẻ có thể nói: “Tớ cho gà ăn kẹo!”
4. Sau đó bố mẹ và con lần lượt cho gà ăn kẹo.

## Hướng dẫn của chuyên gia
- Chúng ta cũng nên chú ý đến việc diễn đạt “bạn” và “tôi” trong cuộc sống hằng ngày.
- Nếu trẻ bắt đầu cảm thấy chán trò chơi, bố mẹ có thể nuôi một con gà trống thật để trẻ được thực hành quan sát gà trống và thức ăn của nó.

> Trong khi chơi, bố mẹ nên tăng cường giọng điệu khi diễn đạt “con” và “tớ” và liên tục lặp lại khi nói “con” và “tớ”, có thể dùng cử chỉ để giúp trẻ hiểu.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 24, 30,
       'Một đồ chơi hình gà trống và nhiều viên kẹo màu sắc.', ARRAY['Một đồ chơi hình gà trống và nhiều viên kẹo màu sắc']::text[], '/static/activities/g112/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước hành động, Tăng cường trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('54361dff-9765-561d-9b92-8a270102084e', 1, 'Bố mẹ lấy ra một con gà trống đồ chơi và nhiều viên kẹo màu sắc và nói: “Ò ó o, tớ là một chú gà trống to lớn. Tớ thích ăn kẹo nhất. Bạn có thể cho tớ ăn được không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('54361dff-9765-561d-9b92-8a270102084e', 2, 'Bố mẹ đặt gà trống trước mặt trẻ, làm mẫu cho gà ăn kẹo và nói: “Tớ cho gà ăn kẹo!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('54361dff-9765-561d-9b92-8a270102084e', 3, 'Bố mẹ đưa cho trẻ một viên kẹo và nói: “Đến lượt con cho gà trống ăn!” Khi trẻ cho gà trống ăn, trẻ có thể nói: “Tớ cho gà ăn kẹo!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('54361dff-9765-561d-9b92-8a270102084e', 4, 'Sau đó bố mẹ và con lần lượt cho gà ăn kẹo.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('54361dff-9765-561d-9b92-8a270102084e', 'image', '/static/activities/g112/main.jpg', 'Trong khi chơi, bố mẹ nên tăng cường giọng điệu khi diễn đạt “con” và “tớ” và liên tục lặp lại khi nói “con” và “tớ”, có thể dùng cử chỉ để giúp trẻ hiểu.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '54361dff-9765-561d-9b92-8a270102084e', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g113: Cùng nhau nói những lời đáng yêu (trang PDF 161)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '108e44bd-8e46-5373-bd59-a77328adb40f', 'Cùng nhau nói những lời đáng yêu', 'Hướng dẫn bé lặp lại những bài đồng dao ngắn, đơn giản. Lúc đầu, bé có thể chỉ gọi được một số từ có âm thanh tương tự, nhưng sau một thời gian, bé sẽ học được toàn bộ bài đồng dao.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng ghi nhớ

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ vừa nói cho trẻ vừa thực hiện các động tác: “Mèo mướp kêu meo meo, thỏ trắng chạy nhảy, chó đen sủa, rùa bò chậm”.
2. Cha mẹ khuyến khích trẻ thực hiện các hành động trong khi nói. Nếu trẻ quên, bố mẹ có thể dùng hành động để nhắc nhở trẻ.
3. Lặp lại vài lần trẻ sẽ có thể đọc thuộc lòng hoàn toàn. Khi trẻ đọc thuộc lòng, bố mẹ có thể thực hiện các động tác theo lời bé đọc để thêm phần thú vị.

## Hướng dẫn của chuyên gia
- Khi khả năng của trẻ được cải thiện, bố mẹ có thể thay đổi lời và thêm lời mới.

> Hướng dẫn bé lặp lại những bài đồng dao ngắn, đơn giản. Lúc đầu, bé có thể chỉ gọi được một số từ có âm thanh tương tự, nhưng sau một thời gian, bé sẽ học được toàn bộ bài đồng dao.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 24, 30,
       'Không có.', NULL, '/static/activities/g113/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng ghi nhớ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('108e44bd-8e46-5373-bd59-a77328adb40f', 1, 'Bố mẹ vừa nói cho trẻ vừa thực hiện các động tác: “Mèo mướp kêu meo meo, thỏ trắng chạy nhảy, chó đen sủa, rùa bò chậm”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('108e44bd-8e46-5373-bd59-a77328adb40f', 2, 'Cha mẹ khuyến khích trẻ thực hiện các hành động trong khi nói. Nếu trẻ quên, bố mẹ có thể dùng hành động để nhắc nhở trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('108e44bd-8e46-5373-bd59-a77328adb40f', 3, 'Lặp lại vài lần trẻ sẽ có thể đọc thuộc lòng hoàn toàn. Khi trẻ đọc thuộc lòng, bố mẹ có thể thực hiện các động tác theo lời bé đọc để thêm phần thú vị.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('108e44bd-8e46-5373-bd59-a77328adb40f', 'image', '/static/activities/g113/main.jpg', 'Hướng dẫn bé lặp lại những bài đồng dao ngắn, đơn giản. Lúc đầu, bé có thể chỉ gọi được một số từ có âm thanh tương tự, nhưng sau một thời gian, bé sẽ học được toàn bộ bài đồng dao.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '108e44bd-8e46-5373-bd59-a77328adb40f', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g114: Thay đổi giọng nói (trang PDF 162)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'd85c9206-85a7-5d3d-9f67-a72c32b33b76', 'Thay đổi giọng nói', '“Đây là cảm xúc gì nào?”', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng bắt chước ngôn ngữ

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Bố mẹ nói chuyện với con bằng giọng to và giọng nhỏ. Thảo luận với trẻ khi nào nên nói to và khi nào nên nói nhỏ. Ví dụ, khi khoảng cách tương đối xa, bạn cần dùng giọng to; trong những tình huống yên tĩnh, hãy dùng giọng trầm.
2. Bố mẹ sử dụng các giọng điệu khác nhau để thể hiện sự ngạc nhiên, vui hay buồn để thu hút sự chú ý của trẻ. Sau đó, thảo luận với con bạn về cảm xúc mà giọng nói này thể hiện.
3. Khuyến khích trẻ nói bằng nhiều giọng điệu khác nhau và để bố mẹ đoán xem chúng thể hiện cảm xúc gì.

## Hướng dẫn của chuyên gia
- Chú ý nhắc trẻ nói bằng nhiều âm lượng hoặc ngôn ngữ khác nhau vào những dịp khác nhau trong cuộc sống. Ví dụ, nhắc nhở con bạn nói chuyện nhẹ nhàng trong thư viện.
- Khi đọc truyện tranh, bạn có thể cho mỗi nhân vật một giọng nói khác nhau.

> “Đây là cảm xúc gì nào?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 24, 30,
       'Không có.', NULL, '/static/activities/g114/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng bắt chước ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d85c9206-85a7-5d3d-9f67-a72c32b33b76', 1, 'Bố mẹ nói chuyện với con bằng giọng to và giọng nhỏ. Thảo luận với trẻ khi nào nên nói to và khi nào nên nói nhỏ. Ví dụ, khi khoảng cách tương đối xa, bạn cần dùng giọng to; trong những tình huống yên tĩnh, hãy dùng giọng trầm.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d85c9206-85a7-5d3d-9f67-a72c32b33b76', 2, 'Bố mẹ sử dụng các giọng điệu khác nhau để thể hiện sự ngạc nhiên, vui hay buồn để thu hút sự chú ý của trẻ. Sau đó, thảo luận với con bạn về cảm xúc mà giọng nói này thể hiện.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('d85c9206-85a7-5d3d-9f67-a72c32b33b76', 3, 'Khuyến khích trẻ nói bằng nhiều giọng điệu khác nhau và để bố mẹ đoán xem chúng thể hiện cảm xúc gì.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('d85c9206-85a7-5d3d-9f67-a72c32b33b76', 'image', '/static/activities/g114/main.jpg', '“Đây là cảm xúc gì nào?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'd85c9206-85a7-5d3d-9f67-a72c32b33b76', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g115: Em bé ngoan và lịch sự khi xếp hàng (trang PDF 163)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', 'Em bé ngoan và lịch sự khi xếp hàng', 'Hãy xếp hàng!', '**Kỹ năng phát triển:** Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ

## Chuẩn bị
- **Không gian:** Trong gia đình.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Tranh ảnh nội dung xếp hàng.

## Các bước thực hiện
1. Mẹ lấy ra một bức ảnh trẻ em đang chơi cầu trượt và hỏi: “Các em này đang làm gì vậy?” Mẹ khuyến khích trẻ nói, rồi hỏi: “Các em đều muốn chơi cầu trượt. Điều gì sẽ xảy ra nếu trẻ chơi cầu trượt? Các em chen vào chơi à?” Mẹ nói: “Mọi người chen nhau vào là rất nguy hiểm. Chúng ta phải xếp hàng và trượt từng người một”.
2. Thực hành xếp hàng trong gia đình. Mẹ đi đầu, con ở giữa, bố ở cuối, xếp hàng để lấy trái cây.
3. Bố mẹ lấy các bức tranh xếp hàng đã sưu tầm được ra và thảo luận với con khi nào cần xếp hàng, như đi xe buýt, rửa tay ở trường mẫu giáo,...

## Hướng dẫn của chuyên gia
- Trong quá trình tập xếp hàng, đừng để trẻ luôn là người xếp hàng đầu tiên. Điều này có thể tạo nền tảng để trẻ thích nghi tốt hơn với môi trường mẫu giáo.
- Bố có thể cố tình mắc lỗi, và sẽ bị đứng sang một bên. Điều này không chỉ khiến trò chơi trở nên thú vị hơn mà còn cho bé biết khi không xếp hàng thì không được tiếp tục đứng trong hàng.

> Hãy xếp hàng!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Tranh ảnh nội dung xếp hàng.', ARRAY['Tranh ảnh nội dung xếp hàng']::text[], '/static/activities/g115/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', 1, 'Mẹ lấy ra một bức ảnh trẻ em đang chơi cầu trượt và hỏi: “Các em này đang làm gì vậy?” Mẹ khuyến khích trẻ nói, rồi hỏi: “Các em đều muốn chơi cầu trượt. Điều gì sẽ xảy ra nếu trẻ chơi cầu trượt? Các em chen vào chơi à?” Mẹ nói: “Mọi người chen nhau vào là rất nguy hiểm. Chúng ta phải xếp hàng và trượt từng người một”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', 2, 'Thực hành xếp hàng trong gia đình. Mẹ đi đầu, con ở giữa, bố ở cuối, xếp hàng để lấy trái cây.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', 3, 'Bố mẹ lấy các bức tranh xếp hàng đã sưu tầm được ra và thảo luận với con khi nào cần xếp hàng, như đi xe buýt, rửa tay ở trường mẫu giáo,...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', 'image', '/static/activities/g115/main.jpg', 'Hãy xếp hàng!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'bdd95ea9-4ddc-5b4c-8a40-ca46c5794d92', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g116: Ghép hình (trang PDF 164)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '14da2d80-112b-5f3c-a22f-9a14e4483704', 'Ghép hình', '“Nhìn xem con đã làm gì này!”', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng thị giác, Sự tập trung

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ.

## Các bước thực hiện
1. Bố mẹ nên in trước các bức tranh màu, mỗi loại 2 bức tranh, dùng kéo cắt một bức tranh thành hai mảnh theo đường thẳng để ghép hình, bức tranh còn lại dùng để tham khảo.
2. Bố mẹ lấy mảnh ghép ô tô ra, ghép hai mảnh lại với nhau và hào hứng nói: “Con đã ghép được một chiếc ô tô rồi!”
3. Bố mẹ lấy ra một câu đố khác mà trẻ thích thú (chẳng hạn như một chiếc máy bay), tách hai nửa trên bàn và nói: “Ghép nó lại với nhau nào!”
4. Nếu trẻ làm được, bố mẹ sẽ nồng nhiệt khen ngợi trẻ: “Con đã chế tạo được một chiếc máy bay! Thật tuyệt vời!” Nếu trẻ không thể hoàn thành được, bố mẹ có thể chỉ vào bức tranh tham khảo và nói: “Nhìn này, đây là một chiếc máy bay”. Bố mẹ cũng có thể giúp điều chỉnh hướng của câu đố để giảm bớt độ khó.

## Hướng dẫn của chuyên gia
- Bạn có thể sử dụng những hình ảnh mà trẻ đã quen thuộc lúc đầu và dần dần chuyển sang những hình ảnh mới lạ.
- Ban đầu, bạn có thể cắt bức tranh thành hai mảnh. Hãy tăng dần số lượng mảnh ghép và thay đổi dần cách mở để tăng độ khó.
- Bạn có thể trực tiếp mua các câu đố tượng trưng cho các đồ vật trong cuộc sống hằng ngày và điều chỉnh độ khó của câu đố tùy theo khả năng của trẻ.

> “Nhìn xem con đã làm gì này!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ.', ARRAY['Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ']::text[], '/static/activities/g116/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng thị giác, Sự tập trung.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('14da2d80-112b-5f3c-a22f-9a14e4483704', 1, 'Bố mẹ nên in trước các bức tranh màu, mỗi loại 2 bức tranh, dùng kéo cắt một bức tranh thành hai mảnh theo đường thẳng để ghép hình, bức tranh còn lại dùng để tham khảo.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('14da2d80-112b-5f3c-a22f-9a14e4483704', 2, 'Bố mẹ lấy mảnh ghép ô tô ra, ghép hai mảnh lại với nhau và hào hứng nói: “Con đã ghép được một chiếc ô tô rồi!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('14da2d80-112b-5f3c-a22f-9a14e4483704', 3, 'Bố mẹ lấy ra một câu đố khác mà trẻ thích thú (chẳng hạn như một chiếc máy bay), tách hai nửa trên bàn và nói: “Ghép nó lại với nhau nào!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('14da2d80-112b-5f3c-a22f-9a14e4483704', 4, 'Nếu trẻ làm được, bố mẹ sẽ nồng nhiệt khen ngợi trẻ: “Con đã chế tạo được một chiếc máy bay! Thật tuyệt vời!” Nếu trẻ không thể hoàn thành được, bố mẹ có thể chỉ vào bức tranh tham khảo và nói: “Nhìn này, đây là một chiếc máy bay”. Bố mẹ cũng có thể giúp điều chỉnh hướng của câu đố để giảm bớt độ khó.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('14da2d80-112b-5f3c-a22f-9a14e4483704', 'image', '/static/activities/g116/main.jpg', '“Nhìn xem con đã làm gì này!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '14da2d80-112b-5f3c-a22f-9a14e4483704', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g117: Sửa lỗi sai (trang PDF 165)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '35b9a175-147f-59a3-bd16-9dd2a38591b4', 'Sửa lỗi sai', 'Tốt nhất là cả bố và mẹ cùng tham gia trò chơi này. Nếu một người không thể sửa lỗi cho con thì người kia có thể nhìn thấy và sửa giúp con.', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng diễn đạt ngôn ngữ

## Chuẩn bị
- **Không gian:** Mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi.
- **Đồ dùng:** Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ.

## Các bước thực hiện
1. Bố mẹ và trẻ ngồi cùng nhau. Bố lấy ra bức tranh vẽ một con vật mà trẻ thích thú. Sau khi chắc chắn rằng trẻ đã chú ý, bố sẽ cố tình nói sai nội dung của bức tranh. Mẹ có trách nhiệm sửa lại lỗi sai. Chẳng hạn, bố lấy ra bức ảnh con vịt và cố tình nói: “Con gà đây! Ò ó o!” Lúc này, mẹ hào hứng chỉ ra: “Sai rồi! Đây là con vịt! Quạc quạc!” Bố nói: “Mẹ nói đúng! Đây là vịt con”.
2. Bố lại lấy ra bức ảnh con vật mà trẻ thích thú. Sau khi chắc chắn rằng trẻ để ý, bố cố tình nói sai hình ảnh, lúc này bố nhìn trẻ đầy mong đợi. Bố mẹ đợi bé sửa lỗi trước, nếu trẻ không sửa được thì mẹ có thể nhẹ nhàng nói cho trẻ nội dung đúng. Nếu trẻ vẫn chưa nói được thì đừng ép trẻ tiếp tục nói đúng nội dung.
3. Khi bố lấy bức tranh tiếp theo ra, mẹ vẫn đợi trẻ sửa lỗi trước khi nhắc trẻ.

## Hướng dẫn của chuyên gia
- Nội dung hình ảnh cũng có thể là trái cây thông thường, rau củ, xe cộ,... trong cuộc sống hằng ngày. Nếu trẻ không hứng thú với các bức tranh, bố mẹ cũng có thể sử dụng đồ chơi để làm phong phú thêm chủ đề này, chẳng hạn như lấy một con búp bê mèo con ra thay vì một bức tranh nhỏ.
- Tùy theo khả năng của trẻ, bố mẹ có thể tăng dần độ khó của nội dung mà trẻ cố tình nói đến.

> Tốt nhất là cả bố và mẹ cùng tham gia trò chơi này. Nếu một người không thể sửa lỗi cho con thì người kia có thể nhìn thấy và sửa giúp con.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ.', ARRAY['Một số hình ảnh mà trẻ thích thú hoặc bố mẹ muốn dạy cho trẻ']::text[], '/static/activities/g117/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng diễn đạt ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('35b9a175-147f-59a3-bd16-9dd2a38591b4', 1, 'Bố mẹ và trẻ ngồi cùng nhau. Bố lấy ra bức tranh vẽ một con vật mà trẻ thích thú. Sau khi chắc chắn rằng trẻ đã chú ý, bố sẽ cố tình nói sai nội dung của bức tranh. Mẹ có trách nhiệm sửa lại lỗi sai. Chẳng hạn, bố lấy ra bức ảnh con vịt và cố tình nói: “Con gà đây! Ò ó o!” Lúc này, mẹ hào hứng chỉ ra: “Sai rồi! Đây là con vịt! Quạc quạc!” Bố nói: “Mẹ nói đúng! Đây là vịt con”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('35b9a175-147f-59a3-bd16-9dd2a38591b4', 2, 'Bố lại lấy ra bức ảnh con vật mà trẻ thích thú. Sau khi chắc chắn rằng trẻ để ý, bố cố tình nói sai hình ảnh, lúc này bố nhìn trẻ đầy mong đợi. Bố mẹ đợi bé sửa lỗi trước, nếu trẻ không sửa được thì mẹ có thể nhẹ nhàng nói cho trẻ nội dung đúng. Nếu trẻ vẫn chưa nói được thì đừng ép trẻ tiếp tục nói đúng nội dung.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('35b9a175-147f-59a3-bd16-9dd2a38591b4', 3, 'Khi bố lấy bức tranh tiếp theo ra, mẹ vẫn đợi trẻ sửa lỗi trước khi nhắc trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('35b9a175-147f-59a3-bd16-9dd2a38591b4', 'image', '/static/activities/g117/main.jpg', 'Tốt nhất là cả bố và mẹ cùng tham gia trò chơi này. Nếu một người không thể sửa lỗi cho con thì người kia có thể nhìn thấy và sửa giúp con.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '35b9a175-147f-59a3-bd16-9dd2a38591b4', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g118: Truy tìm đồ vật (trang PDF 166)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '1896da2e-81b5-540e-93ae-e68a10da38b8', 'Truy tìm đồ vật', 'Trong quá trình chơi, bố mẹ có thể giúp đỡ dựa trên khả năng của trẻ, đồng thời thêm mô tả về các vị trí không gian.', '**Kỹ năng phát triển:** Khả năng ghi nhớ, Khả năng quan sát, Cảm giác không gian

## Chuẩn bị
- **Không gian:** Trong nhà hoặc ngoài trời.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một số đồ chơi nhỏ như ô tô, quả bóng,...

## Các bước thực hiện
1. Bố mẹ chọn một vài món đồ chơi nhỏ mà trẻ thường thích rồi dẫn trẻ đi tìm chỗ giấu. Trong khi trốn, hãy nói với trẻ: “Ô tô đang trốn, trốn dưới gầm giường, trốn, trốn trong hộp!”
2. Sau khi trốn, hãy nói với trẻ: “Bây giờ chúng ta hãy tìm chúng nhé!” Bố mẹ cùng trẻ đi tìm. Bố mẹ có thể đưa ra lời nhắc và giúp đỡ dựa trên hoạt động của trẻ, chẳng hạn như: “Nhìn xem, có cái nào dưới gầm giường không con?”, “Còn gì nữa mà chúng ta chưa tìm thấy không?”, “Hãy nghĩ xem, chiếc xe đang trốn ở đâu?”
3. Khi trẻ tìm thấy đồ chơi, bố mẹ liền nói: “Con giỏi quá! Con đã tìm được chiếc ô tô rồi” và mô tả: “Thì ra chiếc ô tô được giấu trong hộp”.

## Hướng dẫn của chuyên gia
- Trò chơi này tập trung phát triển trí nhớ của trẻ nên bố mẹ cần cho trẻ cơ hội và thời gian để tích cực tìm kiếm, đồng thời để trẻ dẫn dắt bố mẹ cùng nhau tìm kiếm.
- Lúc đầu, bạn có thể giấu 1 - 2 món đồ chơi để trẻ tìm, sau đó tăng dần số lượng đồ chơi giấu, thay đổi vị trí và không giúp đỡ trẻ nữa.
- Hoạt động này cũng có thể được tổ chức ngoài trời để giúp trẻ hiểu khái niệm về không gian trong môi trường tự nhiên và nuôi dưỡng sự gần gũi với thiên nhiên.

> Trong quá trình chơi, bố mẹ có thể giúp đỡ dựa trên khả năng của trẻ, đồng thời thêm mô tả về các vị trí không gian.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Một số đồ chơi nhỏ như ô tô, quả bóng,...', ARRAY['Một số đồ chơi nhỏ như ô tô', 'quả bóng,']::text[], '/static/activities/g118/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng ghi nhớ, Khả năng quan sát, Cảm giác không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1896da2e-81b5-540e-93ae-e68a10da38b8', 1, 'Bố mẹ chọn một vài món đồ chơi nhỏ mà trẻ thường thích rồi dẫn trẻ đi tìm chỗ giấu. Trong khi trốn, hãy nói với trẻ: “Ô tô đang trốn, trốn dưới gầm giường, trốn, trốn trong hộp!”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1896da2e-81b5-540e-93ae-e68a10da38b8', 2, 'Sau khi trốn, hãy nói với trẻ: “Bây giờ chúng ta hãy tìm chúng nhé!” Bố mẹ cùng trẻ đi tìm. Bố mẹ có thể đưa ra lời nhắc và giúp đỡ dựa trên hoạt động của trẻ, chẳng hạn như: “Nhìn xem, có cái nào dưới gầm giường không con?”, “Còn gì nữa mà chúng ta chưa tìm thấy không?”, “Hãy nghĩ xem, chiếc xe đang trốn ở đâu?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1896da2e-81b5-540e-93ae-e68a10da38b8', 3, 'Khi trẻ tìm thấy đồ chơi, bố mẹ liền nói: “Con giỏi quá! Con đã tìm được chiếc ô tô rồi” và mô tả: “Thì ra chiếc ô tô được giấu trong hộp”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('1896da2e-81b5-540e-93ae-e68a10da38b8', 'image', '/static/activities/g118/main.jpg', 'Trong quá trình chơi, bố mẹ có thể giúp đỡ dựa trên khả năng của trẻ, đồng thời thêm mô tả về các vị trí không gian.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '1896da2e-81b5-540e-93ae-e68a10da38b8', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g119: Tạo ra “khuôn mặt” (trang PDF 167)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 'Tạo ra “khuôn mặt”', 'Ngay cả khi bé bấm không chính xác cũng đừng chỉ trích hay chỉ trích bé. Hướng dẫn bé quan sát nhiều hơn, cuối cùng bé sẽ biết bộ phận nào nằm ở đâu.', '**Kỹ năng phát triển:** Khả năng nhận thức, Cảm giác không gian, Tự nhận dạng

## Chuẩn bị
- **Không gian:** Trên bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Vài tờ giấy màu, một chiếc gương.

## Các bước thực hiện
1. Bố mẹ chỉ vào trẻ và nói: “Chúng ta cùng làm một khuôn mặt nhé!” Sau đó, thảo luận với trẻ về các đặc điểm trên khuôn mặt.
2. Bố mẹ đặt những vòng tròn nhỏ và những mảnh giấy có hình dạng khác lên bàn và thảo luận với trẻ về những hình dạng nào có thể sử dụng để thay thế.
3. Đưa cho trẻ một chiếc gương để hướng dẫn trẻ nhìn vào vị trí của mắt, mũi, miệng và chỉ tay để thấy mắt nằm phía trên miệng và mũi ở giữa.
4. Bố mẹ hướng dẫn trẻ xếp các hình tượng trưng cho mắt, mũi, miệng lên giấy.

## Hướng dẫn của chuyên gia
- Bạn cũng có thể sử dụng các cách khác để tạo khuôn mặt, chẳng hạn như vẽ khuôn mặt bằng phấn hoặc ngón tay, hoặc tạo khuôn mặt đơn giản bằng cát nặn thành bột.

> Ngay cả khi bé bấm không chính xác cũng đừng chỉ trích hay chỉ trích bé. Hướng dẫn bé quan sát nhiều hơn, cuối cùng bé sẽ biết bộ phận nào nằm ở đâu.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Vài tờ giấy màu, một chiếc gương.', ARRAY['Vài tờ giấy màu', 'một chiếc gương']::text[], '/static/activities/g119/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Cảm giác không gian, Tự nhận dạng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 1, 'Bố mẹ chỉ vào trẻ và nói: “Chúng ta cùng làm một khuôn mặt nhé!” Sau đó, thảo luận với trẻ về các đặc điểm trên khuôn mặt.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 2, 'Bố mẹ đặt những vòng tròn nhỏ và những mảnh giấy có hình dạng khác lên bàn và thảo luận với trẻ về những hình dạng nào có thể sử dụng để thay thế.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 3, 'Đưa cho trẻ một chiếc gương để hướng dẫn trẻ nhìn vào vị trí của mắt, mũi, miệng và chỉ tay để thấy mắt nằm phía trên miệng và mũi ở giữa.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 4, 'Bố mẹ hướng dẫn trẻ xếp các hình tượng trưng cho mắt, mũi, miệng lên giấy.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c6e8a71d-4bd0-519d-a07f-466c2dc5515f', 'image', '/static/activities/g119/main.jpg', 'Ngay cả khi bé bấm không chính xác cũng đừng chỉ trích hay chỉ trích bé. Hướng dẫn bé quan sát nhiều hơn, cuối cùng bé sẽ biết bộ phận nào nằm ở đâu.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c6e8a71d-4bd0-519d-a07f-466c2dc5515f', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g120: Khăn ăn cho mỗi người (trang PDF 168)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '78e78aeb-f4d8-5574-9399-cfdf67020905', 'Khăn ăn cho mỗi người', 'Một chiếc!', '**Kỹ năng phát triển:** Khả năng nhận thức, Khả năng đếm

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Bé ngồi.
- **Đồ dùng:** Một số khăn ăn và một số đĩa.

## Các bước thực hiện
1. Bố mẹ làm mẫu bằng cách đặt khăn ăn lên đĩa và hướng dẫn trẻ giúp dọn bàn.
2. Bố mẹ đưa cho trẻ đủ khăn ăn và hướng dẫn trẻ đặt khăn ăn lên đĩa. Bố mẹ dùng từ “cái” để mô tả việc trẻ đang làm: “Một cái cho bố, một cái cho mẹ, một cái cho con”.
3. Nếu cuối cùng trẻ thấy không có đủ khăn ăn, bố mẹ có thể giải thích cho trẻ hiểu chuyện gì đã xảy ra và động viên: “Có hai chiếc khăn ăn trên đĩa này, con có thể đặt nó lên đĩa cuối cùng được không? Vậy là mỗi người có một cái. Đây là khăn ăn. Bố mẹ cảm ơn con đã giúp bố mẹ dọn bàn ăn”.

## Hướng dẫn của chuyên gia
- Sau khi lặp lại điều này một vài lần, hãy thử yêu cầu trẻ đếm số lượng khăn ăn và đĩa trên bàn. Giúp trẻ làm quen với số lượng.
- Nếu khăn ăn hoặc đồ dùng khác không đủ, bố mẹ không nên vội vàng giúp bé giải quyết vấn đề. Hãy khuyến khích trẻ cố gắng tự mình giải quyết vấn đề tương tự.

> Một chiếc!

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Một số khăn ăn và một số đĩa.', ARRAY['Một số khăn ăn và một số đĩa']::text[], '/static/activities/g120/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Khả năng đếm.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78e78aeb-f4d8-5574-9399-cfdf67020905', 1, 'Bố mẹ làm mẫu bằng cách đặt khăn ăn lên đĩa và hướng dẫn trẻ giúp dọn bàn.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78e78aeb-f4d8-5574-9399-cfdf67020905', 2, 'Bố mẹ đưa cho trẻ đủ khăn ăn và hướng dẫn trẻ đặt khăn ăn lên đĩa. Bố mẹ dùng từ “cái” để mô tả việc trẻ đang làm: “Một cái cho bố, một cái cho mẹ, một cái cho con”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('78e78aeb-f4d8-5574-9399-cfdf67020905', 3, 'Nếu cuối cùng trẻ thấy không có đủ khăn ăn, bố mẹ có thể giải thích cho trẻ hiểu chuyện gì đã xảy ra và động viên: “Có hai chiếc khăn ăn trên đĩa này, con có thể đặt nó lên đĩa cuối cùng được không? Vậy là mỗi người có một cái. Đây là khăn ăn. Bố mẹ cảm ơn con đã giúp bố mẹ dọn bàn ăn”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('78e78aeb-f4d8-5574-9399-cfdf67020905', 'image', '/static/activities/g120/main.jpg', 'Một chiếc!', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '78e78aeb-f4d8-5574-9399-cfdf67020905', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g121: Khuôn mặt cảm xúc (trang PDF 169)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '104c8531-58ae-5f7c-be35-a6a069433796', 'Khuôn mặt cảm xúc', 'Kỹ năng phát triển: Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ, Thể hiện cảm xúc.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Trên bàn hoặc thảm trải sàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số tranh hoặc ảnh người thật thể hiện niềm vui, nỗi buồn, sự tức giận.

## Các bước thực hiện
1. Đầu tiên, bố mẹ cho trẻ xem một bức ảnh vui vẻ và nói với trẻ: “Con đang cười, con rất vui”. Đồng thời, trẻ cũng có biểu hiện tương tự. Sau đó, cho trẻ xem một bức ảnh buồn và nói: “Con đang khóc, con rất buồn”. Trẻ cũng tỏ ra buồn bã. Tiếp tục lấy ra một bức ảnh tức giận và nói: “Nhìn kìa, con đang giận dữ”. Cuối cùng, lấy bức ảnh sợ hãi ra và nói: “Con đang sợ hãi”.
2. Bố mẹ tỏ vẻ tức giận và khuyến khích trẻ chỉ vào bức tranh có biểu cảm giống bố mẹ và nói các từ tương ứng với biểu cảm đó. Tương tự, thực hiện 3 biểu cảm còn lại để khuyến khích trẻ nhận biết và diễn đạt.

## Hướng dẫn của chuyên gia
- Bố mẹ có thể cùng nhau nhìn biểu cảm của các nhân vật trong tranh để khuyến khích trẻ nhận biết và thể hiện biểu cảm của mình.
- Trong cuộc sống hằng ngày, người ta thường dùng những từ ngữ để mô tả cảm xúc, như: “Mẹ đang tức giận”, “Con đang rất sợ”.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi cảm xúc._', 'play', 24, 30,
       'Một số tranh hoặc ảnh người thật thể hiện niềm vui, nỗi buồn, sự tức giận.', ARRAY['Một số tranh hoặc ảnh người thật thể hiện niềm vui', 'nỗi buồn', 'sự tức giận']::text[], '/static/activities/g121/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('104c8531-58ae-5f7c-be35-a6a069433796', 1, 'Đầu tiên, bố mẹ cho trẻ xem một bức ảnh vui vẻ và nói với trẻ: “Con đang cười, con rất vui”. Đồng thời, trẻ cũng có biểu hiện tương tự. Sau đó, cho trẻ xem một bức ảnh buồn và nói: “Con đang khóc, con rất buồn”. Trẻ cũng tỏ ra buồn bã. Tiếp tục lấy ra một bức ảnh tức giận và nói: “Nhìn kìa, con đang giận dữ”. Cuối cùng, lấy bức ảnh sợ hãi ra và nói: “Con đang sợ hãi”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('104c8531-58ae-5f7c-be35-a6a069433796', 2, 'Bố mẹ tỏ vẻ tức giận và khuyến khích trẻ chỉ vào bức tranh có biểu cảm giống bố mẹ và nói các từ tương ứng với biểu cảm đó. Tương tự, thực hiện 3 biểu cảm còn lại để khuyến khích trẻ nhận biết và diễn đạt.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('104c8531-58ae-5f7c-be35-a6a069433796', 'image', '/static/activities/g121/main.jpg', NULL, 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '104c8531-58ae-5f7c-be35-a6a069433796', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g122: Hãy thể hiện cảm xúc bản thân (trang PDF 170)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '1d13af51-1c24-5130-9b3d-7e679ccd7c97', 'Hãy thể hiện cảm xúc bản thân', 'Cha mẹ nên sử dụng những cử động, biểu cảm có thể để thể hiện những cảm xúc như buồn bã, tự tin để bé ngồi yên.', '**Kỹ năng phát triển:** Kỹ năng xã hội, Rèn luyện trí tưởng tượng, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Không có.

## Các bước thực hiện
1. Cùng trẻ chơi trò chơi “Các con vật nhỏ vào rừng tìm thức ăn”. Mẹ đóng vai thỏ, bố đóng vai hổ lớn, con trẻ đóng vai sóc nhỏ. Thỏ con và sóc nhỏ là bạn tốt của nhau. Mẹ giả vờ vô tình ngã xuống và kêu lên “Áaaa...”
2. Bố mẹ chờ phản ứng của trẻ. Nếu trẻ đến chạm vào chân mẹ hoặc nói “Đừng khóc, đừng khóc”, thì mẹ liền nói: “Cảm ơn con đã an ủi, mẹ đã đỡ hơn nhiều rồi”. Trẻ không phản ứng, mẹ có thể nói: “Mẹ ngã đau quá, con có thể lại đây sờ vào chân mẹ được không?”
3. Thỏ con và sóc nhỏ tiếp tục đi, con hổ lớn do người bố đóng vai đến bắt chúng. Lúc này, mẹ giả vờ sợ hãi: “Ồ, con hổ lớn đang đến, mẹ sợ quá!” Sau đó mẹ chờ đợi phản ứng của trẻ.

## Hướng dẫn của chuyên gia
- Trong cuộc sống hằng ngày, bố mẹ thường có thể mô tả nhiều cảm xúc khác nhau và thể hiện những cảm xúc đó một cách phù hợp.

> Cha mẹ nên sử dụng những cử động, biểu cảm có thể để thể hiện những cảm xúc như buồn bã, tự tin để bé ngồi yên.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi cảm xúc._', 'play', 24, 30,
       'Không có.', NULL, '/static/activities/g122/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Rèn luyện trí tưởng tượng, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1d13af51-1c24-5130-9b3d-7e679ccd7c97', 1, 'Cùng trẻ chơi trò chơi “Các con vật nhỏ vào rừng tìm thức ăn”. Mẹ đóng vai thỏ, bố đóng vai hổ lớn, con trẻ đóng vai sóc nhỏ. Thỏ con và sóc nhỏ là bạn tốt của nhau. Mẹ giả vờ vô tình ngã xuống và kêu lên “Áaaa...”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1d13af51-1c24-5130-9b3d-7e679ccd7c97', 2, 'Bố mẹ chờ phản ứng của trẻ. Nếu trẻ đến chạm vào chân mẹ hoặc nói “Đừng khóc, đừng khóc”, thì mẹ liền nói: “Cảm ơn con đã an ủi, mẹ đã đỡ hơn nhiều rồi”. Trẻ không phản ứng, mẹ có thể nói: “Mẹ ngã đau quá, con có thể lại đây sờ vào chân mẹ được không?”', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('1d13af51-1c24-5130-9b3d-7e679ccd7c97', 3, 'Thỏ con và sóc nhỏ tiếp tục đi, con hổ lớn do người bố đóng vai đến bắt chúng. Lúc này, mẹ giả vờ sợ hãi: “Ồ, con hổ lớn đang đến, mẹ sợ quá!” Sau đó mẹ chờ đợi phản ứng của trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('1d13af51-1c24-5130-9b3d-7e679ccd7c97', 'image', '/static/activities/g122/main.jpg', 'Cha mẹ nên sử dụng những cử động, biểu cảm có thể để thể hiện những cảm xúc như buồn bã, tự tin để bé ngồi yên.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '1d13af51-1c24-5130-9b3d-7e679ccd7c97', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g123: Biết nói lời “cảm ơn” (trang PDF 171)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'b6bc6e82-78cc-55a4-934e-6f7a70433dac', 'Biết nói lời “cảm ơn”', 'Sau khi trẻ đã quen với những tình huống này và có thể nói “cảm ơn”, bố mẹ có thể sử dụng phương pháp tương tự để dạy bé cách chào, cách nói “xin chào”, “xin lỗi”,... Ví dụ: Khi gặp người quen, hãy chủ động chào và nói “xin chào!”; khi người khác rời đi, hãy chủ động nói “tạm biệt!”; khi cần được ai đó giúp đỡ thì dùng “làm ơn”,...', '**Kỹ năng phát triển:** Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ

## Chuẩn bị
- **Không gian:** Trong gia đình.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Táo, sữa,...

## Các bước thực hiện
1. Sau khi bố mẹ hướng dẫn trẻ giúp lấy đồ, bố mẹ bày tỏ lời “cảm ơn” với trẻ bằng biểu cảm. Lặp lại một số mệnh lệnh khác nhau và nói “cảm ơn” khi trẻ giúp đỡ.
2. Bố mẹ thực hiện cách nói “cảm ơn” trước mặt con mình. Ví dụ, mẹ nhờ bố lấy quả táo giúp, bố đưa quả táo cho mẹ và mẹ nói “cảm ơn bố”.
3. Tạo tình huống mẹ giúp trẻ lấy đồ và hướng dẫn trẻ chủ động nói “cảm ơn”.

## Hướng dẫn của chuyên gia
- Bố mẹ nên cho trẻ nhiều cơ hội thực hành trong cuộc sống hằng ngày và giúp trẻ học phép xã giao.
- Nếu trẻ không muốn nói thì cũng đừng ép buộc mà hãy khuyến khích nhiều hơn và cho thêm ví dụ.

> Sau khi trẻ đã quen với những tình huống này và có thể nói “cảm ơn”, bố mẹ có thể sử dụng phương pháp tương tự để dạy bé cách chào, cách nói “xin chào”, “xin lỗi”,... Ví dụ: Khi gặp người quen, hãy chủ động chào và nói “xin chào!”; khi người khác rời đi, hãy chủ động nói “tạm biệt!”; khi cần được ai đó giúp đỡ thì dùng “làm ơn”,...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 24, 30,
       'Táo, sữa,...', ARRAY['Táo', 'sữa,']::text[], '/static/activities/g123/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Kỹ năng diễn đạt ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b6bc6e82-78cc-55a4-934e-6f7a70433dac', 1, 'Sau khi bố mẹ hướng dẫn trẻ giúp lấy đồ, bố mẹ bày tỏ lời “cảm ơn” với trẻ bằng biểu cảm. Lặp lại một số mệnh lệnh khác nhau và nói “cảm ơn” khi trẻ giúp đỡ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b6bc6e82-78cc-55a4-934e-6f7a70433dac', 2, 'Bố mẹ thực hiện cách nói “cảm ơn” trước mặt con mình. Ví dụ, mẹ nhờ bố lấy quả táo giúp, bố đưa quả táo cho mẹ và mẹ nói “cảm ơn bố”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('b6bc6e82-78cc-55a4-934e-6f7a70433dac', 3, 'Tạo tình huống mẹ giúp trẻ lấy đồ và hướng dẫn trẻ chủ động nói “cảm ơn”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('b6bc6e82-78cc-55a4-934e-6f7a70433dac', 'image', '/static/activities/g123/main.jpg', 'Sau khi trẻ đã quen với những tình huống này và có thể nói “cảm ơn”, bố mẹ có thể sử dụng phương pháp tương tự để dạy bé cách chào, cách nói “xin chào”, “xin lỗi”,... Ví dụ: Khi gặp người quen, hãy chủ động chào và nói “xin chào!”; khi người khác rời đi, hãy chủ động nói “tạm biệt!”; khi cần được ai', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'b6bc6e82-78cc-55a4-934e-6f7a70433dac', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g124: Cầu thủ bóng đá tí hon (trang PDF 172, 173)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'Cầu thủ bóng đá tí hon', 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Phối hợp chân, mắt, Khả năng giữ thăng bằng cơ thể, Cảm giác không gian.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Phối hợp chân, mắt, Khả năng giữ thăng bằng cơ thể, Cảm giác không gian

## Chuẩn bị
- **Không gian:** Một nơi có không gian rộng rãi ở nhà.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Một hộp bìa cứng lớn và một quả bóng đá.

## Các bước thực hiện
1. Bố đã chuẩn bị trước một hộp bìa cứng lớn, cắt bỏ một bên để làm “khung thành” và đặt “khung thành” vào tường.
2. Trẻ và bố đứng cùng một phía, đặt quả bóng cách khung thành khoảng 1 m, bố thực hiện đá bóng vào khung thành, rồi nói với trẻ: “Hãy đá vào như bố nhé!”
3. Thực hành nhiều lần cho đến khi trẻ có thể đá được quả bóng vào khung thành. Mỗi lần trẻ đá vào, bố sẽ vỗ tay khen ngợi.
4. Tăng dần độ khó bằng cách đặt bóng cách khung thành khoảng 2 m để nâng cao khả năng sút bóng chính xác của trẻ vào thời điểm này.

## Hướng dẫn của chuyên gia
- Bạn có thể đặt quả bóng ở nhiều góc độ khác nhau và cho trẻ đá vào. Cố gắng để trẻ hoàn thành các hoạt động một mình, có sự khuyến khích của bố.
- Bố và trẻ có thể thay phiên nhau chơi bóng và đưa mắt nhìn nhau để tăng thêm niềm vui.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 30, 36,
       'Một hộp bìa cứng lớn và một quả bóng đá.', ARRAY['Một hộp bìa cứng lớn và một quả bóng đá']::text[], '/static/activities/g124/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Phối hợp chân, mắt, Khả năng giữ thăng bằng cơ thể, Cảm giác không gian.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 1, 'Bố đã chuẩn bị trước một hộp bìa cứng lớn, cắt bỏ một bên để làm “khung thành” và đặt “khung thành” vào tường.', '/static/activities/g124/step-1.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 2, 'Trẻ và bố đứng cùng một phía, đặt quả bóng cách khung thành khoảng 1 m, bố thực hiện đá bóng vào khung thành, rồi nói với trẻ: “Hãy đá vào như bố nhé!”', '/static/activities/g124/step-2.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 3, 'Thực hành nhiều lần cho đến khi trẻ có thể đá được quả bóng vào khung thành. Mỗi lần trẻ đá vào, bố sẽ vỗ tay khen ngợi.', '/static/activities/g124/step-3.jpg');
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 4, 'Tăng dần độ khó bằng cách đặt bóng cách khung thành khoảng 2 m để nâng cao khả năng sút bóng chính xác của trẻ vào thời điểm này.', '/static/activities/g124/step-4.jpg');
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'image', '/static/activities/g124/main.jpg', NULL, 0);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'image', '/static/activities/g124/step-1.jpg', 'Bước 1', 1);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'image', '/static/activities/g124/step-2.jpg', 'Bước 2', 2);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'image', '/static/activities/g124/step-3.jpg', 'Bước 3', 3);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('c74b869d-ce00-5d16-ae09-f76ec0d43f87', 'image', '/static/activities/g124/step-4.jpg', 'Bước 4', 4);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'c74b869d-ce00-5d16-ae09-f76ec0d43f87', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g125: Rùa và Thỏ (trang PDF 174)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', 'Rùa và Thỏ', 'Khuyến cáo bố mẹ nên bò chậm hơn trong vòng đầu tiên để trẻ giành chiến thắng và tạo cho trẻ sự tự tin. Khi chơi lại, bạn có thể để trẻ tự lựa chọn nhân vật của mình.', '**Kỹ năng phát triển:** Khả năng thể thao tuyệt vời, Sức mạnh cơ bắp, Khả năng phối hợp cơ thể

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Trẻ đứng.
- **Đồ dùng:** Một cuộn băng dính màu, một cái gối và vài miếng dán.

## Các bước thực hiện
1. Dùng băng dính màu dán hai đường trên mặt đất để tượng trưng cho điểm bắt đầu và điểm kết thúc. Bố mẹ đóng vai con rùa và nói với trẻ: “Bố mẹ đóng vai con rùa. Con cần ôm mai rùa (cái đệm) và bò qua. Trẻ đóng vai con thỏ với đôi tai nhỏ vểnh lên. Hãy thi xem ai về đích trước nhé!” Bố mẹ đếm “một, hai, ba” rồi cùng trẻ xuất phát.
2. Bố mẹ ôm gối trên lưng và leo về đích. Trong quá trình thực hiện, trẻ sẽ đóng vai thỏ và đặt hai tay lên đầu để giả vờ thỏ nhảy liên tục về đích.
3. Người về đích đầu tiên sẽ được thưởng một nhãn dán.

## Hướng dẫn của chuyên gia
- Bố mẹ nên kể cho trẻ nghe câu chuyện “Rùa và Thỏ” trước, sau đó chơi trò chơi này, hiệu quả sẽ tốt hơn!
- Bố mẹ cần chậm rãi hơn khi đưa ra các quy tắc và sử dụng hành động để giúp trẻ hiểu.

> Khuyến cáo bố mẹ nên bò chậm hơn trong vòng đầu tiên để trẻ giành chiến thắng và tạo cho trẻ sự tự tin. Khi chơi lại, bạn có thể để trẻ tự lựa chọn nhân vật của mình.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động thô._', 'play', 30, 36,
       'Một cuộn băng dính màu, một cái gối và vài miếng dán.', ARRAY['Một cuộn băng dính màu', 'một cái gối và vài miếng dán']::text[], '/static/activities/g125/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'gross_motor'), 'Kỹ năng phát triển: Khả năng thể thao tuyệt vời, Sức mạnh cơ bắp, Khả năng phối hợp cơ thể.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', 1, 'Dùng băng dính màu dán hai đường trên mặt đất để tượng trưng cho điểm bắt đầu và điểm kết thúc. Bố mẹ đóng vai con rùa và nói với trẻ: “Bố mẹ đóng vai con rùa. Con cần ôm mai rùa (cái đệm) và bò qua. Trẻ đóng vai con thỏ với đôi tai nhỏ vểnh lên. Hãy thi xem ai về đích trước nhé!” Bố mẹ đếm “một, hai, ba” rồi cùng trẻ xuất phát.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', 2, 'Bố mẹ ôm gối trên lưng và leo về đích. Trong quá trình thực hiện, trẻ sẽ đóng vai thỏ và đặt hai tay lên đầu để giả vờ thỏ nhảy liên tục về đích.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', 3, 'Người về đích đầu tiên sẽ được thưởng một nhãn dán.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', 'image', '/static/activities/g125/main.jpg', 'Khuyến cáo bố mẹ nên bò chậm hơn trong vòng đầu tiên để trẻ giành chiến thắng và tạo cho trẻ sự tự tin. Khi chơi lại, bạn có thể để trẻ tự lựa chọn nhân vật của mình.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '3cd4f24e-6150-50c3-bdaf-eaf1a438e88a', id FROM criteria.developmental_domains WHERE code IN ('gross_motor');

-- g126: Bé có thể làm (trang PDF 175)
-- Cần duyệt: Trang scan bị cắt mất nửa trái (phần Chuẩn bị, Hướng dẫn chuyên gia, một phần tên kỹ năng).
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'bec2dc6e-a4b9-58b1-b8eb-c35a53e26fc6', 'Bé có thể làm', 'Bố mẹ dặn trẻ trước khi rửa tay: “Rửa tay đi con!”, sau đó mô tả quá trình rửa tay như: “vặn vòi”, “làm ướt tay”, “nhấn vòi để lấy nước rửa tay”, “đưa tay vào”,... Quá trình thay quần áo còn được miêu tả bằng những từ ngữ như: “nhặt quần áo lên”, “kéo khóa lên”,...', '**Kỹ năng phát triển:** Khả năng tự chăm sóc, Sự tự tin

## Các bước thực hiện
1. Bố mẹ đưa trẻ đến bồn rửa và thực hiện các bước xắn tay áo, mở vòi, rửa tay, thoa nước rửa tay, xả và tắt vòi. Khuyến khích trẻ làm theo sự hướng dẫn và thực hành của bố mẹ. Nếu gặp khó khăn, bố mẹ có thể đưa ra sự hỗ trợ phù hợp.
2. Bố mẹ hướng dẫn các bước mặc quần áo và khuyến khích trẻ làm theo. Nếu gặp khó khăn, bố mẹ có thể đưa ra sự hỗ trợ phù hợp.

> Bố mẹ dặn trẻ trước khi rửa tay: “Rửa tay đi con!”, sau đó mô tả quá trình rửa tay như: “vặn vòi”, “làm ướt tay”, “nhấn vòi để lấy nước rửa tay”, “đưa tay vào”,... Quá trình thay quần áo còn được miêu tả bằng những từ ngữ như: “nhặt quần áo lên”, “kéo khóa lên”,...

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi tự chăm sóc._', 'play', 30, 36,
       NULL, NULL, '/static/activities/g126/main.jpg', 'draft', NULL,
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng tự chăm sóc, Sự tự tin.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bec2dc6e-a4b9-58b1-b8eb-c35a53e26fc6', 1, 'Bố mẹ đưa trẻ đến bồn rửa và thực hiện các bước xắn tay áo, mở vòi, rửa tay, thoa nước rửa tay, xả và tắt vòi. Khuyến khích trẻ làm theo sự hướng dẫn và thực hành của bố mẹ. Nếu gặp khó khăn, bố mẹ có thể đưa ra sự hỗ trợ phù hợp.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('bec2dc6e-a4b9-58b1-b8eb-c35a53e26fc6', 2, 'Bố mẹ hướng dẫn các bước mặc quần áo và khuyến khích trẻ làm theo. Nếu gặp khó khăn, bố mẹ có thể đưa ra sự hỗ trợ phù hợp.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('bec2dc6e-a4b9-58b1-b8eb-c35a53e26fc6', 'image', '/static/activities/g126/main.jpg', 'Bố mẹ dặn trẻ trước khi rửa tay: “Rửa tay đi con!”, sau đó mô tả quá trình rửa tay như: “vặn vòi”, “làm ướt tay”, “nhấn vòi để lấy nước rửa tay”, “đưa tay vào”,... Quá trình thay quần áo còn được miêu tả bằng những từ ngữ như: “nhặt quần áo lên”, “kéo khóa lên”,...', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'bec2dc6e-a4b9-58b1-b8eb-c35a53e26fc6', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g127: Gấp giấy (trang PDF 176)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '53db1c68-9f7f-5325-8130-f1933289d6f5', 'Gấp giấy', 'Trẻ ở giai đoạn này chưa thể gấp được những sản phẩm đẹp nên bố mẹ không cần đặt ra yêu cầu quá cao.', '**Kỹ năng phát triển:** Kỹ năng vận động tinh, Khả năng phối hợp tay, Khả năng phối hợp tay, mắt

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một số giấy màu.

## Các bước thực hiện
1. Bố mẹ gấp một chiếc máy bay giấy trước mặt trẻ và cho trẻ biết rằng có thể làm những đồ chơi thú vị từ giấy.
2. Bố mẹ lấy ra hai tờ giấy màu, cho trẻ một tờ và dạy trẻ cách gấp đôi đơn giản, đồng thời nói: “Con hãy lật tờ giấy lại như thế này, chỉnh các cạnh rồi dùng tay ấn vào”. Chỉ cần trẻ cố gắng làm, bố mẹ nên nhiệt tình khen ngợi và giúp trẻ chỉnh sửa các nếp nhăn của giấy.
3. Bố mẹ và trẻ cùng xếp lại với nhau để cùng tiến bộ. Khi bố mẹ nhận thấy trẻ khó duy trì được hứng thú thì có thể tăng tốc độ gấp máy bay, cho trẻ chơi và thử gấp giấy vào lần sau.

## Hướng dẫn của chuyên gia
- Khi bố mẹ gấp giấy, bố mẹ cũng cần luôn chú ý đến biểu cảm của trẻ, giúp đỡ trẻ kịp thời và phát hiện kịp thời sự mất tập trung của trẻ.
- Trẻ ở giai đoạn này chỉ có thể gấp 2 - 3 bước. Khi mới gấp giấy, bố mẹ có thể cho trẻ tham gia 2 - 3 bước đầu tiên hoặc cho trẻ tham gia 2 - 3 bước cuối cùng.

> Trẻ ở giai đoạn này chưa thể gấp được những sản phẩm đẹp nên bố mẹ không cần đặt ra yêu cầu quá cao.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi vận động tinh._', 'play', 30, 36,
       'Một số giấy màu.', ARRAY['Một số giấy màu']::text[], '/static/activities/g127/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'fine_motor'), 'Kỹ năng phát triển: Kỹ năng vận động tinh, Khả năng phối hợp tay, Khả năng phối hợp tay, mắt.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('53db1c68-9f7f-5325-8130-f1933289d6f5', 1, 'Bố mẹ gấp một chiếc máy bay giấy trước mặt trẻ và cho trẻ biết rằng có thể làm những đồ chơi thú vị từ giấy.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('53db1c68-9f7f-5325-8130-f1933289d6f5', 2, 'Bố mẹ lấy ra hai tờ giấy màu, cho trẻ một tờ và dạy trẻ cách gấp đôi đơn giản, đồng thời nói: “Con hãy lật tờ giấy lại như thế này, chỉnh các cạnh rồi dùng tay ấn vào”. Chỉ cần trẻ cố gắng làm, bố mẹ nên nhiệt tình khen ngợi và giúp trẻ chỉnh sửa các nếp nhăn của giấy.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('53db1c68-9f7f-5325-8130-f1933289d6f5', 3, 'Bố mẹ và trẻ cùng xếp lại với nhau để cùng tiến bộ. Khi bố mẹ nhận thấy trẻ khó duy trì được hứng thú thì có thể tăng tốc độ gấp máy bay, cho trẻ chơi và thử gấp giấy vào lần sau.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('53db1c68-9f7f-5325-8130-f1933289d6f5', 'image', '/static/activities/g127/main.jpg', 'Trẻ ở giai đoạn này chưa thể gấp được những sản phẩm đẹp nên bố mẹ không cần đặt ra yêu cầu quá cao.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '53db1c68-9f7f-5325-8130-f1933289d6f5', id FROM criteria.developmental_domains WHERE code IN ('fine_motor');

-- g128: Đoán xem là ai? (trang PDF 177)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'ffbf322b-8594-5754-8837-849f70c8037c', 'Đoán xem là ai?', 'Khi bố mẹ đóng vai các nhân vật khác nhau, hành động của mình phải làm nổi bật đặc điểm nghề nghiệp.', '**Kỹ năng phát triển:** Khả năng hiểu ngôn ngữ, Khả năng nhận thức

## Chuẩn bị
- **Không gian:** Trên mặt bàn hoặc thảm trải sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một bộ đồ chơi đặc trưng cho các ngành nghề khác nhau (gồm nồi và thìa đồ chơi đầu bếp, ống nghe của bác sĩ, ống tiêm của y tá, mũ cảnh sát, mũi chú hề,...).

## Các bước thực hiện
1. Bố mẹ nói với trẻ: “Hôm nay, chúng ta sẽ chơi một trò chơi tên là “Bố mẹ sẽ biểu diễn và con đoán”. Mẹ sẽ đóng vai những người khác nhau bên dưới, hãy đoán xem mẹ là ai nhé!” Trong khi mẹ nấu ăn, hãy hỏi lần lượt: “Mẹ đang làm gì?” và “Đoán xem mẹ làm gì?” Dù trẻ có đoán đúng hay không thì bố mẹ cũng sẽ nói: “Mẹ là đầu bếp và mẹ đang nấu ăn”.
2. Bố mẹ lấy ra những đồ chơi có đặc điểm nghề nghiệp khác nhau hoặc thực hiện các động tác đặc trưng, sau đó cho trẻ đoán xem bố mẹ đang làm gì trước, sau đó kể lại nghề nghiệp tương ứng. Nếu trẻ không đoán được, bố mẹ có thể sử dụng lời nhắc bằng lời như “Mẹ là...”, “Em bé được tiêm thuốc”, “Mẹ đang bán thứ gì đó”,...
3. Bố mẹ có thể thay phiên nhau giả vờ và đoán mò cùng trẻ.

## Hướng dẫn của chuyên gia
- Sau khi bố mẹ hỏi “Bố mẹ đang làm gì”, cần đợi 3 giây để trẻ có thời gian suy nghĩ. Nếu trẻ trả lời đúng thì tiếp tục đoán xem bố mẹ là ai. Nếu trẻ vẫn không trả lời đúng sau khi được nhắc, bố mẹ cần cho biết mình đang làm gì rồi hỏi trẻ “Đoán xem bố mẹ là ai?”

> Khi bố mẹ đóng vai các nhân vật khác nhau, hành động của mình phải làm nổi bật đặc điểm nghề nghiệp.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 30, 36,
       'Một bộ đồ chơi đặc trưng cho các ngành nghề khác nhau (gồm nồi và thìa đồ chơi đầu bếp, ống nghe của bác sĩ, ống tiêm của y tá, mũ cảnh sát, mũi chú hề,...).', ARRAY['Một bộ đồ chơi đặc trưng cho các ngành nghề khác nhau (gồm nồi và thìa đồ chơi đầu bếp', 'ống nghe của bác sĩ', 'ống tiêm của y tá', 'mũ cảnh sát', 'mũi chú hề,...)']::text[], '/static/activities/g128/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng hiểu ngôn ngữ, Khả năng nhận thức.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ffbf322b-8594-5754-8837-849f70c8037c', 1, 'Bố mẹ nói với trẻ: “Hôm nay, chúng ta sẽ chơi một trò chơi tên là “Bố mẹ sẽ biểu diễn và con đoán”. Mẹ sẽ đóng vai những người khác nhau bên dưới, hãy đoán xem mẹ là ai nhé!” Trong khi mẹ nấu ăn, hãy hỏi lần lượt: “Mẹ đang làm gì?” và “Đoán xem mẹ làm gì?” Dù trẻ có đoán đúng hay không thì bố mẹ cũng sẽ nói: “Mẹ là đầu bếp và mẹ đang nấu ăn”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ffbf322b-8594-5754-8837-849f70c8037c', 2, 'Bố mẹ lấy ra những đồ chơi có đặc điểm nghề nghiệp khác nhau hoặc thực hiện các động tác đặc trưng, sau đó cho trẻ đoán xem bố mẹ đang làm gì trước, sau đó kể lại nghề nghiệp tương ứng. Nếu trẻ không đoán được, bố mẹ có thể sử dụng lời nhắc bằng lời như “Mẹ là...”, “Em bé được tiêm thuốc”, “Mẹ đang bán thứ gì đó”,...', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('ffbf322b-8594-5754-8837-849f70c8037c', 3, 'Bố mẹ có thể thay phiên nhau giả vờ và đoán mò cùng trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('ffbf322b-8594-5754-8837-849f70c8037c', 'image', '/static/activities/g128/main.jpg', 'Khi bố mẹ đóng vai các nhân vật khác nhau, hành động của mình phải làm nổi bật đặc điểm nghề nghiệp.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'ffbf322b-8594-5754-8837-849f70c8037c', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g129: Một ngày sinh hoạt của bé (trang PDF 178)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'e4f23110-fe1b-542e-b259-9fe36d64077b', 'Một ngày sinh hoạt của bé', 'Chọn những việc để bé làm thường xuyên và điều quan trọng là sắp xếp chúng một cách có trật tự.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức, Khả năng tự chăm sóc

## Chuẩn bị
- **Không gian:** Trong gia đình.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một biểu đồ sinh hoạt tự làm.

## Các bước thực hiện
1. Bố mẹ dán biểu đồ cuộc sống hằng ngày của trẻ vào khu vực hoạt động của trẻ, trong đó thể hiện một số việc trẻ cần làm sau khi thức dậy vào buổi sáng như mặc quần áo, đi vệ sinh, đánh răng, rửa mặt, ăn sáng, và một số việc trẻ cần làm khi trời tối như rửa mặt, đi vệ sinh, rửa chân, thay quần áo và đi ngủ.
2. Bố mẹ hướng dẫn trẻ nhìn vào biểu đồ, trước tiên cho trẻ nói những gì trên biểu đồ, sau đó giúp trẻ nói từng từ một để mô tả việc cần làm. Bố mẹ tập trung nói các từ chỉ thời gian và trình tự, chẳng hạn như “Trời đã sáng, trời đã sáng và em bé sắp dậy”.
3. Khuyến khích và hướng dẫn trẻ thuật lại một loạt sự kiện trên biểu đồ.
4. Tách các gợi ý trong biểu đồ và để trẻ mô tả trực tiếp những việc trẻ nên làm sau khi thức dậy vào buổi sáng.

## Hướng dẫn của chuyên gia
- Khi trẻ có thể nói được nội dung trên hình thì bắt đầu chơi trò chơi này.
- Bố mẹ có thể tự lập biểu đồ mô tả các sự kiện.

> Chọn những việc để bé làm thường xuyên và điều quan trọng là sắp xếp chúng một cách có trật tự.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 30, 36,
       'Một biểu đồ sinh hoạt tự làm.', ARRAY['Một biểu đồ sinh hoạt tự làm']::text[], '/static/activities/g129/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức, Khả năng tự chăm sóc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4f23110-fe1b-542e-b259-9fe36d64077b', 1, 'Bố mẹ dán biểu đồ cuộc sống hằng ngày của trẻ vào khu vực hoạt động của trẻ, trong đó thể hiện một số việc trẻ cần làm sau khi thức dậy vào buổi sáng như mặc quần áo, đi vệ sinh, đánh răng, rửa mặt, ăn sáng, và một số việc trẻ cần làm khi trời tối như rửa mặt, đi vệ sinh, rửa chân, thay quần áo và đi ngủ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4f23110-fe1b-542e-b259-9fe36d64077b', 2, 'Bố mẹ hướng dẫn trẻ nhìn vào biểu đồ, trước tiên cho trẻ nói những gì trên biểu đồ, sau đó giúp trẻ nói từng từ một để mô tả việc cần làm. Bố mẹ tập trung nói các từ chỉ thời gian và trình tự, chẳng hạn như “Trời đã sáng, trời đã sáng và em bé sắp dậy”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4f23110-fe1b-542e-b259-9fe36d64077b', 3, 'Khuyến khích và hướng dẫn trẻ thuật lại một loạt sự kiện trên biểu đồ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('e4f23110-fe1b-542e-b259-9fe36d64077b', 4, 'Tách các gợi ý trong biểu đồ và để trẻ mô tả trực tiếp những việc trẻ nên làm sau khi thức dậy vào buổi sáng.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('e4f23110-fe1b-542e-b259-9fe36d64077b', 'image', '/static/activities/g129/main.jpg', 'Chọn những việc để bé làm thường xuyên và điều quan trọng là sắp xếp chúng một cách có trật tự.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'e4f23110-fe1b-542e-b259-9fe36d64077b', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g130: Rửa tay sạch sẽ (trang PDF 179)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'dfef5cd2-581a-5510-a974-a245a1a244eb', 'Rửa tay sạch sẽ', 'Khi trẻ nói, bố mẹ nên lắng nghe kỹ rồi dùng từ nối để hoàn thiện, nhưng không nên ép trẻ lặp lại những gì người lớn nói.', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức, Rèn luyện trí tưởng tượng

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một khăn, một chai nước rửa tay rỗng.

## Các bước thực hiện
1. Bố mẹ nói với trẻ: “Chúng ta chơi trò giả vờ rửa tay nhé!” Bố mẹ tạo hình vuông trước mặt trẻ: “Đây là bồn rửa, đây là vòi nước. Chúng ta học cách rửa tay nhé!” Bố mẹ hướng dẫn trẻ trong khi nói.
2. Nếu trẻ không phản ứng, bố mẹ có thể nhắc: “Đầu tiên...” và đợi trẻ nói tiếp: “Đầu tiên, hãy mở vòi, rửa tay, bóp nước rửa tay, xoa và rửa tay”. Bố mẹ theo dõi trẻ thực hiện các động tác, đồng thời sử dụng các từ nối để hoàn thành lời nói của trẻ: “Ồ, đầu tiên hãy bật vòi, rửa tay, sau đó lấy nước rửa tay ra, sau đó xoa tay và cuối cùng rửa sạch”.
3. Thảo luận với trẻ câu hỏi: “Điều gì sẽ xảy ra nếu...”, chẳng hạn như: “Điều gì sẽ xảy ra nếu con không biết mở chai nước rửa tay?”, “Nếu con không dùng nước rửa tay để rửa thì có sao không?”,...

## Hướng dẫn của chuyên gia
- Nếu trẻ nói sai thứ tự, bố mẹ không nên sửa ngay mà có thể hỏi những câu hỏi “nếu như...” để kích thích trẻ tự suy nghĩ và giúp trẻ dần dần hiểu rằng một số việc phải xảy ra trước tiên.

> Khi trẻ nói, bố mẹ nên lắng nghe kỹ rồi dùng từ nối để hoàn thiện, nhưng không nên ép trẻ lặp lại những gì người lớn nói.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 30, 36,
       'Một khăn, một chai nước rửa tay rỗng.', ARRAY['Một khăn', 'một chai nước rửa tay rỗng']::text[], '/static/activities/g130/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Khả năng nhận thức, Rèn luyện trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfef5cd2-581a-5510-a974-a245a1a244eb', 1, 'Bố mẹ nói với trẻ: “Chúng ta chơi trò giả vờ rửa tay nhé!” Bố mẹ tạo hình vuông trước mặt trẻ: “Đây là bồn rửa, đây là vòi nước. Chúng ta học cách rửa tay nhé!” Bố mẹ hướng dẫn trẻ trong khi nói.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfef5cd2-581a-5510-a974-a245a1a244eb', 2, 'Nếu trẻ không phản ứng, bố mẹ có thể nhắc: “Đầu tiên...” và đợi trẻ nói tiếp: “Đầu tiên, hãy mở vòi, rửa tay, bóp nước rửa tay, xoa và rửa tay”. Bố mẹ theo dõi trẻ thực hiện các động tác, đồng thời sử dụng các từ nối để hoàn thành lời nói của trẻ: “Ồ, đầu tiên hãy bật vòi, rửa tay, sau đó lấy nước rửa tay ra, sau đó xoa tay và cuối cùng rửa sạch”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('dfef5cd2-581a-5510-a974-a245a1a244eb', 3, 'Thảo luận với trẻ câu hỏi: “Điều gì sẽ xảy ra nếu...”, chẳng hạn như: “Điều gì sẽ xảy ra nếu con không biết mở chai nước rửa tay?”, “Nếu con không dùng nước rửa tay để rửa thì có sao không?”,...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('dfef5cd2-581a-5510-a974-a245a1a244eb', 'image', '/static/activities/g130/main.jpg', 'Khi trẻ nói, bố mẹ nên lắng nghe kỹ rồi dùng từ nối để hoàn thiện, nhưng không nên ép trẻ lặp lại những gì người lớn nói.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'dfef5cd2-581a-5510-a974-a245a1a244eb', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g131: Kể câu chuyện về gia đình chúng ta (trang PDF 180)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '8e5dc006-8667-54aa-aba0-d5b82d0643a1', 'Kể câu chuyện về gia đình chúng ta', '“Chúng ta sẽ sáng tác chuyện!”', '**Kỹ năng phát triển:** Khả năng diễn đạt ngôn ngữ, Tăng cường trí tưởng tượng

## Chuẩn bị
- **Không gian:** Không có yêu cầu đặc biệt.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Ảnh các thành viên trong gia đình và bạn bè, một số que kem.

## Các bước thực hiện
1. Bố mẹ cắt ảnh của các thành viên trong gia đình và bạn bè và dán chúng lên que kem để làm búp bê. Yêu cầu trẻ cho bạn biết những người trên những con búp bê này là ai và nói với trẻ: “Hôm nay, chúng ta sẽ chơi trò chơi nói chuyện với búp bê”.
2. Bố mẹ làm mẫu trước tiên, cầm con búp bê tượng trưng cho mình và nói: “À, hôm nay thời tiết đẹp quá, mẹ có thể đưa con ra ngoài chơi.” Sau đó bố mẹ đến gần búp bê của trẻ và nói: “Con ơi, mình ra ngoài chơi nhé!” Khuyến khích trẻ di chuyển búp bê và cùng nhau tham gia hoạt động với bố mẹ.
3. Trong quá trình này, bố mẹ có thể đặt câu hỏi cho trẻ và khuyến khích trẻ sáng tạo cốt truyện tiếp theo. Ví dụ: “Con sẽ làm gì tiếp theo?”, “Con sẽ cảm thấy thế nào nếu con làm điều này?” Khuyến khích con bạn trở thành nhân vật chính và tạo ra câu chuyện của riêng mình.

## Hướng dẫn của chuyên gia
- Truyện có thể chứa một số nội dung có thật và nội dung tưởng tượng.
- Việc sáng tạo ra những câu chuyện sẽ giúp trẻ hiểu rõ hơn về những câu chuyện mình đọc sau này.

> “Chúng ta sẽ sáng tác chuyện!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi ngôn ngữ._', 'play', 30, 36,
       'Ảnh các thành viên trong gia đình và bạn bè, một số que kem.', ARRAY['Ảnh các thành viên trong gia đình và bạn bè', 'một số que kem']::text[], '/static/activities/g131/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'language'), 'Kỹ năng phát triển: Khả năng diễn đạt ngôn ngữ, Tăng cường trí tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8e5dc006-8667-54aa-aba0-d5b82d0643a1', 1, 'Bố mẹ cắt ảnh của các thành viên trong gia đình và bạn bè và dán chúng lên que kem để làm búp bê. Yêu cầu trẻ cho bạn biết những người trên những con búp bê này là ai và nói với trẻ: “Hôm nay, chúng ta sẽ chơi trò chơi nói chuyện với búp bê”.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8e5dc006-8667-54aa-aba0-d5b82d0643a1', 2, 'Bố mẹ làm mẫu trước tiên, cầm con búp bê tượng trưng cho mình và nói: “À, hôm nay thời tiết đẹp quá, mẹ có thể đưa con ra ngoài chơi.” Sau đó bố mẹ đến gần búp bê của trẻ và nói: “Con ơi, mình ra ngoài chơi nhé!” Khuyến khích trẻ di chuyển búp bê và cùng nhau tham gia hoạt động với bố mẹ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('8e5dc006-8667-54aa-aba0-d5b82d0643a1', 3, 'Trong quá trình này, bố mẹ có thể đặt câu hỏi cho trẻ và khuyến khích trẻ sáng tạo cốt truyện tiếp theo. Ví dụ: “Con sẽ làm gì tiếp theo?”, “Con sẽ cảm thấy thế nào nếu con làm điều này?” Khuyến khích con bạn trở thành nhân vật chính và tạo ra câu chuyện của riêng mình.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('8e5dc006-8667-54aa-aba0-d5b82d0643a1', 'image', '/static/activities/g131/main.jpg', '“Chúng ta sẽ sáng tác chuyện!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '8e5dc006-8667-54aa-aba0-d5b82d0643a1', id FROM criteria.developmental_domains WHERE code IN ('language');

-- g132: Những đồ chơi bị thiếu (trang PDF 181)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT 'db527b3a-c74a-57bc-89cf-2932bf5f91d0', 'Những đồ chơi bị thiếu', '“Hãy nói món đồ chơi nào bị thiếu con nhé!”', '**Kỹ năng phát triển:** Khả năng ghi nhớ, Khả năng quan sát, Khả năng diễn đạt ngôn ngữ

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Một vài đồ chơi, một mảnh vải hoặc khăn tắm.

## Các bước thực hiện
1. Bố mẹ đặt ba món đồ chơi lên bàn và để trẻ nhớ trên bàn có những đồ chơi nào.
2. Bố mẹ bọc đồ chơi bằng một mảnh vải hoặc khăn tắm rồi yêu cầu trẻ quay lưng lại với đồ chơi.
3. Sau khi bố mẹ lén lấy đồ chơi đi, hãy yêu cầu trẻ lật đồ chơi lại, mở ra, xem và nói xem đồ chơi nào bị thiếu.

## Hướng dẫn của chuyên gia
- Tổng số đồ chơi có thể điều chỉnh theo khả năng của trẻ. Càng nhiều đồ chơi, độ khó càng lớn. Có thể điều chỉnh số lượng đồ chơi lấy đi càng nhiều thì độ khó càng lớn.
- Trẻ cũng có thể tìm kiếm những đồ vật còn thiếu trên giường, trong tủ, trong tủ lạnh,...
- Những vật dụng bị thiếu có thể là đồ chơi, thực phẩm, nhu yếu phẩm hằng ngày,...

> “Hãy nói món đồ chơi nào bị thiếu con nhé!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 30, 36,
       'Một vài đồ chơi, một mảnh vải hoặc khăn tắm.', ARRAY['Một vài đồ chơi', 'một mảnh vải hoặc khăn tắm']::text[], '/static/activities/g132/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng ghi nhớ, Khả năng quan sát, Khả năng diễn đạt ngôn ngữ.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('db527b3a-c74a-57bc-89cf-2932bf5f91d0', 1, 'Bố mẹ đặt ba món đồ chơi lên bàn và để trẻ nhớ trên bàn có những đồ chơi nào.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('db527b3a-c74a-57bc-89cf-2932bf5f91d0', 2, 'Bố mẹ bọc đồ chơi bằng một mảnh vải hoặc khăn tắm rồi yêu cầu trẻ quay lưng lại với đồ chơi.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('db527b3a-c74a-57bc-89cf-2932bf5f91d0', 3, 'Sau khi bố mẹ lén lấy đồ chơi đi, hãy yêu cầu trẻ lật đồ chơi lại, mở ra, xem và nói xem đồ chơi nào bị thiếu.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('db527b3a-c74a-57bc-89cf-2932bf5f91d0', 'image', '/static/activities/g132/main.jpg', '“Hãy nói món đồ chơi nào bị thiếu con nhé!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT 'db527b3a-c74a-57bc-89cf-2932bf5f91d0', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g133: Xâu vòng cổ (trang PDF 182)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '06b27b21-d4a7-544e-a9b9-ac02446f2618', 'Xâu vòng cổ', '“Con đã bao giờ nhìn thấy một chiếc vòng cổ như thế này chưa?”', '**Kỹ năng phát triển:** Khả năng thị giác, Khả năng nhận thức, Kỹ năng vận động tinh

## Chuẩn bị
- **Không gian:** Trên mặt bàn.
- **Tư thế:** Trẻ ngồi quay mặt về phía bố mẹ.
- **Đồ dùng:** Vài mảnh được cắt từ ống hút xanh, đỏ và một sợi dây.

## Các bước thực hiện
1. Bố mẹ nói với trẻ: “Chúng ta hãy làm một chiếc vòng cổ nhé!” Bố mẹ thực hiện xâu chuỗi các ống hút màu đỏ trước tiên, sau đó đến các ống hút màu xanh lá cây và xâu chuỗi chúng theo thứ tự.
2. Bố mẹ khuyến khích trẻ xâu ống hút theo thứ tự. Lúc đầu, bố mẹ có thể gợi ý: “Đầu tiên xâu màu đỏ, sau đó đến màu xanh, sau đó là màu đỏ. Tiếp theo là gì con nhỉ?” Nếu trẻ xâu dây theo đúng thứ tự, hãy khen ngợi trẻ.

## Hướng dẫn của chuyên gia
- Khi khả năng của trẻ tăng lên, các loại ống hút có màu sắc có thể tăng lên.
- Loại trò chơi sắp xếp này có thể được mở rộng sang các loại trò chơi khác.

> “Con đã bao giờ nhìn thấy một chiếc vòng cổ như thế này chưa?”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 30, 36,
       'Vài mảnh được cắt từ ống hút xanh, đỏ và một sợi dây.', ARRAY['Vài mảnh được cắt từ ống hút xanh', 'đỏ và một sợi dây']::text[], '/static/activities/g133/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng thị giác, Khả năng nhận thức, Kỹ năng vận động tinh.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('06b27b21-d4a7-544e-a9b9-ac02446f2618', 1, 'Bố mẹ nói với trẻ: “Chúng ta hãy làm một chiếc vòng cổ nhé!” Bố mẹ thực hiện xâu chuỗi các ống hút màu đỏ trước tiên, sau đó đến các ống hút màu xanh lá cây và xâu chuỗi chúng theo thứ tự.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('06b27b21-d4a7-544e-a9b9-ac02446f2618', 2, 'Bố mẹ khuyến khích trẻ xâu ống hút theo thứ tự. Lúc đầu, bố mẹ có thể gợi ý: “Đầu tiên xâu màu đỏ, sau đó đến màu xanh, sau đó là màu đỏ. Tiếp theo là gì con nhỉ?” Nếu trẻ xâu dây theo đúng thứ tự, hãy khen ngợi trẻ.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('06b27b21-d4a7-544e-a9b9-ac02446f2618', 'image', '/static/activities/g133/main.jpg', '“Con đã bao giờ nhìn thấy một chiếc vòng cổ như thế này chưa?”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '06b27b21-d4a7-544e-a9b9-ac02446f2618', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g134: Đánh trống (trang PDF 183)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '5b9bfd5f-d1ee-5b2f-a9d5-ed06408970c5', 'Đánh trống', 'Ai muốn biểu diễn ở lễ hội nào?', '**Kỹ năng phát triển:** Kỹ năng xã hội, Thể hiện cảm xúc

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc sàn.
- **Tư thế:** Trẻ ngồi.
- **Đồ dùng:** Một thanh gỗ nhỏ và 1 quả bóng.

## Các bước thực hiện
1. Bố mẹ giới thiệu luật chơi: Một người dùng gậy gỗ gõ lên bàn, những người còn lại ngồi thành vòng tròn, chuyền bóng theo chiều kim đồng hồ. Khi tiếng gõ dừng, dừng chuyền bóng và người có bóng sẽ biểu diễn văn nghệ (có thể hát những bài hát thiếu nhi, cũng có thể bắt chước âm thanh của các loài động vật nhỏ,...).
2. Ban đầu, trẻ có thể chưa hiểu luật chơi. Bố mẹ nên gợi ý: “Quả bóng cho con đây, mẹ chơi thêm vài vòng nữa là con sẽ hiểu luật chơi”.

## Hướng dẫn của chuyên gia
- Trong những vòng đầu tiên, những người ngồi xung quanh sẽ xích lại gần nhau hơn để rút ngắn thời gian chờ đợi của trẻ và tăng thêm sự hứng thú cho trẻ.
- Các màn biểu diễn có thể đa dạng, chẳng hạn như bắt chước các chuyển động quen thuộc của một thành viên trong gia đình hoặc một người bạn quen thuộc, học cách nói của người khác hoặc nhảy theo nhạc.

> Ai muốn biểu diễn ở lễ hội nào?

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 30, 36,
       'Một thanh gỗ nhỏ và 1 quả bóng.', ARRAY['Một thanh gỗ nhỏ và 1 quả bóng']::text[], '/static/activities/g134/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Kỹ năng xã hội, Thể hiện cảm xúc.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('5b9bfd5f-d1ee-5b2f-a9d5-ed06408970c5', 1, 'Bố mẹ giới thiệu luật chơi: Một người dùng gậy gỗ gõ lên bàn, những người còn lại ngồi thành vòng tròn, chuyền bóng theo chiều kim đồng hồ. Khi tiếng gõ dừng, dừng chuyền bóng và người có bóng sẽ biểu diễn văn nghệ (có thể hát những bài hát thiếu nhi, cũng có thể bắt chước âm thanh của các loài động vật nhỏ,...).', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('5b9bfd5f-d1ee-5b2f-a9d5-ed06408970c5', 2, 'Ban đầu, trẻ có thể chưa hiểu luật chơi. Bố mẹ nên gợi ý: “Quả bóng cho con đây, mẹ chơi thêm vài vòng nữa là con sẽ hiểu luật chơi”.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('5b9bfd5f-d1ee-5b2f-a9d5-ed06408970c5', 'image', '/static/activities/g134/main.jpg', 'Ai muốn biểu diễn ở lễ hội nào?', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '5b9bfd5f-d1ee-5b2f-a9d5-ed06408970c5', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g135: Bác sĩ tí hon (trang PDF 184)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '817c889c-4dc1-5419-893e-259546db1952', 'Bác sĩ tí hon', 'Trò chơi do trẻ dẫn dắt. Bố mẹ không nên áp đặt ý tưởng của riêng mình lên con cái, ngay cả khi những gì trẻ nói và làm có khác xa với thực tế hay không.', '**Kỹ năng phát triển:** Khả năng nhận thức tính cách, Khả năng tưởng tượng

## Chuẩn bị
- **Không gian:** Thảm trải sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một bộ đồ chơi bệnh viện.

## Các bước thực hiện
1. Mẹ nói: “Cùng chơi trò chơi bác sĩ tí hon nhé. Những người trong bệnh viện là ai con nhỉ?” Mẹ hướng dẫn trẻ trả lời và hỏi tiếp: “Có bác sĩ, y tá và bệnh nhân, con muốn trở thành ai?” Mẹ khuyến khích bé chọn vai mà trẻ muốn đóng.
2. Nếu trẻ chọn đóng vai bác sĩ, bố có thể đóng vai bệnh nhân và mẹ có thể đóng vai y tá. Bố giả vờ đau bụng và đi khám bác sĩ. Mẹ khuyến khích trẻ nói như bác sĩ và chữa trị cho bệnh nhân.

## Hướng dẫn của chuyên gia
- Trước khi chơi, bạn có thể đọc truyện tranh về bác sĩ cho trẻ nghe để học những kiến thức liên quan.

> Trò chơi do trẻ dẫn dắt. Bố mẹ không nên áp đặt ý tưởng của riêng mình lên con cái, ngay cả khi những gì trẻ nói và làm có khác xa với thực tế hay không.

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 30, 36,
       'Một bộ đồ chơi bệnh viện.', ARRAY['Một bộ đồ chơi bệnh viện']::text[], '/static/activities/g135/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức tính cách, Khả năng tưởng tượng.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('817c889c-4dc1-5419-893e-259546db1952', 1, 'Mẹ nói: “Cùng chơi trò chơi bác sĩ tí hon nhé. Những người trong bệnh viện là ai con nhỉ?” Mẹ hướng dẫn trẻ trả lời và hỏi tiếp: “Có bác sĩ, y tá và bệnh nhân, con muốn trở thành ai?” Mẹ khuyến khích bé chọn vai mà trẻ muốn đóng.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('817c889c-4dc1-5419-893e-259546db1952', 2, 'Nếu trẻ chọn đóng vai bác sĩ, bố có thể đóng vai bệnh nhân và mẹ có thể đóng vai y tá. Bố giả vờ đau bụng và đi khám bác sĩ. Mẹ khuyến khích trẻ nói như bác sĩ và chữa trị cho bệnh nhân.', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('817c889c-4dc1-5419-893e-259546db1952', 'image', '/static/activities/g135/main.jpg', 'Trò chơi do trẻ dẫn dắt. Bố mẹ không nên áp đặt ý tưởng của riêng mình lên con cái, ngay cả khi những gì trẻ nói và làm có khác xa với thực tế hay không.', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '817c889c-4dc1-5419-893e-259546db1952', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');

-- g136: Đèn giao thông (trang PDF 185)
INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, needs_adult, lyrics)
SELECT '22f41601-f146-5322-9650-a5d298f012cc', 'Đèn giao thông', '“Đèn đỏ dừng, Đèn xanh đi!”', '**Kỹ năng phát triển:** Khả năng nhận thức, Tuân thủ quy định

## Chuẩn bị
- **Không gian:** Thảm trải sàn hoặc sàn.
- **Tư thế:** Không có yêu cầu đặc biệt.
- **Đồ dùng:** Một bộ biển báo giao thông tự chế.

## Các bước thực hiện
1. Đánh dấu đường bằng băng dính trên mặt đất. Bố đóng vai cảnh sát giao thông, cầm biển báo đèn đỏ và đèn xanh, đồng thời giải thích rõ ràng luật chơi cho trẻ.
2. Mẹ và bé giả vờ sang đường, lúc này bố giơ đèn đỏ lên và nói: “Đèn đỏ dừng lại!” Khi mẹ và bé muốn dừng lại, bố giơ đèn xanh lên nói: “Đèn xanh, đi thôi!” Bé và mẹ có thể tiếp tục đi bộ. Mẹ nên nhắc bé chú ý đèn giao thông và nghe theo hiệu lệnh của “cảnh sát giao thông” khi qua đường.
3. Sau khi trẻ đã làm quen với luật chơi, bố giơ biển hiệu lên, không nói gì và hướng dẫn trẻ điều chỉnh hành vi của mình theo biển báo.
4. Đổi vai, mẹ và bé cũng có thể thay nhau đóng vai “cảnh sát giao thông”. Ai vi phạm luật giao thông sẽ nhận những “hình phạt nhỏ” như cạo mũi, nhảy thỏ,...

## Hướng dẫn của chuyên gia
- Trong trò chơi, bố có thể cố tình mắc lỗi và bị rời khỏi trò chơi, đứng sang một bên. Điều này không chỉ làm tăng thêm sự thú vị của trò chơi mà còn khiến trẻ cảm thấy rằng mình sẽ bị trừng phạt nếu không tuân theo các quy tắc.
- Khi bố mẹ đưa trẻ đi qua các ngã tư, có thể hướng dẫn trẻ nhìn đèn giao thông để trẻ có ấn tượng cơ bản về luật giao thông.

> “Đèn đỏ dừng, Đèn xanh đi!”

_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, trò chơi nhận thức._', 'play', 30, 36,
       'Một bộ biển báo giao thông tự chế.', ARRAY['Một bộ biển báo giao thông tự chế']::text[], '/static/activities/g136/main.jpg', 'published', now(),
       (SELECT id FROM activity.activity_groups WHERE code = 'cognitive_social'), 'Kỹ năng phát triển: Khả năng nhận thức, Tuân thủ quy định.', true, NULL;
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22f41601-f146-5322-9650-a5d298f012cc', 1, 'Đánh dấu đường bằng băng dính trên mặt đất. Bố đóng vai cảnh sát giao thông, cầm biển báo đèn đỏ và đèn xanh, đồng thời giải thích rõ ràng luật chơi cho trẻ.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22f41601-f146-5322-9650-a5d298f012cc', 2, 'Mẹ và bé giả vờ sang đường, lúc này bố giơ đèn đỏ lên và nói: “Đèn đỏ dừng lại!” Khi mẹ và bé muốn dừng lại, bố giơ đèn xanh lên nói: “Đèn xanh, đi thôi!” Bé và mẹ có thể tiếp tục đi bộ. Mẹ nên nhắc bé chú ý đèn giao thông và nghe theo hiệu lệnh của “cảnh sát giao thông” khi qua đường.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22f41601-f146-5322-9650-a5d298f012cc', 3, 'Sau khi trẻ đã làm quen với luật chơi, bố giơ biển hiệu lên, không nói gì và hướng dẫn trẻ điều chỉnh hành vi của mình theo biển báo.', NULL);
INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES ('22f41601-f146-5322-9650-a5d298f012cc', 4, 'Đổi vai, mẹ và bé cũng có thể thay nhau đóng vai “cảnh sát giao thông”. Ai vi phạm luật giao thông sẽ nhận những “hình phạt nhỏ” như cạo mũi, nhảy thỏ,...', NULL);
INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES ('22f41601-f146-5322-9650-a5d298f012cc', 'image', '/static/activities/g136/main.jpg', '“Đèn đỏ dừng, Đèn xanh đi!”', 0);
INSERT INTO activity.activity_domains (activity_id, domain_id) SELECT '22f41601-f146-5322-9650-a5d298f012cc', id FROM criteria.developmental_domains WHERE code IN ('cognitive', 'social_emotional');
