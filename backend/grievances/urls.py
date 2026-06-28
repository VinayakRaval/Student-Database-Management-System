from django.urls import path
from .views import GrievanceViewSet

grievance_list = GrievanceViewSet.as_view({
    "get": "list",
    "post": "create",
})

grievance_detail = GrievanceViewSet.as_view({
    "get": "retrieve",
    "put": "update",
    "patch": "partial_update",
    "delete": "destroy",
})

respond_grievance = GrievanceViewSet.as_view({"post": "respond"})

urlpatterns = [
    path("", grievance_list, name="grievance-list"),
    path("<int:pk>/", grievance_detail, name="grievance-detail"),
    path("<int:pk>/respond/", respond_grievance, name="grievance-respond"),
]
