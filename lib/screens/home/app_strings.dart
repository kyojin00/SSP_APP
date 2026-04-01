// ══════════════════════════════════════════
// 앱 전체 번역 문자열
// 사용법: context.tr(AppStrings.키)
// ══════════════════════════════════════════
class AppStrings {
  AppStrings._();

  // ── 공통
  static const yes           = {'ko': '예',           'en': 'Yes',         'vi': 'Co',           'uz': 'Ha',          'km': 'បាទ/ចាស'};
  static const no2           = {'ko': '아니오',       'en': 'No',          'vi': 'Khong',        'uz': "Yo'q",        'km': 'ទេ'};
  static const logout        = {'ko': '로그아웃',     'en': 'Logout',      'vi': 'Dang xuat',    'uz': 'Chiqish',     'km': 'ចាកចេញ'};
  static const logoutConfirm = {'ko': '로그아웃 하시겠습니까?', 'en': 'Are you sure you want to logout?', 'vi': 'Ban co muon dang xuat?', 'uz': 'Chiqishni xohlaysizmi?', 'km': 'តើអ្នកចង់ចាកចេញមែនទេ?'};
  static const logoutFailed  = {'ko': '로그아웃에 실패했습니다.', 'en': 'Logout failed.', 'vi': 'Dang xuat that bai.', 'uz': 'Chiqishda xato.', 'km': 'ចាកចេញបរាជ័យ។'};
  static const cancel        = {'ko': '취소',        'en': 'Cancel',      'vi': 'Huy',          'uz': 'Bekor',       'km': 'បោះបង់'};
  static const confirm       = {'ko': '확인',        'en': 'Confirm',     'vi': 'Xac nhan',     'uz': 'Tasdiqlash',  'km': 'បញ្ជាក់'};
  static const save          = {'ko': '저장',        'en': 'Save',        'vi': 'Luu',          'uz': 'Saqlash',     'km': 'រក្សាទុក'};
  static const close         = {'ko': '닫기',        'en': 'Close',       'vi': 'Dong',         'uz': 'Yopish',      'km': 'បិទ'};
  static const retry         = {'ko': '다시 시도',   'en': 'Retry',       'vi': 'Thu lai',      'uz': 'Qayta',       'km': 'សាកម្ដងទៀត'};
  static const loading       = {'ko': '로딩 중...',  'en': 'Loading...',  'vi': 'Dang tai...',  'uz': 'Yuklanmoqda', 'km': 'កំពុងផ្ទុក...'};
  static const approve       = {'ko': '승인',        'en': 'Approve',     'vi': 'Duyet',        'uz': 'Tasdiqlash',  'km': 'អនុម័ត'};
  static const reject        = {'ko': '반려',        'en': 'Reject',      'vi': 'Tu choi',      'uz': 'Rad etish',   'km': 'បដិសេធ'};
  static const approved      = {'ko': '승인됨',      'en': 'Approved',    'vi': 'Da duyet',     'uz': 'Tasdiqlandi', 'km': 'បានអនុម័ត'};
  static const rejected      = {'ko': '반려됨',      'en': 'Rejected',    'vi': 'Da tu choi',   'uz': 'Rad etildi',  'km': 'បានបដិសេធ'};
  static const pending       = {'ko': '대기 중',     'en': 'Pending',     'vi': 'Cho duyet',    'uz': 'Kutilmoqda',  'km': 'កំពុងរង់ចាំ'};
  static const noData        = {'ko': '데이터 없음', 'en': 'No data',     'vi': 'Khong co du lieu', 'uz': "Ma'lumot yo'q", 'km': 'គ្មានទិន្នន័យ'};
  static const preparing     = {'ko': '준비 중입니다.', 'en': 'Coming soon.', 'vi': 'Sap ra mat.', 'uz': 'Tez kunda.', 'km': 'នឹងមកដល់ឆាប់ៗ។'};
  static const errorOccurred = {'ko': '오류가 발생했습니다.', 'en': 'An error occurred.', 'vi': 'Da xay ra loi.', 'uz': 'Xato yuz berdi.', 'km': 'មានកំហុសកើតឡើង។'};
  static const year          = {'ko': '년', 'en': '',     'vi': '',    'uz': '-yil', 'km': ''};
  static const month         = {'ko': '월', 'en': '/',   'vi': '/',   'uz': '/',    'km': '/'};
  static const members       = {'ko': '명', 'en': '',    'vi': ' ng', 'uz': ' k',   'km': 'នាក់'};

  // ── 홈 화면
  static const appName       = {'ko': '승산팩 시스템', 'en': 'Seungsanpack',  'vi': 'Seungsanpack',    'uz': 'Seungsanpack',   'km': 'Seungsanpack'};
  static const menu          = {'ko': '메뉴',          'en': 'Menu',          'vi': 'Menu',            'uz': 'Menyu',          'km': 'មុខងារ'};
  static const menuSubtitle  = {'ko': '카테고리를 눌러 기능을 선택하세요', 'en': 'Tap a category', 'vi': 'Nhan danh muc', 'uz': 'Kategoriyani bosing', 'km': 'ចុចប្រភេទ'};
  static const quickAction   = {'ko': '빠른 실행',    'en': 'Quick Actions', 'vi': 'Thao tac nhanh',  'uz': 'Tezkor',         'km': 'សកម្មភាពរហ័ស'};
  static const quickSubtitle = {'ko': '자주 쓰는 기능', 'en': 'Frequently used', 'vi': 'Thuong dung', 'uz': 'Tez-tez ishlatiladigan', 'km': 'ប្រើញឹកញាប់'};
  static const profileError  = {'ko': '프로필을 불러오지 못했습니다.', 'en': 'Failed to load profile.', 'vi': 'Khong tai duoc ho so.', 'uz': 'Profil yuklanmadi.', 'km': 'មិនអាចផ្ទុកប្រវត្តិរូបបាន។'};
  static const retryBtn      = {'ko': '다시 시도',    'en': 'Retry',         'vi': 'Thu lai',         'uz': 'Qayta urinish',  'km': 'ព្យាយាមម្តងទៀត'};
  static const exitHint      = {'ko': '한 번 더 누르면 종료됩니다', 'en': 'Press again to exit', 'vi': 'Nhan lan nua de thoat', 'uz': 'Chiqish uchun yana bosing', 'km': 'ចុចម្ដងទៀតដើម្បីចេញ'};

