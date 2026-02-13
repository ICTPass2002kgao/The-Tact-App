import datetime
import os
import json
import threading
import tempfile
import urllib.request
import hmac
import hashlib
import subprocess
import shutil
import requests
import cv2
import numpy as np
from decimal import Decimal
from email.message import EmailMessage

# Cryptography & AI
from cryptography.fernet import Fernet
from sklearn.metrics.pairwise import cosine_similarity
from insightface.app import FaceAnalysis

# Django Imports
from django.conf import settings
from django.core.mail import send_mail, get_connection
from django.http import HttpResponse, FileResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from rest_framework import viewsets, filters, status
from rest_framework.views import APIView

# Firebase Imports
import firebase_admin
from firebase_admin import credentials, firestore, storage

from django.core.mail import EmailMultiAlternatives
from django.conf import settings
import requests


# Custom Mixins
from .mixins import CachedListMixin
from django.db import transaction 
# Models & Serializers
from .models import (
    Order, Songs, Product, Users, Overseer, District, Community, 
    CommitteeMember, OverseerExpenseReport, UpcomingEvent, 
    CareerOpportunity, TactsoBranch, StaffMember, AuditLog,
    BranchCommitteeMember, ApplicationRequest, UserUniversityApplication, 
    SellerListing,ContributionHistory, MonthlyReport
)
from .serializers import (
    OrderSerializer, SongSerializer, ProductSerializer, UsersSerializer, 
    OverseerSerializer, DistrictSerializer, CommunitySerializer, 
    CommitteeMemberSerializer, OverseerExpenseReportSerializer, 
    UpcomingEventSerializer, CareerOpportunitySerializer, 
    TactsoBranchSerializer, StaffMemberSerializer, AuditLogSerializer,
    BranchCommitteeMemberSerializer, ApplicationRequestSerializer,
    UserUniversityApplicationSerializer, SellerListingSerializer,ContributionHistorySerializer,MonthlyReportSerializer
)

# ==========================================
# 1. INITIALIZATION & SETUP
# ==========================================

# A. Encryption Key Setup
try:
    if hasattr(settings, 'ENCRYPTION_KEY') and settings.ENCRYPTION_KEY:
        cipher_suite = Fernet(settings.ENCRYPTION_KEY)
    else:
        print("⚠️ CRITICAL SECURITY WARNING: No ENCRYPTION_KEY found. Generating ephemeral key.")
        cipher_suite = Fernet(Fernet.generate_key())
except Exception as e:
    print(f"❌ Encryption Init Failed: {e}")
    cipher_suite = None

# B. InsightFace Model
try:
    GLOBAL_FACE_APP = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    GLOBAL_FACE_APP.prepare(ctx_id=0)
    print("✅ InsightFace model loaded.")
except Exception as e:
    GLOBAL_FACE_APP = None
    print(f"❌ Error loading InsightFace: {e}")
if not firebase_admin._apps:
    # Get the raw string (the curly brackets you pasted in Railway)
    firebase_config = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')

    if firebase_config:
        try:
            # 2. Check if it's a file path or raw JSON
            if os.path.exists(str(firebase_config)):
                 # It's a file path (Local Dev)
                cred = credentials.Certificate(firebase_config)
            else:
                # It's raw JSON string (Railway / Production)
                # Parse the string into a Python dictionary
                cred_dict = json.loads(firebase_config)
                cred = credentials.Certificate(cred_dict)

            bucket_name = getattr(settings, 'FIREBASE_STORAGE_BUCKET', 'tact-3c612.appspot.com')
            
            firebase_admin.initialize_app(cred, {
                'storageBucket': bucket_name
            })
            print(f"✅ Firebase initialized: {bucket_name}")
            
        except Exception as e:
            print(f"❌ Firebase Init Error: {e}")
    else:
        print("⚠️ Warning: FIREBASE_SERVICE_ACCOUNT_JSON missing in .env")
# ==========================================
# 2. HELPER FUNCTIONS (Security, AI, Email)
# ==========================================

def encrypt_and_upload_to_firebase(file_obj, folder):
    """Encrypts in-memory and uploads to Firebase Storage."""
    if not cipher_suite: return None
    try:
        file_data = file_obj.read()
        encrypted_data = cipher_suite.encrypt(file_data)
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
    """Downloads .enc file, decrypts, writes to temp file."""
    if not cipher_suite: return None
    try:
        with requests.get(url, stream=True, timeout=120) as response:
            response.raise_for_status()
            encrypted_data = response.content
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        temp_file.write(decrypted_data)
        temp_file.close()
        return temp_file.name
    except Exception as e:
        print(f"Decryption Error: {e}")
        return None

