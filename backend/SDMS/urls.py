
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import HttpResponse
from userlogin.views import DashboardView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
    path('userlogin/', include('userlogin.urls')),
    path('auth/', include('userlogin.urls')),
    path('api/auth/', include('userlogin.urls')),
    path('academics/', include('academics.urls')),
    path('faculty/', include('faculty.urls')),
    path('students/', include('students.urls')),
    path('hod_assignment/', include('hod_assignment.urls')),
    path('subjects/', include('subjects.urls')),
    path('timetable/', include('timetable.urls')),
    path('attendance/', include('attendance.urls')),
    path('fees/', include('fees.urls')),
    path('ia_assessment/', include('ia_assessment.urls')),
    path('ia/', include('ia_assessment.urls')),
    path('library/', include('library.urls')),
    path('grievances/', include('grievances.urls')),
    path('external_results/', include('external_results.urls')),
    path('announcements/', include('announcements.urls')),
    path('', lambda request: HttpResponse(
        "<h1>Student Data Management System</h1>"
        "<p>Backend is running successfully.</p>"
    ), name='home'),
]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT,
    )
