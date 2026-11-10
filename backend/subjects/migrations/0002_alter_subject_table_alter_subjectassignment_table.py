from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('subjects', '0001_initial')]
    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(
                    sql="""
                        DO $$
                        BEGIN
                            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'subjects_subject') THEN
                                ALTER TABLE subjects_subject RENAME TO subject;
                            END IF;
                            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'subjects_subjectassignment') THEN
                                ALTER TABLE subjects_subjectassignment RENAME TO subject_assignment;
                            END IF;
                        END $$;
                    """,
                    reverse_sql="""
                        DO $$
                        BEGIN
                            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'subject') THEN
                                ALTER TABLE subject RENAME TO subjects_subject;
                            END IF;
                            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'subject_assignment') THEN
                                ALTER TABLE subject_assignment RENAME TO subjects_subjectassignment;
                            END IF;
                        END $$;
                    """
                ),
            ],
            state_operations=[
                migrations.AlterModelTable(name='subject', table='subject'),
                migrations.AlterModelTable(name='subjectassignment', table='subject_assignment'),
            ],
        ),
    ]
