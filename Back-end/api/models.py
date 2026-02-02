import uuid
from django.db import models
from django.utils import timezone
from geopy.geocoders import Nominatim # <--- Import this
# ===========================
# 1. CORE CONTENT MODELS
# ===========================

class Songs(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    artist = models.TextField(max_length=255, verbose_name="Artist", blank=False)
    category = models.TextField(max_length=255, verbose_name="Category", blank=False)
    released = models.TextField(null=True, blank=True, verbose_name="Released Date")
    songUrl = models.URLField(verbose_name="Song url", blank=False)
    songName = models.TextField(max_length=255, verbose_name="Song Name", blank=False)
    
    def __str__(self):
        return self.songName

class Product(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.TextField(max_length=255, verbose_name="Product Name", null=True, blank=True)
    description = models.TextField(max_length=1000, verbose_name="Product Description", blank=False)
    category = models.TextField(max_length=255, verbose_name="Category", blank=False)
    createdAt = models.DateTimeField(default=timezone.now, verbose_name="Created At")
    imageUrl = models.URLField(verbose_name="Image url", blank=False) 
    
    def __str__(self):
        return self.name if self.name else "Unnamed Product"

# ===========================
# 2. USER & OVERSEER MODELS
# ===========================

class Users(models.Model):
    uid = models.TextField(max_length=50, primary_key=True, blank=False)
    address = models.TextField(max_length=50, blank=True, null=True)
    role = models.TextField(max_length=50, blank=True, null=True)
    communityName = models.TextField(max_length=50, blank=True, null=True)
    districtElderName = models.TextField(max_length=50, blank=True, null=True)
    email = models.TextField(max_length=50, blank=True, null=True)
    overseerUid = models.TextField(max_length=50, blank=True, null=True)
    phone = models.TextField(max_length=50, blank=True, null=True)
    province = models.TextField(max_length=50, blank=True, null=True)
    profileUrl = models.TextField(max_length=255, blank=True, null=True)  
    surname = models.TextField(max_length=50, blank=True, null=True)     
    week1 = models.TextField(max_length=50, blank=True, null=True)  
    week2 = models.TextField(max_length=50, blank=True, null=True)  
    week3 = models.TextField(max_length=50, blank=True, null=True)  
    week4 = models.TextField(max_length=50, blank=True, null=True) 
    
    
    def __str__(self):
        return f"{self.email} ({self.role})"

# ... (Keep all existing models) ...

class UserUniversityApplication(models.Model):
    """
    Sub-collection for Users: 'university_applications'
    Represents the user's personal record of an application.
    """
    user = models.ForeignKey(Users, related_name="university_applications", on_delete=models.CASCADE)
    application_uid = models.CharField(max_length=255, verbose_name="Application UID")
    university_name = models.CharField(max_length=255, verbose_name="University Name")
    campus_name = models.CharField(max_length=255, blank=True, verbose_name="Campus Name")
    
    status = models.CharField(max_length=100, verbose_name="Status")
    submission_date = models.TextField(blank=True, verbose_name="Submission Date")
    
    primary_program = models.CharField(max_length=255, blank=True, verbose_name="Primary Program")
    second_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Second Choice Program")
    third_choice_program = models.CharField(max_length=255, blank=True, verbose_name="Third Choice Program")
    
    applying_for_funding = models.BooleanField(default=False, verbose_name="Funding")
    applying_for_residence = models.BooleanField(default=False, verbose_name="Residence")
    
    # Personal Details Snapshot
    full_name = models.CharField(max_length=255, blank=True, verbose_name="Full Name")
    email = models.EmailField(blank=True, verbose_name="Email")
    phone = models.CharField(max_length=50, blank=True, verbose_name="Phone")
    highest_qualification = models.CharField(max_length=255, blank=True, verbose_name="Highest Qualification")
    previous_school = models.CharField(max_length=255, blank=True, verbose_name="Previous School")

    def __str__(self):
        return f"{self.university_name} - {self.status}"
 

class Overseer(models.Model):
    # uid = models.TextField(primary_key=True,null=False,blank=False)
    overseer_initials_surname = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    province = models.CharField(max_length=100)
    region = models.CharField(max_length=100)
    code = models.CharField(max_length=50)
    
    # Biometric/Committee Info
    secretary_name = models.CharField(max_length=255, blank=True)
    chairperson_name = models.CharField(max_length=255, blank=True)
    secretary_face_url = models.TextField(blank=True, null=True)
    chairperson_face_url = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.overseer_initials_surname

class District(models.Model):
    overseer = models.ForeignKey(Overseer, related_name='districts', on_delete=models.CASCADE)
    district_elder_name = models.CharField(max_length=255)

    def __str__(self):
        return f"{self.district_elder_name} ({self.overseer})"

class Community(models.Model):
    district = models.ForeignKey(District, related_name='communities', on_delete=models.CASCADE)
    district_elder_name =models.TextField(max_length=255,blank=True,null=True)
    community_name = models.CharField(max_length=255)
    
    # Auto-Generated Fields
    full_address = models.TextField(blank=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)

    def save(self, *args, **kwargs):
        # 1. Construct the Address automatically
        # Logic: Community Name + Overseer Region + Overseer Province
        overseer = self.district.overseer
        address_string = f"{self.community_name}, {overseer.region}, {overseer.province}, South Africa"
        self.full_address = address_string

        # 2. Geocode (Get Lat/Lon) ONLY if they are missing
        if not self.latitude or not self.longitude:
            try:
                print(f"📍 Geocoding: {address_string}")
                geolocator = Nominatim(user_agent="tact_backend_v1")
                location = geolocator.geocode(address_string, timeout=10)
                
                if location:
                    self.latitude = location.latitude
                    self.longitude = location.longitude
                    print(f"✅ Found: {self.latitude}, {self.longitude}")
                else:
                    print("⚠️ Address not found by Google/OSM")
            except Exception as e:
                print(f"❌ Geocoding Error: {e}")

        super(Community, self).save(*args, **kwargs)

    def __str__(self):
        return self.community_name


class CommitteeMember(models.Model):
    overseer = models.ForeignKey(Overseer, related_name="committee_members", on_delete=models.CASCADE)
    name = models.CharField(max_length=255, verbose_name="Name")
    email = models.EmailField(blank=True, verbose_name="Email")
    role = models.CharField(max_length=100, verbose_name="Role")
    portfolio = models.CharField(max_length=255, verbose_name="Portfolio")
    face_url = models.URLField(blank=True, verbose_name="Face URL")
    added_at = models.TextField(blank=True, verbose_name="Added At")

    def __str__(self):
        return f"{self.name} - {self.portfolio}"

# ===========================
# 3. FINANCIAL & EVENTS
# ===========================

class OverseerExpenseReport(models.Model):
    archived_at = models.TextField(verbose_name="Archived At", blank=True, null=True)
    overseer_uid = models.CharField(max_length=255, verbose_name="Overseer UID")
    district_elder_name = models.CharField(max_length=255, verbose_name="District Elder Name")
    community_name = models.CharField(max_length=255, verbose_name="Community Name")
    province = models.CharField(max_length=100, verbose_name="Province")
     
    expense_central = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Central")
    expense_other = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Other")
    expense_rent = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Rent")
    expense_mine = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Expense Mine")
     
    total_banked = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Banked")
    total_expenses = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Expenses")
    total_income = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, verbose_name="Total Income")
     
    month = models.IntegerField(verbose_name="Month")
    year = models.IntegerField(verbose_name="Year")

    def __str__(self):
        return f"Report: {self.community_name} ({self.month}/{self.year})"

class UpcomingEvent(models.Model):
    title = models.CharField(max_length=255, verbose_name="Title")
    poster_url = models.URLField(blank=True, verbose_name="Poster URL")
    day = models.CharField(max_length=10, verbose_name="Day") 
    month = models.CharField(max_length=20, verbose_name="Month")
    parsed_date = models.TextField(blank=True, verbose_name="Parsed Date", null=True) 
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return self.title

# ===========================
# 4. CAREERS & EDUCATION
# ===========================

class CareerOpportunity(models.Model):
    title = models.CharField(max_length=255, verbose_name="Title")
    description = models.TextField(verbose_name="Description")
    category = models.CharField(max_length=255, verbose_name="Category")
    application_email = models.EmailField(max_length=255, verbose_name="Application Email")
    contact_number = models.CharField(max_length=50, blank=True, verbose_name="Contact Number")
    is_active = models.BooleanField(default=True, verbose_name="Is Active")
    expiry_date = models.TextField(blank=True, verbose_name="Expiry Date", null=True)
    created_at = models.TextField(blank=True, verbose_name="Created At")
    updated_at = models.TextField(blank=True, null=True, verbose_name="Updated At")
    image_url = models.URLField(blank=True, verbose_name="Image URL")
    link = models.URLField(blank=True, verbose_name="External Link")

    details_address = models.TextField(blank=True, verbose_name="Details Address")
    course_duration = models.CharField(max_length=255, blank=True, verbose_name="Course Duration")
    duties_financial = models.TextField(blank=True, verbose_name="Duties Financial")
    duties_location = models.CharField(max_length=255, blank=True, verbose_name="Duties Location")
    requirements_subtitle = models.TextField(blank=True, verbose_name="Requirements Subtitle")

    benefits = models.TextField(blank=True, default="[]", verbose_name="Benefits (JSON)")
    required_documents = models.TextField(blank=True, default="[]", verbose_name="Required Documents (JSON)")

    def __str__(self):
        return self.title

class TactsoBranch(models.Model):
    uid = models.CharField(max_length=255, unique=True, verbose_name="UID")
    university_name = models.CharField(max_length=255, verbose_name="University Name")
    email = models.EmailField(blank=True, verbose_name="Email")
    address = models.TextField(blank=True, verbose_name="Address")
    application_link = models.URLField(blank=True, verbose_name="Application Link")
    
    # Updated: To handle multiple images (JSON) and officer info
    image_urls = models.TextField(blank=True, default="[]", verbose_name="Image URLs (JSON)")
    education_officer_name = models.CharField(max_length=255, blank=True, verbose_name="Education Officer Name")
    education_officer_face_url = models.URLField(blank=True, verbose_name="Education Officer Face URL")
    authorized_user_face_urls = models.TextField(blank=True, default="[]", verbose_name="Authorized Face URLs (JSON)")

    has_multiple_campuses = models.BooleanField(default=False, verbose_name="Has Multiple Campuses")
    is_application_open = models.BooleanField(default=False, verbose_name="Is Application Open")
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return self.university_name

class Campus(models.Model):
    branch = models.ForeignKey(TactsoBranch, related_name="campuses", on_delete=models.CASCADE)
    campus_name = models.CharField(max_length=255, verbose_name="Campus Name")

    def __str__(self):
        return f"{self.campus_name} ({self.branch.university_name})"

class BranchCommitteeMember(models.Model):
    """
    Sub-collection for TactsoBranch
    """
    branch = models.ForeignKey(TactsoBranch, related_name="committee_members", on_delete=models.CASCADE)
    name = models.CharField(max_length=255, verbose_name="Name")
    email = models.EmailField(blank=True, verbose_name="Email")
    role = models.CharField(max_length=100, verbose_name="Role")
    face_url = models.URLField(blank=True, verbose_name="Face URL")
    added_at = models.TextField(blank=True, verbose_name="Added At")

    def __str__(self):
        return f"{self.name} ({self.branch.university_name})"

class ApplicationRequest(models.Model):
    """
    Sub-collection for TactsoBranch
    """
    branch = models.ForeignKey(TactsoBranch, related_name="applications", on_delete=models.CASCADE)
    uid = models.CharField(max_length=255, verbose_name="Application UID")
    user_id = models.CharField(max_length=255, verbose_name="User ID")
    full_name = models.CharField(max_length=255, verbose_name="Full Name")
    email = models.EmailField(blank=True, verbose_name="Email")
    phone = models.CharField(max_length=50, blank=True, verbose_name="Phone")
    status = models.CharField(max_length=100, verbose_name="Status")
    submission_date = models.TextField(blank=True, verbose_name="Submission Date")
    
    # Application Details
    applying_for_funding = models.BooleanField(default=False, verbose_name="Funding")
    applying_for_residence = models.BooleanField(default=False, verbose_name="Residence")
    highest_qualification = models.CharField(max_length=255, blank=True, verbose_name="Qualification")
    campus = models.CharField(max_length=255, blank=True, verbose_name="Campus",null=True)
    primary_program = models.CharField(max_length=255, blank=True, verbose_name="Primary Program")

    # Document URLs (Flattened from 'documents' map)
    id_passport_url = models.URLField(blank=True, verbose_name="ID/Passport URL")
    school_results_url = models.URLField(blank=True, verbose_name="School Results URL")
    proof_of_registration_url = models.URLField(blank=True, verbose_name="Proof of Reg URL")
    other_qualifications_url = models.URLField(blank=True, verbose_name="Other Docs URL")

    def __str__(self):
        return f"{self.full_name} - {self.status}"

# ===========================
# 5. STAFF & LOGS
# ===========================

class StaffMember(models.Model):
    uid = models.CharField(max_length=255, unique=True, verbose_name="UID")
    full_name = models.CharField(max_length=255, verbose_name="Full Name")
    name = models.CharField(max_length=255, verbose_name="First Name")
    surname = models.CharField(max_length=255, verbose_name="Surname")
    email = models.EmailField(verbose_name="Email")
    role = models.CharField(max_length=100, verbose_name="Role")
    portfolio = models.CharField(max_length=255, blank=True, verbose_name="Portfolio")
    province = models.CharField(max_length=100, blank=True, verbose_name="Province")
    face_url = models.URLField(blank=True, verbose_name="Face URL")
    is_active = models.BooleanField(default=True, verbose_name="Is Active")
    created_at = models.TextField(blank=True, verbose_name="Created At")

    def __str__(self):
        return f"{self.full_name} ({self.role})"

class AuditLog(models.Model):
    action = models.CharField(max_length=255, verbose_name="Action")
    details = models.TextField(verbose_name="Details") 
     
    actor_name = models.CharField(max_length=255, verbose_name="Actor Name")
    actor_role = models.CharField(max_length=100, verbose_name="Actor Role")
    actor_face_url = models.URLField(blank=True, verbose_name="Actor Face URL")
    uid = models.CharField(max_length=255, verbose_name="User UID")
    
    university_name = models.CharField(max_length=255, blank=True, verbose_name="University Name")
    university_logo = models.URLField(blank=True, verbose_name="University Logo")
    branch_email = models.EmailField(blank=True, verbose_name="Branch Email")
    
    target_member_name = models.CharField(max_length=255, blank=True, verbose_name="Target Member Name")
    target_member_role = models.CharField(max_length=100, blank=True, verbose_name="Target Member Role")
    student_name = models.CharField(max_length=255, blank=True, default="N/A", verbose_name="Student Name")
    
    timestamp = models.TextField(verbose_name="Timestamp")
    device_time = models.CharField(max_length=255, blank=True, verbose_name="Device Time")

    def __str__(self):
        return f"{self.action} - {self.actor_name}"