from rest_framework import serializers
from .models import (
    Songs, Product, Users, Overseer, District, Community, 
    CommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch,  StaffMember, AuditLog,
    BranchCommitteeMember, ApplicationRequest,UserUniversityApplication,Community, District, Overseer
,SellerListing,Product, Order,OrderItem,ContributionHistory, MonthlyReport)
class OrderItemSerializer(serializers.ModelSerializer):
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), 
        source='product'
    )

    class Meta:
        model = OrderItem
        # IMPORTANT: 'price' must be listed here to be accepted from Flutter
        fields = ['product_id', 'quantity', 'price', 'color', 'size']
# api/serializers.py
# api/serializers.py
# api/serializers.py

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True)

    user_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(),
        slug_field='uid',  
        source='user',     
        write_only=True
    )

    class Meta:
        model = Order
        fields = [
            'id', 
            'user_uid', 
            'full_name', 'email', 'phone_number', 
            'address', 'city', 'postal_code', 'total_amount', 
            'status', 'is_paid', 'transaction_id', 'created_at', 'items'
        ]
        read_only_fields = ['created_at', 'updated_at', 'status', 'is_paid', 'transaction_id']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        
        # 1. Create the Order
        order = Order.objects.create(**validated_data)

        # 2. Create Order Items
        for item_data in items_data:
            # FIX: Use the price sent from the App (item_data['price'])
            # We cannot use product.price because the Product model doesn't have a price column.
            OrderItem.objects.create(
                order=order,
                **item_data 
            )

        return order
    
class ProductSerializer(serializers.ModelSerializer):
    # Map 'image_url' to 'imageUrl' for Flutter consistency
    imageUrl = serializers.URLField(source='image_url')
    additionalImages = serializers.JSONField(source='additional_images', required=False)
    
    class Meta:
        model = Product
        fields = [
            'id', 'name', 'description', 'category', 'createdAt',
            'image_url', 'additional_images', # New field
            'all_available_colors', 'all_available_sizes'
        ]

    def validate_additionalImages(self, value):
        """
        Enforce the rule: Max 10 images total.
        Since we have 1 main image, we allow max 9 in this list.
        """
        if isinstance(value, list) and len(value) > 9:
            raise serializers.ValidationError("You can only have up to 10 images total (1 Main + 9 Additional).")
        return value

 
class SellerListingSerializer(serializers.ModelSerializer):
    """
    Used for the Seller's Dashboard (My Products).
    Now fully SNAKE_CASE to match standard Django conventions.
    """
    # 1. Read-only fields from Parent Product (Snake Case)
    product_name = serializers.ReadOnlyField(source='product.name')
    description = serializers.ReadOnlyField(source='product.description')
    image_url = serializers.ReadOnlyField(source='product.image_url') # Links to model 'image_url'
    category = serializers.ReadOnlyField(source='product.category')
    
    # 2. Input fields (Snake Case)
    # We rename 'productId' -> 'product_id' to be consistent
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), 
        source='product',  
        
    )

    # 3. Seller Link
    seller_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(),
        slug_field='uid',
        source='seller', 
    )

    class Meta:
        model = SellerListing
        # IMPORTANT: These must match the variable names defined above exactly!
        fields = [
            'id', 
            'product_id',   # Matches var name above
            'seller_uid',   # Matches var name above
            'price', 
            'location', 
            'seller_colors', 
            'seller_sizes',
            'product_name', # Matches var name above
            'description', 
            'image_url',    # Matches var name above
            'category', 
            'created_at'
        ]

class SongSerializer(serializers.ModelSerializer):
    class Meta:
        model = Songs
        fields = "__all__"

class UsersSerializer(serializers.ModelSerializer):
    
    class Meta:
        model = Users
        fields ="__all__"
class UserUniversityApplicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserUniversityApplication
        fields = "__all__" 

class CommunitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Community
        fields = ['community_name', 'latitude', 'longitude', 'full_address','district_elder_name']
        read_only_fields = ['latitude', 'longitude']

class DistrictSerializer(serializers.ModelSerializer):
    communities = CommunitySerializer(many=True)
    overseer_uid = serializers.ReadOnlyField(source='overseer.uid')

    class Meta:
        model = District
        fields = [
            'id', 
            'district_elder_name', 
            'communities', 
            'overseer_uid' # ⭐️ Must be included here
        ]
class OverseerSerializer(serializers.ModelSerializer):
    districts = DistrictSerializer(many=True)

    class Meta:
        model = Overseer
        fields = '__all__'

    def create(self, validated_data): 
        districts_data = validated_data.pop('districts')
         
        overseer = Overseer.objects.create(**validated_data)
 
        for district_data in districts_data:
            communities_data = district_data.pop('communities')
            district = District.objects.create(overseer=overseer, **district_data)
 
            for community_data in communities_data:
                Community.objects.create(district=district, **community_data)

        return overseer

class CommitteeMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommitteeMember
        fields = "__all__"

class OverseerExpenseReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = OverseerExpenseReport
        fields = "__all__"

class UpcomingEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = UpcomingEvent
        fields = "__all__"

class CareerOpportunitySerializer(serializers.ModelSerializer):
    class Meta:
        model = CareerOpportunity
        fields = "__all__"

class TactsoBranchSerializer(serializers.ModelSerializer):
    class Meta:
        model = TactsoBranch
        fields = "__all__"
 

class BranchCommitteeMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = BranchCommitteeMember
        fields = "__all__"

class ApplicationRequestSerializer(serializers.ModelSerializer):
    # We accept the raw ID for writing, but can return details if needed
    branch_id = serializers.PrimaryKeyRelatedField(
        queryset=TactsoBranch.objects.all(), source='branch', write_only=True
    )
    user_uid = serializers.SlugRelatedField(
        queryset=Users.objects.all(), 
        slug_field='uid', 
        source='user', 
        write_only=True
    )

    # Read-only fields for frontend display
    university_name = serializers.ReadOnlyField(source='branch.university_name')
    
    class Meta:
        model = ApplicationRequest
        fields = '__all__'

class StaffMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = StaffMember
        fields = "__all__"

class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = "__all__"
# api/serializers.py


class ContributionHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ContributionHistory
        fields = '__all__'

class MonthlyReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = MonthlyReport
        fields = '__all__'