def perform_verification(live_path, ref_path, is_encrypted_ref):
    if GLOBAL_FACE_APP is None: return {'matched': False, 'error': 'AI Engine Down'}
    real_ref_path = ref_path
    temp_files_to_clean = []
    try:
        if is_encrypted_ref:
            real_ref_path = decrypt_from_url_to_temp(ref_path)
            if not real_ref_path: return {'matched': False, 'error': 'Decryption failed'}
            temp_files_to_clean.append(real_ref_path)
        elif ref_path.startswith('http'):
            legacy_temp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
            urllib.request.urlretrieve(ref_path, legacy_temp)
            real_ref_path = legacy_temp
            temp_files_to_clean.append(legacy_temp)

        def get_embedding(path):
            img = cv2.imread(path)
            if img is None: return None
            faces = GLOBAL_FACE_APP.get(img)
            if not faces: return None
            faces = sorted(faces, key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]), reverse=True)
            return faces[0].embedding

        emb_live = get_embedding(live_path)
        emb_ref = get_embedding(real_ref_path)
        if emb_live is None or emb_ref is None: return {'matched': False, 'error': 'Face not detected'}
        
        sim = cosine_similarity(emb_live.reshape(1, -1), emb_ref.reshape(1, -1))[0][0]
        return {'matched': sim > 0.50, 'score': float(sim)}
    except Exception as e:
        return {'matched': False, 'error': str(e)}
    finally:
        for p in temp_files_to_clean:
            if os.path.exists(p): os.remove(p)

def _process_bulk_email(include_terms, include_policy):
    """Background task for legal broadcast."""
    try:
        db = firestore.client()
        docs = db.collection('users').stream()
        connection = get_connection()
        connection.open()
        
        terms_link = "https://dankie-website.web.app/terms_and_conditions.html"
        policy_link = "https://dankie-website.web.app/privacy_policy.html"
        
        for doc in docs:
            u = doc.to_dict()
            email = u.get('email')
            if email:
                body = f"Dear Member,\n\nWe have updated our legal documents.\n"
                if include_terms: body += f"Terms: {terms_link}\n"
                if include_policy: body += f"Privacy: {policy_link}\n"
                try:
                    send_mail("Important Legal Update", body, settings.EMAIL_HOST_USER, [email], connection=connection, fail_silently=True)
                except: pass
        connection.close()
    except Exception as e:
        print(f"Error in email process: {e}")


# ==========================================
# 3. FUNCTIONAL VIEWS (Paystack, Email, Audio)
# ==========================================

@api_view(['POST'])
def recognize_face(request):
    live_file = request.FILES.get('live_image')
    ref_url = request.data.get('reference_url')
    if not live_file or not ref_url: return Response({'error': 'Missing data'}, status=400)

    temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
    try:
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)
        is_encrypted = ref_url.endswith('.enc')
        result = perform_verification(temp_live, ref_url, is_encrypted)
        if result.get('error'): return Response({'matched': False, 'message': result['error']})
        return Response({'matched': result['matched'], 'distance': result.get('score', 0.0)})
    finally:
        if os.path.exists(temp_live): os.remove(temp_live)

@api_view(['POST'])
def send_legal_broadcast(request):
    inc_terms = request.data.get('include_terms', False)
    inc_policy = request.data.get('include_policy', False)
    if not inc_terms and not inc_policy: return Response({'error': 'Select document type.'}, status=400)
    threading.Thread(target=_process_bulk_email, args=(inc_terms, inc_policy)).start()
    return Response({'message': 'Broadcast started.'})

class ServeDecryptedImageView(APIView):
    def get(self, request):
        encrypted_url = request.query_params.get('url')
        if not encrypted_url: return HttpResponse("Missing URL", status=400)
        try:
            response = requests.get(encrypted_url)
            if response.status_code != 200: return HttpResponse("Failed to fetch image", status=404)
            decrypted_image_data = cipher_suite.decrypt(response.content)
            return HttpResponse(decrypted_image_data, content_type="image/jpeg")
        except Exception as e:
            return HttpResponse(f"Error: {e}", status=500)
import logging

logger = logging.getLogger(__name__)