  // ── 홈 상태 배너
  static const bannerUnreadNotice     = {'ko': '읽지 않은 공지가 {n}건 있어요',             'en': 'You have {n} unread notice(s)',           'vi': 'Ban co {n} thong bao chua doc',         'uz': "{n} ta o'qilmagan xabar bor",           'km': 'មានសេចក្ដីជូនដំណឹង {n} មិនទាន់អាន'};
  static const bannerGoCheck         = {'ko': '확인하기',                                   'en': 'View',                                    'vi': 'Xem ngay',                              'uz': "Ko'rish",                               'km': 'មើល'};
  static const bannerMealBoth        = {'ko': '오늘 점심·저녁 식수를 아직 체크하지 않았어요', 'en': "You haven't checked lunch & dinner yet", 'vi': 'Ban chua check bua trua va toi hom nay', 'uz': 'Tushlik va kechki ovqat tekshirilmagan', 'km': 'អ្នកមិនទាន់ពិនិត្យអាហារថ្ងៃត្រង់ និងល្ងាចនៅឡើយ'};
  static const bannerMealLunch       = {'ko': '오늘 점심 식수를 아직 체크하지 않았어요',     'en': "You haven't checked lunch yet",          'vi': 'Ban chua check bua trua hom nay',        'uz': 'Tushlik tekshirilmagan',                'km': 'អ្នកមិនទាន់ពិនិត្យអាហារថ្ងៃត្រង់នៅឡើយ'};
  static const bannerMealDinner      = {'ko': '오늘 저녁 식수를 아직 체크하지 않았어요',     'en': "You haven't checked dinner yet",         'vi': 'Ban chua check bua toi hom nay',         'uz': 'Kechki ovqat tekshirilmagan',           'km': 'អ្នកមិនទាន់ពិនិត្យអាហារពេលល្ងាចនៅឡើយ'};
  static const bannerMealCheck       = {'ko': '체크하기',                                   'en': 'Check now',                               'vi': 'Check ngay',                            'uz': 'Tekshirish',                            'km': 'ពិនិត្យឥឡូវ'};
  static const bannerAttendance      = {'ko': '오늘 출석체크를 아직 하지 않았어요',           'en': "You haven't checked in today",           'vi': 'Ban chua diem danh hom nay',            'uz': 'Bugun davomat tekshirilmagan',           'km': 'អ្នកមិនទាន់ពិនិត្យវត្តមានថ្ងៃនេះ'};
  static const bannerAttendanceCheck = {'ko': '출석체크',                                   'en': 'Check In',                                'vi': 'Diem danh',                             'uz': 'Davomat',                               'km': 'ពិនិត្យវត្តមាន'};

  // ── 식수 알림 전송
  static const mealNotifTitle   = {'ko': '식수 알림 전송',                               'en': 'Send Meal Reminder',                      'vi': 'Gui nhac nho bua an',                   'uz': 'Ovqat eslatmasi yuborish',              'km': 'ផ្ញើការរំលឹកអាហារ'};
  static const mealNotifConfirm = {'ko': '전체 입주자 {n}명에게\n식수 체크 알림을 보낼까요?', 'en': 'Send a meal check reminder\nto all {n} residents?', 'vi': 'Gui nhac nho kiem tra bua an\ncho {n} cu dan?', 'uz': "{n} ta rezidentga\novqat eslatmasi yuborilsinmi?", 'km': 'ផ្ញើការរំលឹកពិនិត្យអាហារ\nទៅកាន់អ្នករស់នៅ {n} នាក់?'};
  static const mealNotifSend    = {'ko': '전송',                                         'en': 'Send',                                    'vi': 'Gui',                                   'uz': 'Yuborish',                              'km': 'ផ្ញើ'};
  static const mealNotifDone    = {'ko': '✅ 전체 입주자에게 식수 알림을 전송했어요!',    'en': '✅ Meal reminder sent to all residents!',  'vi': '✅ Da gui nhac nho den tat ca cu dan!',  'uz': '✅ Barcha rezidentlarga ovqat eslatmasi yuborildi!', 'km': '✅ បានផ្ញើការរំលឹកអាហារទៅអ្នករស់នៅទាំងអស់!'};
  static const mealNotifFail    = {'ko': '알림 전송 실패: {e}',                          'en': 'Failed to send reminder: {e}',            'vi': 'Gui that bai: {e}',                     'uz': 'Yuborishda xato: {e}',                  'km': 'ផ្ញើបរាជ័យ: {e}'};

  // ── 카테고리
  static const catMeal       = {'ko': '식사/급식',    'en': 'Meals',            'vi': 'Bua an',              'uz': 'Ovqat',               'km': 'អាហារ'};
  static const catMealDesc   = {'ko': '식수보고 · 식수리포트', 'en': 'Meal check · Report', 'vi': 'Bao an · Thong ke', 'uz': 'Ovqat · Hisobot',   'km': 'ពិនិត្យ · របាយការណ៍'};
  static const catWork       = {'ko': '근태/휴가',    'en': 'Attendance',       'vi': 'Cham cong',           'uz': 'Davomiylik',          'km': 'វត្តមាន'};
  static const catWorkDesc   = {'ko': '출퇴근 · 휴가신청 · 근태관리', 'en': 'Check-in · Leave · Manage', 'vi': 'Vao/ra · Nghi · Quan ly', 'uz': 'Kirish/Chiqish',  'km': 'ចូល/ចេញ · 휴가'};
  static const catNotice     = {'ko': '공지/소통',    'en': 'Notice',           'vi': 'Thong bao',           'uz': 'Xabarnoma',           'km': 'សេចក្ដីជូនដំណឹង'};
  static const catNoticeDesc = {'ko': '공지사항 · 건의/신고', 'en': 'Notice · Report', 'vi': 'Thong bao · Bao cao', 'uz': 'Xabar · Hisobot', 'km': 'ជូនដំណឹង · របាយការណ៍'};
  static const catField      = {'ko': '현장/설비',    'en': 'Field',            'vi': 'Hien truong',         'uz': 'Maydon',              'km': 'កន្លែងធ្វើការ'};
  static const catFieldDesc  = {'ko': '현장관리',     'en': 'Field management', 'vi': 'Quan ly hien truong', 'uz': 'Maydon boshq.',       'km': 'គ្រប់គ្រងទីតាំង'};
  static const catDorm       = {'ko': '기숙사',       'en': 'Dormitory',        'vi': 'Ky tuc xa',           'uz': 'Yotoqxona',           'km': 'អាគារស្នាក់នៅ'};
  static const catDormDesc   = {'ko': '기숙사 관리',  'en': 'Dorm management',  'vi': 'Quan ly KTX',         'uz': 'Yotoqxona boshq.',    'km': 'គ្រប់គ្រងអាគារ'};
  static const catAdmin      = {'ko': '관리',         'en': 'Admin',            'vi': 'Quan tri',            'uz': 'Boshqaruv',           'km': 'គ្រប់គ្រង'};
  static const catAdminDesc  = {'ko': '직원관리 · 엑셀 내보내기', 'en': 'Employee · Excel export', 'vi': 'Nhan vien · Xuat Excel', 'uz': 'Xodimlar · Excel', 'km': 'បុគ្គលិក · Excel'};
  static const catEtc        = {'ko': '기타',         'en': 'More',             'vi': 'Khac',                'uz': 'Boshqa',              'km': 'ច្រើនទៀត'};
  static const catEtcDesc    = {'ko': '매뉴얼/교육 · 앱 설치', 'en': 'Manual · Install', 'vi': 'Huong dan · Cai dat', 'uz': 'Qollanma',        'km': 'ណែនាំ · ដំឡើង'};
  static const catTrend      = {'ko': '동향 분석',    'en': 'Trend Analysis',   'vi': 'Phan tich xu huong',  'uz': 'Trend tahlili',       'km': 'វិភាគទំនោរ'};
  static const catTrendDesc  = {'ko': '식수·출근 추이 그래프', 'en': 'Meal & Attendance graph', 'vi': 'Bieu do an va cham cong', 'uz': 'Ovqat va davomat grafigi', 'km': 'ក្រាហ្វិកអាហារ & វត្តមាន'};
  static const catVehicle    = {'ko': '차량 일지',    'en': 'Vehicle Log',      'vi': 'Nhat ky xe',          'uz': 'Avtomobil jurnali',   'km': 'កំណត់ហេតុយានយន្ត'};
  static const catVehicleDesc= {'ko': '법인차량 운행 기록', 'en': 'Company vehicle log', 'vi': 'Nhat ky xe cong ty', 'uz': 'Korporativ avtomobil', 'km': 'កំណត់ហេតុយានយន្តក្រុមហ៊ុន'};
  static const catRequest    = {'ko': '신청/서류',    'en': 'Requests',         'vi': 'Yeu cau/Ho so',       'uz': 'Arizalar',            'km': 'ស្នើសុំ/ឯកសារ'};
  static const catRequestDesc= {'ko': '피복 등 각종 신청', 'en': 'Uniform & other requests', 'vi': 'Dong phuc va yeu cau khac', 'uz': 'Kiyim va boshqa arizalar', 'km': 'ឯកសណ្ឋាន និងការស្នើសុំផ្សេងៗ'};

