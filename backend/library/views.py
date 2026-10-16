import uuid
import hashlib
from datetime import timedelta
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import viewsets, status, filters, permissions
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import (
    Department, BookCategory, Book, BookCopy, EBook, BookRequest,
    IssueRecord, Fine, AuditLog, LibraryCard,
    LibraryConfiguration, LibraryFeedback
)
from .serializers import (
    DepartmentSerializer, BookCategorySerializer, BookSerializer, BookCopySerializer, EBookSerializer,
    BookRequestSerializer, IssueRecordSerializer, FineSerializer, LibraryCardSerializer,
    LibraryConfigurationSerializer, LibraryFeedbackSerializer
)
from .permissions import (
    IsLibraryOfficer, IsLibraryOfficerOrReadOnly,
    IsPrincipal, IsBorrowerOrLibraryOfficer, IsRequesterOrLibraryOfficer, IsHOD
)

User = get_user_model()


def ensure_user_for_faculty(fac):
    if not fac:
        return None
    if fac.user:
        return fac.user
    user = User.objects.filter(Q(email__iexact=fac.email) | Q(user_id__iexact=fac.faculty_id)).first()
    if not user:
        user = User.objects.create_user(
            email=fac.email,
            user_id=fac.faculty_id or f"FAC-{fac.id}",
            role="PROFESSOR",
            department=fac.department
        )
    fac.user = user
    fac.save(update_fields=['user'])
    return user


def ensure_user_for_student(st):
    if not st:
        return None
    if st.user:
        return st.user
    identifier = st.usn or st.admission_id or f"STU-{st.id}"
    user = User.objects.filter(Q(email__iexact=st.email) | Q(usn__iexact=identifier) | Q(user_id__iexact=identifier)).first()
    if not user:
        user = User.objects.create_user(
            email=st.email,
            usn=st.usn or identifier,
            user_id=identifier,
            role="STUDENT",
            department=st.department
        )
    st.user = user
    st.save(update_fields=['user'])
    return user


# ---------- Book Categories ----------
class BookCategoryViewSet(viewsets.ModelViewSet):
    queryset = BookCategory.objects.all().order_by('name')
    serializer_class = BookCategorySerializer
    pagination_class = None
    permission_classes = [permissions.IsAuthenticated, IsLibraryOfficerOrReadOnly]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name']

    def list(self, request, *args, **kwargs):
        if BookCategory.objects.count() == 0:
            defaults = [
                "Computer Science and Engineering",
                "Electronics and Communication Engineering",
                "Civil Engineering",
                "Mechanical Engineering",
                "Basic Sciences & Humanities",
                "Mathematics",
                "Physics & Chemistry",
                "General Reference",
                "Competitive Examinations",
            ]
            for name in defaults:
                BookCategory.objects.get_or_create(name=name)
        return super().list(request, *args, **kwargs)

    def perform_create(self, serializer):
        category = serializer.save()
        AuditLog.objects.create(actor=self.request.user, action='add_category', model_name='BookCategory', object_id=str(category.id))


# ---------- Books ----------
class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.prefetch_related('copies').all().order_by('-id')
    serializer_class = BookSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryOfficerOrReadOnly]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'authors', 'isbn', 'category', 'publisher', 'subtitle']
    ordering_fields = ['title', 'year', 'created_at', 'id']
    ordering = ['-id']

    def perform_create(self, serializer):
        book = serializer.save()
        initial_copies_val = self.request.data.get('initial_copies') or self.request.data.get('copies_count')
        if initial_copies_val is not None:
            try:
                count = int(initial_copies_val)
                if count > 0:
                    for i in range(1, count + 1):
                        BookCopy.objects.create(
                            book=book,
                            copy_number=i,
                            status=BookCopy.STATUS_AVAILABLE,
                            shelf_location='Stack A-1'
                        )
            except (ValueError, TypeError):
                pass
        AuditLog.objects.create(actor=self.request.user, action='add_book', model_name='Book', object_id=str(book.id))

    def perform_destroy(self, instance):
        AuditLog.objects.create(actor=self.request.user, action='delete_book', model_name='Book', object_id=str(instance.id), extra={'title': instance.title})
        instance.delete()

    @action(detail=False, methods=['get'])
    def stats(self, request):
        from django.db.models import Sum
        now_date = timezone.now().date()
        total_titles = Book.objects.count()
        total_copies = BookCopy.objects.count()
        available_copies = BookCopy.objects.filter(status=BookCopy.STATUS_AVAILABLE).count()
        issued_copies = BookCopy.objects.filter(status=BookCopy.STATUS_ISSUED).count()
        overdue_count = IssueRecord.objects.filter(status=IssueRecord.STATUS_ISSUED, due_date__lt=now_date).count()
        lost_copies = BookCopy.objects.filter(status=BookCopy.STATUS_LOST).count()
        pending_requests = BookRequest.objects.filter(status=BookRequest.REQUEST_STATUS_PENDING).count()
        unpaid_fines_agg = Fine.objects.filter(paid=False).aggregate(total=Sum('amount'))
        unpaid_fines_total = float(unpaid_fines_agg['total'] or 0.0)

        return Response({
            'total_titles': total_titles,
            'total_copies': total_copies,
            'available_copies': available_copies,
            'issued_copies': issued_copies,
            'overdue_count': overdue_count,
            'lost_copies': lost_copies,
            'pending_requests': pending_requests,
            'unpaid_fines_total': unpaid_fines_total,
        })

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def add_copies(self, request, pk=None):
        book = self.get_object()
        raw_count = request.data.get('count', 1)
        try:
            count = int(raw_count)
        except (ValueError, TypeError):
            return Response({'detail': 'Invalid copy count. Must be a valid integer.'}, status=status.HTTP_400_BAD_REQUEST)

        if count < 1 or count > 100:
            return Response({'detail': 'Copy count must be between 1 and 100.'}, status=status.HTTP_400_BAD_REQUEST)

        shelf_location = request.data.get('shelf_location', '').strip()
        created = []
        with transaction.atomic():
            last_copy = book.copies.order_by('-copy_number').first()
            start = (last_copy.copy_number + 1) if last_copy else 1
            for i in range(start, start + count):
                copy = BookCopy.objects.create(
                    book=book,
                    copy_number=i,
                    shelf_location=shelf_location or (last_copy.shelf_location if last_copy else 'Stack A-1')
                )
                created.append(copy.id)
        AuditLog.objects.create(actor=request.user, action='add_copies', model_name='Book', object_id=str(book.id), extra={'created_ids': created, 'count': count})
        return Response({'created_copy_ids': created, 'count': count}, status=status.HTTP_201_CREATED)


# ---------- BookCopy ----------
class BookCopyViewSet(viewsets.ModelViewSet):
    queryset = BookCopy.objects.select_related('book').all()
    serializer_class = BookCopySerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryOfficerOrReadOnly]


# ---------- EBooks ----------
class EBookViewSet(viewsets.ModelViewSet):
    queryset = EBook.objects.select_related('book').all()
    serializer_class = EBookSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryOfficerOrReadOnly]

    def perform_create(self, serializer):
        ebook = serializer.save(uploaded_by=self.request.user)
        AuditLog.objects.create(actor=self.request.user, action='upload_ebook', model_name='EBook', object_id=str(ebook.id))

    @action(detail=True, methods=['post'])
    def record_view(self, request, pk=None):
        ebook = self.get_object()
        ebook.views += 1
        ebook.save(update_fields=['views'])
        return Response({'views': ebook.views})

    @action(detail=True, methods=['post'])
    def record_download(self, request, pk=None):
        ebook = self.get_object()
        ebook.downloads += 1
        ebook.save(update_fields=['downloads'])
        AuditLog.objects.create(actor=request.user, action='download_ebook', model_name='EBook', object_id=str(ebook.id))
        return Response({'downloads': ebook.downloads})


