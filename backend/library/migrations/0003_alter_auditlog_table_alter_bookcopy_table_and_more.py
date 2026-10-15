from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [('library', '0002_alter_book_department_delete_department')]
    operations = [migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='auditlog', table='library_audit_log')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='bookcopy', table='library_book_copy')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='bookrequest', table='library_book_request')]), migrations.SeparateDatabaseAndState(database_operations=[], state_operations=[migrations.AlterModelTable(name='issuerecord', table='library_issue_record')])]
