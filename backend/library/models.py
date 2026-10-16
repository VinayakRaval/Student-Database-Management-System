from django.db import models
from django.conf import settings
from django.utils import timezone
from django.core.validators import MinValueValidator
from academics.models import Department  # ✅ Import existing model
from django.utils.text import slugify

User = settings.AUTH_USER_MODEL


# ---------- BookCategory ----------
class BookCategory(models.Model):
    name = models.CharField(max_length=128, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'library_book_category'
        verbose_name_plural = 'Book Categories'
        ordering = ['name']

    def __str__(self):
        return self.name


# ---------- Book ----------
class Book(models.Model):
    title = models.CharField(max_length=512)
    subtitle = models.CharField(max_length=512, blank=True)
    authors = models.CharField(max_length=512, blank=True)
    edition = models.CharField(max_length=64, blank=True)
    publisher = models.CharField(max_length=256, blank=True)
    year = models.PositiveIntegerField(null=True, blank=True)
    department = models.ForeignKey(Department, null=True, blank=True, on_delete=models.SET_NULL)
    category = models.CharField(max_length=128, blank=True)
    language = models.CharField(max_length=64, blank=True)
    isbn = models.CharField(max_length=32, blank=True)
    mrp = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    cover_image = models.ImageField(upload_to='book_covers/', null=True, blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['title']

    def __str__(self):
        return self.title

    @property
    def total_copies(self):
        return self.copies.count()

    @property
    def available_copies(self):
        return self.copies.filter(status=BookCopy.STATUS_AVAILABLE).count()

    @property
    def issued_copies(self):
        return self.copies.filter(status=BookCopy.STATUS_ISSUED).count()

    @property
    def is_out_of_stock(self):
        return self.available_copies == 0

# ---------- BookCopy ----------
class BookCopy(models.Model):
    STATUS_AVAILABLE = 'available'
    STATUS_ISSUED = 'issued'
    STATUS_LOST = 'lost'
    STATUS_DAMAGED = 'damaged'
    STATUS_MAINTENANCE = 'maintenance'

    STATUS_CHOICES = [
        (STATUS_AVAILABLE, 'Available'),
        (STATUS_ISSUED, 'Issued'),
        (STATUS_LOST, 'Lost'),
        (STATUS_DAMAGED, 'Damaged'),
        (STATUS_MAINTENANCE, 'Maintenance'),
    ]

    book = models.ForeignKey('Book', related_name='copies', on_delete=models.CASCADE)
    copy_number = models.PositiveIntegerField(default=1)
    barcode = models.CharField(max_length=128, blank=True, null=True, unique=True)
    shelf_location = models.CharField(max_length=128, blank=True)
    status = models.CharField(max_length=32, choices=STATUS_CHOICES, default=STATUS_AVAILABLE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'library_book_copy'
        unique_together = (('book', 'copy_number'),)
        ordering = ('book', 'copy_number')

    def save(self, *args, **kwargs):
        # Auto-generate collision-resistant barcode if missing
        if not self.barcode:
            import re
            raw_title = self.book.title if (self.book and self.book.title) else "BK"
            clean_prefix = re.sub(r'[^A-Za-z0-9]', '', raw_title)[:3].upper() or "LIB"
            book_id_part = f"{self.book_id:04d}" if self.book_id else "0000"
            self.barcode = f"{clean_prefix}-{book_id_part}-{self.copy_number:03d}"

        # Auto-set shelf location if missing
        if not self.shelf_location:
            existing_copy = BookCopy.objects.filter(book=self.book).exclude(id=self.id).first()
            if existing_copy and existing_copy.shelf_location:
                self.shelf_location = existing_copy.shelf_location
            else:
                self.shelf_location = "Stack A-1"

        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.book.title} - Copy {self.copy_number}"

# ---------- EBook ----------
class EBook(models.Model):
    book = models.OneToOneField(Book, related_name='ebook', on_delete=models.CASCADE)
    file = models.FileField(upload_to='ebooks/', blank=True, null=True)
    external_link = models.URLField(blank=True)
    uploaded_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    downloads = models.PositiveIntegerField(default=0)
    views = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"eBook: {self.book.title}"

# ---------- BookRequest ----------
class BookRequest(models.Model):
    REQUEST_STATUS_PENDING = 'pending'
    REQUEST_STATUS_VERIFIED = 'verified'
    REQUEST_STATUS_APPROVED = 'approved'
    REQUEST_STATUS_PURCHASED = 'purchased'
    REQUEST_STATUS_REJECTED = 'rejected'

    STATUS_CHOICES = [
        (REQUEST_STATUS_PENDING, 'Pending'),
        (REQUEST_STATUS_VERIFIED, 'Verified'),
        (REQUEST_STATUS_APPROVED, 'Approved'),
        (REQUEST_STATUS_PURCHASED, 'Purchased'),
        (REQUEST_STATUS_REJECTED, 'Rejected'),
    ]

    requester = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.CharField(max_length=512)
    authors = models.CharField(max_length=512, blank=True)
    reason = models.TextField(blank=True)
    urgency = models.CharField(max_length=64, blank=True)
    status = models.CharField(max_length=32, choices=STATUS_CHOICES, default=REQUEST_STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    forwarded_to = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='forwarded_requests')

    class Meta:
        db_table = 'library_book_request'
        ordering = ['-created_at']

    def __str__(self):
        return f"Request: {self.title} by {self.requester} [{self.status}]"


# ---------- IssueRecord ----------
class IssueRecord(models.Model):
    STATUS_ISSUED = 'issued'
    STATUS_RETURNED = 'returned'
    STATUS_LOST = 'lost'

    issue_id = models.CharField(max_length=64, unique=True)
    borrower = models.ForeignKey(User, on_delete=models.CASCADE, related_name='borrowed_books')
    copy = models.ForeignKey(BookCopy, on_delete=models.CASCADE, related_name='issues')
    issued_at = models.DateTimeField(default=timezone.now)
    due_date = models.DateField()
    returned_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=32, default=STATUS_ISSUED)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='issues_created')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'library_issue_record'
        ordering = ['-issued_at']

    @property
    def is_overdue(self):
        if self.status == self.STATUS_ISSUED and self.due_date:
            return timezone.now().date() > self.due_date
        return False

    @property
    def overdue_days(self):
        if self.due_date and timezone.now().date() > self.due_date:
            return (timezone.now().date() - self.due_date).days
        return 0

    def __str__(self):
        return f"{self.issue_id} - {self.copy} to {self.borrower}"


