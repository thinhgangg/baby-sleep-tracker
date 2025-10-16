// src/js/main.js

import { database, ref, set, push, auth } from "./firebase-config.js";
import { onValue, query, limitToLast } from "firebase/database";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword, onAuthStateChanged, signOut } from "firebase/auth";
import { startWebRTCStream, closeWebRTCStream } from "./webrtc-stream.js";
import Chart from "chart.js/auto";

const REFS = {
    sleepData: ref(database, "sleepData"),
    userEvents: ref(database, "userEvents"),
};

const THRESHOLDS = {
    BABY_TEMP_DANGER: 37.5,
    BABY_TEMP_WARNING: 37.0,
    ROOM_TEMP_MIN: 19,
    ROOM_TEMP_MAX: 30,
    HUMIDITY_MIN: 35,
    HUMIDITY_MAX: 65,
};

let alertTimeout = null;
let charts = {
    babyTemp: null,
    environment: null,
};

const $ = (id) => document.getElementById(id);

const parseNumber = (text) => {
    if (!text) return null;
    const n = parseFloat(String(text).replace(/[^\d\.\-]/g, ""));
    return Number.isNaN(n) ? null : n;
};

const formatTimestamp = (isoString, full = true) => {
    if (!isoString) return "N/A";

    const date = new Date(isoString);
    const now = new Date();

    const timeOptions = {
        timeZone: "Asia/Ho_Chi_Minh",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
    };

    const dateOptions = {
        timeZone: "Asia/Ho_Chi_Minh",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    };

    const isSameDay = date.toDateString() === now.toDateString();

    if (isSameDay && !full) {
        return new Intl.DateTimeFormat("vi-VN", timeOptions).format(date);
    }

    if (full) {
        return new Intl.DateTimeFormat("vi-VN", { ...dateOptions, ...timeOptions }).format(date);
    }

    return new Intl.DateTimeFormat("vi-VN", timeOptions).format(date) + " - " + new Intl.DateTimeFormat("vi-VN", dateOptions).format(date);
};

const getFirebaseErrorMessage = (code) => {
    const errors = {
        "auth/email-already-in-use": "Email này đã được sử dụng.",
        "auth/invalid-email": "Email không hợp lệ.",
        "auth/weak-password": "Mật khẩu quá yếu (cần ít nhất 6 ký tự).",
        "auth/user-not-found": "Tài khoản không tồn tại.",
        "auth/wrong-password": "Mật khẩu không đúng.",
        default: "Đã xảy ra lỗi không xác định.",
    };
    return errors[code] || errors.default;
};

const showAlertBanner = (message, type = "danger") => {
    const banner = $("alert-banner");
    const msgEl = $("alert-message");
    const closeBtn = $("close-alert-btn");

    if (!banner || !msgEl || !closeBtn) return;

    clearTimeout(alertTimeout);

    const colors = {
        danger: "#dc3545",
        warning: "#ffc107",
        success: "#28a745",
    };

    banner.style.display = "flex";
    banner.style.backgroundColor = colors[type] || colors.danger;
    msgEl.textContent = message;

    const newCloseBtn = closeBtn.cloneNode(true);
    closeBtn.parentNode.replaceChild(newCloseBtn, closeBtn);

    newCloseBtn.addEventListener("click", () => {
        banner.style.display = "none";
    });

    if (type !== "danger") {
        alertTimeout = setTimeout(() => {
            banner.style.display = "none";
        }, 7000);
    }
};

const setBadge = (id, value, alertClass = "alert-info") => {
    const el = $(id);
    if (!el) return;

    el.textContent = value;
    el.className = `info-value alert ${alertClass}`;
};

const setText = (id, value) => {
    const el = $(id);
    if (el) el.textContent = value;
};

const checkBabyTemperature = (temp) => {
    if (!temp) return { class: "alert-info", alert: null };

    if (temp > THRESHOLDS.BABY_TEMP_DANGER) {
        return {
            class: "alert-danger",
            alert: {
                message: `🔥 CẢNH BÁO: Nhiệt độ em bé ĐANG CAO! (${temp}°C)`,
                type: "danger",
            },
        };
    }

    if (temp > THRESHOLDS.BABY_TEMP_WARNING) {
        return {
            class: "alert-warning",
            alert: {
                message: `⚠️ Nhiệt độ em bé cần chú ý: (${temp}°C)`,
                type: "warning",
            },
        };
    }

    return { class: "alert-success", alert: null };
};