  // ── 메뉴 항목
  static const mealCheck      = {'ko': '식수보고',       'en': 'Meal Check',       'vi': 'Bao an',              'uz': 'Ovqat',              'km': 'ពិនិត្យអាហារ'};
  static const mealReport     = {'ko': '식수리포트',     'en': 'Meal Report',      'vi': 'Thong ke an',         'uz': 'Ovqat hisoboti',     'km': 'របាយការណ៍អាហារ'};
  static const mealStats      = {'ko': '통계/관제',      'en': 'Statistics',       'vi': 'Thong ke',            'uz': 'Statistika',         'km': 'ស្ថិតិ'};
  static const mealMenuWeekly = {'ko': '이번주 식단표',  'en': "This Week's Menu", 'vi': 'Thuc don tuan nay',   'uz': 'Bu haftaning menyusi','km': 'ម៉ឺនុយសប្ដាហ៍នេះ'};
  static const attendance     = {'ko': '출퇴근',         'en': 'Attendance',       'vi': 'Vao/ra',              'uz': 'Kirish/Chiqish',     'km': 'ចូល/ចេញ'};
  static const leaveRequest   = {'ko': '휴가신청',       'en': 'Leave Request',    'vi': 'Dang ky nghi',        'uz': "Ta'til arizasi",     'km': 'ស្នើសុំ휴가'};
  static const leaveRealtime  = {'ko': '휴가 실시간 현황','en': 'Live Leave Status','vi': 'Trang thai nghi phep', 'uz': "Jonli ta'til holati",'km': 'ស្ថានភាព휴가ផ្ទាល់'};
  static const attendanceMgmt = {'ko': '근태관리',       'en': 'Attendance Mgmt',  'vi': 'Quan ly cong',        'uz': 'Davomiylik boshq.',  'km': 'គ្រប់គ្រងវត្តមាន'};
  static const notice         = {'ko': '공지사항',       'en': 'Notice',           'vi': 'Thong bao',           'uz': 'Xabarnoma',          'km': 'សេចក្ដីជូនដំណឹង'};
  static const suggestion     = {'ko': '건의/신고',      'en': 'Report',           'vi': 'Bao cao',             'uz': 'Taklif/Hisobot',     'km': 'ស្នើ/របាយការណ៍'};
  static const fieldMgmt      = {'ko': '현장관리',       'en': 'Field Mgmt',       'vi': 'Quan ly cong truong', 'uz': 'Maydon boshq.',      'km': 'គ្រប់គ្រងទីតាំង'};
  static const dormitory      = {'ko': '기숙사',         'en': 'Dormitory',        'vi': 'Ky tuc xa',           'uz': 'Yotoqxona',          'km': 'អាគារស្នាក់នៅ'};
  static const employeeMgmt   = {'ko': '직원관리',       'en': 'Employee Mgmt',    'vi': 'Quan ly nhan vien',   'uz': 'Xodimlar boshq.',    'km': 'គ្រប់គ្រងបុគ្គលិក'};
  static const excelExport    = {'ko': '엑셀 내보내기',  'en': 'Excel Export',     'vi': 'Xuat Excel',          'uz': 'Excel export',       'km': 'នាំចេញ Excel'};
  static const langSettings   = {'ko': '언어 설정',      'en': 'Language',         'vi': 'Ngon ngu',            'uz': 'Til',                'km': 'ភាសា'};
  static const manual         = {'ko': '매뉴얼/교육',    'en': 'Manual',           'vi': 'Huong dan',           'uz': 'Qollanma',           'km': 'ណែនាំ'};
  static const appInstall     = {'ko': '앱 설치',        'en': 'Install App',      'vi': 'Cai dat ung dung',    'uz': "Ilovani o'rnatish",  'km': 'ដំឡើងកម្មវិធី'};
  static const mealCheckSub   = {'ko': '오늘 식사 체크', 'en': "Today's meal",     'vi': 'Bua an hom nay',      'uz': 'Bugungi ovqat',      'km': 'អាហារថ្ងៃនេះ'};
  static const attendanceSub  = {'ko': '출근/퇴근 기록', 'en': 'Clock in/out',     'vi': 'Cham cong',           'uz': 'Kirib/chiqish',      'km': 'ចូល/ចេញ'};

  // ── 언어 설정
  static const langTitle    = {'ko': '언어 설정',    'en': 'Language',      'vi': 'Ngon ngu',        'uz': 'Til sozlamalari', 'km': 'ការកំណត់ភាសា'};
  static const langSubtitle = {'ko': '선택한 언어로 앱 전체가 변경됩니다', 'en': 'The app will change to the selected language', 'vi': 'Ung dung se doi ngon ngu', 'uz': "Ilova tanlangan tilga o'tadi", 'km': 'កម្មវិធីនឹងប្ដូរភាសា'};

