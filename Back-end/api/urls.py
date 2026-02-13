from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    SongViewSet, UsersViewSet, OverseerViewSet,
    DistrictViewSet, CommunityViewSet, CommitteeMemberViewSet,
    OverseerExpenseReportViewSet, UpcomingEventViewSet,
    CareerOpportunityViewSet, TactsoBranchViewSet,  
    StaffMemberViewSet, AuditLogViewSet, BranchCommitteeMemberViewSet,
    ApplicationRequestViewSet, UserUniversityApplicationViewSet,
    recognize_face, send_legal_broadcast,ServeDecryptedImageView,
    CatalogViewSet, 
    SellerInventoryViewSet, 
    OrderViewSet
)
from . import views
 
# Initialize Router
router = DefaultRouter()  

# 2. Global Product Catalog (Read-Only for searching items to sell)
router.register(r'products', CatalogViewSet, basename='products')

# 3. Seller Inventory (Manage "My Products")
router.register(r'seller-inventory', SellerInventoryViewSet, basename='seller-inventory')

# 4. Orders (Handling sales and purchases)
router.register(r'orders', OrderViewSet, basename='orders')
router.register(r'staff', StaffMemberViewSet)
router.register(r'overseers', OverseerViewSet)
router.register(r'tactso_branches', TactsoBranchViewSet) 
router.register(r'users', UsersViewSet) 
router.register(r'communities', CommunityViewSet) 
router.register(r'songs', SongViewSet) 
router.register(r'districts', DistrictViewSet)
router.register(r'committee_members', CommitteeMemberViewSet)
router.register(r'overseer_expenses_reports', OverseerExpenseReportViewSet,basename='overseer-expenses')
router.register(r'events', UpcomingEventViewSet)
router.register(r'careers', CareerOpportunityViewSet) 
router.register(r'branch_committee', BranchCommitteeMemberViewSet)
router.register(r'applications', ApplicationRequestViewSet)
router.register(r'university_applications', UserUniversityApplicationViewSet)
router.register(r'audit_logs', AuditLogViewSet)

# api/urls.py
router.register(r'contribution_history', views.ContributionHistoryViewSet)
router.register(r'monthly_reports', views.MonthlyReportViewSet)
urlpatterns = [ 
    path('', include(router.urls)), 
    path('verify_faces/', recognize_face, name='verify_faces'),  
    path('send-email/', send_legal_broadcast, name='send_email'),
    path('serve_image/', ServeDecryptedImageView.as_view(), name='serve_image'), 
    path('initialize-subscription/', views.initialize_subscription), 
    
    # Marketplace
    path('create_seller_subaccount/', views.create_seller_subaccount),
    path('create-payment-link/', views.create_payment_link),
    path('paystack-webhook/', views.paystack_webhook),
    
    # Utilities
    path('send_custom_email/', views.send_custom_email), 
]

