from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('subjects', '0001_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='subject', table='subject')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='subjectassignment', table='subject_assignment')])]
