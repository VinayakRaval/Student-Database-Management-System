# 🎓 Student Data Management System (SDMS)

A comprehensive **Student Data Management System (SDMS)** built using **Django REST Framework** for the backend, **Flutter** for the frontend, and **PostgreSQL** for database management. The system streamlines college administration through role-based access for administrators, faculty, students, and other departments.

---

## 📌 Features

### 👨‍🎓 Student Management
- Student registration and profile management
- Admission ID generation
- Student academic history
- Document management
- Photo and signature uploads

### 👨‍🏫 Faculty Management
- Faculty profile management
- Subject allocation
- Faculty attendance management
- Internal Assessment (IA) marks entry

### 🏫 Academic Management
- Department management
- Course and semester management
- Subject management
- Timetable management
- Academic year management

### 📊 Attendance System
- Daily attendance tracking
- Attendance reports
- Student attendance history

### 📝 Internal Assessment
- IA test creation
- Marks entry
- Marks analysis
- Student performance reports

### 📚 Library Management
- Book management
- Book issue and return
- Fine calculation
- E-book support

### 💰 Fee Management
- Fee structure management
- Student fee assignment
- Online payment records
- Receipt generation

### 📄 Document Management
- Student document management
- Faculty document management
- Secure file uploads

### 🎓 External Results
- External examination result management
- Semester-wise result tracking

### 📢 Grievance Management
- Grievance submission
- Grievance status tracking
- Department-wise grievance handling

### 🔐 Authentication and Security
- JWT authentication
- Role-Based Access Control (RBAC)
- Secure password hashing
- Protected REST API endpoints

---

## 👥 User Roles

The system supports the following roles:

- System Administrator
- Principal
- Head of Department (HOD)
- Faculty
- Student
- Library Staff
- Fee Department
- Examination Department

*Actual permissions depend on the roles and access-control rules implemented in the application.*

---

## 🛠 Technology Stack

### Backend
- Python
- Django
- Django REST Framework
- JWT Authentication

### Frontend
- Flutter
- Dart

### Database
- PostgreSQL

### Development Tools
- Git
- GitHub
- Postman
- Visual Studio Code

---

## 📂 Project Structure

```text
SDMS/
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
│   ├── manage.py
│   ├── requirements.txt
│   └── .env
│
├── frontend/
│   ├── lib/
│   ├── assets/
│   ├── web/
│   └── pubspec.yaml
│
├── .gitignore
└── README.md
```

*This is a representative structure. Adjust it to match the actual files and directories in your repository.*

---

## 🚀 Installation and Setup

### Prerequisites

Install the following tools before starting:

- Python
- PostgreSQL
- Flutter SDK
- Git
- Visual Studio Code or another suitable IDE

Verify the installations:

```bash
python --version
git --version
flutter --version
```

Check Flutter's environment:

```bash
flutter doctor
```

### 1. Clone the Repository

Replace the placeholder repository URL with your actual GitHub repository URL.

```bash
git clone https://github.com/your-username/SDMS.git
cd SDMS
```

### 2. Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Create a Python virtual environment:

```bash
python -m venv .venv
```

#### Windows — Command Prompt

```bat
.venv\Scripts\activate.bat
```

#### Windows — PowerShell

```powershell
.\.venv\Scripts\Activate.ps1
```

#### Linux and macOS

```bash
source .venv/bin/activate
```

Install the Python dependencies:

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

**Note:** If `requirements.txt` does not exist, install the project's documented dependencies or generate the file from the existing environment. Do not create an arbitrary dependency list without checking the codebase.

### 3. Configure Environment Variables

Create or update `backend/.env` using the environment variable names expected by your Django settings.

For example:

```dotenv
DEBUG=True
SECRET_KEY=replace-with-a-local-development-secret
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_HOST=127.0.0.1
DB_PORT=5432
```

These names are examples. Use the variable names expected by your existing project.

**Security requirements:**
- Never commit real secrets or passwords to GitHub.
- Add `.env` and `.venv/` to `.gitignore`.
- Keep `DEBUG=True` only for local development.
- Use a strong secret key and `DEBUG=False` in production.
- Configure `ALLOWED_HOSTS` and other production security settings before deployment.

### 4. Configure PostgreSQL

Start PostgreSQL and create a database for SDMS.

Example SQL:

```sql
CREATE DATABASE sdms_db;
```

Create or select a database user with appropriate permissions, then configure the database name, username, password, host, and port in your environment variables.

Ensure the Django database settings use PostgreSQL and the correct credentials.

### 5. Apply Database Migrations

From the `backend` directory, run:

```bash
python manage.py check
python manage.py migrate
```

