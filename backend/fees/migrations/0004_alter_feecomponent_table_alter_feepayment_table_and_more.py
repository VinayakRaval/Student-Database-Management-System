from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('fees', '0003_feestructure_rejection_remark')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='feecomponent', table='fee_component')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='feepayment', table='fee_payment')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='feereceipt', table='fee_receipt')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='feestructure', table='fee_structure')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='studentfee', table='student_fee')])]
