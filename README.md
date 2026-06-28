# 🎓 Student Data Management System (SDMS)

A comprehensive **Student Data Management System (SDMS)** built using **Django REST Framework** for the backend and **Flutter** for the frontend. The system streamlines college administration by providing role-based access for administrators, faculty, students, and other departments.

---

## 📌 Features

### 👨‍🎓 Student Management
- Student registration and profile management
- Admission ID generation
- Student academic history
- Document management
- Photo and signature upload

### 👨‍🏫 Faculty Management
- Faculty profile management
- Subject allocation
- Attendance management
- Internal Assessment (IA) marks entry

### 🏫 Academic Management
- Departments
- Courses
- Semesters
- Subjects
- Timetable management
- Academic year management

### 📊 Attendance System
- Daily attendance tracking
- Attendance reports
- Student attendance history

### 📝 Internal Assessment
- IA Test creation
- Marks entry
- Marks analysis
- Student performance reports

### 📚 Library Management
- Book management
- Book issue & return
- Fine calculation
- E-Book support

### 💰 Fee Management
- Fee structure management
- Student fee assignment
- Online payment records
- Receipt generation

### 📄 Document Management
- Student documents
- Faculty documents
- Secure file uploads

### 🎓 External Results
- External examination result management
- Semester-wise results

### 📢 Grievance System
- Raise grievances
- Track grievance status
- Department-wise grievance handling

### 🔐 Authentication & Security
- JWT Authentication
- Role-Based Access Control (RBAC)
- Password encryption
- Secure REST APIs

---

# 👥 User Roles

- Administrator
- Principal
- Head of Department (HOD)
- Faculty
- Student
- Library Staff
- Fee Department
- Examination Department

---

# 🛠 Tech Stack

## Backend

- Python
- Django
- Django REST Framework
- PostgreSQL
- JWT Authentication

## Frontend

- Flutter
- Dart

## Database

- PostgreSQL

## Tools

- Git
- GitHub
- Postman
- VS Code

---

# 📂 Project Structure

```
SDMS/
│
├── backend/
│   ├── academics/
│   ├── attendance/
│   ├── students/
│   ├── faculty/
│   ├── fees/
│   ├── library/
│   ├── grievances/
│   ├── subjects/
│   ├── timetable/
│   ├── userlogin/
│   ├── SDMS/
│   └── manage.py
│
├── frontend/
│   ├── lib/
│   ├── assets/
│   ├── web/
│   └── pubspec.yaml
│
└── README.md
```

---

# 🚀 Installation

## Clone Repository

```bash
git clone https://github.com/your-username/SDMS.git

cd SDMS
```

---

## Backend Setup

```bash
cd backend

python -m venv .venv
```

### Windows

```bash
.venv\Scripts\activate
```

### Linux / Mac

```bash
source .venv/bin/activate
```

Install dependencies

```bash
pip install -r requirements.txt
```

Configure PostgreSQL database in `settings.py`.

Run migrations

```bash
python manage.py makemigrations

python manage.py migrate
```

Start the backend

```bash
python manage.py runserver
```

Backend URL

```
http://127.0.0.1:8000/
```

---

## Frontend Setup

```bash
cd frontend

flutter pub get
```

Run

```bash
flutter run
```

---

# 🔐 Authentication

The system uses:

- JWT Authentication
- Role Based Authorization
- Secure API endpoints

---

# 📦 Major Modules

- Authentication
- Student Management
- Faculty Management
- Attendance
- Internal Assessment
- Fee Management
- Library
- Timetable
- Subject Management
- Academic Management
- Grievance Management
- External Results
- Document Management

---

# 🌟 Future Enhancements

- AI-based Student Performance Prediction
- Face Recognition Attendance
- Parent Portal
- Online Fee Payment Gateway
- Notification System
- Mobile Push Notifications
- Dashboard Analytics
- AI Chatbot Support

---

# 📷 Screenshots

Add screenshots of:

- Login Page
- Dashboard
- Student Profile
- Attendance Module
- Fee Module
- Library Module
- IA Marks Module

---

# 🤝 Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a new branch.
3. Commit your changes.
4. Push to your branch.
5. Create a Pull Request.

---

# 📄 License

This project is developed for educational and academic purposes.

---

# 👨‍💻 Developed By

**Shabber**

Computer Science Engineering

Python | Django | Flutter | PostgreSQL | REST API
