from django.urls import path
from .views import CurrentHODView, PreviousHODView, AssignHODView

urlpatterns = [
    path("current/", CurrentHODView.as_view(), name="current_hod"),
    path("previous/", PreviousHODView.as_view(), name="previous_hod"),
    path("assign/", AssignHODView.as_view(), name="assign_hod"),
]
