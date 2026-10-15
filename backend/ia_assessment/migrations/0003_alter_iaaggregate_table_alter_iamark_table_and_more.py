from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('ia_assessment', '0002_alter_iatestsetup_unique_together_and_more')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='iaaggregate', table='ia_aggregate')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='iamark', table='ia_mark')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='iatestsetup', table='ia_test_setup')])]
