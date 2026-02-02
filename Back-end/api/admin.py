from django.contrib import admin
from .models import (
    Songs, Product, Users, UserUniversityApplication,
    Overseer, District, Community, CommitteeMember,
    OverseerExpenseReport, UpcomingEvent,
    CareerOpportunity, TactsoBranch, Campus, BranchCommitteeMember, ApplicationRequest,
    StaffMember, AuditLog
)

# ===========================
# 1. CORE CONTENT
# ===========================

@admin.register(Songs)
class SongsAdmin(admin.ModelAdmin):
    list_display = ('songName', 'artist', 'category', 'released')
    search_fields = ('songName', 'artist')

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'createdAt')
    search_fields = ('name', 'description')

# ===========================
# 2. USER & OVERSEER
# ===========================

@admin.register(Users)
class UsersAdmin(admin.ModelAdmin):
    list_display = ('email', 'role', 'province', 'uid')
    search_fields = ('email', 'uid', 'surname')
    list_filter = ('role', 'province')

@admin.register(UserUniversityApplication)
class UserUniversityApplicationAdmin(admin.ModelAdmin):
    list_display = ('user', 'university_name', 'status', 'primary_program')
    search_fields = ('university_name', 'status', 'user__email')

class DistrictInline(admin.TabularInline):
    model = District
    extra = 0

@admin.register(Overseer)
class OverseerAdmin(admin.ModelAdmin):
    list_display = ('overseer_initials_surname', 'code', 'province', 'region')
    search_fields = ('overseer_initials_surname', 'email', 'code')
    inlines = [DistrictInline]

class CommunityInline(admin.TabularInline):
    model = Community
    extra = 0

@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ('district_elder_name', 'overseer')
    search_fields = ('district_elder_name', 'overseer__overseer_initials_surname')
    inlines = [CommunityInline]

@admin.register(Community)
class CommunityAdmin(admin.ModelAdmin):
    list_display = ('community_name', 'district', 'full_address', 'latitude', 'longitude')
    search_fields = ('community_name', 'full_address')

@admin.register(CommitteeMember)
class CommitteeMemberAdmin(admin.ModelAdmin):
    list_display = ('name', 'role', 'portfolio', 'overseer')
    search_fields = ('name', 'role')

# ===========================
# 3. FINANCIAL & EVENTS
# ===========================

@admin.register(OverseerExpenseReport)
class OverseerExpenseReportAdmin(admin.ModelAdmin):
    list_display = ('community_name', 'month', 'year', 'total_banked', 'total_expenses')
    list_filter = ('month', 'year', 'province')
    search_fields = ('community_name', 'overseer_uid')

@admin.register(UpcomingEvent)
class UpcomingEventAdmin(admin.ModelAdmin):
    list_display = ('title', 'day', 'month', 'created_at')
    search_fields = ('title',)

# ===========================
# 4. CAREERS & EDUCATION
# ===========================

@admin.register(CareerOpportunity)
class CareerOpportunityAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'expiry_date', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('title', 'description')

class CampusInline(admin.TabularInline):
    model = Campus
    extra = 0

@admin.register(TactsoBranch)
class TactsoBranchAdmin(admin.ModelAdmin):
    list_display = ('university_name', 'email', 'is_application_open')
    search_fields = ('university_name', 'email')
    inlines = [CampusInline]

@admin.register(Campus)
class CampusAdmin(admin.ModelAdmin):
    list_display = ('campus_name', 'branch')
    search_fields = ('campus_name', 'branch__university_name')

@admin.register(BranchCommitteeMember)
class BranchCommitteeMemberAdmin(admin.ModelAdmin):
    list_display = ('name', 'role', 'branch')
    search_fields = ('name', 'branch__university_name')

@admin.register(ApplicationRequest)
class ApplicationRequestAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'branch', 'status', 'primary_program')
    list_filter = ('status',)
    search_fields = ('full_name', 'email', 'branch__university_name')

# ===========================
# 5. STAFF & LOGS
# ===========================

@admin.register(StaffMember)
class StaffMemberAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'role', 'email', 'is_active')
    list_filter = ('role', 'is_active')
    search_fields = ('full_name', 'email')

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('action', 'actor_name', 'timestamp', 'university_name')
    list_filter = ('action', 'actor_role')
    search_fields = ('actor_name', 'details', 'uid')