  // ── 식수 체크
  static const mealCheckTitle = {'ko': '식수 체크',   'en': 'Meal Check',    'vi': 'Kiem tra bua an', 'uz': 'Ovqat tekshiruvi', 'km': 'ពិនិត្យអាហារ'};
  static const mealSelectHint = {'ko': '오늘 식사를 선택해주세요', 'en': "Select today's meal", 'vi': 'Chon bua an hom nay', 'uz': 'Bugungi ovqatni tanlang', 'km': 'ជ្រើសរើសអាហារថ្ងៃនេះ'};
  static const lunch          = {'ko': '점심 식사',   'en': 'Lunch',         'vi': 'Bua trua',        'uz': 'Tushlik',        'km': 'អាហារថ្ងៃត្រង់'};
  static const dinner         = {'ko': '저녁 식사',   'en': 'Dinner',        'vi': 'Bua toi',         'uz': 'Kechki ovqat',   'km': 'អាហារពេលល្ងាច'};

  // ── 식수 리포트
  static const mealReportTitle  = {'ko': '식수 리포트',         'en': 'Meal Report',     'vi': 'Bao cao bua an',     'uz': 'Ovqat hisoboti',  'km': 'របាយការណ៍អាហារ'};
  static const todayStatus      = {'ko': '오늘 현황',           'en': 'Today',           'vi': 'Hom nay',            'uz': 'Bugun',           'km': 'ថ្ងៃនេះ'};
  static const yearMonthSummary = {'ko': '{y}년 {m}월 요약',    'en': '{y}/{m} Summary', 'vi': 'Tom tat {m}/{y}',    'uz': '{y}/{m} Xulosa',  'km': 'សង្ខេប {m}/{y}'};
  static const dailyDetail      = {'ko': '일별 상세',           'en': 'Daily Detail',    'vi': 'Chi tiet theo ngay', 'uz': 'Kunlik',          'km': 'លម្អិតប្រចាំថ្ងៃ'};
  static const dailyDetailSub   = {'ko': '최근순 · 탭해서 부서별 확인', 'en': 'Recent · Tap for dept', 'vi': 'Gan day · Nhan xem phong', 'uz': "So'nggi · Bosing", 'km': 'ថ្មីបំផុត · ចុច'};
  static const lunchShort       = {'ko': '점심',                'en': 'Lunch',           'vi': 'Trua',               'uz': 'Tushlik',         'km': 'ថ្ងៃត្រង់'};
  static const dinnerShort      = {'ko': '저녁',                'en': 'Dinner',          'vi': 'Toi',                'uz': 'Kechki',          'km': 'ល្ងាច'};
  static const lunchMeal        = {'ko': '🌞 점심',             'en': '🌞 Lunch',        'vi': '🌞 Trua',            'uz': '🌞 Tushlik',      'km': '🌞 ថ្ងៃត្រង់'};
  static const dinnerMeal2      = {'ko': '🌙 저녁',             'en': '🌙 Dinner',       'vi': '🌙 Toi',             'uz': '🌙 Kechki',       'km': '🌙 ល្ងាច'};
  static const eating           = {'ko': '식사',                'en': 'Eating',          'vi': 'An',                 'uz': 'Ovqat',           'km': 'ញ៉ាំ'};
  static const notEating        = {'ko': '불참',                'en': 'Skip',            'vi': 'Bo qua',             'uz': "O'tkazib",        'km': 'មិនញ៉ាំ'};
  static const noReply          = {'ko': '미응답',              'en': 'No reply',        'vi': 'Chua tra loi',       'uz': 'Javobsiz',        'km': 'មិនឆ្លើយ'};
  static const participation    = {'ko': '참여율',              'en': 'Rate',            'vi': 'Ti le',              'uz': 'Ishtirok',        'km': 'អត្រា'};
  static const monthlyStatus    = {'ko': '부서별 월간 현황',    'en': 'Monthly by Dept', 'vi': 'Theo thang/phong',   'uz': "Oylik bo'limlar", 'km': 'ប្រចាំខែ'};
  static const allNoReply       = {'ko': '전원 미응답',         'en': 'No replies',      'vi': 'Chua ai tra loi',    'uz': 'Hech kim javob bermadi', 'km': 'គ្មាននរណាឆ្លើយ'};
  static const uncounted        = {'ko': '미집계',              'en': 'Uncounted',       'vi': 'Chua tinh',          'uz': 'Hisoblanmagan',   'km': 'មិនបានរាប់'};
  static const realtime         = {'ko': '실시간',              'en': 'Live',            'vi': 'Truc tiep',          'uz': 'Jonli',           'km': 'ផ្ទាល់'};
  static const expandAll        = {'ko': '모두 펼치기',         'en': 'Expand all',      'vi': 'Mo rong tat ca',     'uz': 'Hammasini oching','km': 'បើកទាំងអស់'};
  static const collapseAll      = {'ko': '모두 접기',           'en': 'Collapse all',    'vi': 'Thu gon tat ca',     'uz': 'Hammasini yoping','km': 'បិទទាំងអស់'};
  static const eatUnit          = {'ko': '식', 'en': '', 'vi': ' an', 'uz': '', 'km': ''};
  static const notEatUnit       = {'ko': '불', 'en': '', 'vi': ' bo', 'uz': '', 'km': ''};
  static const noReplyUnit      = {'ko': '무', 'en': '', 'vi': '',    'uz': '', 'km': ''};
  static const noDataMonth      = {'ko': '{y}년 {m}월 데이터가 없습니다.', 'en': 'No data for {y}/{m}.', 'vi': 'Khong co du lieu {m}/{y}.', 'uz': "{y}/{m} ma'lumot yo'q.", 'km': 'គ្មានទិន្នន័យ {m}/{y}។'};

  // ── 부서명
  static const deptManagement = {'ko': '관리부',      'en': 'Management',    'vi': 'Phong quan ly',    'uz': 'Boshqaruv',       'km': 'នាយកដ្ឋានគ្រប់គ្រង'};
  static const deptProduction = {'ko': '생산관리부',  'en': 'Production',    'vi': 'Phong san xuat',   'uz': 'Ishlab chiqarish','km': 'នាយកដ្ឋានផលិតកម្ម'};
  static const deptSales      = {'ko': '영업부',      'en': 'Sales',         'vi': 'Phong kinh doanh', 'uz': 'Savdo',           'km': 'នាយកដ្ឋានលក់'};
  static const deptRnd        = {'ko': '연구소',      'en': 'R&D',           'vi': 'Nghien cuu',       'uz': 'Tadqiqot',        'km': 'ស្រាវជ្រាវ'};
  static const deptSteel      = {'ko': '스틸생산부',  'en': 'Steel',         'vi': 'Phong thep',       'uz': "Po'lat",          'km': 'នាយកដ្ឋានដែក'};
  static const deptBox        = {'ko': '박스생산부',  'en': 'Box',           'vi': 'Phong hop',        'uz': 'Quti',            'km': 'នាយកដ្ឋានប្រអប់'};
  static const deptDelivery   = {'ko': '포장납품부',  'en': 'Delivery',      'vi': 'Phong giao hang',  'uz': 'Yetkazib berish', 'km': 'នាយកដ្ឋានដឹកជញ្ជូន'};
  static const deptSsg        = {'ko': '에스에스지',  'en': 'SSG',           'vi': 'SSG',              'uz': 'SSG',             'km': 'SSG'};
  static const deptCleaning   = {'ko': '환경미화',    'en': 'Cleaning',      'vi': 'Ve sinh',          'uz': 'Tozalash',        'km': 'សំអាត'};
  static const deptNutrition  = {'ko': '영양사',      'en': 'Nutrition',     'vi': 'Dinh duong',       'uz': 'Ovqatlanish',     'km': 'អាហារូបត្ថម្ភ'};

