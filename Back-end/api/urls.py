from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    SongViewSet, ProductViewSet, UsersViewSet, OverseerViewSet,
    DistrictViewSet, CommunityViewSet, CommitteeMemberViewSet,
    OverseerExpenseReportViewSet, UpcomingEventViewSet,
    CareerOpportunityViewSet, TactsoBranchViewSet, CampusViewSet,
    StaffMemberViewSet, AuditLogViewSet, BranchCommitteeMemberViewSet,
    ApplicationRequestViewSet, UserUniversityApplicationViewSet,
    recognize_face, send_legal_broadcast,ServeDecryptedImageView
)

# Initialize Router
router = DefaultRouter()

# === CRITICAL ROUTES FOR AUTH & LOGIN ===
# These names MUST match the strings used in your Flutter Login_Page
router.register(r'staff', StaffMemberViewSet)
router.register(r'overseers', OverseerViewSet)
router.register(r'tactso_branches', TactsoBranchViewSet) # Flutter calls this 'tactso-branches' usually, check your code
# Note: In your Flutter code you used 'tactso_branches' in one place and 'tactso-branches' in another.
# I have standardized on 'tactso_branches' (underscore) to match Python variable naming.
# Make sure your Flutter code uses: _fetchProfileFromDjango('tactso_branches', uid)

router.register(r'users', UsersViewSet)

# === CRITICAL ROUTES FOR MAPS ===
router.register(r'communities', CommunityViewSet) # For the Map

# === OTHER ROUTES ===
router.register(r'songs', SongViewSet)
router.register(r'products', ProductViewSet)
router.register(r'districts', DistrictViewSet)
router.register(r'committee_members', CommitteeMemberViewSet)
router.register(r'overseer_expenses', OverseerExpenseReportViewSet)
router.register(r'events', UpcomingEventViewSet)
router.register(r'careers', CareerOpportunityViewSet)
router.register(r'campuses', CampusViewSet)
router.register(r'branch_committee', BranchCommitteeMemberViewSet)
router.register(r'applications', ApplicationRequestViewSet)
router.register(r'university_applications', UserUniversityApplicationViewSet)
router.register(r'audit_logs', AuditLogViewSet)

urlpatterns = [
    # Router URLs (The ViewSets)
    path('', include(router.urls)),
    
    # Function Views (The Custom Logic)
    path('verify_faces/', recognize_face, name='verify_faces'), # Matches Flutter _verificationApiEndpoint
    path('send-email/', send_legal_broadcast, name='send_email'),
    path('serve_image/', ServeDecryptedImageView.as_view(), name='serve_image'),
]