const checkRoomTemperature = (temp) => {
    if (temp == null) return { class: "alert-info", alert: null };

    if (temp < THRESHOLDS.ROOM_TEMP_MIN) {
        return {
            class: "alert-warning",
            alert: { message: `❄️ Nhiệt độ phòng quá thấp! (${temp}°C)`, type: "warning" },
        };
    }

    if (temp > THRESHOLDS.ROOM_TEMP_MAX) {
        return {
            class: "alert-warning",
            alert: { message: `🔥 Nhiệt độ phòng quá cao! (${temp}°C)`, type: "warning" },
        };
    }

    return { class: "alert-success", alert: null };
};

const checkHumidity = (humidity) => {
    if (humidity == null) return { class: "alert-info", alert: null };

    if (humidity < THRESHOLDS.HUMIDITY_MIN) {
        return {
            class: "alert-warning",
            alert: { message: `💧 Độ ẩm phòng quá thấp! (${humidity}%)`, type: "warning" },
        };
    }

    if (humidity > THRESHOLDS.HUMIDITY_MAX) {
        return {
            class: "alert-warning",
            alert: { message: `💦 Độ ẩm phòng quá cao! (${humidity}%)`, type: "warning" },
        };
    }

    return { class: "alert-success", alert: null };
};

const updateUI = (entry) => {
    if (!entry) return;

    const alerts = [];

    // 1. Cập nhật Trạng thái Ngủ
    const statusMap = { sleeping: "Ngủ", awake: "Thức" };
    const statusText = statusMap[entry.status] || "N/A";
    const statusClass = { sleeping: "alert-success", awake: "alert-warning" }["N/A" === statusText ? statusText : entry.status] || "alert-info";
    setBadge("sleep-status", statusText, statusClass);

    // 2. Cập nhật và Kiểm tra Khóc
    const isCrying = entry.isCrying;
    setBadge("is-crying", isCrying ? "Có" : "Không", isCrying ? "alert-danger" : "alert-success");
    if (isCrying) {
        alerts.push({ message: "🚨 Em bé ĐANG KHÓC! Vui lòng kiểm tra.", type: "danger", priority: 1 });
    }

    // 3. Cập nhật và Kiểm tra Nhiệt độ Bé
    const babyTempCheck = checkBabyTemperature(entry.babyTemperature);
    setBadge("baby-temperature", `${entry.babyTemperature || "N/A"}°C`, babyTempCheck.class);
    if (babyTempCheck.alert) {
        alerts.push({ ...babyTempCheck.alert, priority: babyTempCheck.alert.type === "danger" ? 2 : 3 });
    }

    // 4. Cập nhật và Kiểm tra Nhiệt độ Phòng
    const roomTempCheck = checkRoomTemperature(entry.environmentTemperature);
    setBadge("room-temperature", `${entry.environmentTemperature || "N/A"}°C`, roomTempCheck.class);
    if (roomTempCheck.alert) {
        alerts.push({ ...roomTempCheck.alert, priority: 4 });
    }

    // 5. Cập nhật và Kiểm tra Độ ẩm Phòng
    const humidityCheck = checkHumidity(entry.environmentHumidity);
    setBadge("room-humidity", `${entry.environmentHumidity || "N/A"}%`, humidityCheck.class);
    if (humidityCheck.alert) {
        alerts.push({ ...humidityCheck.alert, priority: 5 });
    }

    // 6. Cập nhật Tư thế Ngủ
    const positionMap = { supine: "Ngửa", prone: "Sấp", side: "Nghiêng", back: "N/A" };
    const positionText = positionMap[entry.sleepPosition] || "N/A";
    const positionClass =
        {
            supine: "alert-success",
            prone: "alert-danger",
            side: "alert-warning",
        }[entry.sleepPosition] || "alert-info";
    setBadge("sleep-position", positionText, positionClass);

    // 7. Cập nhật Timestamp
    setText("timestamp", entry.timestamp ? formatTimestamp(entry.timestamp, true) : "N/A");

    if (alerts.length > 0) {
        alerts.sort((a, b) => a.priority - b.priority);

        const highestPriority = alerts[0].priority;
        const highestType = alerts[0].type;

        const criticalAlerts = alerts.filter((a) => a.priority === highestPriority);

        const combinedMessage = criticalAlerts.map((a) => a.message).join(" | ");

        showAlertBanner(combinedMessage, highestType);
    } else {
        $("alert-banner").style.display = "none";
    }
};

