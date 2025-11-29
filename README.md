# Baby Sleep Tracker

![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue?logo=flutter)
![Dart Version](https://img.shields.io/badge/Dart-%3E%3D2.17.0-blue?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange?logo=firebase)
![License](https://img.shields.io/badge/License-MIT-green)

**Baby Sleep Tracker** là một ứng dụng Flutter gọn nhẹ giúp cha mẹ giám sát giấc ngủ và môi trường xung quanh bé theo thời gian thực. Ứng dụng đọc dữ liệu cảm biến (nhiệt độ, độ ẩm, tư thế ngủ, tiếng khóc) từ Firebase Realtime Database và hiển thị cảnh báo ngay lập tức, giúp gia đình yên tâm hơn khi chăm sóc bé.

---

## Tính Năng Chính

-   **Giám sát Thời gian thực:** Theo dõi trực tiếp các chỉ số cảm biến: Nhiệt độ cơ thể, Nhiệt độ phòng, Độ ẩm, Tư thế nằm, Trạng thái khóc.
-   **Xác thực & Bảo mật:** Đăng nhập bằng số điện thoại (OTP) và liên kết thiết bị giữa các thành viên gia đình qua mã QR.
-   **Hệ thống Cảnh báo:**
    -   Tự động cảnh báo khi các chỉ số vượt ngưỡng an toàn (do người dùng cài đặt).
    -   Thông báo đẩy (Push Notification) và thông báo cục bộ (Local Notification).
    -   **Background Service:** Dịch vụ chạy ngầm giúp duy trì cảnh báo ngay cả khi tắt màn hình.
-   **Biểu đồ Lịch sử:** Xem lại lịch sử giấc ngủ và môi trường qua biểu đồ trực quan.

---

## Tech Stack

### Core

-   **Framework:** Flutter (Dart) - Hỗ trợ Android & iOS.
-   **Backend:** Firebase Realtime Database, Firebase Authentication (Phone/OTP), Firebase Cloud Messaging (FCM).

### Thư viện quan trọng

-   `flutter_background_service`: Xử lý tác vụ chạy ngầm để giám sát liên tục.
-   `flutter_local_notifications`: Hiển thị thông báo trên thiết bị.
-   `mobile_scanner` / `qr_flutter`: Quét và tạo mã QR để chia sẻ quyền truy cập.
-   `fl_chart`: Vẽ biểu đồ lịch sử nhiệt độ/độ ẩm.
-   `shared_preferences`: Lưu trữ cấu hình cục bộ.

### State Management

-   Sử dụng kết hợp `StatefulWidget`, `Streams` và `StreamBuilder` để phản hồi dữ liệu thời gian thực từ Firebase một cách hiệu quả nhất.

---

## Cài đặt & Chạy Dự Án

### 1. Yêu cầu tiên quyết

-   Flutter SDK đã được cài đặt.
-   Tài khoản Firebase và một Project đã được tạo trên Firebase Console.

### 2. Cấu hình Firebase

Dự án yêu cầu các file cấu hình từ Firebase:

-   **Android:** Tải `google-services.json` và đặt vào `android/app/`.
-   **iOS:** Tải `GoogleService-Info.plist` và đặt vào `ios/Runner/`.
-   **FlutterFire:** Đảm bảo file `lib/firebase_options.dart` đã được tạo (thường dùng `flutterfire configure`).

### 3. Cài đặt Dependencies

Chạy lệnh sau tại thư mục gốc của dự án:

```bash
flutter pub get
```

### 4. Chạy ứng dụng

```bash
# Kiểm tra lỗi
flutter analyze

# Chạy trên thiết bị
flutter run
```
