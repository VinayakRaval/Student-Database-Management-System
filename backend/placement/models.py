from django.db import models
from django.conf import settings
from academics.models import Department
from faculty.models import Faculty
from students.models import Student


class Company(models.Model):
    name = models.CharField(max_length=200, unique=True)
    industry = models.CharField(max_length=100)
    location = models.CharField(max_length=150)
    website = models.CharField(max_length=255, blank=True, default='')
    contact_person = models.CharField(max_length=150)
    contact_email = models.EmailField(max_length=254)
    contact_phone = models.CharField(max_length=20)
    description = models.TextField(blank=True, default='')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'placement_company'
        ordering = ['name']
        verbose_name_plural = 'Companies'

    def __str__(self):
        return self.name


class PlacementDrive(models.Model):
    EMPLOYMENT_CHOICES = [
        ('FULL_TIME', 'Full Time'),
        ('INTERNSHIP', 'Internship'),
        ('INTERN_PLUS_FULL_TIME', 'Internship + Full Time'),
    ]
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('PUBLISHED', 'Published'),
        ('CLOSED', 'Closed'),
        ('CANCELLED', 'Cancelled'),
    ]

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='drives')
    job_role = models.CharField(max_length=150)
    job_description = models.TextField()
    employment_type = models.CharField(max_length=30, choices=EMPLOYMENT_CHOICES, default='FULL_TIME')
    package_lpa = models.DecimalField(max_digits=6, decimal_places=2, default=0.0)
    stipend_per_month = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    job_location = models.CharField(max_length=150, default='Pan India')
    eligible_batch = models.CharField(max_length=50, blank=True, default='')
    eligible_departments = models.ManyToManyField(Department, related_name='eligible_placement_drives', blank=True)
    min_cgpa = models.DecimalField(max_digits=4, decimal_places=2, default=0.0)
    max_active_backlogs = models.IntegerField(default=0)
    application_deadline = models.DateTimeField()
    drive_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')
    selection_process = models.TextField(blank=True, default='')
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_drives')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'placement_drive'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.job_role} - {self.company.name}"


class PlacementRound(models.Model):
    ROUND_TYPES = [
        ('ONLINE_TEST', 'Online Assessment / Aptitude'),
        ('TECHNICAL', 'Technical Interview'),
        ('HR', 'HR Interview'),
        ('GROUP_DISCUSSION', 'Group Discussion'),
        ('OTHER', 'Other Assessment'),
    ]

    drive = models.ForeignKey(PlacementDrive, on_delete=models.CASCADE, related_name='rounds')
    round_number = models.IntegerField(default=1)
    round_name = models.CharField(max_length=100)
    round_type = models.CharField(max_length=30, choices=ROUND_TYPES, default='ONLINE_TEST')
    scheduled_at = models.DateTimeField(null=True, blank=True)
    venue = models.CharField(max_length=200, blank=True, default='')
    details = models.TextField(blank=True, default='')
    is_completed = models.BooleanField(default=False)

    class Meta:
        db_table = 'placement_round'
        ordering = ['drive', 'round_number']
        unique_together = ('drive', 'round_number')

    def __str__(self):
        return f"Round {self.round_number}: {self.round_name} ({self.drive.job_role})"


class PlacementApplication(models.Model):
    STATUS_CHOICES = [
        ('APPLIED', 'Applied'),
        ('SHORTLISTED', 'Shortlisted'),
        ('IN_PROCESS', 'In Process'),
        ('SELECTED', 'Selected'),
        ('REJECTED', 'Rejected'),
    ]

    drive = models.ForeignKey(PlacementDrive, on_delete=models.CASCADE, related_name='applications')
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='placement_applications')
    applied_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='APPLIED')
    current_round = models.ForeignKey(PlacementRound, on_delete=models.SET_NULL, null=True, blank=True, related_name='current_candidates')
    decision_reason = models.TextField(blank=True, default='')

    class Meta:
        db_table = 'placement_application'
        ordering = ['-applied_at']
        unique_together = ('drive', 'student')

    def __str__(self):
        return f"{self.student.name} - {self.drive.job_role}"


class PlacementOffer(models.Model):
    OFFER_STATUS = [
        ('OFFERED', 'Offer Received'),
        ('ACCEPTED', 'Offer Accepted'),
        ('REJECTED', 'Offer Rejected'),
        ('JOINED', 'Joined Company'),
    ]

    application = models.OneToOneField(PlacementApplication, on_delete=models.CASCADE, related_name='offer')
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='placement_offers')
    drive = models.ForeignKey(PlacementDrive, on_delete=models.CASCADE, related_name='offers')
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='offers')
    designation = models.CharField(max_length=150)
    offered_package_lpa = models.DecimalField(max_digits=6, decimal_places=2)
    offer_letter = models.FileField(upload_to='documents/offers/', null=True, blank=True)
    offer_date = models.DateField()
    joining_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=OFFER_STATUS, default='OFFERED')
    status_updated_at = models.DateTimeField(auto_now=True)
    remarks = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'placement_offer'
        ordering = ['-offer_date']

    def __str__(self):
        return f"Offer for {self.student.name} - {self.company.name} ({self.offered_package_lpa} LPA)"


class RoundCandidateResult(models.Model):
    round = models.ForeignKey(PlacementRound, on_delete=models.CASCADE, related_name='candidate_results')
    application = models.ForeignKey(PlacementApplication, on_delete=models.CASCADE, related_name='round_results')
    attendance = models.CharField(max_length=20, choices=[('PENDING', 'Pending'), ('PRESENT', 'Present'), ('ABSENT', 'Absent')], default='PENDING')
    result = models.CharField(max_length=20, choices=[('PENDING', 'Pending Evaluation'), ('CLEARED', 'Cleared / Advanced'), ('ON_HOLD', 'On Hold'), ('ELIMINATED', 'Eliminated')], default='PENDING')
    feedback = models.TextField(blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'placement_round_candidate_result'
        unique_together = ('round', 'application')


class StudentPlacementProfile(models.Model):
    STATUS_CHOICES = [
        ('SEEKING', 'Seeking Placement'),
        ('PLACED', 'Placed'),
        ('OPTED_OUT', 'Opted Out'),
    ]

    student = models.OneToOneField(Student, on_delete=models.CASCADE, related_name='placement_profile')
    is_registered = models.BooleanField(default=True)
    skills = models.TextField(blank=True, default='')
    certifications = models.TextField(blank=True, default='')
    resume = models.FileField(upload_to='documents/resumes/', null=True, blank=True)
    linkedin_url = models.CharField(max_length=255, blank=True, default='')
    github_url = models.CharField(max_length=255, blank=True, default='')
    portfolio_url = models.CharField(max_length=255, blank=True, default='')
    placement_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='SEEKING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'student_placement_profile'


class PlacementOfficerAssignment(models.Model):
    STATUS_CHOICES = [
        ('INVITATION_PENDING', 'Invitation Pending'),
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
    ]

    faculty = models.ForeignKey(Faculty, on_delete=models.CASCADE, related_name='placement_officer_assignments')
    department = models.ForeignKey(Department, on_delete=models.CASCADE, related_name='placement_officer_assignments')
    assigned_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_placement_officers')
    official_email = models.EmailField(max_length=254)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='ACTIVE')
    assigned_date = models.DateField(auto_now_add=True)
    revoked_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'placement_officer_assignment'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.faculty.name} - Placement Officer ({self.department.name}) [{self.status}]"
