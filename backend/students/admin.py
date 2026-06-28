from django.contrib import admin
from .models import Student

@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ('name', 'cet_no', 'email', 'mobile_no', 'department', 'admission_id', 'registration_status')
    list_filter = ('department', 'registration_status', 'gender', 'caste')
    search_fields = ('name', 'email', 'mobile_no', 'admission_id', 'usn', 'cet_no')
    readonly_fields = ('admission_id',)
    fieldsets = (
        ("Personal Information", {
            'fields': ('name', 'cet_no', 'dob', 'gender', 'religion', 'city_type',
                       'mobile_no', 'email', 'father_name', 'mother_name', 'parent_occupation',
                       'address', 'permanent_address', 'nationality', 'state')
        }),
        ("Academic Details", {
            'fields': ('department', 'semester', 'academic_year',
                       'date_of_admission', 'seat_type', 'other_reservation', 'caste')
        }),
        ("Admission Info", {
            'fields': ('admission_id', 'usn', 'admission_quota', 'rank',
                       'status', 'registration_status')
        }),
        ("Marks & Documents", {
            'classes': ('collapse',),
            'fields': (
                'sslc_regno', 'sslc_year', 'sslc_obtain_marks', 'sslc_total_marks', 'sslc_marksheet',
                'puc_regno', 'puc_year', 'puc_obtain_marks', 'puc_total_marks', 'puc_marksheet',
                'diploma_regno', 'diploma_year', 'diploma_obtain_marks', 'diploma_total_marks', 'diploma_marksheet',
                'kannada_medium_certificate', 'hyderabad_karnataka_certificate', 'caste_certificate',
                'kea_acknowledgement', 'study_certificate', 'photo', 'signature'
            )
        }),
    )