Use `makemigrations` only when you have changed Django models and need new migration files:

```bash
python manage.py makemigrations
python manage.py migrate
```

Do not delete existing migrations or reset the database to resolve migration errors without investigating them first.

### 6. Create an Administrator Account

If you need an initial Django superuser and the project uses Django's standard user management, run:

```bash
python manage.py createsuperuser
```

Follow the prompts.

**Important:** A Django superuser is not automatically the same as an application-level System Administrator or Principal. Configure the appropriate SDMS role and permissions according to the project's existing authentication design.

### 7. Start the Backend

Run the Django development server:

```bash
python manage.py runserver
```

The local backend address is:

```text
http://127.0.0.1:8000/
```

Keep the terminal running.

If the project exposes Django REST Framework endpoints, use the actual API routes defined in the codebase to test them.

---

## 📱 Frontend Setup

Open a second terminal and navigate to the frontend directory from the project root:

```bash
cd frontend
```

Install Flutter dependencies:

```bash
flutter pub get
```

Check the project:

```bash
flutter analyze
```

### Run on a Connected Device

```bash
flutter devices
flutter run
```

Select the desired device if Flutter lists multiple available devices.

### Run in Google Chrome

If the project supports Flutter Web:

```bash
flutter run -d chrome
```

### Backend API Configuration

Configure the Flutter application's API base URL to match the environment where Django is running.

Examples:

- **Flutter Web on the same computer:** `http://127.0.0.1:8000/`
- **Android emulator:** commonly `http://10.0.2.2:8000/`
- **Physical Android phone:** use your computer's reachable local network IP address and configure Django to accept the development host.

The exact URL and API path depend on your existing Flutter API client and Django URL configuration.

For HTTPS deployments, configure the API to use the deployed HTTPS endpoint. Do not expose database credentials or email-service secrets in Flutter.

---

## 🔐 Authentication and Authorization

The system uses JWT authentication and role-based authorization, as implemented in the application.

Security principles include:

- Secure password hashing through Django's authentication system
- Access-token and refresh-token handling according to the configured JWT library
- Role-based API permissions
- Department-level access restrictions where required
- Protected account activation and password setup
- Server-side validation of sensitive operations

The backend must enforce permissions independently of the Flutter UI.

---

## 📦 Major Modules

- Authentication and account management
- Student management
- Faculty management
- Faculty and student attendance
- Internal Assessment (IA)
- Fee management
- Library management
- Timetable management
- Subject management
- Academic management
- Grievance management
- External examination results
- Document management

---

## 📧 Email Service Configuration

If the project uses Brevo for account invitations or password setup:

1. Create a Brevo account.
2. Verify an authorized sender address.
3. Generate SMTP credentials from the Brevo dashboard.
4. Store the credentials in the backend environment configuration.
5. Configure Django's email backend to use the Brevo SMTP relay.
6. Send a test email to an address you control.
7. Test faculty and student invitation workflows.

Keep SMTP credentials on the backend. Never store them in Flutter, commit them to GitHub, or return them through API responses.

An accepted SMTP request does not guarantee inbox delivery; verify the test message in the recipient's mailbox and check Brevo's delivery logs if necessary.

---

## 🧪 Testing

### Backend

From the `backend` directory:

```bash
python manage.py check
python manage.py test
```

### Frontend

From the `frontend` directory:

```bash
flutter analyze
flutter test
```

Run the tests available in the project and resolve failures before deployment.

---

## 🌟 Future Enhancements

Potential future enhancements include:

- AI-based student performance prediction
- Face-recognition attendance
- Parent portal
- Online fee payment gateway
- Email and notification system
- Mobile push notifications
- Advanced dashboard analytics
- AI chatbot support

These are proposed enhancements and should not be considered implemented unless they are available in the application.

---

## 📷 Screenshots

Add screenshots of the actual application to showcase:

- Login page
- Dashboard
- Student profile
- Attendance module
- Fee management module
- Library module
- Internal Assessment marks module

Store the screenshots in a repository directory such as `screenshots/` and reference them in this README using relative paths.

Example:

```markdown
![SDMS Dashboard](screenshots/dashboard.png)
```

---

## 🤝 Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Implement and test your changes.
4. Commit your changes with a descriptive message.
5. Push your branch to GitHub.
6. Open a Pull Request.

---

## 📄 License

This project is developed for educational and academic purposes.

Add a `LICENSE` file if you intend to distribute the project under a specific open-source license.

---

## 👨‍💻 Developed By

**Vinayak Raval**  
Computer Science and Engineering

**Technologies:** Python · Django REST Framework · Flutter · Dart · PostgreSQL · REST APIs