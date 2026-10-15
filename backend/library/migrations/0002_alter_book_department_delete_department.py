import django.db.models.deletion
from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('academics', '0001_initial'), ('library', '0001_initial')]
    operations = [migrations.AlterField(model_name='book', name='department', field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to='academics.department')), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.DeleteModel(name='Department')])]
