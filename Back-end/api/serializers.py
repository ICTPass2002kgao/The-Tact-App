from rest_framework import serializers
from .models import (
    Songs, Product, Users, Overseer, District, Community, 
    CommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch, Campus, StaffMember, AuditLog,
    BranchCommitteeMember, ApplicationRequest,UserUniversityApplication,Community, District, Overseer
)

class SongSerializer(serializers.ModelSerializer):
    class Meta:
        model = Songs
        fields = "__all__"

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = "__all__"

class UsersSerializer(serializers.ModelSerializer):
    class Meta:
        model = Users
        fields = "__all__"
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

    class Meta:
        model = District
        fields = ['district_elder_name', 'communities']

class OverseerSerializer(serializers.ModelSerializer):
    districts = DistrictSerializer(many=True)

    class Meta:
        model = Overseer
        fields = '__all__'

    def create(self, validated_data):
        # Extract nested data
        districts_data = validated_data.pop('districts')
        
        # 1. Create Overseer
        overseer = Overseer.objects.create(**validated_data)

        # 2. Create Districts
        for district_data in districts_data:
            communities_data = district_data.pop('communities')
            district = District.objects.create(overseer=overseer, **district_data)

            # 3. Create Communities (This triggers the .save() geocoding logic in models.py)
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

class CampusSerializer(serializers.ModelSerializer):
    class Meta:
        model = Campus
        fields = "__all__"

class BranchCommitteeMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = BranchCommitteeMember
        fields = "__all__"

class ApplicationRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = ApplicationRequest
        fields = "__all__"

class StaffMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = StaffMember
        fields = "__all__"

class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = "__all__"
        