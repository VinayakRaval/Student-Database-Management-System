from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone
import corrections.models

class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('academics', '0001_initial'),
        ('students', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL if hasattr(settings, 'AUTH_USER_MODEL') else 'userlogin.CustomUser'),
    ]

    operations = [
        migrations.CreateModel(
            name='CorrectionRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('request_id', models.CharField(default=corrections.models.generate_correction_request_id, max_length=30, unique=True)),
                ('category', models.CharField(choices=[('PERSONAL', 'Personal Details'), ('ADMISSION_USN', 'USN & Admission Records'), ('ATTENDANCE', 'Attendance'), ('IA_MARKS', 'IA Marks'), ('EXAM_RESULTS', 'External Examination Results'), ('FEES', 'Fees & Payments'), ('DOCUMENTS', 'Uploaded Documents'), ('LIBRARY', 'Library Records'), ('ACADEMIC', 'Subjects & Academic History'), ('ACCOUNT', 'Account Access'), ('OTHER', 'Other Discrepancies')], max_length=40)),
                ('target_record_ref', models.CharField(blank=True, help_text='e.g. Subject Code, Class Date, Receipt No, Document Name', max_length=255)),
                ('current_value', models.TextField(blank=True, help_text='Current recorded value if known')),
                ('requested_value', models.TextField(help_text='Requested correction or expected value')),
                ('description', models.TextField(help_text='Detailed description of the mistake')),
                ('reason', models.TextField(help_text='Reason for the correction request')),
                ('evidence_file', models.FileField(blank=True, null=True, upload_to='correction_evidence/')),
                ('status', models.CharField(choices=[('SUBMITTED', 'Submitted'), ('PENDING_REVIEW', 'Pending Review'), ('MORE_INFO_REQUIRED', 'More Information Required'), ('FORWARDED', 'Forwarded to Reviewer'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected'), ('COMPLETED', 'Completed')], default='SUBMITTED', max_length=30)),
                ('assigned_role', models.CharField(blank=True, default='ADMISSION', max_length=50)),
                ('reviewer_comments', models.TextField(blank=True, default='')),
                ('rejection_reason', models.TextField(blank=True, default='')),
                ('resolution_notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('resolved_at', models.DateTimeField(blank=True, null=True)),
                ('assigned_department', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='correction_requests', to='academics.department')),
                ('assigned_to', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='assigned_corrections', to=settings.AUTH_USER_MODEL)),
                ('student', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='correction_requests', to='students.student')),
            ],
            options={
                'db_table': 'correction_request',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='CorrectionRequestHistory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('action', models.CharField(choices=[('SUBMITTED', 'Request Submitted'), ('REVIEWED', 'Request Under Review'), ('INFO_REQUESTED', 'Information Requested'), ('FORWARDED', 'Forwarded'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected'), ('RESOLVED', 'Correction Applied & Completed')], max_length=40)),
                ('from_status', models.CharField(blank=True, max_length=30)),
                ('to_status', models.CharField(blank=True, max_length=30)),
                ('comments', models.TextField(blank=True, default='')),
                ('timestamp', models.DateTimeField(default=django.utils.timezone.now)),
                ('actor', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to=settings.AUTH_USER_MODEL)),
                ('request', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='history', to='corrections.correctionrequest')),
            ],
            options={
                'db_table': 'correction_request_history',
                'ordering': ['timestamp'],
            },
        ),
        migrations.AddIndex(
            model_name='correctionrequest',
            index=models.Index(fields=['student', 'status'], name='correction__student_d763ef_idx'),
        ),
        migrations.AddIndex(
            model_name='correctionrequest',
            index=models.Index(fields=['assigned_department', 'status'], name='correction__assigne_c6b12a_idx'),
        ),
        migrations.AddIndex(
            model_name='correctionrequest',
            index=models.Index(fields=['category', 'status'], name='correction__categor_c7c00a_idx'),
        ),
    ]
