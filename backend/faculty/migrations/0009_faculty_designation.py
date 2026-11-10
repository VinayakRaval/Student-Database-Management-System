from django.db import migrations, models

class Migration(migrations.Migration):

    dependencies = [
        ('faculty', '0008_faculty_date_of_joining_faculty_employment_type_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='faculty',
            name='designation',
            field=models.CharField(blank=True, default='Professor', max_length=150, null=True),
        ),
    ]