  // ── 기숙사
  static const dormHub         = {'ko': '기숙사 허브',  'en': 'Dorm Hub',           'vi': 'Trung tam KTX',      'uz': 'Yotoqxona',           'km': 'មជ្ឈមណ្ឌលអាគារ'};
  static const myDormitory     = {'ko': '나의 기숙사',  'en': 'My Dormitory',       'vi': 'KTX cua toi',        'uz': 'Mening yotoqxona',    'km': 'អាគារស្នាក់នៅរបស់ខ្ញុំ'};
  static const roomSelect      = {'ko': '호실 선택',   'en': 'Select Room',         'vi': 'Chon phong',         'uz': 'Xona tanlash',        'km': 'ជ្រើសរើសបន្ទប់'};
  static const checkInSubmit   = {'ko': '입실 신청하기','en': 'Apply Check-In',      'vi': 'Dang ky vao phong',  'uz': 'Kirish uchun ariza',  'km': 'ដាក់ពាក្យចូលស្នាក់'};
  static const checkOutSubmit  = {'ko': '퇴실 신청하기','en': 'Apply Check-Out',     'vi': 'Dang ky ra phong',   'uz': 'Chiqish uchun ariza', 'km': 'ដាក់ពាក្យចាកចេញ'};
  static const dormRoomNone    = {'ko': '배정된 호실 없음', 'en': 'No room assigned', 'vi': 'Chua co phong',     'uz': "Xona yo'q",           'km': 'មិនទាន់ចាត់ចែងបន្ទប់'};
  static const dormApplyHint   = {'ko': '우측 하단 버튼으로 신청하세요', 'en': 'Use the button below to apply', 'vi': 'Nhan nut phia duoi de dang ky', 'uz': 'Pastdagi tugmani bosing', 'km': 'ចុចប៊ូតុងខាងក្រោមស្ដាំ'};
  static const currentRoom     = {'ko': '현재 거주 호실','en': 'Current Room',       'vi': 'Phong hien tai',     'uz': 'Hozirgi xona',        'km': 'បន្ទប់បច្ចុប្បន្ន'};
  static const roomUnit        = {'ko': '호',           'en': '',                   'vi': '',                   'uz': '-xona',               'km': ''};
  static const checkInDone     = {'ko': '입실 완료',   'en': 'Checked In',          'vi': 'Da vao phong',       'uz': 'Kirildi',             'km': 'បានចូលស្នាក់'};
  static const checkInPending  = {'ko': '입실 대기중', 'en': 'Check-In Pending',    'vi': 'Cho vao phong',      'uz': 'Kirish kutilmoqda',   'km': 'រង់ចាំចូលស្នាក់'};
  static const alreadyResident = {'ko': '이미 거주중', 'en': 'Already residing',    'vi': 'Dang o',             'uz': 'Allaqachon yashamoqda','km': 'រស់នៅរួចហើយ'};
  static const checkOutPending = {'ko': '퇴실 대기중', 'en': 'Check-Out Pending',   'vi': 'Cho ra phong',       'uz': 'Chiqish kutilmoqda',  'km': 'រង់ចាំចាកចេញ'};
  static const noAssignment    = {'ko': '배정 없음',   'en': 'No assignment',       'vi': 'Chua phan phong',    'uz': 'Tayinlanmagan',       'km': 'គ្មានការចាត់ចែង'};
  static const checkOutRoom    = {'ko': '퇴실할 호실', 'en': 'Room to check out',   'vi': 'Phong se ra',        'uz': 'Chiqiladigan xona',   'km': 'បន្ទប់ដែលនឹងចាកចេញ'};
  static const onlyCurrentRoom = {'ko': '현재 배정된 호실만 퇴실 신청 가능합니다.', 'en': 'You can only check out of your assigned room.', 'vi': 'Chi co the dang ky ra phong hien tai.', 'uz': 'Faqat belgilangan xonadan chiqish mumkin.', 'km': 'អាចដាក់ពាក្យចាកចេញពីបន្ទប់បច្ចុប្បន្នប៉ុណ្ណោះ។'};
  static const recentHistory   = {'ko': '⌛ 최근 신청 현황', 'en': '⌛ Recent Applications', 'vi': '⌛ Lich su dang ky', 'uz': "⌛ So'nggi arizalar", 'km': '⌛ ពាក្យស្នើសុំថ្មីៗ'};
  static const noHistory       = {'ko': '신청 이력이 없습니다.', 'en': 'No applications yet.', 'vi': 'Chua co lich su dang ky.', 'uz': "Arizalar yo'q.", 'km': 'មិនទាន់មានពាក្យស្នើសុំ។'};
  static const checkInApp      = {'ko': '입실 신청',   'en': 'Check-In Application', 'vi': 'Don vao phong',     'uz': 'Kirish arizasi',      'km': 'ពាក្យចូលស្នាក់'};
  static const checkOutApp     = {'ko': '퇴실 신청',   'en': 'Check-Out Application','vi': 'Don ra phong',       'uz': 'Chiqish arizasi',     'km': 'ពាក្យចាកចេញ'};
  static const roomNumCheckIn  = {'ko': '{n}호 입실 신청', 'en': 'Room {n} Check-In', 'vi': 'Phong {n} vao',    'uz': '{n}-xona kirish',     'km': 'បន្ទប់ {n} ចូលស្នាក់'};
  static const roomNumCheckOut = {'ko': '{n}호 퇴실 신청', 'en': 'Room {n} Check-Out','vi': 'Phong {n} ra',      'uz': '{n}-xona chiqish',    'km': 'បន្ទប់ {n} ចាកចេញ'};
  static const checkIn         = {'ko': '입실 신청',   'en': 'Check In',            'vi': 'Dang ky vao',        'uz': 'Kirish',              'km': 'ចូលស្នាក់'};
  static const checkOut        = {'ko': '퇴실 신청',   'en': 'Check Out',           'vi': 'Dang ky ra',         'uz': 'Chiqish',             'km': 'ចាកចេញ'};
  static const dormRules       = {'ko': '생활 규정',   'en': 'Dorm Rules',          'vi': 'Noi quy KTX',        'uz': 'Qoidalar',            'km': 'វិធាន'};
  static const repairReport    = {'ko': '비품/고장 신고','en': 'Repair Report',      'vi': 'Bao hong',           'uz': "Ta'mirlash",          'km': 'រាយការណ៍ជួសជុល'};
  static const demeritMgmt    = {'ko': '벌점 관리',   'en': 'Demerit Mgmt',        'vi': 'Quan ly diem phat',  'uz': 'Jarima boshq.',       'km': 'គ្រប់គ្រងពិន្ទុ'};
  static const myDemerit       = {'ko': '나의 벌점',   'en': 'My Demerits',         'vi': 'Diem phat cua toi',  'uz': 'Mening jarima',       'km': 'ពិន្ទុទណ្ឌរបស់ខ្ញុំ'};
  static const approvalAssign  = {'ko': '승인 및 배정', 'en': 'Approve & Assign',   'vi': 'Duyet & Phan phong', 'uz': 'Tasdiqlash',          'km': 'អនុម័ត & ចាត់ចែង'};