@api_view(['POST'])
def initialize_subscription(request):
    print("----- DEBUG: SUBSCRIPTION REQUEST START -----")
    print(f"Incoming Data: {request.data}")  # 👈 This will show up in your terminal

    try:
        email = request.data.get('email')
        uid = request.data.get('uid')
        plan_code = request.data.get('plan_code')
        member_count = request.data.get('member_count', 0)

        # 1. Validation Check
        if not all([email, uid, plan_code]):
            print(f"❌ Validation Failed. Missing fields. Email: {email}, UID: {uid}, Plan: {plan_code}")
            return Response({'error': 'Missing required subscription details.'}, status=400)

        # 2. Prepare Paystack Request
        reference = f"SUB_{uid}_{int(datetime.datetime.now().timestamp())}"
        
        # Ensure your settings.PAYSTACK_API_BASE is correct (usually https://api.paystack.co)
        paystack_url = f"{settings.PAYSTACK_API_BASE}/transaction/initialize"
        
        body = {
            "email": email,
            "amount": "0", # Amount is 0 for subscriptions (Paystack charges based on plan)
            "plan": plan_code,
            "currency": "ZAR",
            "reference": reference,
            "callback_url": "https://standard.paystack.co/close",
            "metadata": {
                "custom_fields": [
                    {
                        "display_name": "Subscription_Type",
                        "variable_name": "subscription_type", 
                        "value": "monthly_overseer_tier"
                    },
                    {
                        "display_name": "overseer_uid", 
                        "variable_name": "overseer_uid", 
                        "value": uid
                    },
                    {
                        "display_name": "Plan_Code", 
                        "variable_name": "plan_code", 
                        "value": plan_code
                    },
                    {
                        "display_name": "Member_Count", 
                        "variable_name": "member_count", 
                        "value": str(member_count)
                    },
                ]
            }
        }
        
        headers = {
            "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
            "Content-Type": "application/json",
        }

        print(f"🚀 Sending to Paystack: {paystack_url}")
        
        # 3. Call Paystack
        resp = requests.post(paystack_url, json=body, headers=headers)
        data = resp.json()

        print(f"📩 Paystack Response: {data}") # 👈 Critical for debugging

        if not data.get('status'):
            # This passes the actual Paystack error back to Flutter
            error_msg = data.get('message', 'Paystack initialization failed.')
            print(f"❌ Paystack Error: {error_msg}")
            return Response({'error': error_msg}, status=400)

        print("✅ Success! URL generated.")
        return Response({'authorization_url': data['data']['authorization_url']})

    except Exception as e:
        print(f"🔥 EXCEPTION: {str(e)}")
        return Response({'error': str(e)}, status=500)  

# --- NEW: Unified Paystack Webhook (From Node.js) ---
@csrf_exempt
def paystack_webhook(request):
    """
    Handles Paystack webhooks for:
    1. Subscription Success (monthly_overseer_tier)
    2. Subscription Failure (monthly_overseer_tier)
    3. Regular Order Success
    """
    if request.method != 'POST':
        return HttpResponse("Method not allowed", status=405)

    # 1. Security: Verify Signature
    secret = settings.PAYSTACK_SECRET_KEY
    signature = request.headers.get('x-paystack-signature')
    
    if not signature:
        print("Webhook Security Failure: No signature.")
        return HttpResponse("No signature", status=401)

    try:
        # Calculate HMAC
        hash_calc = hmac.new(
            secret.encode('utf-8'), 
            request.body, 
            digestmod=hashlib.sha512
        ).hexdigest()

        if hash_calc != signature:
            print("Webhook Security Failure: Mismatched signature.")
            return HttpResponse("Unauthorized", status=401)
    except Exception as e:
        print(f"Signature Verification Error: {e}")
        return HttpResponse("Server Error", status=500)

    # 2. Parse Event Data
    try:
        event = json.loads(request.body)
    except json.JSONDecodeError:
        return HttpResponse("Invalid JSON", status=400)

    event_type = event.get('event')
    data = event.get('data', {})
    
    # Extract Metadata Helper
    metadata_fields = data.get('metadata', {}).get('custom_fields', [])
    
    def get_meta(variable_name):
        field = next((f for f in metadata_fields if f.get('variable_name') == variable_name), None)
        return field['value'] if field else None

    # ======================================================================
    # CASE A: CHARGE SUCCESS (Subscription OR Order)
    # ======================================================================
    if event_type == 'charge.success' and data.get('status') == 'success':
        
        subscription_type = get_meta('subscription_type')

        # --- A1. SUBSCRIPTION SUCCESS ---
        if subscription_type == 'monthly_overseer_tier':
            overseer_uid = get_meta('overseer_uid')
            member_count_val = get_meta('member_count')

            # Validation similar to Node check: if (!overseerUidField?.value) ...
            if not overseer_uid:
                print("Event received, but missing 'overseer_uid'.")
                return HttpResponse('Event received, but not a valid subscription charge.', status=200)

            auth_code = data.get('authorization', {}).get('authorization_code')
            paystack_email = data.get('customer', {}).get('email')
            charged_amount_cents = data.get('amount')

            if not auth_code or not paystack_email:
                print(f"Missing vital data in subscription charge for UID: {overseer_uid}")
                return HttpResponse('Missing critical data in payload.', status=200)

            try:
                # Calculate Next Charge Date (30 days from now)
                next_charge_date = datetime.datetime.now() + datetime.timedelta(days=30)
                current_member_count = int(member_count_val) if member_count_val else 0 
                Overseer.objects.update_or_create(
                    uid=overseer_uid,
                    defaults={
                        'paystack_auth_code': auth_code,
                        'paystack_email': paystack_email,
                        'subscription_status': 'active',
                        'last_charged': datetime.datetime.now(),
                        'last_charged_amount': Decimal(charged_amount_cents) / 100, 
                        'current_member_count': current_member_count,
                        'next_charge_date': next_charge_date
                    }
                )
                print(f"Overseer {overseer_uid} successfully subscribed/authorized.")
                return HttpResponse('Subscription webhook processed.', status=200)

            except Exception as e:
                print(f"Error processing subscription charge for {overseer_uid}: {e}")
                return HttpResponse('Internal server error during DB update.', status=500)
 
        else:
            order_ref = data.get('reference')
            try: 
                order = Order.objects.get(id=order_ref)
                 
                expected_cents = int(order.total_amount * 100)
                paid_cents = int(data.get('amount', 0))

                if expected_cents == paid_cents:
                    order.is_paid = True
                    order.status = 'paid'
                    order.transaction_id = str(data.get('id'))
                    order.paystack_transaction_data = data
                    order.save()
                    print(f"Order {order_ref} updated to paid.")
                    return HttpResponse('Webhook received and order updated.', status=200)
                else:
                    print(f"Amount mismatch for Order {order_ref}: Expected {expected_cents}, got {paid_cents}")
                    return HttpResponse('Amount mismatch', status=400)

            except Order.DoesNotExist:
                print(f"Order {order_ref} not found.")
                return HttpResponse('Order not found', status=404)
            except Exception as e:
                print(f"Error updating order status: {e}")
                return HttpResponse('Internal server error.', status=500)

    # ======================================================================
    # CASE B: CHARGE FAILURE (Subscription Only logic added here)
    # ======================================================================
    elif event_type == 'charge.failure':
        
        # Check if this failure belongs to an Overseer Subscription
        overseer_uid = get_meta('overseer_uid')
        
        if overseer_uid:
            try:
                print(f"Processing payment failure for overseer {overseer_uid}")
                
                # Update Django Database (Equivalent to setting subscriptionStatus: 'payment_failed')
                # We use filter().update() to avoid creating a new record if one doesn't exist (safety)
                Overseer.objects.filter(uid=overseer_uid).update(
                    subscription_status='payment_failed',
                    last_attempted=datetime.datetime.now()
                )
                print(f"Initial charge failed for overseer {overseer_uid}.")
            except Exception as e:
                print(f"Error handling failure for {overseer_uid}: {e}")
         
        return HttpResponse('Webhook received.', status=200)
 
    return HttpResponse('Webhook received.', status=200) 

