from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('grievances', '0006_alter_grievance_id')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='grievance', table='grievance')])]
