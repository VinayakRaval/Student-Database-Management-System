from rest_framework import serializers
from .models import (
    Department, Book, BookCopy, EBook,
    BookRequest, IssueRecord, Fine, AuditLog
)
from academics.serializers import DepartmentSerializer


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

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'subtitle', 'authors', 'edition', 'publisher', 'year',
            'department',"department_id", 'category', 'language', 'isbn', 'mrp',
            'description', 'total_copies', 'available_copies', 'issued_copies', 'copies'
        ]

class EBookSerializer(serializers.ModelSerializer):
    book = BookSerializer(read_only=True)
    book_id = serializers.PrimaryKeyRelatedField(queryset=Book.objects.all(), source='book', write_only=True)

    class Meta:
        model = EBook
        fields = ['id', 'book', 'book_id', 'file', 'external_link', 'uploaded_by', 'uploaded_at', 'downloads', 'views']
        read_only_fields = ('uploaded_by', 'uploaded_at', 'downloads', 'views')

class BookRequestSerializer(serializers.ModelSerializer):
    requester = serializers.PrimaryKeyRelatedField(read_only=True)
    class Meta:
        model = BookRequest
        fields = ['id', 'requester', 'title', 'authors', 'reason', 'urgency', 'status', 'created_at', 'updated_at']

class IssueRecordSerializer(serializers.ModelSerializer):
    copy = BookCopySerializer(read_only=True)
    copy_id = serializers.PrimaryKeyRelatedField(queryset=BookCopy.objects.all(), source='copy', write_only=True)
    borrower = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = IssueRecord
        fields = ['id', 'issue_id', 'borrower', 'copy', 'copy_id', 'issued_at', 'due_date', 'returned_at', 'status', 'created_by']
        read_only_fields = ('issue_id', 'issued_at', 'status', 'created_by')

class FineSerializer(serializers.ModelSerializer):
    issue = IssueRecordSerializer(read_only=True)
    issue_id = serializers.PrimaryKeyRelatedField(queryset=IssueRecord.objects.all(), source='issue', write_only=True)

    class Meta:
        model = Fine
        fields = ['id', 'issue', 'issue_id', 'amount', 'reason', 'assigned_by', 'assigned_at', 'paid', 'paid_at', 'payment_reference']
        read_only_fields = ('assigned_by', 'assigned_at')
