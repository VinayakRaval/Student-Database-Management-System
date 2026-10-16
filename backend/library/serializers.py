from rest_framework import serializers
from .models import (
    Department, BookCategory, Book, BookCopy, EBook,
    BookRequest, IssueRecord, Fine, AuditLog, LibraryCard,
    LibraryConfiguration, LibraryFeedback
)
from academics.serializers import DepartmentSerializer


class BookCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = BookCategory
        fields = ['id', 'name', 'description', 'created_at']

    def validate_name(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("Category name cannot be empty.")
        instance_id = self.instance.id if self.instance else None
        if BookCategory.objects.filter(name__iexact=cleaned).exclude(id=instance_id).exists():
            raise serializers.ValidationError(f"Category '{cleaned}' already exists.")
        return cleaned


class BookCopySerializer(serializers.ModelSerializer):
    # Allow user to POST book ID and show book name in GET
    book_id = serializers.PrimaryKeyRelatedField(
        queryset=Book.objects.all(), source='book', write_only=True
    )
    book = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = BookCopy
        fields = [
            'id',
            'book',        # read-only display
            'book_id',     # used for writing (POST)
            'copy_number',
            'barcode',
            'shelf_location',
            'status',
            'created_at'
        ]
class BookSerializer(serializers.ModelSerializer):
    total_copies = serializers.IntegerField(read_only=True)
    available_copies = serializers.IntegerField(read_only=True)
    issued_copies = serializers.IntegerField(read_only=True)
    copies = BookCopySerializer(many=True, read_only=True)
    department = DepartmentSerializer(read_only=True)
    department_id = serializers.PrimaryKeyRelatedField(queryset=Department.objects.all(), source='department', write_only=True, required=False)
    cover_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'subtitle', 'authors', 'edition', 'publisher', 'year',
            'department', "department_id", 'category', 'language', 'isbn', 'mrp',
            'cover_image', 'cover_image_url', 'description',
            'total_copies', 'available_copies', 'issued_copies', 'copies'
        ]

    def get_cover_image_url(self, obj):
        request = self.context.get('request')
        if obj.cover_image and request:
            return request.build_absolute_uri(obj.cover_image.url)
        elif obj.cover_image:
            return obj.cover_image.url
        return None

class EBookSerializer(serializers.ModelSerializer):
    book = BookSerializer(read_only=True)
    book_id = serializers.PrimaryKeyRelatedField(queryset=Book.objects.all(), source='book', write_only=True)

    class Meta:
        model = EBook
        fields = ['id', 'book', 'book_id', 'file', 'external_link', 'uploaded_by', 'uploaded_at', 'downloads', 'views']
        read_only_fields = ('uploaded_by', 'uploaded_at', 'downloads', 'views')

class BookRequestSerializer(serializers.ModelSerializer):
    requester = serializers.PrimaryKeyRelatedField(read_only=True)
    requester_name = serializers.SerializerMethodField()
    requester_role = serializers.SerializerMethodField()
    requester_id_number = serializers.SerializerMethodField()
    requester_department = serializers.SerializerMethodField()
    requester_semester = serializers.SerializerMethodField()
    queue_position = serializers.SerializerMethodField()

    class Meta:
        model = BookRequest
        fields = [
            'id', 'requester', 'requester_name', 'requester_role',
            'requester_id_number', 'requester_department', 'requester_semester',
            'queue_position', 'title', 'authors', 'reason', 'urgency',
            'status', 'created_at', 'updated_at'
        ]

    def _get_requester_details(self, obj):
        if not hasattr(obj, '_cached_details'):
            user = obj.requester
            from django.apps import apps
            details = {
                'name': user.get_full_name() or getattr(user, 'user_id', None) or user.email,
                'role': 'STUDENT',
                'id_number': getattr(user, 'usn', '') or getattr(user, 'user_id', '') or '',
                'department': 'General',
                'semester': None,
            }
            try:
                Faculty = apps.get_model('faculty', 'Faculty')
                fac = Faculty.objects.filter(user=user).select_related('department').first()
                if fac or getattr(user, 'role', '').upper() == 'PROFESSOR':
                    details['role'] = 'FACULTY'
                    if fac:
                        details['name'] = fac.name
                        details['id_number'] = fac.faculty_id
                        if fac.department:
                            details['department'] = fac.department.name
            except Exception:
                pass

            if details['role'] != 'FACULTY':
                try:
                    Student = apps.get_model('students', 'Student')
                    st = Student.objects.filter(user=user).select_related('department', 'semester').first()
                    if st:
                        details['name'] = st.name
                        details['id_number'] = st.usn
                        if st.department:
                            details['department'] = st.department.name
                        if st.semester:
                            details['semester'] = st.semester.sem_number
                except Exception:
                    pass
            obj._cached_details = details
        return obj._cached_details

    def get_requester_name(self, obj):
        return self._get_requester_details(obj)['name']

    def get_requester_role(self, obj):
        return self._get_requester_details(obj)['role']

    def get_requester_id_number(self, obj):
        return self._get_requester_details(obj)['id_number']

    def get_requester_department(self, obj):
        return self._get_requester_details(obj)['department']

    def get_requester_semester(self, obj):
        return self._get_requester_details(obj)['semester']

    def get_queue_position(self, obj):
        if obj.status in ['pending', 'verified']:
            prior_count = BookRequest.objects.filter(
                title__iexact=obj.title,
                status__in=['pending', 'verified'],
                created_at__lt=obj.created_at
            ).count()
            return prior_count + 1
        return 1