@api_view(['POST']) 
def create_seller_subaccount(request):
    
    print(f"Subaccount Request Data: {request.data}") # Debugging 
    uid = request.data.get('uid') # Get UID sent from Flutter
    business_name = request.data.get('business_name')
    bank_code = request.data.get('bank_code')
    account_number = request.data.get('account_number')
    contact_email = request.data.get('contact_email')

    # 1. Validate Fields
    if not all([uid, business_name, bank_code, account_number, contact_email]):
         return Response({'error': 'Missing required fields (uid, business_name, etc.)'}, status=400)

    try: 
        user = Users.objects.get(uid=uid)
    except Users.DoesNotExist:
        return Response({'error': f"User with uid {uid} not found"}, status=404)
 
    platform_fee = 9.0 
    
    payload = {
        "business_name": business_name,
        "settlement_bank": bank_code,
        "account_number": account_number,
        "percentage_charge": platform_fee, 
        "primary_contact_email": contact_email,
    }
    
    headers = {
        "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }

    try:
        # 4. Call Paystack
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/subaccount", json=payload, headers=headers)
        data = resp.json()
        
        print(f"Paystack Response: {data}") # Debugging

        if resp.status_code == 200 or resp.status_code == 201:
            if data.get('status') is True:
                sub_code = data['data']['subaccount_code']
                
                # 5. Save to User Model
                user.seller_paystack_account = sub_code 
                user.save()
                
                return Response({'success': True, 'subaccount_code': sub_code})
            else:
                return Response({'error': data.get('message')}, status=400)
        else:
            return Response({'error': data.get('message', 'Paystack validation failed')}, status=400)

    except Exception as e:
        print(f"Server Error: {str(e)}")
        return Response({'error': str(e)}, status=500)
# --- NEW: Create Payment Link (From Node.js) ---


@api_view(['POST']) 
def create_payment_link(request):
    try:
        email = request.data.get('email')
        products = request.data.get('products', [])
        order_ref = request.data.get('orderReference')

        if not email or not products or not order_ref:
            return Response({'error': 'Invalid request body'}, status=400)

        total_amount = 0
        subaccounts = []
        
        for product in products:
            price = float(product.get('price', 0))
            qty = int(product.get('quantity', 1))
            amount_cents = int(round(price * qty * 100))
            total_amount += amount_cents
 
            if product.get('subaccount'):
                # Using 8% as ADMIN_SHARE based on Node.js constant
                ADMIN_SHARE_PERCENT = getattr(settings, 'ADMIN_SHARE_PERCENT', 9)
                seller_share = int(round(amount_cents * (1 - ADMIN_SHARE_PERCENT / 100.0)))
                subaccounts.append({
                    "subaccount": product['subaccount'],
                    "share": seller_share
                })

        body = {
            "email": email,
            "amount": total_amount,
            "currency": "ZAR",
            "channels": ['card', 'bank', 'ussd', 'qr', 'mobile_money'],
            "reference": order_ref, 
        }

        if subaccounts:
            body['split'] = {
                "type": "flat",
                "subaccounts": subaccounts
            }

        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}"}
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/transaction/initialize", json=body, headers=headers)
        data = resp.json()

        if not data.get('status'):
            return Response({'error': data.get('message')}, status=400)

        return Response({'paymentLink': data['data']['authorization_url']})

    except Exception as e: 
        return Response({'error': 'Server error'}, status=500)

