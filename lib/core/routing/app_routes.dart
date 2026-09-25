/// Route path constants — names mirror the prototype's screen ids in
/// comments (see prototype_reference.md § navigation graph).
abstract final class AppRoutes {
  static const splash = '/'; // s0 "1"
  static const onboarding = '/onboarding'; // s1 "2"
  static const login = '/login'; // s2 "3"
  static const childPicker = '/child-picker'; // s3 "3b"
  static const home = '/home'; // s4 "4"
  static const childProfile = '/child-profile'; // s5 "5"
  static const childProfileNew = '/child-profile/new'; // "Thêm hồ sơ bé mới" — no dedicated prototype screen id, reuses s5's form in a blank/add state (see child_profile_screen.dart)
  static const growth = '/growth'; // s6 "6"
  static const growthHistory = '/growth/history'; // growth metric history (own screen, not the assessment history)
  static const assessmentQuestion = '/assessment/question'; // s7-10 "8a-8d" (:domainIndex)
  static const assessmentResult = '/assessment/result'; // s11 "9"
  static const history = '/history'; // s12 "10"
  static const activityGroups = '/activities'; // s13 "11"
  static const activityGroupDetail = '/activities/group'; // s14 "12" (:groupId)
  static const activityDetail = '/activities/detail'; // s15-17 "12b/13/13b" (:activityId)
  static const activityFavorites = '/activities/favorites'; // yêu thích hoạt động
  static const journal = '/journal'; // s18 "14"
  static const journalAdd = '/journal/add'; // s19 "15"
  static const journalDetail = '/journal/detail'; // xem/sửa chi tiết 1 nhật ký (:entryId)
  static const companion = '/companion'; // s20 "16"
  static const companionSaved = '/companion/saved'; // bài viết đã lưu
  static const notifications = '/notifications'; // s21 "18"
  static const settings = '/settings'; // s22 "19"
  static const accountSettings = '/settings/account'; // Thông tin & cài đặt tài khoản của mẹ
  static const vaccination = '/vaccination'; // module "Tiêm chủng / Mọc răng" (extra: childId)
  static const vaccineDoseDetail = '/vaccination/dose'; // (:childId/:doseId)
  static const vaccineAdd = '/vaccination/add'; // thêm mũi tiêm ngoài lịch TCMR (:childId)
  static const toothAdd = '/vaccination/teeth/add'; // ghi nhận răng mọc (:childId)
  static const toothList = '/vaccination/teeth/list'; // danh sách răng đã mọc, sửa/bỏ đánh dấu (:childId)
  static const moreHub = '/more'; // bottom-nav "Thêm" hub (documented interpretation)
  static const chatStub = '/companion/chat';
  static const communityCreatePost = '/companion/community/new';
}