class IssueRecordSerializer(serializers.ModelSerializer):
    copy = BookCopySerializer(read_only=True)
    copy_id = serializers.PrimaryKeyRelatedField(queryset=BookCopy.objects.all(), source='copy', write_only=True)
    borrower = serializers.PrimaryKeyRelatedField(read_only=True)
    borrower_name = serializers.SerializerMethodField()
    borrower_usn = serializers.SerializerMethodField()
    borrower_department = serializers.SerializerMethodField()
    borrower_semester = serializers.SerializerMethodField()
    copy_barcode = serializers.CharField(source='copy.barcode', read_only=True)
    book_title = serializers.CharField(source='copy.book.title', read_only=True)
    book_authors = serializers.CharField(source='copy.book.authors', read_only=True)
    shelf_location = serializers.CharField(source='copy.shelf_location', read_only=True)
    is_overdue = serializers.SerializerMethodField()

    class Meta:
        model = IssueRecord
        fields = [
            'id', 'issue_id', 'borrower', 'borrower_name', 'borrower_usn',
            'borrower_department', 'borrower_semester', 'copy', 'copy_id',
            'copy_barcode', 'book_title', 'book_authors', 'shelf_location',
            'issued_at', 'due_date', 'returned_at', 'status', 'created_by', 'is_overdue'
        ]
        read_only_fields = (
            'issue_id', 'issued_at', 'status', 'created_by', 'book_title',
            'book_authors', 'shelf_location', 'borrower_name', 'copy_barcode',
            'borrower_usn', 'borrower_department', 'borrower_semester', 'is_overdue'
        )

    def get_borrower_name(self, obj):
        if not obj.borrower:
            return "Unknown"
        if hasattr(obj.borrower, 'student') and obj.borrower.student:
            return obj.borrower.student.name
        if hasattr(obj.borrower, 'faculty_profile') and obj.borrower.faculty_profile:
            return obj.borrower.faculty_profile.name
        return obj.borrower.get_full_name() or getattr(obj.borrower, 'user_id', None) or obj.borrower.email

    def get_borrower_usn(self, obj):
        if not obj.borrower:
            return ""
        if hasattr(obj.borrower, 'student') and obj.borrower.student and obj.borrower.student.usn:
            return obj.borrower.student.usn
        if hasattr(obj.borrower, 'faculty_profile') and obj.borrower.faculty_profile:
            return obj.borrower.faculty_profile.faculty_id
        return getattr(obj.borrower, 'usn', None) or getattr(obj.borrower, 'user_id', None) or ""

    def get_borrower_department(self, obj):
        if not obj.borrower:
            return ""
        if hasattr(obj.borrower, 'student') and obj.borrower.student and obj.borrower.student.department:
            return obj.borrower.student.department.name
        if hasattr(obj.borrower, 'faculty_profile') and obj.borrower.faculty_profile and obj.borrower.faculty_profile.department:
            return obj.borrower.faculty_profile.department.name
        if getattr(obj.borrower, 'department', None):
            return obj.borrower.department.name
        return ""

    def get_borrower_semester(self, obj):
        if not obj.borrower:
            return None
        if hasattr(obj.borrower, 'student') and obj.borrower.student and obj.borrower.student.semester:
            return obj.borrower.student.semester.sem_number
        return None

    def get_is_overdue(self, obj):
        if obj.status == IssueRecord.STATUS_ISSUED and obj.due_date:
            from django.utils import timezone
            return timezone.now().date() > obj.due_date
        return False

class FineSerializer(serializers.ModelSerializer):
    issue = IssueRecordSerializer(read_only=True)
    issue_id = serializers.PrimaryKeyRelatedField(queryset=IssueRecord.objects.all(), source='issue', write_only=True)

    class Meta:
        model = Fine
        fields = ['id', 'issue', 'issue_id', 'amount', 'reason', 'assigned_by', 'assigned_at', 'paid', 'paid_at', 'payment_reference']
        read_only_fields = ('assigned_by', 'assigned_at')


