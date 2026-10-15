from django.db import models
from django.conf import settings
from django.utils import timezone
from django.core.validators import MinValueValidator
from academics.models import Department  # ✅ Import existing model
from django.utils.text import slugify

User = settings.AUTH_USER_MODEL


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

    class Meta:
        db_table = 'library_book_copy'
        unique_together = (('book', 'copy_number'),)
        ordering = ('book', 'copy_number')

    def save(self, *args, **kwargs):
        # ✅ Auto-generate barcode if missing
        if not self.barcode:
            prefix = (self.book.title[:3].upper() if self.book and self.book.title else "BOOK")
            self.barcode = f"{prefix}-{self.copy_number:03}"

        # ✅ Auto-set shelf location
        if not self.shelf_location:
            # Try to reuse shelf location from any existing copy of same book
            existing_copy = BookCopy.objects.filter(book=self.book).exclude(id=self.id).first()
            if existing_copy and existing_copy.shelf_location:
                self.shelf_location = existing_copy.shelf_location
            else:
                self.shelf_location = "Rack"  # default generic rack name

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

    def __str__(self):
        return f"Request: {self.title} by {self.requester} [{self.status}]"

# ---------- IssueRecord ----------

    class Meta:
        db_table = 'library_book_request'
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

    def __str__(self):
        return f"{self.issue_id} - {self.copy} to {self.borrower}"

# ---------- Fine ----------

    class Meta:
        db_table = 'library_issue_record'
class Fine(models.Model):
    issue = models.ForeignKey(IssueRecord, related_name='fines', on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    reason = models.CharField(max_length=256, blank=True)
    assigned_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL)
    assigned_at = models.DateTimeField(auto_now_add=True)
    paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    payment_reference = models.CharField(max_length=256, blank=True)

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
