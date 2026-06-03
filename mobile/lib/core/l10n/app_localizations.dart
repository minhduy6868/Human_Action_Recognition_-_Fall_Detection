import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'english': 'English',
      'vietnamese': 'Tiếng Việt',
      'title': 'Video AI Detect',
      'failed': 'Failed',
      'failed_to_load_sources': 'Failed to load sources',
      'activated': 'Activated',
      'activate_failed': 'Activate failed',
      'stopped': 'Stopped',
      'stop_failed': 'Stop failed',
      'delete_source': 'Delete source',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'deleted': 'Deleted',
      'delete_failed': 'Delete failed',
      'rtsp': 'RTSP',
      'file': 'File',
      'webcam_index': 'Webcam (index)',
      'http_mjpeg': 'HTTP MJPEG',
      'mjpeg': 'MJPEG',
      'activate_after_save': 'Activate after save',
      'save_failed': 'Save failed',
      'camera_sources': 'Camera sources',
      'quick_source': 'Quick source',
      'active_source': 'Active source',
      'camera_sources_subtitle':
          'Create, edit, activate, or stop streams without leaving the app.',
      'no_sources_configured': 'No sources configured yet',
      'create_first_camera_source':
          'Create the first camera source to start live monitoring.',
      'create_source': 'Create source',
      'refresh': 'Refresh',
      'retry': 'Retry',
      'no_reports_available': 'No reports available',
      'edit': 'Edit',
      'stop': 'Stop',
      'activate': 'Activate',
      'manage': 'Manage',
      'no_camera_sources_yet': 'No camera sources yet.',
      'recent_activity': 'Recent activity',
      'open_reports': 'Open reports',
      'sync_data': 'Sync data',
      'activity_history': 'Activity history',
      'review_realtime_events':
          'Review realtime events and fall-related actions captured by the backend.',
      'no_history_items': 'No history items yet',
      'refresh_after_backend':
          'Refresh after the backend starts emitting events.',
      'fall_detection_title': 'Fall Detection',
      'live_camera_feed': 'Live camera feed',
      'realtime_snapshot': 'Realtime snapshot',
      'system_snapshot': 'System snapshot',
      'switch_between_light_and_dark': 'Switch between light and dark themes',
      'track': 'Track',
      'edit_source': 'Edit source',
      'source_type': 'Source type',
      'url_index_path': 'URL / index / path',
      'source_created': 'Source created',
      'source_updated': 'Source updated',
      'save_changes': 'Save changes',
      'window': 'Window',
      'reports_subtitle':
          'Summaries generated from the backend history pipeline and monitoring windows.',
      'report': 'Report',
      'logs': 'Logs',
      'no_log_message_provided': 'No log message provided',
      'no_logs_available': 'No logs available',
      'home': 'Home',
      'analytics': 'Analytics',
      'ai': 'AI',
      'appearance': 'Appearance',
      'control_center': 'Control Center',
      'unable_to_load_data': 'Unable to load data',
      'no_active_source_selected': 'No active source selected',
      'stream_unavailable': 'Stream unavailable',
      'no_stream_available': 'No stream available',
      'updated': 'Updated',
      'fall_monitor': 'Fall monitor',
      'realtime_alert_view': 'Realtime alert view',
      'detection_events_will_appear':
          'Detection events will appear here once the backend starts streaming.',
      'monitor': 'Monitor',
      'connecting_to_backend': 'Connecting to backend',
      'waiting_for_realtime_stream': 'Waiting for realtime stream...',
      'fall_alert': 'FALL ALERT',
      'immediate_assistance_recommended': 'Immediate assistance recommended',
      'telegram_notifications': 'Telegram notifications',
      'push_notifications': 'Push notifications',
      'notification_setup': 'Notification setup',
      'unknown': 'Unknown',
      'active': 'Active',
      'idle': 'Idle',
      'connected': 'Connected',
      'connecting': 'Connecting...',
      'connection_error': 'Connection error',
      'live': 'Live',
      'reconnecting': 'Reconnecting',
      'waiting': 'Waiting',
      'unknown_clothing': 'Unknown clothing',
      'history': 'History',
      'summary': 'Summary',
      'chat': 'Chat',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'darkMode': 'Dark Mode',
      'action': 'Action',
      'confidence': 'Confidence',
      'fall_detected': 'Fall Detected',
      'no_data': 'No data available',
      'admin_tip': 'Tip: Use the admin account created by backend seed.',
      'secure_access': 'Secure access to realtime monitoring and fall alerts.',
      'sign_in': 'Sign in',
      'email': 'Email',
      'password': 'Password',
      'continue_btn': 'Continue',
      'continue_with_google': 'Continue with Google',
      'back_to_login': 'Back to login',
      'create_account': 'Create account',
      'forgot_password': 'Forgot password?',
      'email_required': 'Email is required',
      'password_required': 'Password is required',
      'register': 'Register',
      'name': 'Name',
      'full_name': 'Full name',
      'full_name_optional': 'Full name (optional)',
      'confirm_password': 'Confirm Password',
      'email_required_short': 'Email required',
      'password_min_chars': 'Min 6 chars',
      'passwords_do_not_match': 'Passwords do not match',
      'google_login_failed_missing_token':
          'Google login failed: missing ID token',
      'forgot_password_title': 'Forgot Password',
      'send_otp': 'Send OTP',
      'reset_password_title': 'Reset Password',
      'otp_code': 'OTP code',
      'otp_required': 'OTP is required',
      'new_password': 'New password',
      'confirm_new_password': 'Confirm new password',
      'set_password': 'Set password',
      'account_created_success':
          'Account created successfully. Please sign in.',
      'otp_sent_success':
          'OTP sent. Check your email or use the code shown in debug mode.',
      'password_reset_success':
          'Password reset successful. You can sign in now.',
      'email_hint_reset': 'Enter the email address used for your account',
      'email_hint_register': 'Use a valid email address to create your account',
      'ai_assistant': 'AI Assistant',
      'ai_is_thinking': 'AI is thinking...',
      'ask_about_home': 'Ask about your home...',
      'manage_sources': 'Manage Sources',
      'add_edit_remove_cameras': 'Add, edit, or remove cameras',
      'view_detection_history': 'View detection history',
      'system_logs': 'System logs and events',
      'view_activity_reports': 'View activity reports',
      'monitoring': 'Monitoring',
      'reports': 'Reports',
      'logout': 'Logout',
      'settings_management': 'Settings & Management',
      'camera': 'Camera',
      'vip_promo_title': 'Upgrade to VIP',
      'vip_promo_subtitle':
          'Unlock multiple cameras, unlimited AI queries, and extended history.',
      'vip_promo_subtitle_short': 'Multiple cameras & unlimited AI',
      'upgrade_vip': 'Upgrade VIP',
      'upgrade_vip_short': 'Upgrade VIP',
      'upgrade_vip_via': '@Codebox88',
      'admin_panel': 'Admin',
      'vip_upgrade_title': 'VIP Membership',
      'plan_comparison': 'Plan comparison',
      'current_plan': 'Current',
      'how_to_upgrade': 'How to upgrade',
      'upgrade_contact_admin':
          'Message @Codebox88 on Telegram to activate VIP on your account.',
      'upgrade_via_telegram':
          'Contact @Codebox88 on Telegram to upgrade your VIP plan.',
      'open_telegram_codebox88': 'Message @Codebox88 on Telegram',
      'telegram_open_failed': 'Could not open Telegram. Install the app or try again.',
      'admin_can_upgrade_hint':
          'As admin, open Admin users in Settings to upgrade any account instantly.',
      'vip_active_message': 'You are on the VIP plan with full access.',
      'vip_member': 'VIP Member',
      'free_feature_sources': '1 camera source, 1 active stream',
      'free_feature_ai': '20 AI queries per day',
      'free_feature_history': '24-hour history window',
      'vip_feature_sources': 'Unlimited camera sources',
      'vip_feature_ai': 'Unlimited AI queries',
      'vip_feature_history': 'Extended history retention',
      'vip_feature_reports': 'Multi-day reports and summaries',
      'administration': 'Administration',
      'admin_users_title': 'Manage users',
      'admin_users_subtitle': 'Change roles and VIP plans',
      'search_users': 'Search by email or name',
      'no_users_found': 'No users found',
      'user_updated': 'User updated',
      'role': 'Role',
      'plan': 'Plan',
      'role_user': 'User',
      'role_admin': 'Admin',
      'admin_tab_overview': 'Overview',
      'admin_tab_users': 'Users',
      'admin_stat_total': 'Users',
      'admin_stat_free': 'Free',
      'admin_stat_vip': 'VIP',
      'admin_stat_sources': 'Sources',
      'admin_filter_all': 'All',
      'admin_make_vip': 'Set VIP',
      'admin_make_free': 'Set Free',
      'admin_user_sources': 'Sources',
      'admin_sources_short': 'sources',
      'delete_user': 'Delete user',
      'user_deleted': 'User deleted',
    },
    'vi': {
      'english': 'English',
      'vietnamese': 'Tiếng Việt',
      'title': 'Phát hiện hành động AI',
      'failed': 'Thất bại',
      'failed_to_load_sources': 'Tải nguồn thất bại',
      'activated': 'Đã kích hoạt',
      'activate_failed': 'Kích hoạt thất bại',
      'stopped': 'Đã dừng',
      'stop_failed': 'Dừng thất bại',
      'delete_source': 'Xóa nguồn',
      'cancel': 'Hủy',
      'delete': 'Xóa',
      'deleted': 'Đã xóa',
      'delete_failed': 'Xóa thất bại',
      'rtsp': 'RTSP',
      'file': 'Tệp',
      'webcam_index': 'Webcam (index)',
      'http_mjpeg': 'HTTP MJPEG',
      'mjpeg': 'MJPEG',
      'activate_after_save': 'Kích hoạt sau khi lưu',
      'save_failed': 'Lưu thất bại',
      'camera_sources': 'Nguồn camera',
      'quick_source': 'Chọn nguồn nhanh',
      'active_source': 'Nguồn đang dùng',
      'camera_sources_subtitle':
          'Tạo, chỉnh sửa, kích hoạt, hoặc dừng luồng mà không rời app.',
      'no_sources_configured': 'Chưa có nguồn nào được cấu hình',
      'create_first_camera_source':
          'Tạo nguồn camera đầu tiên để bắt đầu giám sát.',
      'create_source': 'Tạo nguồn',
      'refresh': 'Làm mới',
      'retry': 'Thử lại',
      'no_reports_available': 'Chưa có báo cáo',
      'edit': 'Chỉnh sửa',
      'stop': 'Dừng',
      'activate': 'Kích hoạt',
      'manage': 'Quản lý',
      'no_camera_sources_yet': 'Chưa có nguồn camera.',
      'recent_activity': 'Hoạt động gần đây',
      'open_reports': 'Mở báo cáo',
      'sync_data': 'Đồng bộ dữ liệu',
      'activity_history': 'Lịch sử hoạt động',
      'review_realtime_events':
          'Xem sự kiện thời gian thực và hành động liên quan đến té ngã được backend ghi lại.',
      'no_history_items': 'Chưa có mục lịch sử nào',
      'refresh_after_backend': 'Làm mới sau khi backend bắt đầu phát sự kiện.',
      'fall_detection_title': 'Phát hiện té ngã',
      'live_camera_feed': 'Luồng camera trực tiếp',
      'realtime_snapshot': 'Ảnh chụp thời gian thực',
      'system_snapshot': 'Ảnh chụp hệ thống',
      'switch_between_light_and_dark': 'Chuyển giữa giao diện sáng và tối',
      'track': 'Track',
      'edit_source': 'Chỉnh sửa nguồn',
      'source_type': 'Loại nguồn',
      'url_index_path': 'URL / index / đường dẫn',
      'source_created': 'Đã tạo nguồn',
      'source_updated': 'Cập nhật nguồn',
      'save_changes': 'Lưu thay đổi',
      'window': 'Cửa sổ',
      'reports_subtitle':
          'Tóm tắt được tạo từ pipeline lịch sử của backend và cửa sổ giám sát.',
      'report': 'Báo cáo',
      'logs': 'Nhật ký',
      'no_log_message_provided': 'Không có nội dung nhật ký',
      'no_logs_available': 'Không có nhật ký',
      'home': 'Trang chủ',
      'analytics': 'Phân tích',
      'ai': 'AI',
      'appearance': 'Giao diện',
      'control_center': 'Trung tâm điều khiển',
      'unable_to_load_data': 'Không thể tải dữ liệu',
      'no_active_source_selected': 'Chưa chọn nguồn hoạt động',
      'stream_unavailable': 'Luồng không khả dụng',
      'no_stream_available': 'Không có luồng',
      'updated': 'Đã cập nhật',
      'fall_monitor': 'Giám sát té ngã',
      'realtime_alert_view': 'Xem cảnh báo thời gian thực',
      'detection_events_will_appear':
          'Các sự kiện phát hiện sẽ xuất hiện ở đây khi backend bắt đầu phát luồng.',
      'monitor': 'Giám sát',
      'connecting_to_backend': 'Đang kết nối tới backend',
      'waiting_for_realtime_stream': 'Đang chờ luồng thời gian thực...',
      'fall_alert': 'CẢNH BÁO TÉ NGÃ',
      'immediate_assistance_recommended': 'Khuyến nghị hỗ trợ ngay lập tức',
      'telegram_notifications': 'Thông báo Telegram',
      'push_notifications': 'Thông báo đẩy',
      'notification_setup': 'Thiết lập thông báo',
      'unknown': 'Không xác định',
      'active': 'Đang hoạt động',
      'idle': 'Không hoạt động',
      'connected': 'Đã kết nối',
      'connecting': 'Đang kết nối...',
      'connection_error': 'Lỗi kết nối',
      'live': 'Trực tiếp',
      'reconnecting': 'Đang kết nối lại',
      'waiting': 'Đang chờ',
      'unknown_clothing': 'Trang phục không xác định',
      'history': 'Lịch sử',
      'summary': 'Tóm tắt',
      'chat': 'Trò chuyện',
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'camera': 'Camera',
      'theme': 'Giao diện',
      'darkMode': 'Chế độ tối',
      'action': 'Hành động',
      'confidence': 'Độ tin cậy',
      'fall_detected': 'Phát hiện té ngã',
      'no_data': 'Không có dữ liệu',
      'admin_tip': 'Mẹo: Sử dụng tài khoản admin được tạo bởi backend seed.',
      'secure_access':
          'Truy cập an toàn để giám sát theo thời gian thực và cảnh báo té ngã.',
      'sign_in': 'Đăng nhập',
      'email': 'Email',
      'password': 'Mật khẩu',
      'continue_btn': 'Tiếp tục',
      'continue_with_google': 'Tiếp tục với Google',
      'back_to_login': 'Quay lại đăng nhập',
      'create_account': 'Tạo tài khoản',
      'forgot_password': 'Quên mật khẩu?',
      'email_required': 'Email là bắt buộc',
      'password_required': 'Mật khẩu là bắt buộc',
      'register': 'Đăng ký',
      'name': 'Tên',
      'full_name': 'Họ và tên',
      'full_name_optional': 'Họ và tên (không bắt buộc)',
      'confirm_password': 'Xác nhận mật khẩu',
      'email_required_short': 'Email bắt buộc',
      'password_min_chars': 'Tối thiểu 6 ký tự',
      'passwords_do_not_match': 'Mật khẩu không khớp',
      'google_login_failed_missing_token':
          'Đăng nhập Google thất bại: thiếu ID token',
      'forgot_password_title': 'Quên mật khẩu',
      'send_otp': 'Gửi OTP',
      'reset_password_title': 'Đặt lại mật khẩu',
      'otp_code': 'Mã OTP',
      'otp_required': 'Mã OTP là bắt buộc',
      'new_password': 'Mật khẩu mới',
      'confirm_new_password': 'Xác nhận mật khẩu mới',
      'set_password': 'Đặt mật khẩu',
      'account_created_success':
          'Tạo tài khoản thành công. Vui lòng đăng nhập.',
      'otp_sent_success':
          'Đã gửi OTP. Kiểm tra email hoặc dùng mã hiển thị ở chế độ debug.',
      'password_reset_success':
          'Đặt lại mật khẩu thành công. Bạn có thể đăng nhập ngay.',
      'email_hint_reset': 'Nhập email bạn đã dùng để tạo tài khoản',
      'email_hint_register': 'Nhập email hợp lệ để tạo tài khoản',
      'ai_assistant': 'Trợ lý AI',
      'ai_is_thinking': 'AI đang suy nghĩ...',
      'ask_about_home': 'Hỏi về nhà của bạn...',
      'manage_sources': 'Quản lý nguồn',
      'add_edit_remove_cameras': 'Thêm, chỉnh sửa hoặc xóa camera',
      'view_detection_history': 'Xem lịch sử phát hiện',
      'system_logs': 'Nhật ký hệ thống và sự kiện',
      'view_activity_reports': 'Xem báo cáo hoạt động',
      'monitoring': 'Giám sát',
      'reports': 'Báo cáo',
      'logout': 'Đăng xuất',
      'settings_management': 'Cài đặt & Quản lý',
      'vip_promo_title': 'Nâng cấp VIP',
      'vip_promo_subtitle':
          'Mở khóa nhiều camera, hỏi AI không giới hạn và lịch sử dài hơn.',
      'vip_promo_subtitle_short': 'Nhiều camera & AI không giới hạn',
      'upgrade_vip': 'Nâng VIP',
      'upgrade_vip_short': 'Nâng VIP',
      'upgrade_vip_via': '@Codebox88',
      'admin_panel': 'Quản trị',
      'vip_upgrade_title': 'Gói VIP',
      'plan_comparison': 'So sánh gói',
      'current_plan': 'Đang dùng',
      'how_to_upgrade': 'Cách nâng cấp',
      'upgrade_contact_admin':
          'Nhắn Telegram @Codebox88 để kích hoạt gói VIP cho tài khoản của bạn.',
      'upgrade_via_telegram':
          'Liên hệ @Codebox88 trên Telegram để nâng cấp gói VIP.',
      'open_telegram_codebox88': 'Nhắn Telegram @Codebox88',
      'telegram_open_failed':
          'Không mở được Telegram. Hãy cài app Telegram hoặc thử lại.',
      'admin_can_upgrade_hint':
          'Với quyền admin, vào Quản lý người dùng trong Cài đặt để nâng VIP ngay.',
      'vip_active_message': 'Bạn đang dùng gói VIP với đầy đủ quyền.',
      'vip_member': 'Thành viên VIP',
      'free_feature_sources': '1 nguồn camera, 1 luồng active',
      'free_feature_ai': '20 lượt hỏi AI mỗi ngày',
      'free_feature_history': 'Lịch sử trong 24 giờ',
      'vip_feature_sources': 'Không giới hạn nguồn camera',
      'vip_feature_ai': 'Hỏi AI không giới hạn',
      'vip_feature_history': 'Lưu lịch sử dài hơn',
      'vip_feature_reports': 'Báo cáo và tóm tắt nhiều ngày',
      'administration': 'Quản trị',
      'admin_users_title': 'Quản lý tài khoản',
      'admin_users_subtitle': 'Đổi vai trò và nâng gói VIP',
      'search_users': 'Tìm theo email hoặc tên',
      'no_users_found': 'Không tìm thấy người dùng',
      'user_updated': 'Đã cập nhật người dùng',
      'role': 'Vai trò',
      'plan': 'Gói',
      'role_user': 'Người dùng',
      'role_admin': 'Admin',
      'admin_tab_overview': 'Tổng quan',
      'admin_tab_users': 'Tài khoản',
      'admin_stat_total': 'Người dùng',
      'admin_stat_free': 'Free',
      'admin_stat_vip': 'VIP',
      'admin_stat_sources': 'Nguồn',
      'admin_filter_all': 'Tất cả',
      'admin_make_vip': 'Nâng VIP',
      'admin_make_free': 'Hạ Free',
      'admin_user_sources': 'Nguồn video',
      'admin_sources_short': 'nguồn',
      'delete_user': 'Xóa tài khoản',
      'user_deleted': 'Đã xóa tài khoản',
    },
  };

  String translate(String key) {
    final langCode = locale.languageCode;
    return _localizedStrings[langCode]?[key] ??
        _localizedStrings['en']?[key] ??
        key;
  }

  String actionLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'standing':
        return locale.languageCode == 'vi' ? 'Đứng' : 'Standing';
      case 'walking':
        return locale.languageCode == 'vi' ? 'Đi bộ' : 'Walking';
      case 'running':
        return locale.languageCode == 'vi' ? 'Chạy' : 'Running';
      case 'sitting':
        return locale.languageCode == 'vi' ? 'Ngồi' : 'Sitting';
      case 'lying':
        return locale.languageCode == 'vi' ? 'Nằm' : 'Lying';
      case 'crouching':
        return locale.languageCode == 'vi' ? 'Ngồi xổm' : 'Crouching';
      case 'fall':
        return locale.languageCode == 'vi' ? 'Té ngã' : 'Fall';
      case 'unknown':
      case 'idle':
        return translate(raw.toLowerCase());
      default:
        return raw.isEmpty ? translate('unknown') : raw;
    }
  }

  String actionLabelUpper(String raw) => actionLabel(raw).toUpperCase();

  String statusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'active':
      case 'idle':
      case 'connected':
      case 'connecting':
      case 'connection_error':
      case 'live':
      case 'reconnecting':
      case 'waiting':
        return translate(raw.toLowerCase());
      default:
        return raw.isEmpty ? translate('unknown') : raw;
    }
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
