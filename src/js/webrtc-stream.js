// src/js/webrtc-stream.js

import { database, ref, set, push, auth } from "./firebase-config.js";
import { onValue } from "firebase/database";

let pc = null; // Đối tượng RTCPeerConnection

// Lấy thông tin Server ICE/STUN/TURN (cần thiết để kết nối)
const iceServers = {
    iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        // Thêm các server TURN của riêng bạn ở đây nếu cần cho mạng phức tạp
    ],
};

/**
 * Khởi tạo kết nối WebRTC để nhận luồng video từ Raspberry Pi.
 * Sử dụng Firebase Realtime Database làm Signaling Server.
 */
export function startWebRTCStream() {
    // 1. Kiểm tra trạng thái đăng nhập
    if (!auth.currentUser) {
        console.error("Lỗi WebRTC: Người dùng chưa đăng nhập.");
        return;
    }

    // 2. Thiết lập tham chiếu Firebase và UI
    const userId = auth.currentUser.uid;
    const sessionRef = ref(database, `webrtc_sessions/${userId}`);
    const cameraVideo = document.getElementById("baby-camera");

    if (pc) {
        console.log("WebRTC đã kết nối hoặc đang kết nối. Đóng kết nối cũ.");
        pc.close();
    }

    // 3. Tạo Peer Connection
    pc = new RTCPeerConnection(iceServers);

    // --- CÁC SỰ KIỆN CỦA PEER CONNECTION PHÍA WEB APP (CLIENT) ---

    // 4. Xử lý Remote Stream (Video từ Pi)
    pc.ontrack = (event) => {
        if (event.streams && event.streams[0]) {
            cameraVideo.srcObject = event.streams[0];
            console.log("WebRTC: Stream video từ Pi đã nhận.");
        }
    };

    // 5. Xử lý ICE Candidates của Web App
    // Gửi thông tin kết nối của Web App lên Firebase cho Pi biết
    pc.onicecandidate = async (event) => {
        if (event.candidate) {
            console.log("WebRTC: Gửi ICE Candidate Web App lên Firebase.");
            // Đẩy candidate của web lên node 'web_candidates'
            await push(ref(database, `webrtc_sessions/${userId}/iceCandidates/web_candidates`), event.candidate.toJSON());
        }
    };

    // 6. Lắng nghe SDP Offer từ Pi (Bước 1: Pi tạo Offer và đẩy lên Firebase)
    onValue(
        ref(database, `webrtc_sessions/${userId}/offer`),
        async (snapshot) => {
            const offerData = snapshot.val();
            // Chỉ xử lý Offer khi có dữ liệu và chưa có remoteDescription (tránh lặp lại)
            if (offerData && !pc.remoteDescription) {
                console.log("WebRTC: Nhận SDP Offer từ Pi. Bắt đầu tạo Answer.");

                // Set Offer làm Remote Description
                await pc.setRemoteDescription(new RTCSessionDescription(offerData));

                // Tạo SDP Answer
                const answer = await pc.createAnswer();
                await pc.setLocalDescription(answer);

                // Gửi SDP Answer trở lại Pi qua Firebase
                console.log("WebRTC: Gửi SDP Answer lên Firebase.");
                await set(ref(sessionRef, "answer"), answer.toJSON());
            }
        },
        { onlyOnce: true }
    ); // Lắng nghe Offer chỉ một lần

    // 7. Lắng nghe ICE Candidates của Pi
    // Pi sẽ đẩy các candidate của nó lên node 'pi_candidates'
    onValue(ref(database, `webrtc_sessions/${userId}/iceCandidates/pi_candidates`), (snapshot) => {
        const candidates = snapshot.val();
        if (candidates) {
            // Lặp qua tất cả candidates mới nhận được
            Object.values(candidates).forEach((candidateData) => {
                const candidate = new RTCIceCandidate(candidateData);
                if (pc && pc.remoteDescription) {
                    pc.addIceCandidate(candidate).catch((e) => console.error("WebRTC: Lỗi thêm ICE candidate:", e));
                }
            });
            // Tùy chọn: Xóa các candidate đã xử lý trên Firebase để làm sạch
            // set(ref(sessionRef, 'iceCandidates/pi_candidates'), null);
        }
    });
}

/**
 * Đóng kết nối WebRTC khi người dùng đăng xuất.
 */
export function closeWebRTCStream() {
    if (pc) {
        pc.close();
        pc = null;
        console.log("WebRTC: Đã đóng kết nối.");
    }
    // (Tùy chọn) Xóa session data trên Firebase khi người dùng đăng xuất
}
