from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('attendance', '0002_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='attendancerecord', table='attendance_record')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='attendancesession', table='attendance_session')])]