class LibraryCardSerializer(serializers.ModelSerializer):
    borrower_name = serializers.SerializerMethodField()
    borrower_id_number = serializers.SerializerMethodField()
    student_name = serializers.SerializerMethodField()
    student_usn = serializers.SerializerMethodField()
    department_name = serializers.SerializerMethodField()
    hod_name = serializers.CharField(source='hod_verified_by.get_full_name', read_only=True)
    issued_by_name = serializers.CharField(source='issued_by.get_full_name', read_only=True)
    photo_url = serializers.SerializerMethodField()
    signature_image_url = serializers.SerializerMethodField()
    hod_signature_image_url = serializers.SerializerMethodField()
    circulation_rows = serializers.SerializerMethodField()

    class Meta:
        model = LibraryCard
        fields = [
            'id', 'card_number', 'borrower_type', 'student_user', 'student', 'faculty',
            'borrower_name', 'borrower_id_number', 'student_name', 'student_usn',
            'department', 'department_name', 'academic_year', 'semester', 'section', 'roll_no',
            'student_photo', 'photo_url', 'signature_image', 'signature_image_url',
            'hod_signature_image', 'hod_signature_image_url', 'components', 'recorded_books',
            'circulation_rows', 'card_fee', 'fee_paid', 'fee_payment_reference',
            'fee_paid_at', 'status', 'rejection_reason', 'hod_verified_by', 'hod_name',
            'hod_verified_at', 'submitted_at', 'issued_by', 'issued_by_name', 'issued_at', 'valid_until',
            'digital_signature_hash', 'qr_code_token', 'created_at', 'updated_at'
        ]
        read_only_fields = (
            'card_number', 'status', 'rejection_reason', 'hod_verified_by', 'hod_verified_at',
            'issued_by', 'issued_at', 'digital_signature_hash', 'qr_code_token', 'created_at', 'updated_at'
        )

    def get_borrower_name(self, obj):
        if obj.borrower_type == 'FACULTY' and obj.faculty:
            return obj.faculty.name
        if obj.student:
            return obj.student.name
        return obj.student_user.get_full_name() or obj.student_user.email or "Borrower"

    def get_borrower_id_number(self, obj):
        if obj.borrower_type == 'FACULTY' and obj.faculty:
            return obj.faculty.faculty_id
        if obj.student and obj.student.usn:
            return obj.student.usn
        return getattr(obj.student_user, 'usn', None) or getattr(obj.student_user, 'user_id', None) or ""

    def get_student_name(self, obj):
        return self.get_borrower_name(obj)

    def get_student_usn(self, obj):
        return self.get_borrower_id_number(obj)

    def get_department_name(self, obj):
        if obj.department:
            return obj.department.name
        if obj.faculty and obj.faculty.department:
            return obj.faculty.department.name
        if obj.student and obj.student.department:
            return obj.student.department.name
        if obj.student_user and getattr(obj.student_user, 'department', None):
            return obj.student_user.department.name
        return "Computer Science and Engineering"

    def get_photo_url(self, obj):
        if obj.student_photo:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.student_photo.url)
            return obj.student_photo.url
        return None

    def get_signature_image_url(self, obj):
        if obj.signature_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.signature_image.url)
            return obj.signature_image.url
        return None

    def get_hod_signature_image_url(self, obj):
        # Keep HOD signature strictly hidden until approval is completed
        if obj.status in [LibraryCard.STATUS_HOD_APPROVED, LibraryCard.STATUS_CARD_GENERATED, LibraryCard.STATUS_ACTIVE] and obj.hod_signature_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.hod_signature_image.url)
            return obj.hod_signature_image.url
        return None

    def get_circulation_rows(self, obj):
        if obj.recorded_books and isinstance(obj.recorded_books, list) and len(obj.recorded_books) > 0:
            rows = []
            for idx, r in enumerate(obj.recorded_books, start=1):
                item = dict(r)
                item['serial_no'] = idx
                rows.append(item)
            return rows

        user = obj.student_user
        if not user and obj.faculty and obj.faculty.user:
            user = obj.faculty.user
        if not user and obj.student and obj.student.user:
            user = obj.student.user

        rows = []
        if user:
            issues = IssueRecord.objects.filter(borrower=user).select_related('copy', 'copy__book').order_by('-issued_at')[:8]
            for idx, issue in enumerate(issues, start=1):
                rows.append({
                    'serial_no': idx,
                    'issue_id': issue.issue_id,
                    'book_title': issue.copy.book.title if (issue.copy and issue.copy.book) else 'Book',
                    'book_copy_no': issue.copy.barcode or f"Copy #{issue.copy.copy_number}" if issue.copy else '',
                    'issued_date': issue.issued_at.strftime('%Y-%m-%d') if issue.issued_at else '',
                    'return_date': issue.returned_at.strftime('%Y-%m-%d') if issue.returned_at else (issue.due_date.strftime('%Y-%m-%d') if issue.due_date else ''),
                    'status': issue.status,
                    'is_signed': True,
                })
        return rows


class LibraryConfigurationSerializer(serializers.ModelSerializer):
    updated_by_name = serializers.CharField(source='updated_by.get_full_name', read_only=True)

    class Meta:
        model = LibraryConfiguration
        fields = '__all__'
        read_only_fields = ('updated_by', 'created_at', 'updated_at')


class LibraryFeedbackSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_role = serializers.CharField(source='user.role', read_only=True)
    responded_by_name = serializers.CharField(source='responded_by.get_full_name', read_only=True)

    class Meta:
        model = LibraryFeedback
        fields = [
            'id', 'user', 'user_name', 'user_role', 'subject', 'category',
            'message', 'rating', 'response', 'responded_by', 'responded_by_name',
            'created_at'
        ]
        read_only_fields = ('user', 'responded_by', 'created_at')

