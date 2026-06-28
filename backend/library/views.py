import uuid
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import (
    Department, Book, BookCopy, EBook, BookRequest,
    IssueRecord, Fine, AuditLog
)
from .serializers import (
    DepartmentSerializer, BookSerializer, BookCopySerializer, EBookSerializer,
    BookRequestSerializer, IssueRecordSerializer, FineSerializer
)
from .permissions import IsLibraryOfficer, IsPrincipal


# ---------- Books ----------
class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.prefetch_related('copies').all()
    serializer_class = BookSerializer

    def perform_create(self, serializer):
        book = serializer.save()
        AuditLog.objects.create(actor=self.request.user, action='add_book', model_name='Book', object_id=str(book.id))

    @action(detail=True, methods=['post'])
    def add_copies(self, request, pk=None):
        book = self.get_object()
        count = int(request.data.get('count', 1))
        created = []
        with transaction.atomic():
            last_copy = book.copies.order_by('-copy_number').first()
            start = last_copy.copy_number + 1 if last_copy else 1
            for i in range(start, start + count):
                copy = BookCopy.objects.create(book=book, copy_number=i)
                created.append(copy.id)
        AuditLog.objects.create(actor=request.user, action='add_copies', model_name='Book', object_id=str(book.id), extra={'created_ids': created})
        return Response({'created_copy_ids': created}, status=status.HTTP_201_CREATED)

# ---------- BookCopy ----------
class BookCopyViewSet(viewsets.ModelViewSet):
    queryset = BookCopy.objects.select_related('book').all()
    serializer_class = BookCopySerializer

# ---------- EBooks ----------
class EBookViewSet(viewsets.ModelViewSet):
    queryset = EBook.objects.select_related('book').all()
    serializer_class = EBookSerializer

    def perform_create(self, serializer):
        ebook = serializer.save(uploaded_by=self.request.user)
        AuditLog.objects.create(actor=self.request.user, action='upload_ebook', model_name='EBook', object_id=str(ebook.id))

# ---------- Book Requests ----------
# ---------- Book Requests ----------
class BookRequestViewSet(viewsets.ModelViewSet):
    queryset = BookRequest.objects.all()
    serializer_class = BookRequestSerializer

    def perform_create(self, serializer):
        req = serializer.save(requester=self.request.user)
        AuditLog.objects.create(
            actor=self.request.user,
            action='create_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )

    # Step 2️⃣ — Library Officer verifies the request
    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def verify(self, request, pk=None):
        req = self.get_object()
        req.status = BookRequest.REQUEST_STATUS_VERIFIED
        req.forwarded_to = None  # Optionally clear previous forwarding
        req.save()
        AuditLog.objects.create(
            actor=request.user,
            action='verify_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )
        return Response({'status': req.status})

    # Step 3️⃣ — Principal gives final approval
    @action(detail=True, methods=['post'], permission_classes=[IsPrincipal])
    def final_approve(self, request, pk=None):
        req = self.get_object()

        # Ensure request is verified before Principal approval
        if req.status != BookRequest.REQUEST_STATUS_VERIFIED:
            return Response(
                {'detail': 'Request must be verified before Principal approval.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        req.status = BookRequest.REQUEST_STATUS_PURCHASED
        req.forwarded_to = request.user
        req.save()

        AuditLog.objects.create(
            actor=request.user,
            action='final_approve_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )

        return Response({'status': req.status})

# ---------- Issue / Return ----------
class IssueViewSet(viewsets.ModelViewSet):
    queryset = IssueRecord.objects.select_related('copy', 'borrower').all()
    serializer_class = IssueRecordSerializer

    def create(self, request, *args, **kwargs):
        """
        Issue a book copy to the current request.user (borrower).
        Required fields in request.data: copy_id, due_date (YYYY-MM-DD)
        """
        copy_id = request.data.get('copy_id')
        due_date = request.data.get('due_date')
        if not (copy_id and due_date):
            return Response({'detail': 'copy_id and due_date required'}, status=status.HTTP_400_BAD_REQUEST)
        copy = get_object_or_404(BookCopy, id=copy_id)
        if copy.status != BookCopy.STATUS_AVAILABLE:
            return Response({'detail': 'Copy not available'}, status=status.HTTP_400_BAD_REQUEST)
        # create issue
        issue_id = str(uuid.uuid4())[:12]
        issue = IssueRecord.objects.create(issue_id=issue_id, borrower=request.user, copy=copy, due_date=due_date, created_by=request.user)
        copy.status = BookCopy.STATUS_ISSUED
        copy.save()
        AuditLog.objects.create(actor=request.user, action='issue_book', model_name='IssueRecord', object_id=str(issue.id))
        serializer = self.get_serializer(issue)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def return_book(self, request, pk=None):
        """
        Library officer marks the book returned.
        If late: officer must create/assign Fine (manual).
        """
        issue = self.get_object()
        if issue.status != IssueRecord.STATUS_ISSUED:
            return Response({'detail': 'Issue not active'}, status=status.HTTP_400_BAD_REQUEST)
        issue.returned_at = timezone.now()
        issue.status = IssueRecord.STATUS_RETURNED
        issue.save()
        # update copy
        copy = issue.copy
        copy.status = BookCopy.STATUS_AVAILABLE
        copy.save()
        AuditLog.objects.create(actor=request.user, action='return_book', model_name='IssueRecord', object_id=str(issue.id))
        return Response({'status': 'returned'})

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_lost(self, request, pk=None):
        issue = self.get_object()
        issue.status = IssueRecord.STATUS_LOST
        issue.returned_at = timezone.now()
        issue.save()
        copy = issue.copy
        copy.status = BookCopy.STATUS_LOST
        copy.save()
        # create fine equal to MRP (manual override allowed)
        amount = copy.book.mrp or 0
        fine = Fine.objects.create(issue=issue, amount=amount, reason='Lost book', assigned_by=request.user)
        AuditLog.objects.create(actor=request.user, action='mark_lost', model_name='IssueRecord', object_id=str(issue.id), extra={'fine_id': fine.id})
        return Response({'status': 'lost', 'fine_id': fine.id})

# ---------- Fine ----------
class FineViewSet(viewsets.ModelViewSet):
    queryset = Fine.objects.select_related('issue').all()
    serializer_class = FineSerializer

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def assign(self, request, pk=None):
        fine = self.get_object()
        amount = request.data.get('amount')
        reason = request.data.get('reason', '')
        if amount is None:
            return Response({'detail': 'amount required'}, status=status.HTTP_400_BAD_REQUEST)
        fine.amount = amount
        fine.reason = reason
        fine.assigned_by = request.user
        fine.save()
        AuditLog.objects.create(actor=request.user, action='assign_fine', model_name='Fine', object_id=str(fine.id))
        return Response({'status': 'assigned'})

    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        fine = self.get_object()
        fine.paid = True
        fine.paid_at = timezone.now()
        fine.payment_reference = request.data.get('payment_reference', '')
        fine.save()
        AuditLog.objects.create(actor=request.user, action='pay_fine', model_name='Fine', object_id=str(fine.id))
        return Response({'status': 'paid'})
