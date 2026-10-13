// Menu admin. Mỗi mục gắn với:
//  - permission: mã trong admin.permissions — admin thiếu quyền sẽ không thấy mục đó
//  - tables: bảng DB mà màn hình quản lý (ai_* nằm ở database AI, gọi qua backend)
//  - actions: chức năng cần có — màn chưa dựng sẽ hiển thị danh sách này làm đặc tả
export const navGroups = [
  {
    label: "TỔNG QUAN",
    items: [
      { path: "/", label: "Dashboard", icon: "grid" },
    ],
  },
  {
    label: "NGƯỜI DÙNG",
    items: [
      { path: "/users", label: "Người dùng", icon: "users", permission: "user.read" },
      { path: "/children", label: "Hồ sơ trẻ", icon: "child", permission: "child.stats" },
    ],
  },
  {
    label: "NỘI DUNG CHUYÊN MÔN",
    items: [
      {
        path: "/criteria", label: "Bộ tiêu chí & câu hỏi", icon: "clipboard", permission: "criteria.write",
        description: "Bộ tiêu chí đánh giá phát triển theo phiên bản: draft → published → archived (F12).",
        tables: ["criteria.criteria_versions", "criteria.developmental_domains", "criteria.age_milestones", "criteria.criteria", "criteria.criteria_questions", "criteria.criterion_references"],
        actions: ["Tạo phiên bản nháp bằng cách sao chép bản đang dùng", "Sửa tiêu chí, câu hỏi, gợi ý quan sát theo lĩnh vực × mốc tuổi", "Đánh dấu dấu hiệu cần lưu ý (red flag)", "Gắn nguồn tham chiếu cho từng tiêu chí", "Xuất bản (chỉ 1 phiên bản published), lưu trữ bản cũ"],
      },
      {
        path: "/activities", label: "Hoạt động & nhóm", icon: "spark", permission: "activity.write",
        description: "Thư viện hoạt động hỗ trợ phát triển và 6 nhóm hiển thị trên mobile (F09, F20).",
        tables: ["activity.activity_groups", "activity.activities", "activity.activity_domains", "activity.activity_steps", "activity.activity_media"],
        actions: ["Quản lý nhóm: tên, emoji, màu, kiểu màn chi tiết (move / music / story)", "Soạn hoạt động: độ tuổi, thời lượng, mục tiêu, chuẩn bị, các bước, lưu ý an toàn", "Lời bài hát (music), đoạn truyện + câu hỏi gợi ý (story)", "Gắn lĩnh vực phát triển, upload ảnh / video / audio", "Draft → published → hidden"],
      },
      {
        path: "/health", label: "Tiêm chủng & mọc răng", icon: "heart", permission: "health.write",
        description: "Danh mục vắc xin, lịch tiêm TCMR và mốc mọc răng sữa (F16).",
        tables: ["health.vaccines", "health.vaccine_schedules", "health.tooth_references"],
        actions: ["Danh mục vắc xin TCMR / dịch vụ", "Lịch tiêm: mũi, nhãn liều, độ tuổi, khoảng cách tối thiểu", "20 răng sữa và khoảng tháng mọc thường gặp"],
      },
      {
        path: "/nutrition", label: "Dinh dưỡng & chuẩn WHO", icon: "drop", permission: "health.write",
        description: "Lượng sữa tham khảo theo tuổi và bảng chuẩn tăng trưởng WHO (F05.1, F04).",
        tables: ["health.milk_reference_rules", "growth.who_growth_standards"],
        actions: ["Bảng lượng sữa theo độ tuổi, số cữ, ml/kg/ngày", "Import bảng LMS của WHO (CSV) theo phiên bản", "Xem trước đường chuẩn -3SD … +3SD"],
      },
      {
        path: "/references", label: "Nguồn tham chiếu", icon: "book", permission: "reference.write",
        description: "Nguồn khoa học (WHO, Bộ Y tế, CDC…) và phiên bản bộ dữ liệu tham chiếu (F13).",
        tables: ["reference.reference_sources", "reference.reference_contents", "reference.reference_data_versions"],
        actions: ["Quản lý nguồn: tổ chức, năm, URL, loại tài liệu", "Trích đoạn nội dung tham chiếu theo trang", "Kích hoạt phiên bản dữ liệu tham chiếu (chỉ 1 active)"],
      },
    ],
  },
  {
    label: "AI & CHATBOT",
    items: [
      { path: "/ai/knowledge-base", label: "Kho tri thức", icon: "database", permission: "kb.manage" },
      { path: "/ai/candidates", label: "Tiêu chí AI đề xuất", icon: "bulb", permission: "criteria.write" },
      { path: "/ai/chatbot", label: "Giám sát chatbot", icon: "message", permission: "chatbot.monitor" },
    ],
  },
  {
    label: "CỘNG ĐỒNG",
    items: [
      { path: "/community/reports", label: "Báo cáo vi phạm", icon: "flag", permission: "community.moderate" },
      {
        path: "/community/posts", label: "Bài viết & bình luận", icon: "shield", permission: "community.moderate",
        description: "Tra cứu và xử lý nội dung cộng đồng (F21, F22).",
        tables: ["community.posts", "community.post_comments", "community.post_media", "community.moderation_actions"],
        actions: ["Tìm bài theo tác giả / từ khóa / trạng thái", "Ẩn, gỡ, khôi phục bài viết hoặc bình luận", "Cảnh cáo / khóa tác giả", "Lịch sử thao tác kiểm duyệt"],
      },
    ],
  },
  {
    label: "VẬN HÀNH",
    items: [
      {
        path: "/notifications", label: "Thông báo & nhắc lịch", icon: "bell", permission: "notification.write",
        description: "Loại thông báo, mẫu nội dung, quy tắc nhắc lịch và log gửi (F17).",
        tables: ["notification.notification_types", "notification.notification_templates", "notification.reminder_rules", "notification.notification_delivery_logs"],
        actions: ["Bật / tắt từng loại thông báo, kênh mặc định", "Soạn mẫu với placeholder {{child_name}}, {{date}}", "Quy tắc nhắc: số ngày trước, giờ gửi, lặp lại", "Theo dõi tỷ lệ gửi thành công / lỗi FCM"],
      },
      {
        path: "/legal", label: "Điều khoản & chính sách", icon: "file", permission: "legal.write",
        description: "Điều khoản, chính sách quyền riêng tư theo phiên bản (F01.5).",
        tables: ["account.legal_documents", "account.user_consents"],
        actions: ["Soạn phiên bản mới, đặt ngày hiệu lực", "Đánh dấu bắt buộc đồng ý lại", "Thống kê tỷ lệ người dùng đã đồng ý phiên bản hiện hành"],
      },
    ],
  },
  {
    label: "HỆ THỐNG",
    items: [
      {
        path: "/admins", label: "Quản trị viên & vai trò", icon: "settings", permission: "admin.manage",
        description: "Tài khoản quản trị và phân quyền theo vai trò (F11).",
        tables: ["admin.admin_users", "admin.roles", "admin.permissions", "admin.role_permissions", "admin.admin_user_roles"],
        actions: ["Mời / khóa quản trị viên", "Gán vai trò: super_admin, content_manager, moderator, support", "Ma trận vai trò × quyền"],
      },
      {
        path: "/audit", label: "Nhật ký hoạt động", icon: "activity", permission: "audit.read",
        description: "Mọi thao tác của quản trị viên, kèm dữ liệu trước / sau.",
        tables: ["admin.admin_audit_logs"],
        actions: ["Lọc theo admin, loại đối tượng, hành động, thời gian", "Xem diff before_data / after_data"],
      },
    ],
  },
];

export const allNavItems = navGroups.flatMap((group) => group.items);

// Không nằm trong menu — mở từ góc tài khoản ở sidebar
export const accountItem = { path: "/account", label: "Tài khoản của tôi", icon: "settings" };
