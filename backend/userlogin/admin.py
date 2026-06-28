from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser, PasswordResetOTP


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    model = CustomUser
    ordering = ('email',)
    
    list_display = (
        'id', 'email', 'phone', 'user_id',
        'role', 'department', 'force_password_change', 'is_staff', 'is_active'
    )
    list_filter = ('role', 'department', 'is_staff', 'is_active')
    search_fields = ('email', 'phone', 'user_id')
    
    fieldsets = (
        ('Login Info', {
            'fields': ('email', 'phone', 'user_id', 'password', 'force_password_change')
        }),
    
        ('Permissions', {
            'fields': ('role', 'is_staff', 'is_active', 'is_superuser', 'user_permissions')
        }),
        ('Important Dates', {
            'fields': ('last_login',)
        }),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'password1', 'password2', 'role', 'is_staff', 'is_active')
        }),
    )

@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'otp', 'created_at')
    search_fields = ('user__email', 'user__user_id', 'user__phone')
    readonly_fields = ('created_at',)