const displayHistory = (data) => {
    const historyDiv = $("activity-history");
    if (!historyDiv) return;

    const records = Object.values(data).reverse();
    historyDiv.innerHTML = "";

    records.forEach((entry) => {
        const p = document.createElement("p");
        let statusDisplay = entry.status === "sleeping" ? "😴 Ngủ" : "👀 Thức";
        if (entry.isCrying) {
            statusDisplay = "😭 KHÓC!";
        }

        p.innerHTML = `[${formatTimestamp(entry.timestamp, false)}] <strong>${statusDisplay}</strong> - Nhiệt độ bé: ${
            entry.babyTemperature
        }°C, Phòng: ${entry.environmentTemperature}°C`;
        historyDiv.appendChild(p);
    });
};

const renderCharts = (records) => {
    if (!records || Object.keys(records).length === 0) return;

    const sortedRecords = Object.values(records).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    const labels = sortedRecords.map((entry) => formatTimestamp(entry.timestamp, false).substring(0, 5));
    const babyTemps = sortedRecords.map((entry) => entry.babyTemperature);
    const envTemps = sortedRecords.map((entry) => entry.environmentTemperature);
    const envHums = sortedRecords.map((entry) => entry.environmentHumidity);

    if (charts.babyTemp) charts.babyTemp.destroy();

    const ctxBabyTemp = $("babyTempChart")?.getContext("2d");
    if (ctxBabyTemp) {
        charts.babyTemp = new Chart(ctxBabyTemp, {
            type: "line",
            data: {
                labels: labels,
                datasets: [
                    {
                        label: "Nhiệt độ Bé (°C)",
                        data: babyTemps,
                        borderColor: "rgb(220, 53, 69)",
                        backgroundColor: "rgba(220, 53, 69, 0.1)",
                        tension: 0.1,
                        pointRadius: 3,
                    },
                ],
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: false,
                        title: { display: true, text: "Nhiệt độ (°C)" },
                        suggestedMin: 36.0,
                        suggestedMax: 38.0,
                    },
                },
            },
        });
    }

    if (charts.environment) charts.environment.destroy();

    const ctxEnv = $("envChart")?.getContext("2d");
    if (ctxEnv) {
        charts.environment = new Chart(ctxEnv, {
            type: "line",
            data: {
                labels: labels,
                datasets: [
                    {
                        label: "Nhiệt độ Phòng (°C)",
                        data: envTemps,
                        borderColor: "rgb(13, 116, 177)",
                        backgroundColor: "rgba(13, 116, 177, 0.1)",
                        tension: 0.1,
                        yAxisID: "y1",
                    },
                    {
                        label: "Độ ẩm Phòng (%)",
                        data: envHums,
                        borderColor: "rgb(40, 167, 69)",
                        backgroundColor: "rgba(40, 167, 69, 0.1)",
                        tension: 0.1,
                        yAxisID: "y2",
                    },
                ],
            },
            options: {
                responsive: true,
                scales: {
                    y1: { type: "linear", display: true, position: "left", title: { display: true, text: "Nhiệt độ (°C)" } },
                    y2: {
                        type: "linear",
                        display: true,
                        position: "right",
                        title: { display: true, text: "Độ ẩm (%)" },
                        grid: { drawOnChartArea: false },
                        suggestedMin: 30,
                        suggestedMax: 70,
                    },
                },
            },
        });
    }
};

const handleSignup = async () => {
    const email = $("auth-email")?.value;
    const password = $("auth-password")?.value;
    const msgEl = $("auth-message");

    if (!email || !password || password.length < 6) {
        if (msgEl) msgEl.textContent = "Email và mật khẩu (ít nhất 6 ký tự) là bắt buộc.";
        return;
    }
    try {
        await createUserWithEmailAndPassword(auth, email, password);
        if (msgEl) {
            msgEl.textContent = "Đăng ký thành công! Đang chuyển hướng...";
            msgEl.style.color = "#28a745";
        }
    } catch (error) {
        console.error("Signup error:", error);
        if (msgEl) msgEl.textContent = "Lỗi Đăng ký: " + getFirebaseErrorMessage(error.code);
        if (msgEl) msgEl.style.color = "#dc3545";
    }
};