  // ── 근태/휴가
  static const leaveAnnual  = {'ko': '연차',   'en': 'Annual Leave',  'vi': 'Phep nam',      'uz': "Yillik ta'til", 'km': '휴가ប្រចាំឆ្នាំ'};
  static const leaveHalf    = {'ko': '반차',   'en': 'Half Day',      'vi': 'Nua ngay',      'uz': 'Yarim kun',     'km': 'ក្រៅពាក់កណ្ដាល'};
  static const leavePublic  = {'ko': '공가',   'en': 'Public Leave',  'vi': 'Nghi cong vu',  'uz': "Rasmiy ta'til", 'km': '休假សាធារណៈ'};
  static const leaveSpecial = {'ko': '경조사', 'en': 'Special Leave', 'vi': 'Nghi dac biet', 'uz': "Maxsus ta'til", 'km': '休假ពិសេស'};

  // ── 알림
  static const notifReconnect     = {'ko': '알림 다시 연결',             'en': 'Reconnect Notifications',       'vi': 'Ket noi lai thong bao',    'uz': 'Bildirishnomani qayta ulash',   'km': 'ភ្ជាប់ការជូនដំណឹងឡើងវិញ'};
  static const notifReconnectDone = {'ko': '알림 연결 완료 ✅',           'en': 'Notifications connected ✅',     'vi': 'Da ket noi thong bao ✅',   'uz': 'Bildirishnoma ulandi ✅',        'km': 'ភ្ជាប់ការជូនដំណឹងបានសម្រេច ✅'};
  static const notifReconnectFail = {'ko': '알림 연결 실패. 다시 시도해주세요.', 'en': 'Failed to connect. Please retry.', 'vi': 'Ket noi that bai. Thu lai.', 'uz': 'Ulanmadi. Qayta urining.', 'km': 'ភ្ជាប់មិនបាន។ សាកម្ដងទៀត។'};
  static const notifWebOnly       = {'ko': '알림 연결은 웹(PWA)에서만 가능합니다.', 'en': 'Notifications only available on web (PWA).', 'vi': 'Chi ho tro tren web (PWA).', 'uz': 'Faqat web (PWA) da mavjud.', 'km': 'មានតែលើ web (PWA)ប៉ុណ្ណោះ។'};
  static const notifResend        = {'ko': '알림 재전송',                 'en': 'Resend Notification',            'vi': 'Gui lai thong bao',         'uz': 'Qayta yuborish',                'km': 'ផ្ញើការជូនដំណឹងម្ដងទៀត'};
  static const notifResendDone    = {'ko': '✅ 알림이 재전송되었습니다.', 'en': '✅ Notification resent.',        'vi': '✅ Da gui lai thong bao.',   'uz': '✅ Bildirishnoma qayta yuborildi.', 'km': '✅ បានផ្ញើការជូនដំណឹងម្ដងទៀត។'};
  static const notifResendFail    = {'ko': '⚠️ 알림 전송에 실패했습니다.', 'en': '⚠️ Failed to send notification.', 'vi': '⚠️ Gui thong bao that bai.', 'uz': '⚠️ Yuborishda xato.', 'km': '⚠️ ផ្ញើការជូនដំណឹងបរាជ័យ។'};