# --- NEW: Send Custom Email (From Node.js) ---
@api_view(['POST']) 
def send_custom_email(request):
    to = request.data.get('to')
    subject = request.data.get('subject')
    body = request.data.get('body')
    attachment_url = request.data.get('attachmentUrl')

    if not to or not subject or not body:
        return Response({'error': "Missing required fields"}, status=400)

    try:
        # Use EmailMultiAlternatives for better HTML support
        # We provide a plain-text version first, then attach the HTML
        text_content = body
        html_content = body.replace('\n', '<br>')
        
        email = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[to]
        )
        email.attach_alternative(html_content, "text/html")

        # Strict check for attachment
        if attachment_url and str(attachment_url).strip():
            try:
                r = requests.get(attachment_url, timeout=10)
                if r.status_code == 200:
                    # Explicitly define the attachment
                    email.attach('Report.pdf', r.content, 'application/pdf')
            except Exception as e:
                print(f"Attachment failed but sending email anyway: {e}")

        email.send()
        return Response({'success': True})

    except Exception as e: 
        print(f"Detailed Error: {str(e)}")
        return Response({'error': str(e)}, status=500)
# ==========================================
# 4. MODEL VIEWSETS
# ==========================================

class OverseerViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Overseer.objects.all()
    serializer_class = OverseerSerializer

    # def get_queryset(self):
    #     queryset = Overseer.objects.all()
    #     email = self.request.query_params.get('email')
    #     if email: queryset = queryset.filter(email=email)
        
    #     uid = self.request.query_params.get('uid')
    #     if uid: queryset = queryset.filter(uid=uid)
        
    #     _province = self.request.query_params.get('province')
    #     if _province: queryset = queryset.filter(province=_province)
    #     return queryset
    def get_queryset(self):
        queryset = Overseer.objects.all()
        
        # 1. Email (Now Case-Insensitive & spaces removed)
        email = self.request.query_params.get('email')
        if email: 
            queryset = queryset.filter(email__iexact=email.strip())
        
        # 2. UID (Keep exact match - UIDs are strict)
        uid = self.request.query_params.get('uid')
        if uid: 
            queryset = queryset.filter(uid=uid.strip())
        
        # 3. Province (Case-Insensitive & spaces removed)
        province_param = self.request.query_params.get('province')
        if province_param: 
            queryset = queryset.filter(province__iexact=province_param.strip())
            
        return queryset
    

    def create(self, request, *args, **kwargs):
        data = request.data.dict()
        if 'districts' in data:
            try:
                if isinstance(data['districts'], str):
                    data['districts'] = json.loads(data['districts'])
            except: pass

        # Encrypt & Upload Faces
        sec_file = request.FILES.get('secretary_face_image')
        if sec_file:
            data['secretary_face_url'] = encrypt_and_upload_to_firebase(sec_file, 'secure_faces')
        
        chair_file = request.FILES.get('chairperson_face_image')
        if chair_file:
            data['chairperson_face_url'] = encrypt_and_upload_to_firebase(chair_file, 'secure_faces')

        serializer = self.get_serializer(data=data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        self.perform_create(serializer)
        
        # Auto-Create Committee Members
        overseer = serializer.instance
        if data.get('secretary_name') and data.get('secretary_face_url'):
            CommitteeMember.objects.create(
                overseer=overseer, name=data['secretary_name'], 
                role='Overseer', portfolio='Secretary', face_url=data['secretary_face_url']
            )
        if data.get('chairperson_name') and data.get('chairperson_face_url'):
            CommitteeMember.objects.create(
                overseer=overseer, name=data['chairperson_name'], 
                role='Overseer', portfolio='Chairperson', face_url=data['chairperson_face_url']
            )

        return Response(serializer.data, status=status.HTTP_201_CREATED)

class StaffMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = StaffMember.objects.all() 
    serializer_class = StaffMemberSerializer
    
    def get_queryset(self):
        queryset = StaffMember.objects.all()
        face_url = self.request.query_params.get('face_url')
        if face_url: queryset = queryset.filter(face_url__iexact=face_url)
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email__iexact=email)
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid__iexact=uid)
        return queryset

    @action(detail=False, methods=['get'])
    def find_by_face(self, request):
        url = request.query_params.get('url')
        if not url: return Response({"error": "Missing url"}, status=400)
        staff = StaffMember.objects.filter(face_url=url).first()
        if not staff: return Response({"error": "Not found"}, status=404)
        return Response(self.get_serializer(staff).data)

