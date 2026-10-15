from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('hod_assignment', '0001_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='hodassignment', table='hod_assignment')])]