# ---------- Book Requests ----------
class BookRequestViewSet(viewsets.ModelViewSet):
    queryset = BookRequest.objects.all()
    serializer_class = BookRequestSerializer
    permission_classes = [permissions.IsAuthenticated, IsRequesterOrLibraryOfficer]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return BookRequest.objects.none()
        role = getattr(user, 'role', '').upper()
        if user.is_staff or role in ['LIBRARY', 'HOD', 'PRINCIPAL', 'SYSTEM']:
            return BookRequest.objects.all().order_by('-created_at')
        return BookRequest.objects.filter(requester=user).order_by('-created_at')

    def perform_create(self, serializer):
        req = serializer.save(requester=self.request.user, status=BookRequest.REQUEST_STATUS_PENDING)
        AuditLog.objects.create(
            actor=self.request.user,
            action='create_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )

    def destroy(self, request, *args, **kwargs):
        req = self.get_object()
        role = getattr(request.user, 'role', '').upper()
        is_officer = request.user.is_staff or role in ['LIBRARY', 'SYSTEM']
        if not is_officer:
            if req.requester != request.user:
                return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)
            if req.status != BookRequest.REQUEST_STATUS_PENDING:
                return Response({'detail': 'Only pending requests can be cancelled.'}, status=status.HTTP_400_BAD_REQUEST)
        return super().destroy(request, *args, **kwargs)

    # Step 1: Library Officer verifies request
    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def verify(self, request, pk=None):
        req = self.get_object()
        req.status = BookRequest.REQUEST_STATUS_VERIFIED
        req.forwarded_to = None
        req.save()
        AuditLog.objects.create(
            actor=request.user,
            action='verify_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )
        return Response({'status': req.status})

    # Step 2: Principal gives final approval
    @action(detail=True, methods=['post'], permission_classes=[IsPrincipal])
    def final_approve(self, request, pk=None):
        req = self.get_object()
        if req.status != BookRequest.REQUEST_STATUS_VERIFIED:
            return Response(
                {'detail': 'Request must be verified by Library Officer before Principal approval.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        req.status = BookRequest.REQUEST_STATUS_APPROVED
        req.forwarded_to = request.user
        req.save()
        AuditLog.objects.create(
            actor=request.user,
            action='approve_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )
        return Response({'status': req.status})

    # Step 3: Library Officer marks book as purchased / received
    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_purchased(self, request, pk=None):
        req = self.get_object()
        if req.status != BookRequest.REQUEST_STATUS_APPROVED:
            return Response(
                {'detail': 'Request must be approved by Principal before marking as purchased.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        req.status = BookRequest.REQUEST_STATUS_PURCHASED
        req.save()
        AuditLog.objects.create(
            actor=request.user,
            action='mark_purchased_request',
            model_name='BookRequest',
            object_id=str(req.id)
        )
        return Response({'status': req.status})

    # Rejection by Library Officer or Principal
    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def reject(self, request, pk=None):
        req = self.get_object()
        req.status = BookRequest.REQUEST_STATUS_REJECTED
        req.save()
        AuditLog.objects.create(
            actor=request.user,
            action='reject_request',
            model_name='BookRequest',
            object_id=str(req.id),
            extra={'reason': request.data.get('reason', '')}
        )
        return Response({'status': req.status})

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_ready(self, request, pk=None):
        req = self.get_object()
        req.status = BookRequest.REQUEST_STATUS_VERIFIED
        req.save(update_fields=['status'])
        AuditLog.objects.create(
            actor=request.user,
            action='mark_ready_reservation',
            model_name='BookRequest',
            object_id=str(req.id)
        )
        return Response({'status': req.status, 'detail': 'Reservation marked as ready for collection.'})

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def stats(self, request):
        qs = BookRequest.objects.all()
        from django.apps import apps
        Faculty = apps.get_model('faculty', 'Faculty')
        faculty_user_ids = set(Faculty.objects.values_list('user_id', flat=True))

        total = qs.count()
        pending = qs.filter(status=BookRequest.REQUEST_STATUS_PENDING).count()
        ready = qs.filter(status__in=[BookRequest.REQUEST_STATUS_VERIFIED, BookRequest.REQUEST_STATUS_APPROVED, BookRequest.REQUEST_STATUS_PURCHASED]).count()
        expired = qs.filter(status=BookRequest.REQUEST_STATUS_REJECTED).count()
        faculty_count = qs.filter(Q(requester_id__in=faculty_user_ids) | Q(requester__role='PROFESSOR')).count()

        return Response({
            'total': total,
            'pending': pending,
            'ready_for_collection': ready,
            'expired': expired,
            'faculty_reservations': faculty_count,
        })


# ---------- Issue / Return Desk ----------
class IssueViewSet(viewsets.ModelViewSet):
    queryset = IssueRecord.objects.select_related('copy', 'copy__book', 'borrower').all()
    serializer_class = IssueRecordSerializer
    permission_classes = [permissions.IsAuthenticated, IsBorrowerOrLibraryOfficer]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return IssueRecord.objects.none()
        role = getattr(user, 'role', '').upper()
        if user.is_staff or role in ['LIBRARY', 'HOD', 'PRINCIPAL', 'SYSTEM']:
            return IssueRecord.objects.select_related('copy', 'copy__book', 'borrower').all().order_by('-issued_at')
        return IssueRecord.objects.select_related('copy', 'copy__book', 'borrower').filter(borrower=user).order_by('-issued_at')

    def destroy(self, request, *args, **kwargs):
        if not (request.user.is_staff or getattr(request.user, 'role', '').upper() in ['LIBRARY', 'SYSTEM']):
            return Response({'detail': 'Deleting issue records is restricted to Library Officers.'}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)

    @action(detail=False, methods=['get'])
    def lookup_borrower(self, request):
        query = (request.query_params.get('query') or request.query_params.get('usn') or request.GET.get('query') or '').strip()
        if not query:
            return Response({'detail': 'Query parameter is required.'}, status=status.HTTP_400_BAD_REQUEST)

        raw = str(query).strip()
        clean = raw.lstrip('$\#@').strip()

        from django.db.models import Q
        from django.apps import apps

        # Search User by usn, user_id, email, phone (CustomUser has no username field)
        borrower = User.objects.filter(
            Q(usn__iexact=raw) |
            Q(usn__iexact=clean) |
            Q(usn__iexact=f"4{clean}") |
            Q(user_id__iexact=raw) |
            Q(user_id__iexact=clean) |
            Q(email__iexact=raw) |
            Q(email__iexact=clean)
        ).first()

        student_obj = None
        faculty_obj = None
        try:
            StudentModel = apps.get_model('students', 'Student')
            FacultyModel = apps.get_model('faculty', 'Faculty')
            if not borrower:
                student_obj = StudentModel.objects.filter(
                    Q(usn__iexact=raw) |
                    Q(usn__iexact=clean) |
                    Q(usn__iexact=f"4{clean}") |
                    Q(name__icontains=clean) |
                    Q(admission_id__iexact=clean) |
                    Q(cet_no__iexact=clean)
                ).select_related('user', 'department', 'semester').first()
                if student_obj and student_obj.user:
                    borrower = student_obj.user
            else:
                student_obj = StudentModel.objects.filter(user=borrower).select_related('department', 'semester').first()

            if not borrower:
                faculty_obj = FacultyModel.objects.filter(
                    Q(faculty_id__iexact=raw) |
                    Q(faculty_id__iexact=clean) |
                    Q(email__iexact=raw) |
                    Q(name__icontains=clean)
                ).select_related('user', 'department').first()
                if faculty_obj and faculty_obj.user:
                    borrower = faculty_obj.user
            elif not student_obj:
                faculty_obj = FacultyModel.objects.filter(user=borrower).select_related('department').first()
        except Exception:
            pass

        if not borrower:
            return Response({'detail': f'No student or faculty found matching identifier "{query}".'}, status=status.HTTP_404_NOT_FOUND)

        is_faculty = faculty_obj is not None or getattr(borrower, 'role', '').upper() == 'PROFESSOR'
        borrower_type = 'FACULTY' if is_faculty else 'STUDENT'

        config = LibraryConfiguration.objects.filter(is_active=True).first()
        max_limit = (config.max_books_faculty if config else 5) if is_faculty else (config.max_books_student if config else 3)
        loan_days = (config.loan_duration_days if config else 14) if not is_faculty else (config.loan_duration_days * 2 if config else 30)

        active_loans = IssueRecord.objects.filter(borrower=borrower, status=IssueRecord.STATUS_ISSUED).select_related('copy', 'copy__book')
        active_count = active_loans.count()
        today = timezone.now().date()
        overdue_count = active_loans.filter(due_date__lt=today).count()
        unpaid_fines = Fine.objects.filter(issue__borrower=borrower, paid=False)
        total_unpaid = sum(f.amount for f in unpaid_fines)

        # Verify Library Card status
        card = LibraryCard.objects.filter(
            Q(student_user=borrower) |
            (Q(student=student_obj) if student_obj else Q(pk__isnull=True)) |
            (Q(faculty=faculty_obj) if faculty_obj else Q(pk__isnull=True))
        ).order_by('-created_at').first()
        has_active_card = card is not None and card.status == LibraryCard.STATUS_ACTIVE

        is_eligible = True
        ineligibility_reasons = []

        if not has_active_card:
            is_eligible = False
            card_status_msg = card.status if card else "NOT_APPLIED"
            ineligibility_reasons.append(f"No active Library Card (Status: {card_status_msg}). {borrower_type.capitalize()} must have an active Library Card to borrow books.")

        if active_count >= max_limit:
            is_eligible = False
            ineligibility_reasons.append(f'Maximum active book limit ({max_limit} books) reached for {borrower_type.lower()}s.')
        if overdue_count > 0:
            is_eligible = False
            ineligibility_reasons.append(f'{overdue_count} overdue book(s) pending return.')
        if total_unpaid > 0:
            is_eligible = False
            ineligibility_reasons.append(f'Outstanding fine penalty of ₹{total_unpaid}.')

        dept_name = 'N/A'
        if student_obj and student_obj.department:
            dept_name = student_obj.department.name
        elif faculty_obj and faculty_obj.department:
            dept_name = faculty_obj.department.name
        elif getattr(borrower, 'department', None):
            dept_name = borrower.department.name

        sem_name = f"Semester {student_obj.semester.sem_number}" if (student_obj and student_obj.semester) else ('Faculty' if is_faculty else 'N/A')
        borrower_name = student_obj.name if student_obj else (faculty_obj.name if faculty_obj else (borrower.get_full_name() or getattr(borrower, 'user_id', None) or borrower.email))

        data = {
            'id': borrower.id,
            'user_id': borrower.id,
            'usn': getattr(borrower, 'usn', None) or (student_obj.usn if student_obj else (faculty_obj.faculty_id if faculty_obj else query)),
            'name': borrower_name,
            'email': borrower.email,
            'role': getattr(borrower, 'role', borrower_type),
            'borrower_type': borrower_type,
            'is_faculty': is_faculty,
            'department': dept_name,
            'semester': sem_name,
            'active_loans_count': active_count,
            'active_loans': active_count,
            'max_limit': max_limit,
            'loan_days': loan_days,
            'overdue_count': overdue_count,
            'unpaid_fines_amount': float(total_unpaid),
            'has_active_card': has_active_card,
            'card_number': card.card_number if card else None,
            'card_status': card.status if card else "NOT_APPLIED",
            'is_eligible': is_eligible,
            'ineligibility_reasons': ineligibility_reasons,
            'ineligible_reason': ' • '.join(ineligibility_reasons) if ineligibility_reasons else None,
            'library_card': {
                'id': card.id,
                'card_number': card.card_number,
                'status': card.status,
                'academic_year': card.academic_year,
                'valid_until': str(card.valid_until) if card.valid_until else None,
                'digital_signature_hash': card.digital_signature_hash,
            } if card else None,
        }
        return Response(data)

    def create(self, request, *args, **kwargs):
        """
        Safe transactional checkout:
        - Handled either by Library Officer (can specify borrower via borrower_id or usn)
        - Or Borrower self-checkout.
        - Prevents concurrent race condition on copy via select_for_update.
        """
        user = request.user
        role = getattr(user, 'role', '').upper()
        is_officer = user.is_staff or role in ['LIBRARY', 'SYSTEM']

        copy_id = request.data.get('copy_id')
        if not copy_id:
            return Response({'detail': 'copy_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Determine borrower
        if is_officer and (request.data.get('borrower_id') or request.data.get('usn')):
            borrower_id = request.data.get('borrower_id')
            usn = request.data.get('usn')
            if borrower_id:
                borrower = get_object_or_404(User, id=borrower_id)
            else:
                raw_usn = str(usn).strip()
                clean_usn = raw_usn.lstrip('$\#@').strip()
                from django.db.models import Q
                borrower = User.objects.filter(
                    Q(usn__iexact=raw_usn) |
                    Q(usn__iexact=clean_usn) |
                    Q(usn__iexact=f"4{clean_usn}") |
                    Q(user_id__iexact=raw_usn) |
                    Q(user_id__iexact=clean_usn) |
                    Q(email__iexact=raw_usn)
                ).first()
                if not borrower:
                    from django.apps import apps
                    try:
                        StudentModel = apps.get_model('students', 'Student')
                        st = StudentModel.objects.filter(
                            Q(usn__iexact=raw_usn) |
                            Q(usn__iexact=clean_usn) |
                            Q(usn__iexact=f"4{clean_usn}") |
                            Q(admission_id__iexact=clean_usn)
                        ).first()
                        if st:
                            borrower = ensure_user_for_student(st)
                    except Exception:
                        pass
                if not borrower:
                    from django.apps import apps
                    try:
                        FacultyModel = apps.get_model('faculty', 'Faculty')
                        fac = FacultyModel.objects.filter(
                            Q(faculty_id__iexact=raw_usn) |
                            Q(faculty_id__iexact=clean_usn) |
                            Q(email__iexact=raw_usn)
                        ).first()
                        if fac:
                            borrower = ensure_user_for_faculty(fac)
                    except Exception:
                        pass
                if not borrower:
                    return Response({'detail': f'Borrower not found with USN/ID: {raw_usn}'}, status=status.HTTP_404_NOT_FOUND)
        else:
            borrower = user

        # Verify Library Card status: Must have an active card (Officer can issue to initialize card workflow)
        card = LibraryCard.objects.filter(
            Q(student_user=borrower) |
            Q(student__user=borrower) |
            Q(faculty__user=borrower)
        ).order_by('-created_at').first()
        if not is_officer and (not card or card.status != LibraryCard.STATUS_ACTIVE):
            card_status = card.status if card else "NOT_APPLIED"
            return Response(
                {'detail': f'Borrowing blocked: Borrower does not have an active Library Card (Status: {card_status}). HOD approval and card activation are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Server-enforced loan rules
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        is_fac = getattr(borrower, 'role', '').upper() == 'PROFESSOR' or (card and card.borrower_type == 'FACULTY')
        max_limit = (config.max_books_faculty if config else 5) if is_fac else (config.max_books_student if config else 3)
        active_count = IssueRecord.objects.filter(borrower=borrower, status=IssueRecord.STATUS_ISSUED).count()
        if active_count >= max_limit:
            return Response(
                {'detail': f'Borrowing limit reached: Maximum {max_limit} active books allowed for {"faculty" if is_fac else "students"}.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not is_officer:
            # Check overdue books
            has_overdue = IssueRecord.objects.filter(
                borrower=borrower,
                status=IssueRecord.STATUS_ISSUED,
                due_date__lt=timezone.now().date()
            ).exists()
            if has_overdue:
                return Response(
                    {'detail': 'Borrowing blocked: You have overdue book(s). Please return them before borrowing more.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Check unpaid fines
            has_fines = Fine.objects.filter(issue__borrower=borrower, paid=False).exists()
            if has_fines:
                return Response(
                    {'detail': 'Borrowing blocked: You have outstanding unpaid fines. Please clear fines first.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 2. Check overdue books
            has_overdue = IssueRecord.objects.filter(
                borrower=borrower,
                status=IssueRecord.STATUS_ISSUED,
                due_date__lt=timezone.now().date()
            ).exists()
            if has_overdue:
                return Response(
                    {'detail': 'Borrowing blocked: You have overdue book(s). Please return them before borrowing more.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 3. Check unpaid fines
            has_fines = Fine.objects.filter(issue__borrower=borrower, paid=False).exists()
            if has_fines:
                return Response(
                    {'detail': 'Borrowing blocked: You have outstanding unpaid fines. Please clear fines first.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 4. Server-defined loan period: strictly 14 days
            due_date = timezone.now().date() + timedelta(days=14)
        else:
            loan_days = int(request.data.get('loan_days', 14))
            raw_due = request.data.get('due_date')
            if raw_due:
                from datetime import datetime
                try:
                    due_date = datetime.strptime(str(raw_due).strip()[:10], '%Y-%m-%d').date()
                except ValueError:
                    due_date = timezone.now().date() + timedelta(days=loan_days)
            else:
                due_date = timezone.now().date() + timedelta(days=loan_days)

        # Atomic transaction with row locking
        with transaction.atomic():
            copy = BookCopy.objects.select_for_update().filter(id=copy_id).first()
            if not copy:
                return Response({'detail': 'Book copy not found.'}, status=status.HTTP_404_NOT_FOUND)
            if copy.status != BookCopy.STATUS_AVAILABLE:
                return Response(
                    {'detail': f'Copy #{copy.copy_number} is currently {copy.get_status_display()} and unavailable.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            issue_id = f"ISS-{timezone.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
            issue = IssueRecord.objects.create(
                issue_id=issue_id,
                borrower=borrower,
                copy=copy,
                due_date=due_date,
                created_by=user,
                status=IssueRecord.STATUS_ISSUED
            )
            copy.status = BookCopy.STATUS_ISSUED
            copy.save(update_fields=['status'])

            AuditLog.objects.create(
                actor=user,
                action='issue_book',
                model_name='IssueRecord',
                object_id=str(issue.id),
                extra={'borrower': str(borrower), 'copy': str(copy), 'due_date': str(due_date)}
            )

        serializer = self.get_serializer(issue)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def verify_borrower(self, request):
        """
        Verify borrower USN or Staff ID, check active library issue card, active loan limit, and overdue status.
        """
        query = request.query_params.get('usn', '').strip()
        if not query:
            query = request.query_params.get('identifier', '').strip()
        if not query:
            return Response({'error': 'Please provide a USN or Staff ID.'}, status=status.HTTP_400_BAD_REQUEST)

        clean_usn = query.lstrip('$\#@').strip()
        from django.db.models import Q
        borrower = User.objects.filter(
            Q(usn__iexact=query) |
            Q(usn__iexact=clean_usn) |
            Q(usn__iexact=f"4{clean_usn}") |
            Q(user_id__iexact=query) |
            Q(user_id__iexact=clean_usn) |
            Q(email__iexact=query)
        ).first()

        student_obj = None
        faculty_obj = None
        from django.apps import apps
        StudentModel = apps.get_model('students', 'Student')
        FacultyModel = apps.get_model('faculty', 'Faculty')

        if not borrower:
            student_obj = StudentModel.objects.filter(
                Q(usn__iexact=query) |
                Q(usn__iexact=clean_usn) |
                Q(usn__iexact=f"4{clean_usn}") |
                Q(admission_id__iexact=clean_usn)
            ).select_related('user', 'department', 'semester').first()
            if student_obj and student_obj.user:
                borrower = student_obj.user

        if not borrower:
            faculty_obj = FacultyModel.objects.filter(
                Q(faculty_id__iexact=query) |
                Q(email__iexact=query)
            ).select_related('user', 'department').first()
            if faculty_obj and faculty_obj.user:
                borrower = faculty_obj.user

        if not borrower:
            return Response({'is_valid': False, 'detail': f'Borrower with USN/ID "{query}" not found.'}, status=status.HTTP_404_NOT_FOUND)

        if not student_obj:
            student_obj = StudentModel.objects.filter(user=borrower).select_related('department', 'semester').first()
        if not faculty_obj:
            faculty_obj = FacultyModel.objects.filter(user=borrower).select_related('department').first()

        is_faculty = faculty_obj is not None or getattr(borrower, 'role', '').upper() == 'PROFESSOR'
        borrower_type = 'FACULTY' if is_faculty else 'STUDENT'

        # Fetch active config
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        max_limit = (config.max_books_faculty if config else 5) if is_faculty else (config.max_books_student if config else 3)
        loan_days = (config.loan_duration_days if config else 14) if not is_faculty else (config.loan_duration_days * 2 if config else 30)

        # Check card status
        card = LibraryCard.objects.filter(
            Q(student_user=borrower) |
            (Q(student=student_obj) if student_obj else Q(pk__isnull=True)) |
            (Q(faculty=faculty_obj) if faculty_obj else Q(pk__isnull=True))
        ).order_by('-created_at').first()
        has_active_card = card is not None and card.status == LibraryCard.STATUS_ACTIVE
        card_number = card.card_number if card else None
        card_status = card.status if card else "NOT_APPLIED"

        # Check active loans and overdue
        active_loans = IssueRecord.objects.filter(borrower=borrower, status=IssueRecord.STATUS_ISSUED).count()
        has_overdue = IssueRecord.objects.filter(
            borrower=borrower,
            status=IssueRecord.STATUS_ISSUED,
            due_date__lt=timezone.now().date()
        ).exists()

        is_eligible = has_active_card and (active_loans < max_limit) and not has_overdue
        ineligible_reason = None
        if not has_active_card:
            ineligible_reason = f"No active Library Issue Card (Card status: {card_status}). HOD approval and card issuance are required."
        elif active_loans >= max_limit:
            ineligible_reason = f"Borrowing limit reached: Maximum {max_limit} active books allowed for {borrower_type.lower()}s."
        elif has_overdue:
            ineligible_reason = "Borrower has overdue books that must be returned first."

        dept_name = 'N/A'
        if student_obj and student_obj.department:
            dept_name = student_obj.department.name
        elif faculty_obj and faculty_obj.department:
            dept_name = faculty_obj.department.name
        elif getattr(borrower, 'department', None):
            dept_name = borrower.department.name

        sem_name = f"Semester {student_obj.semester.sem_number}" if (student_obj and student_obj.semester) else ('Faculty' if is_faculty else 'N/A')
        borrower_display_name = student_obj.name if student_obj else (faculty_obj.name if faculty_obj else (borrower.get_full_name() or getattr(borrower, 'user_id', None) or borrower.email))

        data = {
            'is_valid': True,
            'user_id': borrower.id,
            'name': borrower_display_name,
            'usn': getattr(borrower, 'usn', None) or (student_obj.usn if student_obj else (faculty_obj.faculty_id if faculty_obj else query)),
            'borrower_type': borrower_type,
            'department': dept_name,
            'semester': sem_name,
            'has_active_card': has_active_card,
            'card_number': card_number,
            'card_status': card_status,
            'active_loans': active_loans,
            'max_limit': max_limit,
            'loan_days': loan_days,
            'has_overdue': has_overdue,
            'is_eligible': is_eligible,
            'ineligible_reason': ineligible_reason,
        }
        return Response(data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def return_book(self, request, pk=None):
        """
        Library officer marks book returned.
        Supports recording book condition and remarks.
        Enforces ₹0 overdue fines as per college free borrowing policy.
        """
        issue = self.get_object()
        if issue.status != IssueRecord.STATUS_ISSUED:
            return Response({'detail': 'This issue record is not currently active.'}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        issue.returned_at = now
        issue.status = IssueRecord.STATUS_RETURNED
        issue.save(update_fields=['returned_at', 'status'])

        book_condition = request.data.get('book_condition', 'GOOD').upper()
        remarks = request.data.get('remarks', '')

        copy = issue.copy
        if book_condition == 'DAMAGED':
            copy.status = BookCopy.STATUS_DAMAGED
        elif book_condition == 'LOST':
            copy.status = BookCopy.STATUS_LOST
        else:
            copy.status = BookCopy.STATUS_AVAILABLE
        copy.save(update_fields=['status'])

        # Check library configuration for late fine rate (0.00 since college books are free)
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        late_fine_rate = float(config.late_fine_per_day) if (config and config.late_fine_per_day is not None) else 0.0

        fine_created = None
        if late_fine_rate > 0 and issue.due_date and now.date() > issue.due_date:
            overdue_days = (now.date() - issue.due_date).days
            fine_amount = round(overdue_days * late_fine_rate, 2)
            if fine_amount > 0:
                fine_created = Fine.objects.create(
                    issue=issue,
                    amount=fine_amount,
                    reason=f"Overdue return ({overdue_days} days late @ ₹{late_fine_rate}/day)",
                    assigned_by=request.user
                )

        AuditLog.objects.create(
            actor=request.user,
            action='return_book',
            model_name='IssueRecord',
            object_id=str(issue.id),
            extra={'condition': book_condition, 'remarks': remarks, 'fine_id': fine_created.id if fine_created else None}
        )

        resp_data = {'status': 'returned', 'book_condition': book_condition, 'overdue_fine': float(fine_created.amount) if fine_created else 0.0}
        return Response(resp_data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def history(self, request):
        user = request.user
        role = getattr(user, 'role', '').upper()
        if user.is_staff or role in ['LIBRARY', 'PRINCIPAL', 'SYSTEM']:
            queryset = IssueRecord.objects.select_related('copy', 'copy__book', 'borrower', 'created_by').order_by('-issued_at')
        else:
            queryset = IssueRecord.objects.filter(borrower=user).select_related('copy', 'copy__book', 'borrower', 'created_by').order_by('-issued_at')

        results = []
        for iss in queryset[:200]:
            results.append({
                'id': iss.id,
                'issue_id': iss.issue_id,
                'book_title': iss.copy.book.title,
                'book_authors': iss.copy.book.authors,
                'copy_barcode': iss.copy.barcode or f"Copy #{iss.copy.copy_number}",
                'shelf_location': iss.copy.shelf_location,
                'borrower_name': iss.borrower.get_full_name() or iss.borrower.email,
                'borrower_email': iss.borrower.email,
                'borrower_role': iss.borrower.role,
                'issued_at': iss.issued_at.strftime('%Y-%m-%d %H:%M') if iss.issued_at else '-',
                'due_date': iss.due_date.strftime('%Y-%m-%d') if iss.due_date else '-',
                'returned_at': iss.returned_at.strftime('%Y-%m-%d %H:%M') if iss.returned_at else None,
                'status': iss.status,
                'is_overdue': iss.is_overdue,
                'overdue_days': iss.overdue_days,
                'issued_by_name': iss.created_by.get_full_name() if iss.created_by else 'Librarian',
            })
        return Response(results)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_lost(self, request, pk=None):
        issue = self.get_object()
        issue.status = IssueRecord.STATUS_LOST
        issue.returned_at = timezone.now()
        issue.save(update_fields=['returned_at', 'status'])

        copy = issue.copy
        copy.status = BookCopy.STATUS_LOST
        copy.save(update_fields=['status'])

        amount = copy.book.mrp if (copy.book and copy.book.mrp) else 500.00
        fine = Fine.objects.create(
            issue=issue,
            amount=amount,
            reason=f"Lost book copy: {copy.book.title if copy.book else ''} (#{copy.copy_number})",
            assigned_by=request.user
        )
        AuditLog.objects.create(actor=request.user, action='mark_lost', model_name='IssueRecord', object_id=str(issue.id), extra={'fine_id': fine.id})
        return Response({'status': 'lost', 'fine_id': fine.id, 'fine_amount': float(amount)})


# ---------- Fines & Payments Desk ----------
class FineViewSet(viewsets.ModelViewSet):
    queryset = Fine.objects.select_related('issue', 'issue__copy', 'issue__copy__book').all()
    serializer_class = FineSerializer
    permission_classes = [permissions.IsAuthenticated, IsBorrowerOrLibraryOfficer]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return Fine.objects.none()
        role = getattr(user, 'role', '').upper()
        if user.is_staff or role in ['LIBRARY', 'HOD', 'PRINCIPAL', 'SYSTEM']:
            return Fine.objects.select_related('issue', 'issue__copy', 'issue__copy__book').all().order_by('-assigned_at')
        return Fine.objects.select_related('issue', 'issue__copy', 'issue__copy__book').filter(issue__borrower=user).order_by('-assigned_at')

    def destroy(self, request, *args, **kwargs):
        if not (request.user.is_staff or getattr(request.user, 'role', '').upper() in ['LIBRARY', 'SYSTEM']):
            return Response({'detail': 'Deleting fine records is prohibited.'}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def assign(self, request, pk=None):
        fine = self.get_object()
        amount = request.data.get('amount')
        reason = request.data.get('reason', '')
        if amount is None:
            return Response({'detail': 'amount is required.'}, status=status.HTTP_400_BAD_REQUEST)
        fine.amount = amount
        fine.reason = reason
        fine.assigned_by = request.user
        fine.save()
        AuditLog.objects.create(actor=request.user, action='assign_fine', model_name='Fine', object_id=str(fine.id))
        return Response({'status': 'assigned', 'amount': str(fine.amount)})

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_paid(self, request, pk=None):
        """
        Record verified offline / cash / counter payment.
        Only authorized Library Officers can record payment and receipt number.
        """
        fine = self.get_object()
        if fine.paid:
            return Response({'detail': 'This fine has already been marked as paid.'}, status=status.HTTP_400_BAD_REQUEST)

        payment_reference = request.data.get('payment_reference', '').strip()
        if not payment_reference:
            return Response(
                {'detail': 'A valid payment reference (receipt #, UPI ID, or counter receipt) is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        fine.paid = True
        fine.paid_at = timezone.now()
        fine.payment_reference = payment_reference
        fine.save(update_fields=['paid', 'paid_at', 'payment_reference'])

        AuditLog.objects.create(
            actor=request.user,
            action='pay_fine',
            model_name='Fine',
            object_id=str(fine.id),
            extra={'amount': str(fine.amount), 'ref': payment_reference}
        )
        return Response({'status': 'paid', 'paid_at': fine.paid_at, 'payment_reference': fine.payment_reference})


# ---------- LibraryCardViewSet ----------
class LibraryCardViewSet(viewsets.ModelViewSet):
    queryset = LibraryCard.objects.select_related('student_user', 'student', 'department', 'hod_verified_by', 'issued_by').all()
    serializer_class = LibraryCardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return LibraryCard.objects.none()
        role = getattr(user, 'role', '').upper()

        if user.is_staff or role in ['LIBRARY', 'PRINCIPAL', 'SYSTEM']:
            qs = LibraryCard.objects.select_related('student_user', 'student', 'faculty', 'department', 'hod_verified_by', 'issued_by').all()
        elif role == 'HOD':
            dept = getattr(user, 'department', None)
            if dept:
                qs = LibraryCard.objects.select_related('student_user', 'student', 'faculty', 'department', 'hod_verified_by', 'issued_by').filter(department=dept, borrower_type='STUDENT')
            else:
                return LibraryCard.objects.none()
        else:
            qs = LibraryCard.objects.select_related('student_user', 'student', 'faculty', 'department', 'hod_verified_by', 'issued_by').filter(
                Q(student_user=user) | Q(student__user=user) | Q(faculty__user=user)
            )

        # Apply Query Filters
        params = self.request.query_params
        search = params.get('search', '').strip()
        if search:
            qs = qs.filter(
                Q(card_number__icontains=search) |
                Q(student_user__email__icontains=search) |
                Q(student__name__icontains=search) |
                Q(student__usn__icontains=search) |
                Q(faculty__name__icontains=search) |
                Q(faculty__faculty_id__icontains=search)
            )

        borrower_type = params.get('borrower_type', '').strip().upper()
        if borrower_type and borrower_type != 'ALL':
            qs = qs.filter(borrower_type=borrower_type)

        card_status = params.get('status', '').strip().upper()
        if card_status and card_status != 'ALL':
            qs = qs.filter(status=card_status)

        department = params.get('department', '').strip()
        if department and department != 'All Departments':
            qs = qs.filter(department__name__icontains=department)

        semester = params.get('semester', '').strip()
        if semester and semester != 'All Semesters':
            sem_num = ''.join(filter(str.isdigit, semester))
            if sem_num:
                qs = qs.filter(semester=int(sem_num))

        return qs.order_by('-created_at')

    def create(self, request, *args, **kwargs):
        """
        Creates or generates a Library Card.
        - By Library Officer/Admin: Directly issues/updates active card with dynamic components & signature.
        - By Student: Submits card application.
        """
        user = request.user
        role = getattr(user, 'role', '').upper()
        is_officer = user.is_staff or role in ['LIBRARY', 'SYSTEM', 'PRINCIPAL']

        if is_officer:
            config = LibraryConfiguration.objects.filter(is_active=True).first()
            if not config:
                return Response(
                    {'detail': 'Library configuration is incomplete. Please configure library rules first.', 'requires_config': True},
                    status=status.HTTP_400_BAD_REQUEST
                )

            borrower_type = request.data.get('borrower_type', 'STUDENT').upper()
            identifier = (
                request.data.get('identifier') or
                request.data.get('usn') or
                request.data.get('faculty_id') or
                request.data.get('student_id') or
                ''
            ).strip()

            target_user = None
            student_obj = None
            faculty_obj = None

            from django.apps import apps
            from django.db.models import Q
            StudentModel = apps.get_model('students', 'Student')
            FacultyModel = apps.get_model('faculty', 'Faculty')

            if borrower_type == 'FACULTY':
                fac = FacultyModel.objects.filter(
                    Q(faculty_id__iexact=identifier) |
                    Q(email__iexact=identifier) |
                    Q(id=int(identifier) if identifier.isdigit() else -1)
                ).select_related('user', 'department').first()
                if fac:
                    faculty_obj = fac
                    target_user = ensure_user_for_faculty(fac)
            else:
                st = StudentModel.objects.filter(
                    Q(usn__iexact=identifier) |
                    Q(admission_id__iexact=identifier) |
                    Q(email__iexact=identifier) |
                    Q(id=int(identifier) if identifier.isdigit() else -1)
                ).select_related('user', 'department', 'semester').first()
                if st:
                    student_obj = st
                    target_user = ensure_user_for_student(st)

            if not target_user and identifier:
                target_user = User.objects.filter(
                    Q(email__iexact=identifier) |
                    Q(user_id__iexact=identifier) |
                    Q(usn__iexact=identifier)
                ).first()

            if not target_user:
                return Response({'detail': f'Borrower not found with identifier "{identifier}".'}, status=status.HTTP_404_NOT_FOUND)

            if target_user and not student_obj and borrower_type == 'STUDENT':
                student_obj = StudentModel.objects.filter(user=target_user).first()
            if target_user and not faculty_obj and borrower_type == 'FACULTY':
                faculty_obj = FacultyModel.objects.filter(user=target_user).first()

            dept = None
            if student_obj and student_obj.department:
                dept = student_obj.department
            elif faculty_obj and faculty_obj.department:
                dept = faculty_obj.department
            elif getattr(target_user, 'department', None):
                dept = target_user.department
            if not dept:
                from academics.models import Department
                dept = Department.objects.filter(name__icontains='Computer Science').first() or Department.objects.first()

            card = LibraryCard.objects.filter(
                Q(student_user=target_user) |
                (Q(student=student_obj) if student_obj else Q(pk__isnull=True)) |
                (Q(faculty=faculty_obj) if faculty_obj else Q(pk__isnull=True))
            ).first()

            year = timezone.now().year
            card_num = card.card_number if (card and card.card_number) else LibraryCard.generate_next_card_number(year)
            valid_days = config.validity_months * 30 if config.validity_months else 365

            raw_components = request.data.get('components', [])
            if isinstance(raw_components, str):
                import json
                try:
                    components_list = json.loads(raw_components)
                except Exception:
                    components_list = [c.strip() for c in raw_components.split(',') if c.strip()]
            else:
                components_list = raw_components

            librarian_name = config.authorized_librarian_name or user.get_full_name() or "College Library Officer"
            sig_payload = f"CAMPUSFLOW:LC:{card_num}:{target_user.id}:{config.academic_year}:{librarian_name}:{timezone.now().isoformat()}"
            sig_hash = hashlib.sha256(sig_payload.encode('utf-8')).hexdigest()

            signature_file = request.FILES.get('signature_image')

            submit_for_approval = request.data.get('submit_for_approval')
            is_submitting = str(submit_for_approval).lower() in ['true', '1', 'yes']
            
            requested_status = request.data.get('status')
            if borrower_type == 'FACULTY':
                # Faculty library cards do NOT require HOD approval - directly active!
                target_status = LibraryCard.STATUS_ACTIVE
            elif is_submitting:
                target_status = LibraryCard.STATUS_PENDING_HOD
            elif requested_status:
                target_status = requested_status
            elif config.require_hod_approval:
                target_status = LibraryCard.STATUS_PENDING_HOD
            else:
                target_status = LibraryCard.STATUS_ACTIVE

            raw_books = request.data.get('recorded_books', [])
            if isinstance(raw_books, str):
                import json
                try:
                    books_list = json.loads(raw_books)
                except Exception:
                    books_list = []
            elif isinstance(raw_books, list):
                books_list = raw_books
            else:
                books_list = []

            if card:
                card.status = target_status
                card.borrower_type = borrower_type
                card.components = components_list
                if signature_file:
                    card.signature_image = signature_file
                card.academic_year = request.data.get('academic_year') or config.academic_year
                if student_obj and student_obj.semester:
                    card.semester = getattr(student_obj.semester, 'sem_number', None)
                card.section = request.data.get('section', card.section or 'A')
                card.roll_no = student_obj.usn if student_obj else (faculty_obj.faculty_id if faculty_obj else card.roll_no)
                card.issued_by = user
                card.issued_at = timezone.now()
                card.valid_until = timezone.now().date() + timedelta(days=valid_days)
                card.digital_signature_hash = sig_hash

                # Merge recorded_books without duplicates
                existing_books = list(card.recorded_books or [])
                existing_refs = {b.get('issue_id') or b.get('book_copy_no') or b.get('copy_barcode') or b.get('book_title') for b in existing_books if isinstance(b, dict)}
                for b in books_list:
                    if isinstance(b, dict):
                        ref = b.get('issue_id') or b.get('book_copy_no') or b.get('copy_barcode') or b.get('book_title')
                        if ref and ref not in existing_refs:
                            existing_books.append(b)
                            existing_refs.add(ref)
                        elif not ref and b not in existing_books:
                            existing_books.append(b)
                card.recorded_books = existing_books if existing_books else books_list

                if is_submitting:
                    card.submitted_at = timezone.now()
                    card.rejection_reason = ''
                    card.hod_signature_image = None

                if not card.qr_code_token:
                    card.qr_code_token = uuid.uuid4().hex
                card.save()
            else:
                card = LibraryCard.objects.create(
                    card_number=card_num,
                    borrower_type=borrower_type,
                    student_user=target_user,
                    student=student_obj,
                    faculty=faculty_obj,
                    department=dept,
                    academic_year=request.data.get('academic_year') or config.academic_year,
                    semester=getattr(student_obj.semester, 'sem_number', None) if (student_obj and student_obj.semester) else None,
                    section=request.data.get('section', 'A'),
                    roll_no=student_obj.usn if student_obj else (faculty_obj.faculty_id if faculty_obj else ""),
                    student_photo=student_obj.photo if (student_obj and student_obj.photo) else (faculty_obj.photo if (faculty_obj and faculty_obj.photo) else None),
                    signature_image=signature_file,
                    components=components_list,
                    recorded_books=books_list,
                    card_fee=0.00,
                    fee_paid=True,
                    fee_payment_reference="FREE-MEMBERSHIP",
                    status=target_status,
                    submitted_at=timezone.now() if is_submitting else None,
                    issued_by=user,
                    issued_at=timezone.now(),
                    valid_until=timezone.now().date() + timedelta(days=valid_days),
                    digital_signature_hash=sig_hash,
                    qr_code_token=uuid.uuid4().hex
                )

            AuditLog.objects.create(
                actor=user,
                action='create_and_issue_library_card',
                model_name='LibraryCard',
                object_id=str(card.id),
                extra={'card_number': card.card_number, 'borrower': target_user.email, 'type': borrower_type}
            )

            serializer = self.get_serializer(card)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        # Standard student application workflow
        target_user = user
        existing = LibraryCard.objects.filter(
            student_user=target_user,
            status__in=[
                LibraryCard.STATUS_PENDING_HOD,
                LibraryCard.STATUS_HOD_APPROVED,
                LibraryCard.STATUS_CARD_GENERATED,
                LibraryCard.STATUS_ACTIVE
            ]
        ).first()

        if existing:
            return Response(
                {'detail': f'A library card already exists with status: {existing.status} (Card No: {existing.card_number or "Pending"}). Duplicate active cards are prohibited.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        student_obj = None
        from django.apps import apps
        try:
            StudentModel = apps.get_model('students', 'Student')
            student_obj = StudentModel.objects.filter(user=target_user).select_related('department', 'semester').first()
        except Exception:
            pass

        dept = None
        if student_obj and student_obj.department:
            dept = student_obj.department
        elif getattr(target_user, 'department', None):
            dept = target_user.department

        academic_year = request.data.get('academic_year') or "2025-2026"
        semester = request.data.get('semester') or (getattr(student_obj.semester, 'sem_number', 1) if (student_obj and student_obj.semester) else 1)
        section = request.data.get('section', 'A')
        fee_ref = request.data.get('fee_payment_reference', 'FREE-MEMBERSHIP')

        card = LibraryCard.objects.create(
            student_user=target_user,
            student=student_obj,
            department=dept,
            academic_year=academic_year,
            semester=semester,
            section=section,
            student_photo=request.FILES.get('student_photo'),
            card_fee=0.00,
            fee_paid=True,
            fee_payment_reference=fee_ref,
            fee_paid_at=timezone.now(),
            status=LibraryCard.STATUS_PENDING_HOD
        )

        AuditLog.objects.create(
            actor=user,
            action='apply_library_card',
            model_name='LibraryCard',
            object_id=str(card.id),
            extra={'student': target_user.email, 'department': dept.name if dept else None}
        )

        serializer = self.get_serializer(card)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def hod_verify(self, request, pk=None):
        card = self.get_object()
        if card.borrower_type == 'FACULTY':
            return Response({'detail': 'Faculty library cards do not require HOD approval.'}, status=status.HTTP_400_BAD_REQUEST)
        user = request.user
        role = getattr(user, 'role', '').upper()

        is_hod = role == 'HOD'
        is_admin = user.is_staff or role in ['PRINCIPAL', 'SYSTEM']
        if not (is_hod or is_admin):
            return Response({'detail': 'Only HOD or Admin can verify library card applications.'}, status=status.HTTP_403_FORBIDDEN)

        if is_hod:
            hod_dept = getattr(user, 'department', None)
            if not hod_dept:
                from hod_assignment.models import HODAssignment
                ha = HODAssignment.objects.filter(faculty__user=user, end_date__isnull=True).first()
                if ha:
                    hod_dept = ha.department
            if hod_dept and card.department and card.department != hod_dept:
                return Response({'detail': f'HOD can only verify applications within their own department ({hod_dept.name}).'}, status=status.HTTP_403_FORBIDDEN)

        action_type = request.data.get('action', 'approve').lower()
        if action_type == 'approve':
            from faculty.models import Faculty
            from django.core.files.base import ContentFile
            import os

            hod_faculty = Faculty.objects.filter(user=user).first()
            if not hod_faculty and hasattr(user, 'faculty_profile'):
                hod_faculty = user.faculty_profile

            # Check if signature was uploaded directly in this request
            sig_file = request.FILES.get('signature_image') or request.FILES.get('signature')
            if sig_file and hod_faculty:
                hod_faculty.signature = sig_file
                hod_faculty.save()

            has_signature = (sig_file is not None) or (hod_faculty and hod_faculty.signature)

            if not has_signature:
                return Response(
                    {
                        'detail': f'Authorized HOD ({user.get_full_name() or user.email}) has not uploaded a digital signature. Please upload your digital signature image to proceed with approval.',
                        'needs_signature_upload': True
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            with transaction.atomic():
                if sig_file:
                    card.hod_signature_image = sig_file
                elif hod_faculty and hod_faculty.signature:
                    try:
                        hod_faculty.signature.open('rb')
                        sig_bytes = hod_faculty.signature.read()
                        hod_faculty.signature.close()
                        fname = os.path.basename(hod_faculty.signature.name)
                        card.hod_signature_image.save(f"hod_sig_{card.id}_{fname}", ContentFile(sig_bytes), save=False)
                    except Exception:
                        pass

                card.status = LibraryCard.STATUS_HOD_APPROVED
                card.hod_verified_by = user
                card.hod_verified_at = timezone.now()
                card.rejection_reason = ''
                card.save()

                AuditLog.objects.create(
                    actor=user,
                    action='hod_approve_library_card',
                    model_name='LibraryCard',
                    object_id=str(card.id),
                    extra={'hod_name': user.get_full_name(), 'hod_id': getattr(hod_faculty, 'faculty_id', str(user.id))}
                )

            return Response({
                'status': card.status,
                'message': 'Library Issue Card successfully approved with official HOD digital signature.',
                'card': LibraryCardSerializer(card, context={'request': request}).data
            })

        elif action_type == 'reject':
            reason = request.data.get('reason', '').strip()
            if not reason:
                return Response({'detail': 'Rejection reason is required.'}, status=status.HTTP_400_BAD_REQUEST)

            with transaction.atomic():
                card.status = LibraryCard.STATUS_REJECTED
                card.rejection_reason = reason
                card.hod_verified_by = user
                card.hod_verified_at = timezone.now()
                card.hod_signature_image = None
                card.save()

                AuditLog.objects.create(
                    actor=user,
                    action='hod_reject_library_card',
                    model_name='LibraryCard',
                    object_id=str(card.id),
                    extra={'reason': reason, 'hod_name': user.get_full_name()}
                )

            return Response({
                'status': card.status,
                'message': 'Library Issue Card application rejected.',
                'card': LibraryCardSerializer(card, context={'request': request}).data
            })
        else:
            return Response({'detail': 'Action must be either "approve" or "reject".'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def upload_hod_signature(self, request):
        user = request.user
        from faculty.models import Faculty
        hod_faculty = Faculty.objects.filter(user=user).first()
        if not hod_faculty:
            return Response({'detail': 'Faculty profile not found for this user.'}, status=status.HTTP_404_NOT_FOUND)

        sig_file = request.FILES.get('signature') or request.FILES.get('signature_image')
        if not sig_file:
            return Response({'detail': 'Please provide a signature image file.'}, status=status.HTTP_400_BAD_REQUEST)

        hod_faculty.signature = sig_file
        hod_faculty.save()
        return Response({
            'message': 'Digital signature successfully saved to HOD profile.',
            'signature_url': request.build_absolute_uri(hod_faculty.signature.url) if hod_faculty.signature else None
        })

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def submit_for_approval(self, request, pk=None):
        card = self.get_object()
        if card.borrower_type == 'FACULTY':
            card.status = LibraryCard.STATUS_ACTIVE
            card.save()
            return Response({
                'status': card.status,
                'message': 'Faculty library cards do not require HOD approval; card is immediately active.',
                'card': LibraryCardSerializer(card, context={'request': request}).data
            })
        card.status = LibraryCard.STATUS_PENDING_HOD
        card.submitted_at = timezone.now()
        card.rejection_reason = ''
        card.hod_signature_image = None
        card.save()

        AuditLog.objects.create(
            actor=request.user,
            action='submit_library_card_for_hod_approval',
            model_name='LibraryCard',
            object_id=str(card.id)
        )
        return Response({
            'status': card.status,
            'message': 'Library Issue Card submitted for HOD Approval.',
            'card': LibraryCardSerializer(card, context={'request': request}).data
        })

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def record_missing_books(self, request, pk=None):
        card = self.get_object()
        books_to_add = request.data.get('books', [])
        if not isinstance(books_to_add, list):
            return Response({'detail': 'Books must be a list.'}, status=status.HTTP_400_BAD_REQUEST)

        existing = list(card.recorded_books or [])
        existing_ids = {b.get('issue_id') or b.get('book_copy_no') or b.get('copy_barcode') or b.get('book_title') for b in existing if isinstance(b, dict)}

        added_count = 0
        for b in books_to_add:
            if isinstance(b, dict):
                ref = b.get('issue_id') or b.get('book_copy_no') or b.get('copy_barcode') or b.get('book_title')
                if ref and ref in existing_ids:
                    continue
                existing.append(b)
                if ref:
                    existing_ids.add(ref)
                added_count += 1

        card.recorded_books = existing
        if card.status == LibraryCard.STATUS_REJECTED:
            card.status = LibraryCard.STATUS_PENDING_HOD
            card.submitted_at = timezone.now()
            card.rejection_reason = ''
            card.hod_signature_image = None
        card.save()

        AuditLog.objects.create(
            actor=request.user,
            action='record_missing_books_on_card',
            model_name='LibraryCard',
            object_id=str(card.id),
            extra={'added_count': added_count, 'total_books': len(existing)}
        )
        return Response({
            'status': card.status,
            'added_count': added_count,
            'card': LibraryCardSerializer(card, context={'request': request}).data
        })

    @action(detail=False, methods=['get'], permission_classes=[IsLibraryOfficer])
    def borrower_books(self, request):
        params = getattr(request, 'query_params', None) or request.GET
        identifier = params.get('identifier', '').strip()
        borrower_type = params.get('borrower_type', 'STUDENT').upper()
        card_id = params.get('card_id')

        config = LibraryConfiguration.objects.filter(is_active=True).first()
        student_loan_days = getattr(config, 'loan_days_student', 14) if config else 14
        faculty_loan_days = getattr(config, 'loan_days_faculty', 30) if config else 30
        loan_days = faculty_loan_days if borrower_type == 'FACULTY' else student_loan_days

        from django.apps import apps
        from django.db.models import Q
        StudentModel = apps.get_model('students', 'Student')
        FacultyModel = apps.get_model('faculty', 'Faculty')

        target_user = None
        student_obj = None
        faculty_obj = None

        if borrower_type == 'FACULTY':
            faculty_obj = FacultyModel.objects.filter(
                Q(faculty_id__iexact=identifier) | Q(email__iexact=identifier)
            ).select_related('user', 'department').first()
            if faculty_obj:
                target_user = ensure_user_for_faculty(faculty_obj)
        else:
            student_obj = StudentModel.objects.filter(
                Q(usn__iexact=identifier) | Q(admission_id__iexact=identifier) | Q(email__iexact=identifier)
            ).select_related('user', 'department', 'semester').first()
            if student_obj:
                target_user = ensure_user_for_student(student_obj)

        if not target_user and identifier:
            target_user = User.objects.filter(
                Q(email__iexact=identifier) | Q(user_id__iexact=identifier) | Q(usn__iexact=identifier)
            ).first()

        card = None
        if card_id:
            card = LibraryCard.objects.filter(pk=card_id).first()
        if not card and target_user:
            card = LibraryCard.objects.filter(
                Q(student_user=target_user) |
                (Q(student=student_obj) if student_obj else Q(pk__isnull=True)) |
                (Q(faculty=faculty_obj) if faculty_obj else Q(pk__isnull=True))
            ).first()

        recorded_books = card.recorded_books if (card and card.recorded_books) else []
        recorded_ids = set()
        for b in recorded_books:
            if isinstance(b, dict):
                if b.get('issue_id'):
                    recorded_ids.add(str(b.get('issue_id')))
                if b.get('copy_barcode'):
                    recorded_ids.add(str(b.get('copy_barcode')))
                if b.get('book_copy_no'):
                    recorded_ids.add(str(b.get('book_copy_no')))

        issues_qs = []
        if target_user:
            issues_qs = IssueRecord.objects.filter(borrower=target_user).select_related('copy', 'copy__book').order_by('-issued_at')

        missing_books = []
        all_books = []

        for iss in issues_qs:
            copy = iss.copy
            book = copy.book if copy else None
            issue_date = iss.issued_at.strftime('%Y-%m-%d') if iss.issued_at else timezone.now().strftime('%Y-%m-%d')
            if iss.due_date:
                due_date = iss.due_date.strftime('%Y-%m-%d')
            elif iss.issued_at:
                due_date = (iss.issued_at.date() + timedelta(days=loan_days)).strftime('%Y-%m-%d')
            else:
                due_date = (timezone.now().date() + timedelta(days=loan_days)).strftime('%Y-%m-%d')

            return_date = iss.returned_at.strftime('%Y-%m-%d') if iss.returned_at else ''

            is_on_card = (str(iss.issue_id) in recorded_ids) or (copy and str(copy.barcode) in recorded_ids)
            book_info = {
                'issue_id': iss.issue_id,
                'issue_record_id': iss.id,
                'book_id': book.id if book else None,
                'book_title': book.title if book else 'Library Book',
                'authors': book.authors if book else '',
                'copy_id': copy.id if copy else None,
                'copy_barcode': copy.barcode if copy else (f"Copy #{copy.copy_number}" if copy else ''),
                'book_copy_no': copy.barcode if copy else (f"Copy #{copy.copy_number}" if copy else ''),
                'issued_date': issue_date,
                'due_date': due_date,
                'return_date': return_date,
                'loan_days': loan_days,
                'status': iss.status,
                'is_signed': True,
                'is_on_card': is_on_card,
            }
            all_books.append(book_info)
            if not is_on_card:
                missing_books.append(book_info)

        return Response({
            'borrower': {
                'identifier': identifier,
                'borrower_type': borrower_type,
                'name': student_obj.name if student_obj else (faculty_obj.name if faculty_obj else (target_user.get_full_name() if target_user else '')),
                'department': (student_obj.department.name if (student_obj and student_obj.department) else (faculty_obj.department.name if (faculty_obj and faculty_obj.department) else (target_user.department.name if (target_user and getattr(target_user, 'department', None)) else 'Computer Science and Engineering'))),
                'department_name': (student_obj.department.name if (student_obj and student_obj.department) else (faculty_obj.department.name if (faculty_obj and faculty_obj.department) else (target_user.department.name if (target_user and getattr(target_user, 'department', None)) else 'Computer Science and Engineering'))),
                'semester': f"Semester {student_obj.semester.sem_number}" if (student_obj and student_obj.semester) else None,
                'section': getattr(card, 'section', 'A') if card else 'A',
                'designation': faculty_obj.role if faculty_obj else None,
            },
            'has_card': card is not None,
            'card_id': card.id if card else None,
            'card': LibraryCardSerializer(card, context={'request': request}).data if card else None,
            'loan_days': loan_days,
            'missing_books': missing_books,
            'recorded_books': recorded_books,
            'all_books': all_books,
            'all_borrower_books': all_books,
        })

    @action(detail=False, methods=['get'], permission_classes=[IsLibraryOfficer])
    def all_borrowers_directory(self, request):
        from django.apps import apps
        from django.db.models import Q
        StudentModel = apps.get_model('students', 'Student')
        FacultyModel = apps.get_model('faculty', 'Faculty')

        students = StudentModel.objects.all().select_related('department', 'semester', 'user')
        faculty = FacultyModel.objects.all().select_related('department', 'user')

        cards = LibraryCard.objects.all().select_related('student', 'faculty', 'student_user', 'department', 'hod_verified_by', 'issued_by')
        student_cards = {}
        faculty_cards = {}
        user_cards = {}
        for c in cards:
            if c.student_id:
                student_cards[c.student_id] = c
            if c.faculty_id:
                faculty_cards[c.faculty_id] = c
            if c.student_user_id:
                user_cards[c.student_user_id] = c

        issues = IssueRecord.objects.all().select_related('copy', 'copy__book')
        issues_by_user = {}
        for iss in issues:
            issues_by_user.setdefault(iss.borrower_id, []).append(iss)

        borrowers = []

        # Process Students
        for s in students:
            card = student_cards.get(s.id) or (user_cards.get(s.user_id) if s.user_id else None)
            u_issues = issues_by_user.get(s.user_id, []) if s.user_id else []
            active_loans = sum(1 for iss in u_issues if iss.status == IssueRecord.STATUS_ISSUED)
            recorded_books = card.recorded_books if (card and card.recorded_books) else []
            recorded_issue_ids = {str(b.get('issue_id')) for b in recorded_books if isinstance(b, dict) and b.get('issue_id')}
            recorded_barcodes = {str(b.get('book_copy_no') or b.get('copy_barcode')) for b in recorded_books if isinstance(b, dict) and (b.get('book_copy_no') or b.get('copy_barcode'))}
            missing_books_count = sum(1 for iss in u_issues if str(iss.issue_id) not in recorded_issue_ids and (not iss.copy or str(iss.copy.barcode) not in recorded_barcodes))
            card_status = card.status if card else 'NO_CARD'

            s_dept = s.department or (s.user.department if s.user else None)
            s_dept_name = s_dept.name if s_dept else 'Computer Science and Engineering'

            borrowers.append({
                'id': s.id,
                'user_id': s.user_id if s.user else None,
                'borrower_type': 'STUDENT',
                'name': s.name,
                'student_name': s.name,
                'identifier': s.usn or s.admission_id or f"STU-{s.id}",
                'usn': s.usn or s.admission_id or "",
                'student_usn': s.usn or s.admission_id or "",
                'email': s.email or (s.user.email if s.user else ""),
                'phone': getattr(s, 'mobile_no', '') or getattr(s.user, 'phone', '') or "",
                'department': s_dept_name,
                'department_name': s_dept_name,
                'department_id': s_dept.id if s_dept else None,
                'semester': f"Semester {s.semester.sem_number}" if (s.semester and s.semester.sem_number) else 'Semester 1',
                'semester_number': s.semester.sem_number if s.semester else 1,
                'section': getattr(card, 'section', 'A') if card else 'A',
                'roll_no': s.usn or s.admission_id or "",
                'has_card': card is not None,
                'card_id': card.id if card else None,
                'card_number': card.card_number if card else None,
                'card_status': card_status,
                'status': card_status,
                'active_loans': active_loans,
                'active_loans_count': active_loans,
                'missing_books_count': missing_books_count,
                'card_data': LibraryCardSerializer(card, context={'request': request}).data if card else None,
            })

        # Process Faculty
        for f in faculty:
            card = faculty_cards.get(f.id) or (user_cards.get(f.user_id) if f.user_id else None)
            u_issues = issues_by_user.get(f.user_id, []) if f.user_id else []
            active_loans = sum(1 for iss in u_issues if iss.status == IssueRecord.STATUS_ISSUED)
            recorded_books = card.recorded_books if (card and card.recorded_books) else []
            recorded_issue_ids = {str(b.get('issue_id')) for b in recorded_books if isinstance(b, dict) and b.get('issue_id')}
            recorded_barcodes = {str(b.get('book_copy_no') or b.get('copy_barcode')) for b in recorded_books if isinstance(b, dict) and (b.get('book_copy_no') or b.get('copy_barcode'))}
            missing_books_count = sum(1 for iss in u_issues if str(iss.issue_id) not in recorded_issue_ids and (not iss.copy or str(iss.copy.barcode) not in recorded_barcodes))
            card_status = card.status if card else 'NO_CARD'

            f_dept = f.department or (f.user.department if f.user else None)
            f_dept_name = f_dept.name if f_dept else 'Computer Science and Engineering'

            borrowers.append({
                'id': f.id,
                'user_id': f.user_id if f.user else None,
                'borrower_type': 'FACULTY',
                'name': f.name,
                'faculty_name': f.name,
                'identifier': f.faculty_id or f"FAC-{f.id}",
                'faculty_id': f.faculty_id or "",
                'email': f.email or (f.user.email if f.user else ""),
                'phone': f.phone or "",
                'department': f_dept_name,
                'department_name': f_dept_name,
                'department_id': f_dept.id if f_dept else None,
                'designation': f.role or 'Faculty Member',
                'semester': None,
                'section': None,
                'roll_no': f.faculty_id or "",
                'has_card': card is not None,
                'card_id': card.id if card else None,
                'card_number': card.card_number if card else None,
                'card_status': card_status,
                'status': card_status,
                'active_loans': active_loans,
                'active_loans_count': active_loans,
                'missing_books_count': missing_books_count,
                'card_data': LibraryCardSerializer(card, context={'request': request}).data if card else None,
            })

        # Filtering
        params = getattr(request, 'query_params', None) or request.GET
        q = params.get('q', '').strip().lower()
        b_type = params.get('borrower_type', 'ALL').strip().upper()
        b_status = params.get('status', 'ALL').strip().upper()
        dept_filter = params.get('department', 'All Departments').strip()
        sem_filter = params.get('semester', 'All Semesters').strip()
        missing_only = params.get('missing_only', 'false').lower() == 'true'

        filtered = []
        for b in borrowers:
            if q:
                match_q = (
                    q in b['name'].lower() or
                    q in b['identifier'].lower() or
                    q in b['email'].lower() or
                    q in b['department_name'].lower() or
                    (b['card_number'] and q in b['card_number'].lower())
                )
                if not match_q:
                    continue

            if b_type != 'ALL' and b['borrower_type'] != b_type:
                continue

            if b_status != 'ALL':
                if b_status == 'NO_CARD' and b['has_card']:
                    continue
                elif b_status == 'HAS_CARD' and not b['has_card']:
                    continue
                elif b_status not in ['NO_CARD', 'HAS_CARD'] and b['card_status'] != b_status:
                    continue

            if dept_filter != 'All Departments' and b['department_name'].strip().lower() != dept_filter.strip().lower():
                continue

            if sem_filter != 'All Semesters':
                if b['borrower_type'] == 'FACULTY':
                    continue
                b_sem = b.get('semester') or ''
                if b_sem != sem_filter and str(b.get('semester_number')) != sem_filter.replace('Semester ', ''):
                    continue

            if missing_only and b['missing_books_count'] == 0:
                continue

            filtered.append(b)

        # Prioritize:
        # 1. Borrowers without a card (NO_CARD)
        # 2. Borrowers with cards that are not updated (missing_books_count > 0)
        # 3. Borrowers with cards pending HOD approval (PENDING_HOD)
        # 4. Borrowers with active/approved cards
        def borrower_sort_priority(b):
            has_card = b.get('has_card', False)
            missing = b.get('missing_books_count', 0)
            c_status = b.get('card_status', 'NO_CARD')
            if not has_card or c_status == 'NO_CARD':
                return (0, 0, b.get('name', '').lower())
            if missing > 0:
                return (1, -missing, b.get('name', '').lower())
            if c_status == LibraryCard.STATUS_PENDING_HOD:
                return (2, 0, b.get('name', '').lower())
            return (3, 0, b.get('name', '').lower())

        filtered.sort(key=borrower_sort_priority)

        return Response({
            'total_count': len(filtered),
            'results': filtered,
            'summary': {
                'total_borrowers': len(borrowers),
                'total_students': sum(1 for b in borrowers if b['borrower_type'] == 'STUDENT'),
                'total_faculty': sum(1 for b in borrowers if b['borrower_type'] == 'FACULTY'),
                'with_card': sum(1 for b in borrowers if b['has_card']),
                'no_card': sum(1 for b in borrowers if not b['has_card']),
                'pending_approval': sum(1 for b in borrowers if b['card_status'] == LibraryCard.STATUS_PENDING_HOD),
                'approved': sum(1 for b in borrowers if b['card_status'] == LibraryCard.STATUS_HOD_APPROVED),
                'active': sum(1 for b in borrowers if b['card_status'] == LibraryCard.STATUS_ACTIVE),
                'rejected': sum(1 for b in borrowers if b['card_status'] == LibraryCard.STATUS_REJECTED),
                'with_missing_books': sum(1 for b in borrowers if b['missing_books_count'] > 0),
            }
        })

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def generate_and_activate(self, request, pk=None):
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        if not config:
            return Response(
                {
                    'detail': 'Library configuration is incomplete. Please configure library rules before generating an issue card.',
                    'requires_config': True
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        card = self.get_object()
        if config.require_hod_approval and card.status != LibraryCard.STATUS_HOD_APPROVED:
            return Response(
                {'detail': f'Card cannot be generated until verified by HOD. Current status: {card.status}.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        year = timezone.now().year
        if not card.card_number:
            card.card_number = LibraryCard.generate_next_card_number(year)
        card.qr_code_token = uuid.uuid4().hex

        librarian_name = config.authorized_librarian_name or request.user.get_full_name() or "College Library Officer"
        sig_payload = f"CAMPUSFLOW:LC:{card.card_number}:{card.student_user_id}:{card.academic_year}:{librarian_name}:{timezone.now().isoformat()}"
        card.digital_signature_hash = hashlib.sha256(sig_payload.encode('utf-8')).hexdigest()

        card.issued_by = request.user
        card.issued_at = timezone.now()
        valid_days = config.validity_months * 30 if config.validity_months else 365
        card.valid_until = timezone.now().date() + timedelta(days=valid_days)
        card.status = LibraryCard.STATUS_ACTIVE
        card.save()

        AuditLog.objects.create(
            actor=request.user,
            action='generate_and_activate_library_card',
            model_name='LibraryCard',
            object_id=str(card.id),
            extra={'card_number': card.card_number, 'valid_until': str(card.valid_until)}
        )

        serializer = self.get_serializer(card)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], permission_classes=[IsLibraryOfficer])
    def direct_issue(self, request):
        """
        Step-by-step issue card workflow for Library Officer:
        Search borrower (student or faculty) -> Validate eligibility -> Generate unique card number -> Sign & Issue.
        """
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        if not config:
            return Response(
                {
                    'detail': 'Library configuration is incomplete. Please configure library rules before generating an issue card.',
                    'requires_config': True
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        borrower_identifier = request.data.get('identifier', '').strip()
        borrower_type = request.data.get('borrower_type', 'STUDENT').upper()

        if not borrower_identifier:
            return Response({'detail': 'Please provide borrower USN, Staff ID, or Email.'}, status=status.HTTP_400_BAD_REQUEST)

        # Lookup borrower
        target_user = None
        student_obj = None
        faculty_obj = None

        from django.apps import apps
        from django.db.models import Q
        StudentModel = apps.get_model('students', 'Student')
        FacultyModel = apps.get_model('faculty', 'Faculty')

        if borrower_type == 'FACULTY':
            fac = FacultyModel.objects.filter(
                Q(faculty_id__iexact=borrower_identifier) |
                Q(email__iexact=borrower_identifier) |
                Q(phone__iexact=borrower_identifier)
            ).select_related('user', 'department').first()
            if fac:
                faculty_obj = fac
                target_user = ensure_user_for_faculty(fac)
        else:
            st = StudentModel.objects.filter(
                Q(usn__iexact=borrower_identifier) |
                Q(admission_id__iexact=borrower_identifier) |
                Q(email__iexact=borrower_identifier) |
                Q(mobile_no__iexact=borrower_identifier)
            ).select_related('user', 'department', 'semester').first()
            if st:
                student_obj = st
                target_user = ensure_user_for_student(st)

        if not target_user:
            target_user = User.objects.filter(
                Q(email__iexact=borrower_identifier) |
                Q(user_id__iexact=borrower_identifier) |
                Q(usn__iexact=borrower_identifier)
            ).first()

        if not target_user:
            return Response({'detail': f'Borrower not found with identifier: {borrower_identifier}'}, status=status.HTTP_404_NOT_FOUND)

        # Validate eligibility
        if borrower_type == 'STUDENT' and not config.allow_students:
            return Response({'detail': 'Student borrowing is currently disabled in Library Configuration.'}, status=status.HTTP_400_BAD_REQUEST)
        if borrower_type == 'FACULTY' and not config.allow_faculty:
            return Response({'detail': 'Faculty borrowing is currently disabled in Library Configuration.'}, status=status.HTTP_400_BAD_REQUEST)
        if config.require_active_membership and not target_user.is_active:
            return Response({'detail': 'Borrower account is inactive.'}, status=status.HTTP_400_BAD_REQUEST)

        # Check existing active card
        existing = LibraryCard.objects.filter(student_user=target_user, status=LibraryCard.STATUS_ACTIVE).first()
        if existing:
            return Response({
                'detail': f'Borrower already has an active Library Issue Card: {existing.card_number}',
                'card': LibraryCardSerializer(existing, context={'request': request}).data
            }, status=status.HTTP_200_OK)

        # Generate unique card
        year = timezone.now().year
        card_num = LibraryCard.generate_next_card_number(year)
        valid_days = config.validity_months * 30 if config.validity_months else 365

        dept = None
        if student_obj and student_obj.department:
            dept = student_obj.department
        elif faculty_obj and faculty_obj.department:
            dept = faculty_obj.department
        elif getattr(target_user, 'department', None):
            dept = target_user.department

        librarian_name = config.authorized_librarian_name or request.user.get_full_name() or "College Library Officer"
        sig_payload = f"CAMPUSFLOW:LC:{card_num}:{target_user.id}:{config.academic_year}:{librarian_name}:{timezone.now().isoformat()}"
        sig_hash = hashlib.sha256(sig_payload.encode('utf-8')).hexdigest()

        card = LibraryCard.objects.create(
            card_number=card_num,
            borrower_type=borrower_type,
            student_user=target_user,
            student=student_obj,
            faculty=faculty_obj,
            department=dept,
            academic_year=config.academic_year,
            semester=getattr(student_obj.semester, 'sem_number', None) if (student_obj and student_obj.semester) else None,
            section=request.data.get('section', 'A'),
            roll_no=student_obj.usn if student_obj else (faculty_obj.faculty_id if faculty_obj else ""),
            student_photo=student_obj.photo if (student_obj and student_obj.photo) else (faculty_obj.photo if (faculty_obj and faculty_obj.photo) else None),
            card_fee=0.00,
            fee_paid=True,
            fee_payment_reference="FREE-MEMBERSHIP",
            status=LibraryCard.STATUS_ACTIVE,
            issued_by=request.user,
            issued_at=timezone.now(),
            valid_until=timezone.now().date() + timedelta(days=valid_days),
            digital_signature_hash=sig_hash,
            qr_code_token=uuid.uuid4().hex
        )

        AuditLog.objects.create(
            actor=request.user,
            action='direct_issue_library_card',
            model_name='LibraryCard',
            object_id=str(card.id),
            extra={'card_number': card.card_number, 'borrower': target_user.email, 'valid_until': str(card.valid_until)}
        )

        serializer = self.get_serializer(card)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], permission_classes=[IsLibraryOfficer])
    def search_borrower(self, request):
        query = request.query_params.get('q', '').strip()
        if not query:
            return Response({'results': []})

        from django.db.models import Q
        from django.apps import apps
        StudentModel = apps.get_model('students', 'Student')
        FacultyModel = apps.get_model('faculty', 'Faculty')

        results = []

        students = StudentModel.objects.filter(
            Q(usn__icontains=query) |
            Q(name__icontains=query) |
            Q(email__icontains=query) |
            Q(admission_id__icontains=query)
        ).select_related('department', 'semester', 'user')[:10]

        for s in students:
            active_card = LibraryCard.objects.filter(student=s, status=LibraryCard.STATUS_ACTIVE).first()
            active_loans = IssueRecord.objects.filter(borrower=s.user, status=IssueRecord.STATUS_ISSUED).count() if s.user else 0
            s_dept = s.department or (s.user.department if s.user else None)
            s_dept_name = s_dept.name if s_dept else 'Computer Science and Engineering'
            results.append({
                'type': 'STUDENT',
                'id': s.id,
                'user_id': s.user_id if s.user else None,
                'name': s.name,
                'student_name': s.name,
                'identifier': s.usn or s.admission_id or "",
                'usn': s.usn or s.admission_id or "",
                'student_usn': s.usn or s.admission_id or "",
                'email': s.email,
                'department': s_dept_name,
                'department_name': s_dept_name,
                'semester': f"Semester {s.semester.sem_number}" if (s.semester and s.semester.sem_number) else 'Semester 1',
                'semester_number': s.semester.sem_number if s.semester else 1,
                'section': getattr(active_card, 'section', 'A') if active_card else 'A',
                'roll_no': s.usn or s.admission_id or "",
                'has_active_card': active_card is not None,
                'card_id': active_card.id if active_card else None,
                'card_number': active_card.card_number if active_card else None,
                'active_loans': active_loans,
                'active_loans_count': active_loans,
            })

        faculty = FacultyModel.objects.filter(
            Q(faculty_id__icontains=query) |
            Q(name__icontains=query) |
            Q(email__icontains=query)
        ).select_related('department', 'user')[:10]

        for f in faculty:
            active_card = LibraryCard.objects.filter(faculty=f, status=LibraryCard.STATUS_ACTIVE).first()
            active_loans = IssueRecord.objects.filter(borrower=f.user, status=IssueRecord.STATUS_ISSUED).count() if f.user else 0
            f_dept = f.department or (f.user.department if f.user else None)
            f_dept_name = f_dept.name if f_dept else 'Computer Science and Engineering'
            results.append({
                'type': 'FACULTY',
                'id': f.id,
                'user_id': f.user_id if f.user else None,
                'name': f.name,
                'faculty_name': f.name,
                'identifier': f.faculty_id or "",
                'faculty_id': f.faculty_id or "",
                'email': f.email,
                'department': f_dept_name,
                'department_name': f_dept_name,
                'designation': f.role or 'Faculty',
                'has_active_card': active_card is not None,
                'card_id': active_card.id if active_card else None,
                'card_number': active_card.card_number if active_card else None,
                'active_loans': active_loans,
                'active_loans_count': active_loans,
            })

        return Response({'results': results})

    @action(detail=False, methods=['get'], permission_classes=[IsLibraryOfficer])
    def borrowers_list(self, request):
        cards = LibraryCard.objects.select_related('student_user', 'student', 'faculty', 'department').order_by('-created_at')
        borrower_data = []
        for c in cards:
            borrower_data.append(LibraryCardSerializer(c, context={'request': request}).data)
        return Response(borrower_data)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def suspend(self, request, pk=None):
        card = self.get_object()
        card.status = LibraryCard.STATUS_SUSPENDED
        card.save()
        AuditLog.objects.create(actor=request.user, action='suspend_library_card', model_name='LibraryCard', object_id=str(card.id))
        return Response({'status': card.status, 'message': 'Card has been suspended.'})

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def mark_lost(self, request, pk=None):
        card = self.get_object()
        card.status = LibraryCard.STATUS_LOST
        card.save()
        AuditLog.objects.create(actor=request.user, action='mark_lost_library_card', model_name='LibraryCard', object_id=str(card.id))
        return Response({'status': card.status, 'message': 'Card marked as lost.'})

    @action(detail=False, methods=['get'])
    def my_card(self, request):
        user = request.user
        card = LibraryCard.objects.filter(student_user=user).order_by('-created_at').first()
        if not card:
            card = LibraryCard.objects.filter(faculty__user=user).order_by('-created_at').first()
        if not card:
            card = LibraryCard.objects.filter(student__user=user).order_by('-created_at').first()
        if not card:
            return Response({'has_card': False, 'card': None})

        issues = IssueRecord.objects.filter(borrower=user).select_related('copy', 'copy__book', 'created_by').order_by('-issued_at')[:20]
        issue_logs = []
        for idx, iss in enumerate(issues, start=1):
            issue_logs.append({
                'serial_no': idx,
                'book_title': iss.copy.book.title,
                'book_copy_no': iss.copy.barcode or f"Copy #{iss.copy.copy_number}",
                'issued_date': iss.issued_at.strftime('%d-%m-%Y') if iss.issued_at else '-',
                'return_date': iss.returned_at.strftime('%d-%m-%Y') if iss.returned_at else ('Pending' if iss.status == 'issued' else iss.status),
                'librarian_signature': iss.created_by.get_full_name() if iss.created_by else 'Librarian (Digital Stamp)',
                'is_returned': iss.returned_at is not None,
            })

        card_data = LibraryCardSerializer(card, context={'request': request}).data
        return Response({
            'has_card': True,
            'card': card_data,
            'circulation_rows': issue_logs,
        })


# ---------- Library Configuration & Rules ----------
class LibraryConfigurationViewSet(viewsets.ModelViewSet):
    queryset = LibraryConfiguration.objects.all()
    serializer_class = LibraryConfigurationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsLibraryOfficer()]
        return [permissions.IsAuthenticated()]

    @action(detail=False, methods=['get'])
    def active(self, request):
        config = LibraryConfiguration.objects.filter(is_active=True).first()
        if not config:
            config = LibraryConfiguration.objects.create(
                academic_year="2025-2026",
                start_date=timezone.now().date(),
                end_date=timezone.now().date() + timedelta(days=365),
                is_active=True,
                max_books_student=3,
                max_books_faculty=5,
                loan_duration_days=14,
                allow_students=True,
                allow_faculty=True,
                require_active_membership=True,
                card_title="LIBRARY ISSUE CARD",
                card_prefix="LC",
                card_number_format="LC-YYYY-NNNNNN",
                validity_months=12,
                require_hod_approval=True,
                require_principal_approval=False,
                authorized_librarian_name="College Library Officer",
                librarian_designation="Chief Librarian",
                digital_stamp_title="DIGITAL STAMP",
                digital_stamp_sub="College Library Officer",
                borrowing_fee=0.00,
                late_fine_per_day=0.00
            )
        serializer = self.get_serializer(config)
        return Response(serializer.data)

    def perform_create(self, serializer):
        config = serializer.save(updated_by=self.request.user)
        AuditLog.objects.create(actor=self.request.user, action='create_library_config', model_name='LibraryConfiguration', object_id=str(config.id))

    def perform_update(self, serializer):
        config = serializer.save(updated_by=self.request.user)
        AuditLog.objects.create(actor=self.request.user, action='update_library_config', model_name='LibraryConfiguration', object_id=str(config.id))


# ---------- Library Feedback & Suggestions ----------
class LibraryFeedbackViewSet(viewsets.ModelViewSet):
    queryset = LibraryFeedback.objects.all()
    serializer_class = LibraryFeedbackSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        role = getattr(user, 'role', '').upper()
        if user.is_staff or role in ['LIBRARY', 'PRINCIPAL', 'SYSTEM']:
            return LibraryFeedback.objects.select_related('user', 'responded_by').all()
        return LibraryFeedback.objects.filter(user=user).select_related('user', 'responded_by')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[IsLibraryOfficer])
    def respond(self, request, pk=None):
        fb = self.get_object()
        resp_text = request.data.get('response', '').strip()
        if not resp_text:
            return Response({'detail': 'Response message cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)
        fb.response = resp_text
        fb.responded_by = request.user
        fb.save()
        return Response(self.get_serializer(fb).data)


# ---------- Library Officer Comprehensive Reports API ----------
class LibraryReportsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(user, 'role', '').upper()
        if not (user.is_staff or role in ['LIBRARY', 'PRINCIPAL', 'HOD', 'SYSTEM']):
            return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

        dept_filter = request.query_params.get('department', '').strip()
        date_range = request.query_params.get('date_range', 'all').lower()
        search_q = request.query_params.get('search', '').strip().lower()

        now = timezone.now()
        start_date = None
        if date_range == 'today':
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
        elif date_range == 'week':
            start_date = now - timedelta(days=7)
        elif date_range == 'month':
            start_date = now - timedelta(days=30)
        elif date_range == 'semester':
            start_date = now - timedelta(days=180)

        # 1. Summary Dashboard Metrics
        total_titles = Book.objects.count()
        total_copies = BookCopy.objects.count()
        available_copies = BookCopy.objects.filter(status=BookCopy.STATUS_AVAILABLE).count()
        issued_copies = BookCopy.objects.filter(status=BookCopy.STATUS_ISSUED).count()
        damaged_copies = BookCopy.objects.filter(status=BookCopy.STATUS_DAMAGED).count()
        lost_copies = BookCopy.objects.filter(status=BookCopy.STATUS_LOST).count()
        active_loans = IssueRecord.objects.filter(status=IssueRecord.STATUS_ISSUED).count()
        overdue_loans = IssueRecord.objects.filter(status=IssueRecord.STATUS_ISSUED, due_date__lt=now.date()).count()
        total_borrowers = LibraryCard.objects.count()
        pending_reservations = BookRequest.objects.filter(status=BookRequest.REQUEST_STATUS_PENDING).count()

        summary = {
            'total_titles': total_titles,
            'total_copies': total_copies,
            'available_copies': available_copies,
            'issued_copies': issued_copies,
            'damaged_copies': damaged_copies,
            'lost_copies': lost_copies,
            'active_loans': active_loans,
            'overdue_loans': overdue_loans,
            'total_borrowers': total_borrowers,
            'pending_reservations': pending_reservations,
        }

        # 2. Book Inventory Report
        books_qs = Book.objects.all().prefetch_related('copies')
        if dept_filter and dept_filter != 'All Departments':
            books_qs = books_qs.filter(department__name__iexact=dept_filter)
        if search_q:
            books_qs = books_qs.filter(
                Q(title__icontains=search_q) |
                Q(authors__icontains=search_q) |
                Q(isbn__icontains=search_q)
            )

        inventory_report = []
        for b in books_qs:
            copies = list(b.copies.all())
            avail = sum(1 for c in copies if c.status == BookCopy.STATUS_AVAILABLE)
            issued = sum(1 for c in copies if c.status == BookCopy.STATUS_ISSUED)
            damaged = sum(1 for c in copies if c.status == BookCopy.STATUS_DAMAGED)
            lost = sum(1 for c in copies if c.status == BookCopy.STATUS_LOST)
            inventory_report.append({
                'id': b.id,
                'title': b.title,
                'authors': b.authors,
                'isbn': b.isbn,
                'category': b.category,
                'department': b.department.name if b.department else 'General Engineering',
                'total_copies': len(copies),
                'available_copies': avail,
                'issued_copies': issued,
                'damaged_copies': damaged,
                'lost_copies': lost,
            })

        # 3. Issue & Return Report
        issues_qs = IssueRecord.objects.select_related('borrower', 'copy', 'copy__book', 'copy__book__department').order_by('-issued_at')
        if start_date:
            issues_qs = issues_qs.filter(issued_at__gte=start_date)
        if dept_filter and dept_filter != 'All Departments':
            issues_qs = issues_qs.filter(
                Q(borrower__department__name__iexact=dept_filter) |
                Q(copy__book__department__name__iexact=dept_filter)
            )
        if search_q:
            issues_qs = issues_qs.filter(
                Q(issue_id__icontains=search_q) |
                Q(copy__book__title__icontains=search_q) |
                Q(borrower__email__icontains=search_q) |
                Q(borrower__usn__icontains=search_q)
            )

        issues_report = []
        for iss in issues_qs[:200]:
            is_overdue = iss.status == IssueRecord.STATUS_ISSUED and iss.due_date and iss.due_date < now.date()
            issues_report.append({
                'issue_id': iss.issue_id,
                'book_title': iss.copy.book.title,
                'copy_id': iss.copy.barcode or f"Copy #{iss.copy.copy_number}",
                'borrower_name': iss.borrower.get_full_name() or iss.borrower.email,
                'borrower_usn': getattr(iss.borrower, 'usn', '') or iss.borrower.email,
                'issue_date': iss.issued_at.strftime('%Y-%m-%d') if iss.issued_at else '',
                'due_date': str(iss.due_date) if iss.due_date else '',
                'returned_at': iss.returned_at.strftime('%Y-%m-%d') if iss.returned_at else '',
                'status': 'OVERDUE' if is_overdue else iss.status.upper(),
                'is_overdue': is_overdue,
                'fee': 0.0,
            })

        # 4. Borrower Report
        cards_qs = LibraryCard.objects.select_related('student_user', 'student', 'faculty', 'department').order_by('-created_at')
        if dept_filter and dept_filter != 'All Departments':
            cards_qs = cards_qs.filter(department__name__iexact=dept_filter)

        borrowers_report = []
        for c in cards_qs:
            user_obj = c.student_user
            active_cnt = IssueRecord.objects.filter(borrower=user_obj, status=IssueRecord.STATUS_ISSUED).count() if user_obj else 0
            overdue_cnt = IssueRecord.objects.filter(borrower=user_obj, status=IssueRecord.STATUS_ISSUED, due_date__lt=now.date()).count() if user_obj else 0
            borrowers_report.append({
                'card_number': c.card_number,
                'borrower_name': c.student.name if c.student else (c.faculty.name if c.faculty else (user_obj.get_full_name() if user_obj else 'N/A')),
                'borrower_type': c.borrower_type,
                'identifier': c.roll_no or (c.student.usn if c.student else (c.faculty.faculty_id if c.faculty else '')),
                'department': c.department.name if c.department else 'General Engineering',
                'semester': f"Semester {c.semester}" if c.semester else ('Faculty' if c.borrower_type == 'FACULTY' else 'N/A'),
                'status': c.status,
                'active_loans': active_cnt,
                'overdue_books': overdue_cnt,
                'valid_until': str(c.valid_until) if c.valid_until else '',
            })

        # 5. Reservation Report
        reqs_qs = BookRequest.objects.select_related('requester', 'requester__department').order_by('-created_at')
        if dept_filter and dept_filter != 'All Departments':
            reqs_qs = reqs_qs.filter(requester__department__name__iexact=dept_filter)

        reservations_report = []
        for r in reqs_qs[:100]:
            dept_name = 'General'
            if hasattr(r.requester, 'department') and r.requester.department:
                dept_name = r.requester.department.name
            reservations_report.append({
                'id': r.id,
                'title': r.title,
                'authors': r.authors,
                'requester_name': r.requester.get_full_name() or getattr(r.requester, 'user_id', None) or r.requester.email,
                'department': dept_name,
                'status': r.status,
                'created_at': r.created_at.strftime('%Y-%m-%d') if r.created_at else '',
            })

        # 6. Library Issue Card Report
        card_stats = {
            'total_generated': LibraryCard.objects.count(),
            'active_cards': LibraryCard.objects.filter(status=LibraryCard.STATUS_ACTIVE).count(),
            'expired_cards': LibraryCard.objects.filter(status=LibraryCard.STATUS_EXPIRED).count(),
            'suspended_cards': LibraryCard.objects.filter(status=LibraryCard.STATUS_SUSPENDED).count(),
            'pending_generation': LibraryCard.objects.filter(status=LibraryCard.STATUS_HOD_APPROVED).count(),
        }

        return Response({
            'summary': summary,
            'inventory': inventory_report,
            'issues': issues_report,
            'borrowers': borrowers_report,
            'reservations': reservations_report,
            'card_stats': card_stats,
        }, status=status.HTTP_200_OK)


