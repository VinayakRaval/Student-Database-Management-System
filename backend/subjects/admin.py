from django.contrib import admin
from .models import Subject, SubjectAssignment

@admin.register(Subject)
class SubjectAdmin(admin.ModelAdmin):
    list_display = ('subject_code', 'subject_name', 'department', 'semester', 'schema')
    search_fields = ('subject_code', 'subject_name')
    list_filter = ('department', 'semester', 'schema')
    ordering = ('department', 'semester', 'subject_code')


@admin.register(SubjectAssignment)
class SubjectAssignmentAdmin(admin.ModelAdmin):
    list_display = ('subject_code', 'subject_name', 'faculty_name', 'department',  'academic_year')
    search_fields = ('subject__subject_code', 'subject__subject_name', 'faculty__name')
    list_filter = ('department', 'academic_year', 'faculty')
    ordering = ('department', 'academic_year', 'subject__subject_code')

    # Helper methods to display related fields
    def subject_code(self, obj):
        return obj.subject.subject_code
    subject_code.admin_order_field = 'subject__subject_code'
    subject_code.short_description = 'Subject Code'

    def subject_name(self, obj):
        return obj.subject.subject_name
    subject_name.admin_order_field = 'subject__subject_name'
    subject_name.short_description = 'Subject Name'

    def faculty_name(self, obj):
        return obj.faculty.name
    faculty_name.admin_order_field = 'faculty__name'
    faculty_name.short_description = 'Faculty'
