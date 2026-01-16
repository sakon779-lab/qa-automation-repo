# 🤖 QA Automation Repository

Centralized Repository สำหรับ Automated Testing ด้วย **Robot Framework**
ออกแบบมาเพื่อรองรับการทดสอบ API, Web, และ Database สำหรับหลายโปรเจกต์ (e.g., PaymentService, CRM)

---

## 📂 Project Structure

โครงสร้างโฟลเดอร์ออกแบบตามหลัก **Reusability** และ **Separation of Concerns**:

    .
    ├── config/                 # Environment Variables (Dev, Staging, UAT)
    ├── libraries/              # Custom Python Libraries (เมื่อ Robot ทำไม่ได้)
    ├── resources/              # Keywords & Logic
    │   ├── common/             # ✅ Shared Keywords ใช้ได้ทุกโปรเจกต์ (Database, API Auth)
    │   └── projects/           # Keywords เฉพาะของแต่ละโปรเจกต์
    ├── tests/                  # Test Suites (ไฟล์ .robot ที่ใช้รันจริง)
    │   └── payment_service/    # Test Cases ของโปรเจกต์ Payment
    └── results/                # Log และ Report (ถูก GitIgnore)

---

## 🚀 Getting Started

### 1. Prerequisites
* Python 3.10+
* Git

### 2. Installation
แนะนำให้สร้าง Virtual Environment ก่อนเริ่มงาน:

    # สร้าง venv
    python -m venv .venv

    # Activate venv (Windows)
    .venv\Scripts\activate

    # Activate venv (Mac/Linux)
    source .venv/bin/activate

    # ลง Library
    pip install -r requirements.txt

---

## 🏃‍♂️ How to Run Tests

### รันแบบพื้นฐาน
ผลลัพธ์จะไปอยู่ที่โฟลเดอร์ `results/` โดยอัตโนมัติ

    # รันเทสทั้งหมดของ Payment Service
    robot -d results tests/payment_service/

    # รันเฉพาะไฟล์
    robot -d results tests/payment_service/SCRUM-24_reverse.robot

### รันแบบแยก Environment (Advanced)
ใช้ไฟล์ Resource ในโฟลเดอร์ `config/` เพื่อเปลี่ยนตัวแปร (เช่น URL, DB Host)

    # รันบนเครื่องตัวเอง (Dev)
    robot -d results --variablefile config/dev_env.resource tests/payment_service/

    # รันบน Staging
    robot -d results --variablefile config/staging_env.resource tests/payment_service/

### การเลือกเทสด้วย Tag
เราควรติด Tag ใน Test Case เช่น `smoke`, `regression`, `api`

    # รันเฉพาะ Smoke Test
    robot -d results -i smoke tests/

---

## 🛠️ Development Guidelines

1.  **Naming Convention:**
    * **File:** `snake_case.robot` (e.g., `user_login.robot`)
    * **Test Case:** `Sentence Case` (e.g., `Verify User Can Login Successfully`)
    * **Keyword:** `Title Case` (e.g., `Connect To Database`)
    * **Variable:** `UPPER_CASE` (e.g., `${BASE_URL}`)

2.  **Isolation Policy:**
    * **ห้าม** ใช้ Hardcoded ID ในการเทส
    * ต้องสร้างข้อมูลใหม่เสมอ (ใช้ `FakerLibrary` หรือ `Generate Random String`)
    * เคลียร์ข้อมูลหลังจบเทสเสมอ (`[Teardown]`)

3.  **Mocking:**
    * หากต้องต่อ 3rd Party ให้ใช้ Mock Server (Port 1080)
    * Setup Expectation ใน `[Setup]` และ Clear ใน `[Teardown]`

---

## 🤝 Contribution
1.  แตก Branch ใหม่เสมอ: `feature/SCRUM-XX-description`
2.  รันเทส Local ให้ผ่านก่อน Push
3.  เปิด Pull Request เพื่อ Review Code