from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    BookCategoryViewSet, BookViewSet, BookCopyViewSet, EBookViewSet,
    BookRequestViewSet, IssueViewSet, FineViewSet, LibraryCardViewSet,
    LibraryConfigurationViewSet, LibraryFeedbackViewSet, LibraryReportsView
)

router = DefaultRouter()
router.register(r'categories', BookCategoryViewSet, basename='library-categories')
router.register(r'books', BookViewSet)
router.register(r'copies', BookCopyViewSet)
router.register(r'ebooks', EBookViewSet)
router.register(r'requests', BookRequestViewSet)
router.register(r'issues', IssueViewSet)
router.register(r'fines', FineViewSet)
router.register(r'cards', LibraryCardViewSet)
router.register(r'config', LibraryConfigurationViewSet, basename='library-config')
router.register(r'feedback', LibraryFeedbackViewSet, basename='library-feedback')

urlpatterns = [
    path('reports/summary/', LibraryReportsView.as_view(), name='library-reports-summary'),
    path('', include(router.urls)),
]
