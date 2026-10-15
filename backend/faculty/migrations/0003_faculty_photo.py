from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('faculty', '0002_initial')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='faculty', table='faculty')]), migrations.AddField(model_name='faculty', name='photo', field=models.ImageField(blank=True, null=True, upload_to='photos/'))]
