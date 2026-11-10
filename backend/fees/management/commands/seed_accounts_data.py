import datetime
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from academics.models import Department, Semester, AcademicYear
from students.models import Student
from fees.models import (
    FeeStructure,
    FeeComponent,
    StudentFee,
    FeePayment,
    FeeReceipt,
)

User = get_user_model()


class Command(BaseCommand):
    help = "Seed realistic demo data for the Accounts Role (Fee structures, student fees, concessions, payments, receipts)"

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("Seeding Accounts Role demo data..."))

        # 1. Academic Year
        ay, _ = AcademicYear.objects.get_or_create(year_name="2025-2026")

        # 2. Departments
        dept_cse, _ = Department.objects.get_or_create(name="Computer Science and Engineering")
        dept_ece, _ = Department.objects.get_or_create(name="Electronics and Communication Engineering")
        dept_me, _ = Department.objects.get_or_create(name="Mechanical Engineering")
        dept_cv, _ = Department.objects.get_or_create(name="Civil Engineering")

        # 3. Semesters
        sems = {}
        for num in range(1, 9):
            sem_obj, _ = Semester.objects.get_or_create(sem_number=num)
            sems[num] = sem_obj

        # 4. Users (Accounts Officer & Principal)
        accounts_user = User.objects.filter(role="ACCOUNTS").first()
        if not accounts_user:
            accounts_user, _ = User.objects.get_or_create(
                email="accounts@sdms.edu",
                defaults={
                    "user_id": "acc001",
                    "role": "ACCOUNTS",
                    "is_staff": True,
                },
            )
        accounts_user.role = "ACCOUNTS"
        accounts_user.set_password("Password@123")
        accounts_user.save()

        principal_user = User.objects.filter(role="PRINCIPAL").first()
        if not principal_user:
            principal_user, _ = User.objects.get_or_create(
                email="principal@sdms.edu",
                defaults={
                    "user_id": "principal001",
                    "role": "PRINCIPAL",
                    "is_staff": True,
                },
            )
        principal_user.role = "PRINCIPAL"
        principal_user.set_password("Password@123")
        principal_user.save()

        # 5. Fee Structures
        # --- Structure 1: CSE Sem 3 General Merit (All 14 Authentic DTE components) ---
        fs_cse_gm, _ = FeeStructure.objects.get_or_create(
            department=dept_cse,
            academic_year=ay,
            semester=sems[3],
            seat_type="gm",
            title="B.E. CSE 3rd Sem GM Fee Structure",
            defaults={
                "description": "Standard Department of Technical Education 3rd Semester GM Fee Structure",
                "is_active": True,
                "approval_status": "approved",
                "approved_by": principal_user,
                "approved_on": timezone.now() - datetime.timedelta(days=45),
                "created_by": accounts_user,
            },
        )
        fs_cse_gm.is_active = True
        fs_cse_gm.approval_status = "approved"
        fs_cse_gm.approved_by = principal_user
        fs_cse_gm.save()

        fs_cse_gm.components.all().delete()
        dte_14_components = [
            ("Registration fee", 500),
            ("Tuition Fee", 25000),
            ("Sports Fee", 800),
            ("Union Fee", 200),
            ("Library Fee", 1000),
            ("Magazine Fee", 150),
            ("Library Tax", 50),
            ("Laboratory Fee", 4000),
            ("ID card Fee", 150),
            ("Student Welfare Fee", 250),
            ("Teacher's Welfare Fee", 150),
            ("Development Fee", 3000),
            ("NSS Fee", 100),
            ("Other Fee", 650),
        ]
        for name, amt in dte_14_components:
            FeeComponent.objects.create(fee_structure=fs_cse_gm, name=name, amount=Decimal(amt))

        # --- Structure 2: CSE Sem 3 SNQ Quota ---
        fs_cse_snq, _ = FeeStructure.objects.get_or_create(
            department=dept_cse,
            academic_year=ay,
            semester=sems[3],
            seat_type="snq",
            title="B.E. CSE 3rd Sem SNQ Fee Structure",
            defaults={
                "description": "Subsidized SNQ Quota Fee Structure",
                "is_active": True,
                "approval_status": "approved",
                "approved_by": principal_user,
                "approved_on": timezone.now() - datetime.timedelta(days=45),
                "created_by": accounts_user,
            },
        )
        fs_cse_snq.is_active = True
        fs_cse_snq.approval_status = "approved"
        fs_cse_snq.approved_by = principal_user
        fs_cse_snq.save()

        fs_cse_snq.components.all().delete()
        snq_components = [
            ("Registration fee", 500),
            ("Tuition Fee", 4000),
            ("Laboratory Fee", 4000),
            ("Library Fee", 1000),
            ("Development Fee", 3000),
        ]
        for name, amt in snq_components:
            FeeComponent.objects.create(fee_structure=fs_cse_snq, name=name, amount=Decimal(amt))

        # --- Structure 3: ECE Sem 3 Lateral Entry ---
        fs_ece_lat, _ = FeeStructure.objects.get_or_create(
            department=dept_ece,
            academic_year=ay,
            semester=sems[3],
            seat_type="lateral",
            title="B.E. ECE 3rd Sem Lateral Entry Fee Structure",
            defaults={
                "description": "Lateral Diploma Entry Fee Structure",
                "is_active": True,
                "approval_status": "approved",
                "approved_by": principal_user,
                "approved_on": timezone.now() - datetime.timedelta(days=40),
                "created_by": accounts_user,
            },
        )
        fs_ece_lat.is_active = True
        fs_ece_lat.approval_status = "approved"
        fs_ece_lat.approved_by = principal_user
        fs_ece_lat.save()

        fs_ece_lat.components.all().delete()
        lat_components = [
            ("Registration fee", 1500),
            ("Tuition Fee", 28000),
            ("Laboratory Fee", 4500),
            ("Development Fee", 3500),
            ("ID card Fee", 200),
            ("Other Fee", 500),
        ]
        for name, amt in lat_components:
            FeeComponent.objects.create(fee_structure=fs_ece_lat, name=name, amount=Decimal(amt))

        # --- Structure 4: ME Sem 5 Lateral Entry ---
        fs_me_lat, _ = FeeStructure.objects.get_or_create(
            department=dept_me,
            academic_year=ay,
            semester=sems[5],
            seat_type="lateral",
            title="B.E. ME 5th Sem Lateral Entry Fee Structure",
            defaults={
                "description": "5th Semester Mechanical Engineering Lateral Fee Structure",
                "is_active": True,
                "approval_status": "approved",
                "approved_by": principal_user,
                "approved_on": timezone.now() - datetime.timedelta(days=35),
                "created_by": accounts_user,
            },
        )
        fs_me_lat.is_active = True
        fs_me_lat.approval_status = "approved"
        fs_me_lat.approved_by = principal_user
        fs_me_lat.save()

        fs_me_lat.components.all().delete()
        me_components = [
            ("Registration fee", 1000),
            ("Tuition Fee", 26000),
            ("Laboratory Fee", 5000),
            ("Development Fee", 3500),
            ("Sports Fee", 500),
        ]
        for name, amt in me_components:
            FeeComponent.objects.create(fee_structure=fs_me_lat, name=name, amount=Decimal(amt))

        # --- Structure 5: Civil Sem 3 (Pending Approval for Principal testing) ---
        fs_cv_pending, _ = FeeStructure.objects.get_or_create(
            department=dept_cv,
            academic_year=ay,
            semester=sems[3],
            seat_type="gm",
            title="B.E. Civil 3rd Sem Standard Structure",
            defaults={
                "description": "Submitted by Accounts Officer, awaiting Principal signature & approval",
                "is_active": False,
                "approval_status": "pending",
                "created_by": accounts_user,
            },
        )
        fs_cv_pending.components.all().delete()
        for name, amt in [("Tuition Fee", 24000), ("Laboratory Fee", 4000), ("Development Fee", 3000), ("Registration fee", 500)]:
            FeeComponent.objects.create(fee_structure=fs_cv_pending, name=name, amount=Decimal(amt))

        # 6. Students
        def get_or_create_student(usn, name, dept, sem, seat_type, email):
            s_user, _ = User.objects.get_or_create(
                email=email,
                defaults={"user_id": usn.lower(), "role": "STUDENT"},
            )
            s_user.set_password("Student@123")
            s_user.role = "STUDENT"
            s_user.save()

            st, created = Student.objects.get_or_create(
                usn=usn,
                defaults={
                    "user": s_user,
                    "name": name,
                    "cet_no": f"CET{usn[-4:]}",
                    "dob": datetime.date(2004, 5, 15),
                    "gender": "male" if "Manoj" in name or "Rahul" in name or "Amit" in name else "female",
                    "religion": "General",
                    "city_type": "Urban",
                    "mobile_no": "9876543210",
                    "email": email,
                    "parent_occupation": "Private Sector",
                    "address": "Bangalore, Karnataka",
                    "permanent_address": "Bangalore, Karnataka",
                    "date_of_admission": datetime.date(2023, 8, 20),
                    "seat_type": seat_type,
                    "department": dept,
                    "semester": sem,
                    "academic_year": ay,
                    "status": "active",
                    "registration_status": "approved",
                    "admission_id": f"ADM{usn[-6:]}",
                },
            )
            if not created:
                st.department = dept
                st.semester = sem
                st.seat_type = seat_type
                st.save()
            return st

        s1 = get_or_create_student("4GE23CS001", "Rahul Sharma", dept_cse, sems[3], "general_merit", "rahul.cs23@gec.edu")
        s2 = get_or_create_student("4GE23CS002", "Sneha Patil", dept_cse, sems[3], "snq", "sneha.cs23@gec.edu")
        s3 = get_or_create_student("4GE23CS003", "Amit Kulkarni", dept_cse, sems[3], "general_merit", "amit.cs23@gec.edu")
        s4 = get_or_create_student("4GE23EC001", "Priya Hegde", dept_ece, sems[3], "lateral", "priya.ec23@gec.edu")
        s5 = get_or_create_student("4GE23ME001", "Manoj Gowda", dept_me, sems[5], "lateral", "manoj.me23@gec.edu")
        s6 = get_or_create_student("4GE23CV001", "Deepa Naik", dept_cv, sems[3], "general_merit", "deepa.cv23@gec.edu")

        # 7. StudentFee Assignments & Payments
        def clear_payments(sf_obj):
            FeeReceipt.objects.filter(payment__student_fee=sf_obj).delete()
            sf_obj.payments.all().delete()

        # Student 1: Rahul Sharma (Fully Paid via Net Banking + UPI)
        sf1, _ = StudentFee.objects.get_or_create(
            student=s1,
            fee_structure=fs_cse_gm,
            defaults={"due_date": datetime.date(2026, 4, 30)},
        )
        clear_payments(sf1)
        p1_1 = FeePayment.objects.create(
            student_fee=sf1,
            amount=Decimal("20000.00"),
            mode="bank",
            reference_no="NEFT-SBIN202602100492",
            bank_reference_no="SBIN202602100492",
            entered_by=accounts_user,
            verified=True,
            paid_on=timezone.now() - datetime.timedelta(days=15),
            remark="Installment 1 via SBI Net Banking",
        )
        FeeReceipt.objects.get_or_create(payment=p1_1, defaults={"receipt_no": "REC-0821001", "verified_by": accounts_user})

        p1_2 = FeePayment.objects.create(
            student_fee=sf1,
            amount=Decimal("16000.00"),
            mode="upi",
            reference_no="UPI-604819284711",
            upi_txn_id="UPI-604819284711",
            entered_by=accounts_user,
            verified=True,
            paid_on=timezone.now() - datetime.timedelta(days=2),
            remark="Final balance clearance via GPay",
        )
        FeeReceipt.objects.get_or_create(payment=p1_2, defaults={"receipt_no": "REC-0821002", "verified_by": accounts_user})

        sf1.recalculate_status()
        sf1.save()

        # Student 2: Sneha Patil (SNQ, Fully Paid in Cash at Counter)
        sf2, _ = StudentFee.objects.get_or_create(
            student=s2,
            fee_structure=fs_cse_snq,
            defaults={"due_date": datetime.date(2026, 4, 30)},
        )
        clear_payments(sf2)
        p2 = FeePayment.objects.create(
            student_fee=sf2,
            amount=Decimal("12500.00"),
            mode="cash",
            reference_no="CASH-COUNTER-094",
            entered_by=accounts_user,
            verified=True,
            paid_on=timezone.now() - datetime.timedelta(days=8),
            remark="Paid full SNQ subsidized fee at college counter",
        )
        FeeReceipt.objects.get_or_create(payment=p2, defaults={"receipt_no": "REC-0821003", "verified_by": accounts_user})
        sf2.recalculate_status()
        sf2.save()

        # Student 3: Amit Kulkarni (Partial - Merit Scholarship concession ₹10,000 + ₹15,000 paid)
        sf3, _ = StudentFee.objects.get_or_create(
            student=s3,
            fee_structure=fs_cse_gm,
            defaults={"due_date": datetime.date(2026, 4, 30)},
        )
        sf3.concession_amount = Decimal("10000.00")
        sf3.concession_reason = "Academic Merit Scholarship (Top 5% Rank)"
        sf3.concession_approved_by = accounts_user
        sf3.concession_approved_on = timezone.now() - datetime.timedelta(days=20)
        sf3.save()
        clear_payments(sf3)

        p3 = FeePayment.objects.create(
            student_fee=sf3,
            amount=Decimal("15000.00"),
            mode="upi",
            reference_no="UPI-884920194829",
            upi_txn_id="UPI-884920194829",
            entered_by=accounts_user,
            verified=True,
            paid_on=timezone.now() - datetime.timedelta(days=5),
            remark="Installment 1 paid via PhonePe",
        )
        FeeReceipt.objects.get_or_create(payment=p3, defaults={"receipt_no": "REC-0821004", "verified_by": accounts_user})
        sf3.recalculate_status()
        sf3.save()

        # Student 4: Priya Hegde (Sports Quota concession ₹5,000 + Pending Verification Payment ₹33,200)
        sf4, _ = StudentFee.objects.get_or_create(
            student=s4,
            fee_structure=fs_ece_lat,
            defaults={"due_date": datetime.date(2026, 5, 15)},
        )
        sf4.concession_amount = Decimal("5000.00")
        sf4.concession_reason = "State Level Badminton Champion Sports Quota"
        sf4.concession_approved_by = accounts_user
        sf4.concession_approved_on = timezone.now() - datetime.timedelta(days=12)
        sf4.save()
        clear_payments(sf4)

        # Unverified online payment uploaded by student (Ready for Accounts verification screen)
        p4 = FeePayment.objects.create(
            student_fee=sf4,
            amount=Decimal("33200.00"),
            mode="upi",
            reference_no="UPI-992384712019",
            upi_txn_id="UPI-992384712019",
            entered_by=None,
            verified=False,
            paid_on=timezone.now() - datetime.timedelta(hours=6),
            remark="Student online payment confirmation pending Accounts verification",
        )
        sf4.recalculate_status()
        sf4.save()

        # Student 5: Manoj Gowda (Partial - Paid ₹20,000 via Demand Draft, ₹16,000 pending)
        sf5, _ = StudentFee.objects.get_or_create(
            student=s5,
            fee_structure=fs_me_lat,
            defaults={"due_date": datetime.date(2026, 4, 30)},
        )
        clear_payments(sf5)
        p5 = FeePayment.objects.create(
            student_fee=sf5,
            amount=Decimal("20000.00"),
            mode="dd",
            reference_no="DD-884129-CANARA",
            bank_reference_no="DD-884129-CANARA",
            entered_by=accounts_user,
            verified=True,
            paid_on=timezone.now() - datetime.timedelta(days=3),
            remark="Canara Bank DD #884129 deposited at counter",
        )
        FeeReceipt.objects.get_or_create(payment=p5, defaults={"receipt_no": "REC-0821005", "verified_by": accounts_user})
        sf5.recalculate_status()
        sf5.save()

        # Student 6: Deepa Naik (Pending Dues - ₹0 paid, full ₹36,000 outstanding)
        sf6, _ = StudentFee.objects.get_or_create(
            student=s6,
            fee_structure=fs_cse_gm,
            defaults={"due_date": datetime.date(2026, 4, 15)},
        )
        clear_payments(sf6)
        sf6.recalculate_status()
        sf6.save()
        sf6.recalculate_status()
        sf6.save()

        # 8. Seed Principal Notifications for Accounts Officer
        from announcements.models import Notification
        sample_notifs = [
            (
                "Fee Structure Returned",
                "The fee structure has been returned for corrections. Please review the remarks and update the structure before resubmitting it. Remark: 'Please verify the fee components and total amount.'",
                False,
                timezone.now() - datetime.timedelta(minutes=45),
            ),
            (
                "[Principal Directive] Fee Structure Approved: B.E. CSE 3rd Sem GM Fee Structure",
                "The Department of Technical Education 3rd Semester GM Fee Structure has been reviewed and approved. Total assigned fee: ₹36,000. You may proceed with fee collection and receipt generation.",
                False,
                timezone.now() - datetime.timedelta(hours=2),
            ),
            (
                "[Principal Directive] Urgent Fee Collection Review for CSE & ME",
                "Please prepare the semester outstanding dues report for Computer Science and Mechanical Engineering for the upcoming Academic Council meeting on Monday.",
                False,
                timezone.now() - datetime.timedelta(hours=14),
            ),
            (
                "[Principal Directive] Post-Matric Scholarship Concession Verification",
                "Concession recommendation of ₹10,000 for Preethi R (4GE24CS003) under DTE Post-Matric Welfare Scheme has been verified and sanctioned. Ledger updated accordingly.",
                True,
                timezone.now() - datetime.timedelta(days=2),
            ),
            (
                "[Principal Directive] Online UPI Reconciliation Directive",
                "Please reconcile all pending student online UPI submissions before end of week and ensure duplicate UTR checks are strictly enforced.",
                True,
                timezone.now() - datetime.timedelta(days=4),
            ),
        ]
        accounts_users = User.objects.filter(role__iexact="ACCOUNTS")
        for acc in accounts_users:
            Notification.objects.filter(recipient=acc).delete()
            for title, msg, is_read, dt in sample_notifs:
                Notification.objects.create(
                    recipient=acc,
                    title=title,
                    message=msg,
                    notification_type="ANNOUNCEMENT",
                    is_read=is_read,
                    read_at=dt if is_read else None,
                )

        self.stdout.write(self.style.SUCCESS("Successfully seeded comprehensive Accounts demo data!"))
        self.stdout.write(f"  Fee Structures : {FeeStructure.objects.count()} active & pending structures")
        self.stdout.write(f"  Student Fees   : {StudentFee.objects.count()} student fee accounts")
        self.stdout.write(f"  Fee Payments   : {FeePayment.objects.count()} recorded transactions (verified & pending)")
        self.stdout.write(f"  Official Receipts: {FeeReceipt.objects.count()} DTE official receipts")
        self.stdout.write(self.style.SUCCESS("Accounts officer login: accounts@sdms.edu / Password@123"))
        self.stdout.write(self.style.SUCCESS("Principal login: kiruvinu201@gmail.com (or principal@sdms.edu) / Password@123"))
