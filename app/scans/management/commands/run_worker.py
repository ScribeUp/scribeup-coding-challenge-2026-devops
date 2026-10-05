from django.core.management.base import BaseCommand

from scans import worker


class Command(BaseCommand):
    help = "Run the scan worker until interrupted."

    def handle(self, *args, **options):
        try:
            worker.run()
        except KeyboardInterrupt:
            pass
