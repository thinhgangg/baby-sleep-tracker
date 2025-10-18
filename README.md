# 👶 Baby Sleep Tracker (Theo dõi Giấc ngủ Em bé)

Ứng dụng web thời gian thực được thiết kế để giúp cha mẹ theo dõi giấc ngủ, sức khỏe và môi trường xung quanh em bé thông qua dữ liệu cảm biến và luồng camera.

---

## ✨ Tính năng Nổi bật

* **Theo dõi Trực tiếp (Real-time Monitoring):** Cập nhật ngay lập tức các chỉ số quan trọng như nhiệt độ bé, trạng thái ngủ, và tình trạng khóc.
* **Cảnh báo Khẩn cấp Thông minh:** Cảnh báo **ngay lập tức** về các tình trạng nguy hiểm (sốt, khóc) và các điều kiện môi trường bất thường.
* **Xem Camera:** Tích hợp luồng video/WebRTC để theo dõi trực quan em bé.
* **Phân tích Xu hướng:** Biểu đồ hiển thị nhiệt độ em bé, nhiệt độ phòng và độ ẩm trong 24 giờ gần nhất sử dụng **Chart.js**.
* **Xác thực Người dùng:** Đăng nhập/Đăng ký an toàn bằng **Firebase Authentication**.

---

## 🛠️ Công nghệ Sử dụng

* **Frontend:** HTML5, CSS3, JavaScript (ES Modules)
* **Data/Backend:** **Firebase Realtime Database**
* **Authentication:** **Firebase Authentication**
* **Charting:** **Chart.js**
* **Build Tool:** **Vite**

---

## 🚀 Hướng dẫn Cài đặt & Chạy Dự án

### 1. Prerequisites

Cài đặt **Node.js** (phiên bản LTS) và **npm** (hoặc yarn/pnpm).

### 2. Clone Repository

```bash
git clone https://github.com/thinhgangg/baby-sleep-tracker.git
cd baby-sleep-tracker
```

### 3. Install Dependencies

```bash
npm install
# hoặc yarn install
```

### 4. Firebase Configuration

Tạo một dự án Firebase.

Tạo tệp .env trong thư mục gốc.

Thêm các khóa API của dự án Firebase (tìm thấy trong Project settings > SDK setup and configuration):

```env
VITE_FIREBASE_API_KEY="YOUR_API_KEY"
VITE_FIREBASE_AUTH_DOMAIN="YOUR_AUTH_DOMAIN"
VITE_FIREBASE_PROJECT_ID="YOUR_PROJECT_ID"
VITE_FIREBASE_STORAGE_BUCKET="YOUR_STORAGE_BUCKET"
VITE_FIREBASE_MESSAGING_SENDER_ID="YOUR_MESSAGING_SENDER_ID"
VITE_FIREBASE_APP_ID="YOUR_APP_ID"
VITE_FIREBASE_DATABASE_URL="YOUR_DATABASE_URL"
# Ví dụ: https://baby-tracker-default-rtdb.firebaseio.com
```

### 5. Launch the Application
```bash
npm run dev
# hoặc yarn dev
```


