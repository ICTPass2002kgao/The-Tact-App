import os
import json
import threading
import tempfile
import urllib.request
import cv2 
import numpy as np 
from sklearn.metrics.pairwise import cosine_similarity 
from insightface.app import FaceAnalysis 
from cryptography.fernet import Fernet 

# Django Imports
from django.conf import settings
from django.core.mail import send_mail, get_connection
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from rest_framework import status, viewsets

# Firebase Imports
import firebase_admin
from firebase_admin import credentials, firestore, storage
import json
import requests 
from django.http import HttpResponse, JsonResponse
from rest_framework.views import APIView

# Custom Mixins
from .mixins import CachedListMixin

# Models & Serializers
from .models import (
    Songs, Product, Users, Overseer, District, Community, 
    CommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch, Campus, StaffMember, AuditLog,
    BranchCommitteeMember, ApplicationRequest, UserUniversityApplication
)
from .serializers import (
    SongSerializer, ProductSerializer, UsersSerializer, OverseerSerializer,
    DistrictSerializer, CommunitySerializer, CommitteeMemberSerializer,
    OverseerExpenseReportSerializer, UpcomingEventSerializer,
    CareerOpportunitySerializer, TactsoBranchSerializer, CampusSerializer,
    StaffMemberSerializer, AuditLogSerializer,
    BranchCommitteeMemberSerializer, ApplicationRequestSerializer,
    UserUniversityApplicationSerializer
)

# ==========================================
# 1. INITIALIZATION
# ==========================================

# A. Encryption Key Setup
try:
    if hasattr(settings, 'ENCRYPTION_KEY') and settings.ENCRYPTION_KEY:
        cipher_suite = Fernet(settings.ENCRYPTION_KEY)
    else:
        # CRITICAL WARNING FOR PRODUCTION LOGS
        print("⚠️ CRITICAL SECURITY WARNING: No ENCRYPTION_KEY found. Generating ephemeral key (DATA WILL BE LOST ON RESTART).")
        cipher_suite = Fernet(Fernet.generate_key())
except Exception as e:
    print(f"❌ Encryption Init Failed: {e}")
    cipher_suite = None

# B. InsightFace Model
try:
    # 'buffalo_l' is accurate. Ensure you have enough RAM (approx 2GB free).
    GLOBAL_FACE_APP = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    GLOBAL_FACE_APP.prepare(ctx_id=0)
    print("✅ InsightFace model loaded.")
except Exception as e:
    GLOBAL_FACE_APP = None
    print(f"❌ Error loading InsightFace: {e}")

# C. Firebase
if not firebase_admin._apps:
    firebase_json_str = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if firebase_json_str:
        try:
            cred = credentials.Certificate(json.loads(firebase_json_str))
            bucket_name = getattr(settings, 'FIREBASE_STORAGE_BUCKET', 'tact-3c612.appspot.com')
            firebase_admin.initialize_app(cred, {
                'storageBucket': bucket_name
            })
            print(f"✅ Firebase initialized: {bucket_name}")
        except Exception as e:
            print(f"❌ Firebase Init Error: {e}")
    else:
        print("⚠️ Warning: FIREBASE_SERVICE_ACCOUNT_JSON missing.")

# ==========================================
# 2. SECURITY HELPER FUNCTIONS
# ==========================================

class ServeDecryptedImageView(APIView):
    """
    Proxy that downloads an encrypted image from Firebase, 
    decrypts it, and streams the raw JPEG back to Flutter.
    Usage: /api/serve_image/?url=<firebase_url>
    """
    def get(self, request):
        encrypted_url = request.query_params.get('url')
        if not encrypted_url:
            return HttpResponse("Missing URL", status=400)

        try:
            # A. Download the Encrypted File (Text)
            response = requests.get(encrypted_url)
            if response.status_code != 200:
                return HttpResponse("Failed to fetch image", status=404)
            
            encrypted_content = response.content

            # B. Decrypt It
            # Ensure FERNET_KEY is in your settings.py or define it here
            key = settings.ENCRYPTION_KEY
            f = Fernet(key)
            decrypted_image_data = f.decrypt(encrypted_content)

            # C. Return as Standard Image
            return HttpResponse(decrypted_image_data, content_type="image/jpeg")

        except Exception as e:
            print(f"Decryption Error: {e}")
            return HttpResponse("Error decrypting image", status=500)
        
def encrypt_and_upload_to_firebase(file_obj, folder):
    """
    Encrypts in-memory and uploads to Firebase Storage.
    Returns: Public URL of the .enc file.
    """
    if not cipher_suite:
        return None

    try:
        # 1. Read & Encrypt
        file_data = file_obj.read()
        encrypted_data = cipher_suite.encrypt(file_data)
        
        # 2. Upload
        bucket = storage.bucket()
        filename = f"{folder}/{os.urandom(16).hex()}.enc"
        blob = bucket.blob(filename)
        
        blob.upload_from_string(encrypted_data, content_type='application/octet-stream')
        blob.make_public()
        
        return blob.public_url
    except Exception as e:
        print(f"Encryption Upload Error: {e}")
        return None

