from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('timetable', '0001_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='timetable', table='timetable')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='timetableapprovalhistory', table='timetable_approval_history')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='timetableslot', table='timetable_slot')])]