class UsersViewSet(viewsets.ModelViewSet):
    queryset = Users.objects.all()
    serializer_class = UsersSerializer
    lookup_field = 'uid'

    def get_queryset(self):
        queryset = Users.objects.all()
        
        # Existing Filters
        uid = self.request.query_params.get('uid')
        if uid: queryset = queryset.filter(uid=uid)
        
        email = self.request.query_params.get('email')
        if email: queryset = queryset.filter(email=email)
        
        role = self.request.query_params.get('role')
        if role: queryset = queryset.filter(role=role)
        
        overseer_uid = self.request.query_params.get('overseer_uid')
        if overseer_uid: queryset = queryset.filter(overseer_uid=overseer_uid)

        # ---------------------------------------------------------
        # ⭐️ NEW FILTERS ADDED HERE
        # ---------------------------------------------------------
        
        # Filter by Community Name (Case Insensitive)
        community_name = self.request.query_params.get('community_name')
        if community_name:
            queryset = queryset.filter(community_name__iexact=community_name.strip())

        # Filter by District Elder Name (Case Insensitive)
        district_elder_name = self.request.query_params.get('district_elder_name')
        if district_elder_name:
            queryset = queryset.filter(district_elder_name__iexact=district_elder_name.strip())

        return queryset

    def create(self, request, *args, **kwargs):
        uid = request.data.get('uid')
        if not uid: return Response({"error": "UID is required"}, status=400)
        user_instance, created = Users.objects.get_or_create(uid=uid)
        serializer = self.get_serializer(user_instance, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201 if created else 200)
        return Response(serializer.errors, status=400)
class TactsoBranchViewSet(viewsets.ModelViewSet):
    queryset = TactsoBranch.objects.all()
    serializer_class = TactsoBranchSerializer

    def create(self, request, *args, **kwargs):
        data = request.data.dict()
        if 'image_url' not in data: data['image_url'] = ""
       
        auth_faces = []
        # Officer Face
        officer_file = request.FILES.get('education_officer_face_image')
        if officer_file:
            url = encrypt_and_upload_to_firebase(officer_file, 'secure_faces')
            if url:
                data['education_officer_face_url'] = url
                auth_faces.append(url)
            else: return Response({"error": "Failed to encrypt Officer face"}, status=500)
        else: return Response({"error": "Education Officer face is required"}, status=400)

        # Chairperson Face
        chair_file = request.FILES.get('chairperson_face_image')
        chair_url = None
        if chair_file:
            chair_url = encrypt_and_upload_to_firebase(chair_file, 'secure_faces')
            if chair_url: auth_faces.append(chair_url)
            else: return Response({"error": "Failed to encrypt Chairperson face"}, status=500)
        else: return Response({"error": "Chairperson face is required"}, status=400)

        data['authorized_user_face_urls'] = json.dumps(auth_faces)
        serializer = self.get_serializer(data=data)
        if not serializer.is_valid(): return Response(serializer.errors, status=400)
        
        self.perform_create(serializer)
        branch = serializer.instance

        # Auto-Create Members
        BranchCommitteeMember.objects.create(
            branch=branch, fullname=data.get('education_officer_name', 'Education Officer'),
            role='Education Officer', email=data.get('email', ''), face_url=data['education_officer_face_url']
        )
        BranchCommitteeMember.objects.create(
            branch=branch, fullname=data.get('chairperson_name', 'Chairperson'),
            role='Chairperson', email=data.get('email', ''), face_url=chair_url
        )
        return Response(serializer.data, status=201)

class CommunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Community.objects.all()
    serializer_class = CommunitySerializer
    def get_queryset(self):
        queryset = Community.objects.all()
        province = self.request.query_params.get('province')
        if province: queryset = queryset.filter(district__overseer__province__iexact=province)
        return queryset
class DistrictViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = District.objects.all()
    serializer_class = DistrictSerializer

    def get_queryset(self):
        # Start with all districts
        queryset = District.objects.all()
        
        # 1. Get params from the Flutter request
        province = self.request.query_params.get('province')
        limit = self.request.query_params.get('limit')

        # 2. Filter by Province (if sent)
        # Note: This assumes your District model has a foreign key to Overseer 
        # named 'overseer', and Overseer has a 'province' field.
        # If District has a direct 'province' field, change this to: queryset.filter(province__iexact=province)
        if province and province != 'All':
            # Check your models: does District link to Overseer? 
            # If yes:
            queryset = queryset.filter(overseer__province__iexact=province)
            # If District has its own province field:
            # queryset = queryset.filter(province__iexact=province)

        # 3. Handle Limit (Flutter sends limit=3000)
        if limit:
            try:
                return queryset[:int(limit)]
            except ValueError:
                pass
        
        return queryset
class SongViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = Songs.objects.all()
    serializer_class = SongSerializer

class CatalogViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'category']

