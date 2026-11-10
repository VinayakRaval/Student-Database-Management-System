from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Informs the user that email delivery has been removed from SDMS."

    def add_arguments(self, parser):
        parser.add_argument(
            "--to",
            dest="recipient",
            required=False,
            default="",
            help="Recipient address (unused)",
        )
        parser.add_argument(
            "--check-only",
            action="store_true",
            help="Check status",
        )

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.WARNING(
                "\n[SDMS NOTICE] Email service has been completely removed from this application.\n"
                "Initial credentials and password resets are managed directly through authorized in-app interfaces.\n"
            )
        )
