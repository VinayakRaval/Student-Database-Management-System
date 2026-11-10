from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser, PasswordResetOTP, PasswordAuditLog


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


@admin.register(PasswordAuditLog)
class PasswordAuditLogAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'timestamp', 'action', 'actor_email', 'actor_role',
        'target_user_id_str', 'target_role', 'status'
    )
    list_filter = ('action', 'status', 'actor_role', 'target_role')
    search_fields = ('actor_email', 'target_user_id_str', 'reason', 'ip_address')
    readonly_fields = (
        'timestamp', 'action', 'actor', 'actor_email', 'actor_role',
        'target_user', 'target_user_id_str', 'target_role', 'ip_address',
        'status', 'reason'
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
