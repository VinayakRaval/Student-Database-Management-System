
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("academics", "0001_initial"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.AddField(
                    model_name="department",
                    name="created_at",
                    field=models.DateTimeField(auto_now_add=True),
                ),
                migrations.AddField(
                    model_name="department",
                    name="updated_at",
                    field=models.DateTimeField(auto_now=True),
                ),
                migrations.AddField(
                    model_name="semester",
                    name="created_at",
                    field=models.DateTimeField(auto_now_add=True),
                ),
                migrations.AddField(
                    model_name="semester",
                    name="updated_at",
                    field=models.DateTimeField(auto_now=True),
                ),
                migrations.AddField(
                    model_name="academicyear",
                    name="created_at",
                    field=models.DateTimeField(auto_now_add=True),
                ),
                migrations.AddField(
                    model_name="academicyear",
                    name="updated_at",
                    field=models.DateTimeField(auto_now=True),
                ),
                migrations.AddField(
                    model_name="schema",
                    name="created_at",
                    field=models.DateTimeField(auto_now_add=True),
                ),
                migrations.AddField(
                    model_name="schema",
                    name="updated_at",
                    field=models.DateTimeField(auto_now=True),
                ),
            ],
        ),
    ]