# ---------- Fine ----------
class Fine(models.Model):
    issue = models.ForeignKey(IssueRecord, related_name='fines', on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    reason = models.CharField(max_length=256, blank=True)
    assigned_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL)
    assigned_at = models.DateTimeField(auto_now_add=True)
    paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    payment_reference = models.CharField(max_length=256, blank=True)

    class Meta:
        db_table = 'library_fine'
        ordering = ['-assigned_at']

    def __str__(self):
        return f"Fine: {self.amount} for {self.issue}"

# ---------- AuditLog ----------
class AuditLog(models.Model):
    actor = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=128)
    model_name = models.CharField(max_length=128, blank=True)
    object_id = models.CharField(max_length=64, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    extra = models.JSONField(null=True, blank=True)

    class Meta:
        db_table = 'library_audit_log'
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.timestamp} - {self.actor} - {self.action}"


# ---------- LibraryCard ----------
# ---------- LibraryConfiguration ----------
class LibraryConfiguration(models.Model):
    academic_year = models.CharField(max_length=32, default="2025-2026")
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    # Borrowing Rules
    max_books_student = models.PositiveIntegerField(default=3)
    max_books_faculty = models.PositiveIntegerField(default=5)
    loan_duration_days = models.PositiveIntegerField(default=14)
    loan_days_student = models.PositiveIntegerField(default=14)
    loan_days_faculty = models.PositiveIntegerField(default=30)

    # Eligibility
    allow_students = models.BooleanField(default=True)
    allow_faculty = models.BooleanField(default=True)
    require_active_membership = models.BooleanField(default=True)

    # Card Settings
    card_title = models.CharField(max_length=128, default="LIBRARY ISSUE CARD")
    card_prefix = models.CharField(max_length=16, default="LC")
    card_number_format = models.CharField(max_length=64, default="LC-YYYY-NNNNNN")
    validity_months = models.PositiveIntegerField(default=12)

    # Approval Settings
    require_hod_approval = models.BooleanField(default=True)
    require_principal_approval = models.BooleanField(default=False)

    # Digital Signature & Authorized Librarian
    authorized_librarian_name = models.CharField(max_length=128, default="College Library Officer")
    librarian_designation = models.CharField(max_length=128, default="Chief Librarian")
    digital_stamp_title = models.CharField(max_length=128, default="DIGITAL STAMP")
    digital_stamp_sub = models.CharField(max_length=128, default="College Library Officer")
    signature_key = models.CharField(max_length=256, blank=True)

    # Charges: Free borrowing, no late fine (0.00)
    borrowing_fee = models.DecimalField(max_digits=6, decimal_places=2, default=0.00)
    late_fine_per_day = models.DecimalField(max_digits=6, decimal_places=2, default=0.00)

    updated_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'library_configuration'
        ordering = ['-updated_at']

    def __str__(self):
        return f"LibraryConfig ({self.academic_year}) - Active: {self.is_active}"