  // ── 피복 신청
  static const uniformTitle         = {'ko': '피복 신청',              'en': 'Uniform Request',      'vi': 'Yeu cau dong phuc',       'uz': 'Kiyim talabi',              'km': 'ស្នើសុំឯកសណ្ឋាន'};
  static const uniformTabMy         = {'ko': '내 신청',                'en': 'My Requests',          'vi': 'Yeu cau cua toi',         'uz': 'Mening arizalarim',         'km': 'ស្នើសុំរបស់ខ្ញុំ'};
  static const uniformTabAll        = {'ko': '전체 관리',              'en': 'All Requests',         'vi': 'Quan ly tat ca',          'uz': 'Barcha arizalar',           'km': 'គ្រប់គ្រងទាំងអស់'};
  static const uniformCatClothing   = {'ko': '🧥 의류',               'en': '🧥 Clothing',          'vi': '🧥 Quan ao',              'uz': '🧥 Kiyim',                  'km': '🧥 សម្លៀកបំពាក់'};
  static const uniformCatSafety     = {'ko': '🦺 안전용품',           'en': '🦺 Safety Gear',       'vi': '🦺 Do bao ho',            'uz': '🦺 Xavfsizlik',             'km': '🦺 ឧបករណ៍សុវត្ថិភាព'};
  static const uniformItemLabel     = {'ko': '품목',                  'en': 'Item',                 'vi': 'San pham',                'uz': 'Mahsulot',                  'km': 'ទំនិញ'};
  static const uniformSizeLabel     = {'ko': '사이즈',                'en': 'Size',                 'vi': 'Kich co',                 'uz': "O'lcham",                   'km': 'ទំហំ'};
  static const uniformQtyLabel      = {'ko': '수량',                  'en': 'Quantity',             'vi': 'So luong',                'uz': 'Miqdor',                    'km': 'បរិមាណ'};
  static const uniformReasonLabel   = {'ko': '신청 사유 (선택)',       'en': 'Reason (optional)',    'vi': 'Ly do (tuy chon)',         'uz': 'Sabab (ixtiyoriy)',         'km': 'មូលហេតុ (ជាជម្រើស)'};
  static const uniformReasonHint    = {'ko': '예: 기존 작업복 파손, 신규 입사', 'en': 'e.g. worn out, new hire', 'vi': 'Vd: bi rach, nhan vien moi', 'uz': 'Masalan: eskirdi',       'km': 'ឧ. ហួសសម័យ, បុគ្គលិកថ្មី'};
  static const uniformSizeHint      = {'ko': '예: 95, 105, 265, 270', 'en': 'e.g. 95, 265',         'vi': 'Vd: 95, 265',             'uz': 'Masalan: 95, 265',          'km': 'ឧ. 95, 265'};
  static const uniformAddItem       = {'ko': '+ 품목 추가',           'en': '+ Add Item',           'vi': '+ Them san pham',         'uz': "+ Mahsulot qo'shish",       'km': '+ បន្ថែមទំនិញ'};
  static const uniformSubmitOne     = {'ko': '신청하기',              'en': 'Submit',               'vi': 'Gui yeu cau',             'uz': 'Yuborish',                  'km': 'ដាក់ស្នើ'};
  static const uniformSubmitMany    = {'ko': '{n}개 품목 신청하기',   'en': 'Submit {n} items',     'vi': 'Gui {n} san pham',        'uz': '{n} ta mahsulot yuborish',  'km': 'ដាក់ស្នើ {n} ទំនិញ'};
  static const uniformStatusPending = {'ko': '검토중',                'en': 'Pending',              'vi': 'Cho duyet',               'uz': "Ko'rib chiqilmoqda",        'km': 'កំពុងពិនិត្យ'};
  static const uniformStatusApproved= {'ko': '승인완료',              'en': 'Approved',             'vi': 'Da duyet',                'uz': 'Tasdiqlandi',               'km': 'បានអនុម័ត'};
  static const uniformStatusRejected= {'ko': '반려',                  'en': 'Rejected',             'vi': 'Tu choi',                 'uz': 'Rad etildi',                'km': 'បានបដិសេធ'};
  static const uniformRejectReason  = {'ko': '반려 사유',             'en': 'Reject Reason',        'vi': 'Ly do tu choi',           'uz': 'Rad sababi',                'km': 'មូលហេតុបដិសេធ'};
  static const uniformRejectLabel   = {'ko': '반려 사유: {r}',        'en': 'Rejected: {r}',        'vi': 'Ly do: {r}',              'uz': 'Sabab: {r}',                'km': 'មូលហេតុ: {r}'};
  static const uniformSummer        = {'ko': '하계',                  'en': 'Summer',               'vi': 'He',                      'uz': 'Yoz',                       'km': 'រដូវក្ដៅ'};
  static const uniformWinter        = {'ko': '동계',                  'en': 'Winter',               'vi': 'Dong',                    'uz': 'Qish',                      'km': 'រដូវរងា'};
  static const uniformEmpty         = {'ko': '신청한 피복이 없습니다', 'en': 'No requests yet',      'vi': 'Chua co yeu cau',         'uz': "Hali arizalar yo'q",        'km': 'មិនទាន់មានការស្នើសុំ'};
  static const uniformEmptyHint     = {'ko': '아래 + 버튼으로 신청하세요', 'en': 'Tap + to submit', 'vi': 'Nhan + de dang ky',       'uz': '+ tugmasini bosing',        'km': 'ចុច + ដើម្បីដាក់ស្នើ'};
  static const uniformNoData        = {'ko': '해당 기간에 신청 내역이 없습니다', 'en': 'No requests for this period', 'vi': 'Khong co yeu cau trong ky nay', 'uz': "Bu davrda arizalar yo'q", 'km': 'គ្មានការស្នើសុំក្នុងช่วงนี้'};
  static const uniformApproveOk     = {'ko': '승인되었습니다 ✅',      'en': 'Approved ✅',           'vi': 'Da duyet ✅',              'uz': 'Tasdiqlandi ✅',             'km': 'បានអនុម័ត ✅'};
  static const uniformRejectOk      = {'ko': '반려되었습니다',         'en': 'Rejected',             'vi': 'Da tu choi',              'uz': 'Rad etildi',                'km': 'បានបដិសេធ'};
  static const uniformError         = {'ko': '처리 중 오류가 발생했습니다', 'en': 'An error occurred', 'vi': 'Da xay ra loi',          'uz': 'Xato yuz berdi',            'km': 'មានកំហុសកើតឡើង'};
  static const uniformSubmitError   = {'ko': '신청 중 오류가 발생했습니다', 'en': 'Submission failed', 'vi': 'Gui yeu cau that bai',   'uz': 'Yuborishda xato',           'km': 'ការដាក់ស្នើបរាជ័យ'};
  static const uniformSubmitDone    = {'ko': '피복 신청 완료! ({n}개 품목) ✅', 'en': 'Submitted! ({n} items) ✅', 'vi': 'Da gui! ({n} san pham) ✅', 'uz': 'Yuborildi! ({n} ta) ✅', 'km': 'បានដាក់ស្នើ! ({n} ទំនិញ) ✅'};
  static const uniformYearSelect    = {'ko': '연도 선택',             'en': 'Select Year',          'vi': 'Chon nam',                'uz': 'Yilni tanlang',             'km': 'ជ្រើសរើសឆ្នាំ'};
  static const uniformMonthSelect   = {'ko': '월 선택',              'en': 'Select Month',          'vi': 'Chon thang',              'uz': 'Oyni tanlang',              'km': 'ជ្រើសរើសខែ'};
  static const uniformMonthAll      = {'ko': '전체',                 'en': 'All',                   'vi': 'Tat ca',                  'uz': 'Barchasi',                  'km': 'ទាំងអស់'};
  static const uniformPendingBadge  = {'ko': '대기 {n}',             'en': 'Pending {n}',           'vi': 'Cho {n}',                 'uz': 'Kutish {n}',                'km': 'រង់ចាំ {n}'};
  static const uniformTotal         = {'ko': '총 {n}건',             'en': 'Total {n}',             'vi': 'Tong {n}',                'uz': 'Jami {n}',                  'km': 'សរុប {n}'};

