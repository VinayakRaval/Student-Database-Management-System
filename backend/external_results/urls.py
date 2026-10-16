from django.urls import path
from .views import (
    ExternalResultListCreateView,
    ExternalResultRetrieveUpdateDestroyView,
    VerifyExternalResultView
)

app_name = 'external_results'

urlpatterns = [
    path('', ExternalResultListCreateView.as_view(), name='list_create'),
    path('<int:pk>/', ExternalResultRetrieveUpdateDestroyView.as_view(), name='detail'),
    path('<int:pk>/verify/', VerifyExternalResultView.as_view(), name='verify'),
]