def decrypt_from_url_to_temp(url):
    """
    Downloads .enc file, decrypts in memory, writes to secure temp file.
    Returns: Path to temp .jpg file.
    """
    if not cipher_suite:
        return None

    try:
        # 1. Download
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            encrypted_data = response.read()
            
        # 2. Decrypt
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        
        # 3. Write to Temp
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        temp_file.write(decrypted_data)
        temp_file.close()
        
        return temp_file.name
    except Exception as e:
        print(f"Decryption Error: {e}")
        return None

def perform_verification(live_path, ref_path, is_encrypted_ref):
    if GLOBAL_FACE_APP is None:
        return {'matched': False, 'error': 'AI Engine Down'}
    
    real_ref_path = ref_path
    temp_files_to_clean = []

    try:
        # 1. Handle Decryption
        if is_encrypted_ref:
            real_ref_path = decrypt_from_url_to_temp(ref_path)
            if not real_ref_path:
                return {'matched': False, 'error': 'Failed to decrypt reference'}
            temp_files_to_clean.append(real_ref_path)
        
        # 2. Handle Legacy URL (Non-encrypted http link)
        elif ref_path.startswith('http'):
            legacy_temp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
            try:
                urllib.request.urlretrieve(ref_path, legacy_temp)
                real_ref_path = legacy_temp
                temp_files_to_clean.append(legacy_temp)
            except Exception:
                return {'matched': False, 'error': 'Failed to download legacy image'}

        # 3. AI Comparison
        def get_embedding(path):
            img = cv2.imread(path)
            if img is None: return None
            faces = GLOBAL_FACE_APP.get(img)
            if not faces: return None
            # Sort by area (largest face first)
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            return faces[0].embedding

        emb_live = get_embedding(live_path)
        if emb_live is None: 
            return {'matched': False, 'error': 'No face in live image'}

        emb_ref = get_embedding(real_ref_path)
        if emb_ref is None:
            return {'matched': False, 'error': 'No face in reference image'}

        # 4. Calculate Distance
        sim = cosine_similarity(emb_live.reshape(1, -1), emb_ref.reshape(1, -1))[0][0]
        return {'matched': sim > 0.50, 'score': float(sim)} # 0.50 is a safer threshold for mobile cameras

    except Exception as e:
        return {'matched': False, 'error': str(e)}
    finally:
        # 5. Secure Cleanup
        for path in temp_files_to_clean:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass

# ==========================================
# 3. API VIEWS
# ==========================================

@api_view(['POST'])
def recognize_face(request):
    live_file = request.FILES.get('live_image')
    ref_url = request.data.get('reference_url')

    if not live_file or not ref_url:
        return Response({'error': 'Missing data'}, status=400)

    # Save live image temporarily
    temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
    try:
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)
        
        is_encrypted = ref_url.endswith('.enc')
        result = perform_verification(temp_live, ref_url, is_encrypted)
        
        if result.get('error'):
            return Response({'matched': False, 'message': result['error']})
            
        return Response({
            'matched': result['matched'], 
            'distance': result.get('score', 0.0),
            'message': "Match found" if result['matched'] else "No match"
        })
    finally:
        if os.path.exists(temp_live):
            os.remove(temp_live)
def _process_bulk_email(include_terms, include_policy):
    """
    Background task to send email broadcasts to all users.
    Run in a separate thread to avoid blocking the API response.
    """
    print("--- Starting Bulk Email Process ---")
    try:
        # Get DB Connection
        db = firestore.client()
        docs = db.collection('users').stream()
        
        # Open SMTP Connection once for efficiency
        connection = get_connection()
        connection.open()
        
        terms_link = "https://dankie-website.web.app/terms_and_conditions.html"
        policy_link = "https://dankie-website.web.app/privacy_policy.html"
        count = 0

        for doc in docs:
            u = doc.to_dict()
            email = u.get('email')
            if email:
                body = (
                    f"Dear {u.get('name', 'Valued')} {u.get('surname', 'Member')},\n\n"
                    "We have updated our legal documents.\n"
                )
                if include_terms: body += f"Terms: {terms_link}\n"
                if include_policy: body += f"Privacy: {policy_link}\n"
                
                body += "\nKind regards,\nThe Dankie Team"
                
                try:
                    send_mail(
                        "Important Legal Update", 
                        body, 
                        settings.EMAIL_HOST_USER, 
                        [email], 
                        connection=connection, 
                        fail_silently=True
                    )
                    count += 1
                except Exception:
                    pass
        
        connection.close()
        print(f"--- Finished. Sent {count} emails. ---")
    except Exception as e:
        print(f"Error in email process: {e}")
@api_view(['POST'])
def send_legal_broadcast(request):
    inc_terms = request.data.get('includeTerms', False)
    inc_policy = request.data.get('includePolicy', False)
    if not inc_terms and not inc_policy:
        return Response({'error': 'Select document type.'}, status=400)
    threading.Thread(target=_process_bulk_email, args=(inc_terms, inc_policy)).start()
    return Response({'message': 'Broadcast started.'})


