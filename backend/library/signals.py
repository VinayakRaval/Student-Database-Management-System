from django.db.models.signals import post_save, post_delete, pre_save
from django.dispatch import receiver
from django.utils import timezone
from .models import Book, BookCopy, EBook, IssueRecord, Fine, BookRequest, AuditLog

# --- Helpers: replace with your real notification functions ---
def send_notification(user_or_group, title, message, extras=None):
    # Placeholder: integrate with your SDMS notifications/email/push
    pass

# When a copy is added/removed/changed we keep Book stock properties consistent (these are calculated properties,
# but you might want to send events on status changes).
@receiver(post_save, sender=BookCopy)
def bookcopy_post_save(sender, instance, created, **kwargs):
    # If new copy created -> log and possibly notify department users that stock changed
    AuditLog.objects.create(actor=None, action='bookcopy_saved', model_name='BookCopy', object_id=str(instance.id))
    # Example: Notify when new copy added
    if created:
        # send_notification(...)

        pass

# When an IssueRecord is created -> notify borrower
@receiver(post_save, sender=IssueRecord)
def issue_post_save(sender, instance, created, **kwargs):
    if created:
        # send issue notification to borrower
        AuditLog.objects.create(actor=None, action='issue_created', model_name='IssueRecord', object_id=str(instance.id))
        # send_notification(instance.borrower, "Book Issued", f"Book {instance.copy.book.title} issued. Due on {instance.due_date}")

# When Fine created -> notify student and accounts
@receiver(post_save, sender=Fine)
def fine_post_save(sender, instance, created, **kwargs):
    if created:
        AuditLog.objects.create(actor=None, action='fine_created', model_name='Fine', object_id=str(instance.id))
        # send_notification(instance.issue.borrower, "Fine Added", f"A fine of ₹{instance.amount} added for issue {instance.issue.issue_id}")

# BookRequest status change -> notify appropriate roles
@receiver(post_save, sender=BookRequest)
def request_post_save(sender, instance, created, **kwargs):
    if created:
        AuditLog.objects.create(actor=None, action='request_created', model_name='BookRequest', object_id=str(instance.id))
        # notify library officers
    else:
        AuditLog.objects.create(actor=None, action='request_updated', model_name='BookRequest', object_id=str(instance.id), extra={'status': instance.status})