  // ── 휴가 실시간
  static const leaveRealtimeTitle  = {'ko': '실시간 휴가 현황',       'en': 'Live Leave Status',         'vi': 'Trang thai nghi phep',         'uz': "Jonli ta'til holati",        'km': 'ស្ថានភាព휴가ផ្ទាល់'};
  static const leaveOnToday        = {'ko': '오늘 휴가 중',           'en': 'On Leave Today',            'vi': 'Nghi phep hom nay',            'uz': "Bugun ta'tilda",             'km': 'ឈប់សំរាកថ្ងៃនេះ'};
  static const leaveOnTodayCount   = {'ko': '휴가 {n}명',            'en': '{n} on leave',              'vi': '{n} nghi phep',                'uz': "{n} ta ta'tilda",            'km': '{n} នាក់ឈប់សំរាក'};
  static const leaveOnTodayEmpty   = {'ko': '오늘 휴가 중인 직원이 없습니다', 'en': 'No one on leave today', 'vi': 'Khong co ai nghi hom nay', 'uz': "Bugun ta'tilda hech kim yo'q",'km': 'គ្មាននរណាឈប់សំរាកថ្ងៃនេះ'};
  static const leaveUpcoming       = {'ko': '예정된 휴가',            'en': 'Upcoming Leave',            'vi': 'Nghi phep sap toi',            'uz': "Kelgusi ta'til",             'km': 'ការឈប់សំរាកដែលនឹងមកដល់'};
  static const leaveUpcomingCount  = {'ko': '예정된 휴가 ({n}건)',    'en': 'Upcoming ({n})',            'vi': 'Sap nghi ({n})',               'uz': 'Rejalashtirilgan ({n})',      'km': 'នឹងមកដល់ ({n})'};
  static const leaveUpcomingEmpty  = {'ko': '예정된 휴가가 없습니다', 'en': 'No upcoming leaves',        'vi': 'Khong co lich nghi sap toi',   'uz': "Rejalashtirilgan ta'til yo'q",'km': 'គ្មានការឈប់សំរាកដែលនឹងមកដល់'};
  static const leaveReturnToday    = {'ko': '오늘 복귀',             'en': 'Returns today',             'vi': 'Ve hom nay',                   'uz': 'Bugun qaytadi',              'km': 'ត្រឡប់មកថ្ងៃនេះ'};
  static const leaveReturnTomorrow = {'ko': '내일',                  'en': 'Tomorrow',                  'vi': 'Ngay mai',                     'uz': 'Ertaga',                     'km': 'ថ្ងៃស្អែក'};
  static const leaveReturnDays     = {'ko': '{n}일 후 복귀',         'en': 'Returns in {n} days',       'vi': 'Ve sau {n} ngay',              'uz': '{n} kundan keyin qaytadi',   'km': 'ត្រឡប់ក្នុង {n} ថ្ងៃ'};
  static const leaveTypeAnnual     = {'ko': '연차',                  'en': 'Annual',                    'vi': 'Phep nam',                     'uz': 'Yillik',                     'km': 'ប្រចាំឆ្នាំ'};
  static const leaveTypeHalf       = {'ko': '반차',                  'en': 'Half Day',                  'vi': 'Nua ngay',                     'uz': 'Yarim kun',                  'km': 'ពាក់កណ្ដាលថ្ងៃ'};
  static const leaveTypePublic     = {'ko': '공가',                  'en': 'Official',                  'vi': 'Cong vu',                      'uz': 'Rasmiy',                     'km': 'ផ្លូវការ'};
  static const leaveTypeEvent      = {'ko': '경조사',                'en': 'Special',                   'vi': 'Dac biet',                     'uz': 'Maxsus',                     'km': 'ពិសេស'};

// ── 비품/고장 신고
  static const repairTitle        = {'ko': '고장 및 비품 신고',           'en': 'Repair & Equipment',       'vi': 'Bao hong & Trang thiet bi', 'uz': "Ta'mirlash va jihozlar",    'km': 'ជួសជុល & ឧបករណ៍'};
  static const repairDialog       = {'ko': '고장 / 비품 신고',            'en': 'Report Issue',             'vi': 'Bao cao su co',             'uz': "Muammoni bildirish",        'km': 'រាយការណ៍បញ្ហា'};
  static const repairCategory     = {'ko': '카테고리',                    'en': 'Category',                 'vi': 'Danh muc',                  'uz': 'Kategoriya',                'km': 'ប្រភេទ'};
  static const repairCatFacility  = {'ko': '시설고장',                    'en': 'Facility',                 'vi': 'Co so vat chat',            'uz': 'Inshoot',                   'km': '施設'};
  static const repairCatEquip     = {'ko': '비품요청',                    'en': 'Equipment',                'vi': 'Trang thiet bi',            'uz': 'Jihozlar',                  'km': 'ឧបករណ៍'};
  static const repairCatEtc       = {'ko': '기타문의',                    'en': 'Other',                    'vi': 'Khac',                      'uz': 'Boshqa',                    'km': 'ផ្សេងៗ'};
  static const repairDetail       = {'ko': '상세 내용',                   'en': 'Details',                  'vi': 'Chi tiet',                  'uz': 'Tafsilotlar',               'km': 'លម្អិត'};
  static const repairDetailHint   = {'ko': '고장 내용이나 요청 사항을 적어주세요.', 'en': 'Describe the issue or request.', 'vi': 'Mo ta su co hoac yeu cau.', 'uz': 'Muammo yoki talabni tavsiflang.', 'km': 'ពិពណ៌នាបញ្ហា ឬការស្នើសុំ។'};
  static const repairRoomError    = {'ko': '호실 정보를 불러올 수 없습니다.', 'en': 'Cannot load room info.', 'vi': 'Khong tai duoc thong tin phong.', 'uz': "Xona ma'lumotini yuklab bo'lmadi.", 'km': 'មិនអាចផ្ទុកព័ត៌មានបន្ទប់បាន។'};
  static const repairValidation   = {'ko': '호실과 내용을 모두 입력해주세요.', 'en': 'Please fill in room and details.', 'vi': 'Vui long nhap phong va noi dung.', 'uz': "Xona va tafsilotlarni to'ldiring.", 'km': 'សូមបំពេញបន្ទប់ និងលម្អិត។'};
  static const repairSubmit       = {'ko': '신고 등록',                   'en': 'Submit Report',            'vi': 'Gui bao cao',               'uz': 'Hisobot yuborish',          'km': 'ដាក់ស្នើរបាយការណ៍'};
  static const repairBtn          = {'ko': '신고하기',                    'en': 'Report',                   'vi': 'Bao cao',                   'uz': 'Bildirish',                 'km': 'រាយការណ៍'};
  static const repairStatusAll    = {'ko': '전체',                        'en': 'All',                      'vi': 'Tat ca',                    'uz': 'Barchasi',                  'km': 'ទាំងអស់'};
  static const repairStatusPending = {'ko': '접수완료',                   'en': 'Received',                 'vi': 'Da tiep nhan',              'uz': 'Qabul qilindi',             'km': 'បានទទួល'};
  static const repairStatusInProgress = {'ko': '수리중',                  'en': 'In Progress',              'vi': 'Dang sua',                  'uz': 'Jarayonda',                 'km': 'កំពុងជួសជុល'};
  static const repairStatusDone   = {'ko': '완료',                        'en': 'Done',                     'vi': 'Hoan thanh',                'uz': 'Bajarildi',                 'km': 'រួចរាល់'};
  static const repairEmpty        = {'ko': '해당하는 신고 내역이 없습니다.', 'en': 'No reports found.',      'vi': 'Khong co bao cao nao.',     'uz': "Hisobotlar yo'q.",           'km': 'រកមិនឃើញរបាយការណ៍។'};
  static const repairChangeStatus = {'ko': '상태 변경',                   'en': 'Change Status',            'vi': 'Doi trang thai',            'uz': 'Holatni o\'zgartirish',     'km': 'ផ្លាស់ប្ដូរស្ថានភាព'};
  static const repairStatusChanged = {'ko': "상태가 '{s}'(으)로 변경되었습니다.", 'en': "Status changed to '{s}'.", 'vi': "Trang thai da doi thanh '{s}'.", 'uz': "Holat '{s}' ga o'zgartirildi.", 'km': "ស្ថានភាពផ្លាស់ប្ដូរទៅ '{s}'។"};
}