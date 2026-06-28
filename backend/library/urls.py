from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    BookViewSet, BookCopyViewSet, EBookViewSet,
    BookRequestViewSet, IssueViewSet, FineViewSet
)

router = DefaultRouter()
router.register(r'books', BookViewSet)
router.register(r'copies', BookCopyViewSet)
router.register(r'ebooks', EBookViewSet)
router.register(r'requests', BookRequestViewSet)
router.register(r'issues', IssueViewSet)
router.register(r'fines', FineViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
