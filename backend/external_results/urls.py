from django.urls import path
from .views import ExternalResultListCreateView, ExternalResultRetrieveUpdateDestroyView

app_name = 'external_results'

urlpatterns = [
    path('', ExternalResultListCreateView.as_view(), name='list_create'),
    path('<int:pk>/', ExternalResultRetrieveUpdateDestroyView.as_view(), name='detail'),
]