class SellerInventoryViewSet(viewsets.ModelViewSet):
    serializer_class = SellerListingSerializer
    def get_queryset(self):
        queryset = SellerListing.objects.all()
        seller_uid_param = self.request.query_params.get('seller_uid')
        
        if seller_uid_param:
            # FIX: Use 'seller__uid' (Relationship__Field) or 'seller' 
            # Do NOT use 'seller_uid' directly as that is the DB column, not the Django field.
            queryset = queryset.filter(seller__uid=seller_uid_param)
        return queryset
    def perform_create(self, serializer):
        serializer.save()
# In api/views.py

class OrderViewSet(viewsets.ModelViewSet):
    serializer_class = OrderSerializer 

    def get_queryset(self):
        user_uid = self.request.query_params.get('user_uid')
        if user_uid:
            return Order.objects.filter(user__uid=user_uid)
        return Order.objects.all()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        serializer.save()

    # --- NEW: ACTIVE VERIFICATION ACTION ---
    @action(detail=True, methods=['get'])
    def verify_payment(self, request, pk=None):
        """
        Manually checks Paystack API to see if the transaction was successful.
        This is crucial for localhost testing where Webhooks don't work.
        """
        order = self.get_object()
        
        # 1. If already paid, return immediately
        if order.status == 'paid' and order.is_paid:
             return Response(self.get_serializer(order).data)

        # 2. Ask Paystack: "Is this reference paid?"
        url = f"https://api.paystack.co/transaction/verify/{order.id}"
        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}"}
        
        try:
            resp = requests.get(url, headers=headers)
            data = resp.json()
            
            # 3. If Paystack says 'success'
            if data['status'] and data['data']['status'] == 'success':
                # Verify the amount matches (Paystack uses cents)
                paid_cents = int(data['data']['amount'])
                expected_cents = int(order.total_amount * 100)
                
                if paid_cents >= expected_cents:
                    order.is_paid = True
                    order.status = 'paid'
                    order.transaction_id = str(data['data']['id'])
                    order.paystack_transaction_data = data['data']
                    order.save()
                    print(f"Order {order.id} verified and updated to PAID.")
                    
            return Response(self.get_serializer(order).data)
            
        except Exception as e:
            print(f"Verification Error: {e}")
            # Return current state even if check failed
            return Response(self.get_serializer(order).data)
class CommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = CommitteeMember.objects.all()
    serializer_class = CommitteeMemberSerializer

    def get_queryset(self):
        queryset = CommitteeMember.objects.all()
        
        # 1. Filter by Email (Critical for Login)
        email = self.request.query_params.get('email')
        if email:
            queryset = queryset.filter(email__iexact=email.strip())

        # 2. Filter by Overseer ID (Critical for fetching a specific team)
        overseer_id = self.request.query_params.get('overseer')
        if overseer_id:
            queryset = queryset.filter(overseer__id=overseer_id)

        # 3. Filter by Face URL (Critical for Profile Mapping)
        face_url = self.request.query_params.get('face_url')
        if face_url:
            queryset = queryset.filter(face_url=face_url)

        return queryset
class OverseerExpenseReportViewSet(CachedListMixin, viewsets.ModelViewSet):
    # 1. Add queryset here for the Mixin to find the model name
    queryset = OverseerExpenseReport.objects.all()
    serializer_class = OverseerExpenseReportSerializer

    def get_queryset(self):
        # 2. Removed .select_related('overseer') because the model has no ForeignKey
        queryset = OverseerExpenseReport.objects.all()
        
        month = self.request.query_params.get('month')
        year = self.request.query_params.get('year')
        province = self.request.query_params.get('province')
        limit = self.request.query_params.get('limit')

        if month and month != 'All': 
            queryset = queryset.filter(month__iexact=month) 
        
        if year and year != 'All': 
            queryset = queryset.filter(year=year)
            
        # 3. Commented out Province filter because it requires a ForeignKey relationship.
        # If 'overseer' is just a text ID string, you cannot use 'overseer__province'.
        # if province and province != 'All': 
        #     queryset = queryset.filter(overseer__province__iexact=province)

        if limit:
            try: 
                return queryset[:int(limit)]
            except: 
                pass
                
        return queryset   
     
class UpcomingEventViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = UpcomingEvent.objects.all()
    serializer_class = UpcomingEventSerializer

class CareerOpportunityViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = CareerOpportunity.objects.all()
    serializer_class = CareerOpportunitySerializer

class BranchCommitteeMemberViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = BranchCommitteeMember.objects.all()
    serializer_class = BranchCommitteeMemberSerializer

class ApplicationRequestViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = ApplicationRequest.objects.all()
    serializer_class = ApplicationRequestSerializer

    def get_queryset(self):
        queryset = ApplicationRequest.objects.all()
        branch_id = self.request.query_params.get('branch')
        if branch_id:
            queryset = queryset.filter(branch__id=branch_id)
        user_uid = self.request.query_params.get('user_uid')
        if user_uid:
            queryset = queryset.filter(user__uid=user_uid)
        return queryset

    def create(self, request, *args, **kwargs):
        # 1. Create a mutable copy of the data
        data = request.data.dict()
        
        # 2. Helper to Encrypt Files
        def encrypt_field(field_name):
            file_obj = request.FILES.get(field_name)
            if file_obj:
                # Uses your existing encryption helper
                secure_url = encrypt_and_upload_to_firebase(file_obj, 'secure_applications')
                if secure_url:
                    data[field_name] = secure_url
                else:
                    raise Exception(f"Failed to encrypt {field_name}")

        try:
            # 3. Encrypt specific document fields
            encrypt_field('id_passport_url')
            encrypt_field('school_results_url')
            encrypt_field('proof_of_registration_url')
            encrypt_field('other_qualifications_url')

            # 4. Serialize and Save
            serializer = self.get_serializer(data=data)
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            headers = self.get_success_headers(serializer.data)
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
class UserUniversityApplicationViewSet(CachedListMixin, viewsets.ModelViewSet):
    queryset = UserUniversityApplication.objects.all()
    serializer_class = UserUniversityApplicationSerializer
 
class AuditLogViewSet(viewsets.ModelViewSet): 
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    
    # 1. Enable ?ordering=-timestamp support for Flutter
    filter_backends = [filters.OrderingFilter, filters.SearchFilter]
    ordering_fields = ['timestamp', 'action']
    ordering = ['-timestamp']  # Default ordering
    
    def get_queryset(self):
        # 2. Fix variable scope issue
        queryset = super().get_queryset()
        
        timestamp = self.request.query_params.get('timestamp')
        if timestamp:
            queryset = queryset.filter(timestamp=timestamp)
            
        return queryset
    

class ContributionHistoryViewSet(viewsets.ModelViewSet):
    queryset = ContributionHistory.objects.all()
    serializer_class = ContributionHistorySerializer
    
    def get_queryset(self):
        qs = ContributionHistory.objects.all()
        overseer = self.request.query_params.get('overseer_uid')
        elder = self.request.query_params.get('district_elder')
        community = self.request.query_params.get('community')
        year = self.request.query_params.get('year')
        month = self.request.query_params.get('month')

        if overseer: qs = qs.filter(overseer_uid=overseer)
        if elder: qs = qs.filter(district_elder=elder)
        if community: qs = qs.filter(community=community)
        if year: qs = qs.filter(year=year)
        if month: qs = qs.filter(month=month)
        return qs

class MonthlyReportViewSet(viewsets.ModelViewSet):
    queryset = MonthlyReport.objects.all()
    serializer_class = MonthlyReportSerializer
    lookup_field = 'id' # We use the custom ID string

    @action(detail=False, methods=['post'])
    def archive_month(self, request):
        """
        Transactional operation:
        1. Create ContributionHistory records for all users in community
        2. Reset User weeks to 0
        3. Create MonthlyReport
        4. Create OverseerExpenseReport
        """
        data = request.data
        overseer_uid = data.get('overseer_uid')
        elder = data.get('district_elder')
        community = data.get('community')
        year = data.get('year')
        month = data.get('month')
        province = data.get('province')
        
        # Financial Data
        report_data = data.get('report_data', {})
        expenses_data = data.get('expenses_data', {})

        if not all([overseer_uid, elder, community, year, month]):
            return Response({'error': 'Missing required fields'}, status=400)

        try:
            with transaction.atomic():
                # 1. Fetch Users
                users = Users.objects.filter(
                    overseer_uid=overseer_uid, 
                    district_elder_name=elder, 
                    community_name=community
                )

                # 2. Archive & Reset Users
                history_records = []
                for user in users:
                    # Create History Object
                    history_records.append(ContributionHistory(
                        overseer_uid=overseer_uid,
                        user_uid=user.uid,
                        name=user.name,
                        surname=user.surname,
                        district_elder=elder,
                        community=community,
                        month=month,
                        year=year,
                        week1=float(user.week1 or 0),
                        week2=float(user.week2 or 0),
                        week3=float(user.week3 or 0),
                        week4=float(user.week4 or 0),
                    ))
                    
                    # Reset User
                    user.week1 = "0"
                    user.week2 = "0"
                    user.week3 = "0"
                    user.week4 = "0"
                    user.save()
                
                # Bulk Create History
                ContributionHistory.objects.bulk_create(history_records)

                # 3. Create Monthly Report
                report_id = f"{community}_{year}_{month}"
                MonthlyReport.objects.update_or_create(
                    id=report_id,
                    defaults={
                        'community_name': community,
                        'year': year,
                        'month': month,
                        **report_data # Spread the financial/date fields
                    }
                )

                # 4. Create Overseer Expense Report
                OverseerExpenseReport.objects.create(**expenses_data)

            return Response({'status': 'success', 'message': 'Month archived successfully'})

        except Exception as e:
            return Response({'error': str(e)}, status=500)