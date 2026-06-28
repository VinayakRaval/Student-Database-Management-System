from django.contrib import admin
from .models import (
    Department, Book, BookCopy, EBook,
    BookRequest, IssueRecord, Fine, AuditLog
)


class BookCopyInline(admin.TabularInline):
    model = BookCopy
    extra = 0
    readonly_fields = ('created_at',)

@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ('title', 'authors', 'department', 'total_copies', 'available_copies', 'issued_copies')
    search_fields = ('title', 'authors', 'isbn')
    inlines = [BookCopyInline]
    list_filter = ('department',)

@admin.register(BookCopy)
class BookCopyAdmin(admin.ModelAdmin):
    list_display = ('book', 'copy_number', 'barcode', 'status', 'shelf_location')
    list_filter = ('status',)
    search_fields = ('book__title', 'barcode')

@admin.register(EBook)
class EBookAdmin(admin.ModelAdmin):
    list_display = ('book', 'uploaded_by', 'uploaded_at', 'downloads', 'views')
    search_fields = ('book__title',)

@admin.register(BookRequest)
class BookRequestAdmin(admin.ModelAdmin):
    list_display = ('title', 'requester', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('title', 'requester__username')

@admin.register(IssueRecord)
class IssueRecordAdmin(admin.ModelAdmin):
    list_display = ('issue_id', 'copy', 'borrower', 'issued_at', 'due_date', 'returned_at', 'status')
    search_fields = ('issue_id', 'borrower__username', 'copy__book__title')

@admin.register(Fine)
class FineAdmin(admin.ModelAdmin):
    list_display = ('issue', 'amount', 'assigned_by', 'assigned_at', 'paid')
    list_filter = ('paid',)
    search_fields = ('issue__issue_id', 'assigned_by__username')

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('timestamp', 'actor', 'action', 'model_name', 'object_id')
    search_fields = ('actor__username', 'action')
    readonly_fields = ('actor', 'action', 'model_name', 'object_id', 'timestamp', 'extra')