# ==========================================
# 4. MODEL VIEWSETS
# ==========================================
class OverseerViewSet(CachedListMixin, viewsets.ModelViewSet):
    """
    Handles Overseer creation with ENCRYPTED biometric storage.
    """
    queryset = Overseer.objects.all()
    serializer_class = OverseerSerializer

    def get_queryset(self):
        queryset = Overseer.objects.all()
        email = self.request.query_params.get('email')
        if email: 
            queryset = queryset.filter(email=email)
            
        return queryset

    def create(self, request, *args, **kwargs):
        data = request.data.dict()
        
        # 1. Parse Nested JSON (Districts)
        if 'districts' in data:
            try:
                if isinstance(data['districts'], str):
                    data['districts'] = json.loads(data['districts'])
            except json.JSONDecodeError:
                return Response({"error": "Invalid districts JSON format"}, status=400)

        # 2. Encrypt & Upload Secretary Face
        sec_file = request.FILES.get('secretary_face_image')
        if sec_file:
            url = encrypt_and_upload_to_firebase(sec_file, 'secure_faces')
            if url:
                data['secretary_face_url'] = url
        
        # 3. Encrypt & Upload Chairperson Face
        chair_file = request.FILES.get('chairperson_face_image')
        if chair_file:
            url = encrypt_and_upload_to_firebase(chair_file, 'secure_faces')
            if url:
                data['chairperson_face_url'] = url

        # 4. Standard Create (Save Overseer)
        serializer = self.get_serializer(data=data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        self.perform_create(serializer)
        
        # ============================================================
        # ⭐️ FIX: AUTO-CREATE COMMITTEE MEMBERS
        # This ensures they exist in the 'CommitteeMember' table for Login
        # ============================================================
        overseer_instance = serializer.instance

        # Add Secretary to Committee Table
        if 'secretary_name' in data and 'secretary_face_url' in data:
            CommitteeMember.objects.create(
                overseer=overseer_instance,
                name=data['secretary_name'],
                role='Overseer',
                portfolio='Secretary',
                face_url=data['secretary_face_url']
            )

        # Add Chairperson to Committee Table
        if 'chairperson_name' in data and 'chairperson_face_url' in data:
            CommitteeMember.objects.create(
                overseer=overseer_instance,
                name=data['chairperson_name'],
                role='Overseer',
                portfolio='Chairperson',
                face_url=data['chairperson_face_url']
            )
        # ============================================================

        return Response(serializer.data, status=status.HTTP_201_CREATED)
class StaffMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = StaffMember.objects.all() 
    serializer_class = StaffMemberSerializer
    
    def get_queryset(self):
        queryset = StaffMember.objects.all()
        face_url = self.request.query_params.get('face_url')
        if face_url: queryset = queryset.filter(face_url=face_url)
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email=email)
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        return queryset

    @action(detail=False, methods=['get'])
    def find_by_face(self, request):
        url = request.query_params.get('url')
        if not url: return Response({"error": "Missing url"}, status=400)
        staff = StaffMember.objects.filter(face_url=url).first()
        if not staff: return Response({"error": "Not found"}, status=404)
        return Response(self.get_serializer(staff).data)

# --- Standard ViewSets ---

class UsersViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Users.objects.all()
    serializer_class = UsersSerializer
    def get_queryset(self):
        queryset = Users.objects.all()
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        return queryset

class TactsoBranchViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = TactsoBranch.objects.all()
    serializer_class = TactsoBranchSerializer
    def get_queryset(self):
        queryset = TactsoBranch.objects.all()
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        return queryset

class CommunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Community.objects.all()
    serializer_class = CommunitySerializer
    def get_queryset(self):
        queryset = Community.objects.all()
        province = self.request.query_params.get('province')
        if province:
            queryset = queryset.filter(district__overseer__province__iexact=province)
        return queryset

class DistrictViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = District.objects.all()
    serializer_class = DistrictSerializer

class SongViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Songs.objects.all()
    serializer_class = SongSerializer

class ProductViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer

class CommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = CommitteeMember.objects.all()
    serializer_class = CommitteeMemberSerializer

class OverseerExpenseReportViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = OverseerExpenseReport.objects.all()
    serializer_class = OverseerExpenseReportSerializer

class UpcomingEventViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = UpcomingEvent.objects.all()
    serializer_class = UpcomingEventSerializer

class CareerOpportunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = CareerOpportunity.objects.all()
    serializer_class = CareerOpportunitySerializer

class CampusViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Campus.objects.all()
    serializer_class = CampusSerializer

class BranchCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = BranchCommitteeMember.objects.all()
    serializer_class = BranchCommitteeMemberSerializer

class ApplicationRequestViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = ApplicationRequest.objects.all()
    serializer_class = ApplicationRequestSerializer

class UserUniversityApplicationViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = UserUniversityApplication.objects.all()
    serializer_class = UserUniversityApplicationSerializer

class AuditLogViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer