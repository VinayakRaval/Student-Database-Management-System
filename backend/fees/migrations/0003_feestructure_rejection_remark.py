from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('fees', '0002_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='feestructure', table='fee_structure')]), migrations.AddField(model_name='feestructure', name='rejection_remark', field=models.TextField(blank=True, null=True))]
