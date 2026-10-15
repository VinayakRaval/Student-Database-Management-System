from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('faculty', '0004_alter_faculty_role')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='faculty', table='faculty')])]