const handleLogin = async () => {
    const email = $("auth-email")?.value;
    const password = $("auth-password")?.value;
    const msgEl = $("auth-message");

    if (!email || !password) {
        if (msgEl) msgEl.textContent = "Email và mật khẩu là bắt buộc.";
        return;
    }
    try {
        await signInWithEmailAndPassword(auth, email, password);
        if (msgEl) {
            msgEl.textContent = "Đăng nhập thành công! Đang chuyển hướng...";
            msgEl.style.color = "#28a745";
        }
    } catch (error) {
        console.error("Login error:", error);
        if (msgEl) msgEl.textContent = "Lỗi Đăng nhập: " + getFirebaseErrorMessage(error.code);
        if (msgEl) msgEl.style.color = "#dc3545";
    }
};

let stopListening = null;

const startDataListener = () => {
    if (stopListening) return;

    const latestQuery = query(REFS.sleepData, limitToLast(30));

    const unsubscribe = onValue(latestQuery, (snapshot) => {
        if (snapshot.exists()) {
            const data = snapshot.val();
            const keys = Object.keys(data);

            if (keys.length === 0) return;

            const latestKey = keys[keys.length - 1];
            const latestEntry = data[latestKey];

            updateUI(latestEntry);
            displayHistory(data);
            renderCharts(data);
        } else {
            updateUI(null);
            const historyDiv = $("activity-history");
            if (historyDiv) historyDiv.innerHTML = "<p>Chưa có dữ liệu nào được ghi.</p>";
            if (charts.babyTemp) charts.babyTemp.destroy();
            if (charts.environment) charts.environment.destroy();
        }
    });

    stopListening = unsubscribe;
};

const stopDataListener = () => {
    if (stopListening) {
        stopListening();
        stopListening = null;
    }
};

const toggleUI = (user) => {
    const authScreen = $("auth-screen");
    const mainContent = $("main-content");
    const banner = $("alert-banner");
    let logoutBtn = $("logout-btn");
    const body = document.body;

    if (user) {
        if (authScreen) authScreen.style.display = "none";
        if (mainContent) mainContent.style.display = "block";

        if ($("header") && !logoutBtn) {
            const header = $("header");
            const newLogoutBtn = document.createElement("button");
            newLogoutBtn.id = "logout-btn";
            newLogoutBtn.textContent = "Đăng xuất";
            newLogoutBtn.style.cssText =
                "float: right; margin-top: -30px; background: #c82333; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer;";
            newLogoutBtn.addEventListener("click", () => signOut(auth).catch((err) => console.error(err)));
            header.appendChild(newLogoutBtn);
            logoutBtn = newLogoutBtn;
        } else if (logoutBtn) {
            logoutBtn.style.display = "inline-block";
        }

        console.log("User signed in:", user.email);
        startDataListener();
        startWebRTCStream();
    } else {
        if (authScreen) authScreen.style.display = "block";
        if (mainContent) mainContent.style.display = "none";
        if (logoutBtn) logoutBtn.style.display = "none";
        if (banner) banner.style.display = "none";

        console.log("User signed out.");

        stopDataListener();
        closeWebRTCStream();
    }
    body.classList.remove("auth-loading");
    body.classList.add("auth-ready");
};

document.addEventListener("DOMContentLoaded", () => {
    onAuthStateChanged(auth, (user) => {
        toggleUI(user);
    });

    $("login-btn")?.addEventListener("click", handleLogin);
    $("signup-btn")?.addEventListener("click", handleSignup);

    $("logout-btn")?.addEventListener("click", async () => {
        try {
            await signOut(auth);
            const msgEl = $("auth-message");
            if (msgEl) {
                msgEl.textContent = "Đã đăng xuất thành công.";
                msgEl.style.color = "#28a745";
            }
        } catch (error) {
            console.error("Logout error:", error);
        }
    });
});