# ---------- LibraryCard ----------
class LibraryCard(models.Model):
    STATUS_DRAFT = 'DRAFT'
    STATUS_PAYMENT_PENDING = 'PAYMENT_PENDING'
    STATUS_PENDING_HOD = 'PENDING_HOD'
    STATUS_REJECTED = 'REJECTED'
    STATUS_HOD_APPROVED = 'HOD_APPROVED'
    STATUS_CARD_GENERATED = 'CARD_GENERATED'
    STATUS_ACTIVE = 'ACTIVE'
    STATUS_SUSPENDED = 'SUSPENDED'
    STATUS_EXPIRED = 'EXPIRED'
    STATUS_LOST = 'LOST'

    STATUS_CHOICES = [
        (STATUS_DRAFT, 'Draft'),
        (STATUS_PAYMENT_PENDING, 'Payment Pending'),
        (STATUS_PENDING_HOD, 'Pending HOD Verification'),
        (STATUS_REJECTED, 'Rejected'),
        (STATUS_HOD_APPROVED, 'HOD Approved'),
        (STATUS_CARD_GENERATED, 'Card Generated'),
        (STATUS_ACTIVE, 'Active'),
        (STATUS_SUSPENDED, 'Suspended'),
        (STATUS_EXPIRED, 'Expired'),
        (STATUS_LOST, 'Lost or Replaced'),
    ]

    card_number = models.CharField(max_length=64, unique=True, null=True, blank=True)
    borrower_type = models.CharField(max_length=16, default='STUDENT', choices=[('STUDENT', 'Student'), ('FACULTY', 'Faculty')])
    student_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='library_cards')
    student = models.ForeignKey('students.Student', null=True, blank=True, on_delete=models.CASCADE, related_name='library_cards')
    faculty = models.ForeignKey('faculty.Faculty', null=True, blank=True, on_delete=models.SET_NULL, related_name='library_cards')
    department = models.ForeignKey(Department, on_delete=models.SET_NULL, null=True, blank=True)

    academic_year = models.CharField(max_length=32, default="2025-2026")
    semester = models.IntegerField(null=True, blank=True)
    section = models.CharField(max_length=16, blank=True, default="A")
    roll_no = models.CharField(max_length=32, blank=True)
    student_photo = models.ImageField(upload_to='library_cards/photos/', null=True, blank=True)

    card_fee = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    fee_paid = models.BooleanField(default=True)
    fee_payment_reference = models.CharField(max_length=128, blank=True, default="FREE-MEMBERSHIP")
    fee_paid_at = models.DateTimeField(null=True, blank=True)

    status = models.CharField(max_length=32, choices=STATUS_CHOICES, default=STATUS_PENDING_HOD)
    rejection_reason = models.TextField(blank=True)

    hod_verified_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='hod_verified_library_cards')
    hod_verified_at = models.DateTimeField(null=True, blank=True)

    issued_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='issued_library_cards')
    issued_at = models.DateTimeField(null=True, blank=True)
    valid_until = models.DateField(null=True, blank=True)

    digital_signature_hash = models.CharField(max_length=256, blank=True)
    qr_code_token = models.CharField(max_length=128, unique=True, null=True, blank=True)
    components = models.JSONField(default=list, blank=True)
    signature_image = models.ImageField(upload_to='library_cards/signatures/', null=True, blank=True)
    hod_signature_image = models.ImageField(upload_to='library_cards/hod_signatures/', null=True, blank=True)
    recorded_books = models.JSONField(default=list, blank=True)
    submitted_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'library_card'
        ordering = ['-created_at']

    @classmethod
    def generate_next_card_number(cls, year=None):
        import re
        if not year:
            year = timezone.now().year
        prefix = f"LC-{year}-"
        existing_numbers = cls.objects.filter(card_number__startswith=prefix).values_list('card_number', flat=True)
        max_seq = 0
        for num in existing_numbers:
            if num:
                match = re.search(r'LC-\d+-(\d+)', num)
                if match:
                    try:
                        seq = int(match.group(1))
                        if seq > max_seq:
                            max_seq = seq
                    except ValueError:
                        pass
        next_seq = max_seq + 1
        return f"LC-{year}-{next_seq:06d}"

    def __str__(self):
        return f"LibraryCard {self.card_number or 'UNISSUED'} - {self.student_user}"


# ---------- LibraryFeedback ----------
class LibraryFeedback(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='library_feedbacks')
    subject = models.CharField(max_length=256)
    category = models.CharField(max_length=64, default='General')
    message = models.TextField()
    rating = models.PositiveSmallIntegerField(default=5)
    response = models.TextField(blank=True)
    responded_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='responded_feedbacks')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'library_feedback'
        ordering = ['-created_at']

    def __str__(self):
        return f"Feedback: {self.subject} by {self.user}"

