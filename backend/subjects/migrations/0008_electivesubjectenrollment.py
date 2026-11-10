from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):

    dependencies = [
        ('academics', '0001_initial'),
        ('students', '0001_initial'),
        ('subjects', '0007_alter_subjectassignment_unique_together'),
    ]

    operations = [
        migrations.CreateModel(
            name='ElectiveSubjectEnrollment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('batch', models.CharField(blank=True, max_length=50, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('enrolled_at', models.DateTimeField(auto_now_add=True)),
                ('academic_year', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to='academics.academicyear')),
                ('student', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='elective_enrollments', to='students.student')),
                ('subject', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='elective_enrollments', to='subjects.subject')),
            ],
            options={
                'db_table': 'elective_subject_enrollment',
                'ordering': ['student__usn'],
                'unique_together': {('subject', 'student', 'academic_year')},
            },
        ),
    ]
