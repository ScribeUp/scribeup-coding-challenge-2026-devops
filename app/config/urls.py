from django.urls import path

from scans import views

urlpatterns = [
    path("healthz", views.healthz),
    path("members/<int:member_id>/scans", views.start_scan),
    path("members/<int:member_id>/subscriptions", views.subscriptions),
    path("members/<int:member_id>/exports", views.export),
    path("scans/<int:job_id>", views.scan_status),
]
