import os
import sys
import json
import django
import firebase_admin
from firebase_admin import credentials, firestore

# --- PATH FIX ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)
# ----------------

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "tact_api.settings")
django.setup()

# Import all models (Added AuditLog)
from api.models import (
    Songs, OverseerExpenseReport, UpcomingEvent, Overseer, 
    District, Community, CareerOpportunity, TactsoBranch, Campus, 
    StaffMember, CommitteeMember, AuditLog,ApplicationRequest,BranchCommitteeMember
)

# Firebase setup
cred = credentials.Certificate({
  "type": "service_account",
  "project_id": "tact-3c612",
  "private_key_id": "059a814aad4865e217d923b3726417452955acf8",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDtWbQ3r3lV3zte\nLJVL/kLoynnr0uRIPYi6t5Qj8HzGJuxns89/Lk/5LGvu7h5xaD94N2IxBRF7Ge7L\nf97tIKlFttTw166h/A+JcjVOZqJYdxTdusD/7cdtihM0gqOTjCOtoiPy79kAFR+J\nDXYeEvWssGBIZAWZDrDNiB3gnh/g4p6iiW2WbBJzLNYlYDclywk7dISwqzox1XNr\ngN5iYJ2/ndkUL2MD8KlYEusV3lgaKCyiFz27ziWvfyy37uipQwRyC3qNFLRtlh8K\nXDTfY3v8Yq8Gva586N6w3MwunNl6/VgZ6lvOrdWMjeZkHg92ZoobFCt2bPTw1484\nPrevuXaJAgMBAAECggEAC0u8nvXT8XlJSwcWJ+K27ntMaCPGR4XeLvyzqS410fxi\nPeE529Spa7Nog5uDiWQruR3xp2GVXmVyju7L/j8Sr0WvRrMNFZp4ZtMvpEaQLWOl\nc5QCwWtglV7/4Pziqg/+VrIjwdkWW8GlmZExcOb4GDrgqjFQbuNbGL0Epv7/h2VK\nLPse/ecZ63b85j4UE0taQEow79UvtYju4RUpHXNDcPnmLs8qievB2/iuQyaCz0kE\n6Zu0OD1sNC4TCM/Y+ZwoDlPEy7IMnJUzlWjwP+k3MpH8q04Uu5onqnrfvWjuN0WM\nMg/I2h7SukXgUjCr2+SarwvbKq4koe7YWbYPs8IEgQKBgQD87D2opv1+ZL0yJFD6\n0m3EhzSKqLLCXPKFhFFCFm6n48f8yb84p3UI1t6qO2zD+4EHYQTti9bjLpZmiVXu\njdjTyevEZ3ocvbRMbeMoVCcm7Td72uAjmj6ZEALljTEic6oKxTWKG2enNlcixvrf\nJaCbXSK4jsabxdPsnlBhcCPKeQKBgQDwPPYAHHwiviv6k7vmmyWoNiR2S22hYr7y\nAXKR0pp5fdQfs03+HUJF1Mv+4HQ1VjvFlRGBr0wsdRE4hoMpbaVQN4cegvBWoTSg\nFVSNawXn6ePv2ACrKvwU0na7rkB9o8jhg1P5hAYsRuXecp80NXxC+3UAcdfQv7MY\nAjfDLiAIkQKBgER6cfdHvzqJa/A3hPVkI/Qh50fjhQK6x67+tEGAcVVjhrIarXtZ\nW4aZJpBQppIpdjXZPsxSIExCQNZiOLHuFdbBxOPYYGeHtVk8J1Sz9CXF9E/EYwtA\np9IpU59zKup5BoEEBArwgI/1VoJD/YiNV365KL1varaiSU63TmwTQJ2BAoGBALvM\n7AHqQqBmSbr5AkqjvixhJt/S10DyEJLeztFv8ZJH6ytc3/tmpAgy8cWtcSrA3rj2\nb1kR0FpwqaWmgaJBNJogzl/rvDX8j0cVZaOnplZFYQp9sQgd8jHU1TyiW4fcIY0p\nPNwxeSHjyo66y/nkVd+G81AFrtBhC4AZO744sJIBAoGADvbLI1teCYM2wAlr+OBS\nX0diu4ynkhqR0D+auf2o0tyomHPA0tUd8YmktVSyZBecCT46g3OgoIPliQ56nnIC\nnPYvN6SH0pNzFpjzhuFfLsSAtwzd6JR7S6BEywAnyuUcvI3eJLKNqQuTDkxdtSbA\niioyUaZ697kj3DP1yjhh958=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@tact-3c612.iam.gserviceaccount.com",
  "client_id": "100658254555985172985",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40tact-3c612.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
})

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ==========================================
# 1. MIGRATE SONGS
# ==========================================
print("\n🎵 Starting migration for 'tact_music'...")
songs_ref = db.collection("tact_music")
songs_docs = songs_ref.stream()

s_count, s_skipped = 0, 0
for doc in songs_docs:
    data = doc.to_dict()
    song_name = data.get("songName", "")
    artist = data.get("artist", "")
    if not Songs.objects.filter(songName=song_name, artist=artist).exists():
        try:
            Songs.objects.create(
                artist=artist,
                category=data.get("category", ""),
                released=data.get("released") or "Unknown",
                songName=song_name,
                songUrl=data.get("songUrl", ""),
            )
            s_count += 1
        except Exception as e:
            print(f"❌ Error migrating song {song_name}: {e}")
    else:
        s_skipped += 1
print(f"✅ Songs: {s_count} added, {s_skipped} skipped.")

# ==========================================
# 2. MIGRATE OVERSEER EXPENSES
# ==========================================
print("\n💰 Starting migration for 'overseer_expenses_reports'...")
expenses_ref = db.collection("overseer_expenses_reports")
expenses_docs = expenses_ref.stream()

e_count, e_skipped = 0, 0
for doc in expenses_docs:
    data = doc.to_dict()
    comm_name = data.get("communityName", "")
    month = data.get("month", 0)
    year = data.get("year", 0)
    
    if not OverseerExpenseReport.objects.filter(community_name=comm_name, month=month, year=year).exists():
        try:
            OverseerExpenseReport.objects.create(
                archived_at=data.get("archivedAt", ""),
                overseer_uid=data.get("overseerUid", ""),
                district_elder_name=data.get("districtElderName", ""),
                community_name=comm_name,
                province=data.get("province", ""),
                expense_central=data.get("expenseCentral") or 0,
                expense_other=data.get("expenseOther") or 0,
                expense_rent=data.get("expenseRent") or 0,
                expense_mine=data.get("expenseMine") or 0,
                total_banked=data.get("totalBanked") or 0,
                total_expenses=data.get("totalExpenses") or 0,
                total_income=data.get("totalIncome") or 0,
                month=month,
                year=year
            )
            e_count += 1
        except Exception as e:
            print(f"❌ Error migrating expense: {e}")
    else:
        e_skipped += 1
print(f"✅ Expenses: {e_count} added, {e_skipped} skipped.")

# ==========================================
# 3. MIGRATE UPCOMING EVENTS
# ==========================================
print("\n📅 Starting migration for 'upcoming_events'...")
events_ref = db.collection("upcoming_events")
events_docs = events_ref.stream()

ev_count, ev_skipped = 0, 0
for doc in events_docs:
    data = doc.to_dict()
    title = data.get("title", "")
    parsed_date = data.get("parsedDate", "")
    if not UpcomingEvent.objects.filter(title=title, parsed_date=parsed_date).exists():
        try:
            UpcomingEvent.objects.create(
                title=title,
                poster_url=data.get("posterUrl", ""),
                day=data.get("day", ""),
                month=data.get("month", ""),
                parsed_date=parsed_date,
                created_at=data.get("createdAt", "")
            )
            ev_count += 1
        except Exception as e:
            print(f"❌ Error migrating event {title}: {e}")
    else:
        ev_skipped += 1
print(f"✅ Events: {ev_count} added, {ev_skipped} skipped.")
 
# ==========================================
# 7. MIGRATE STAFF MEMBERS
# ==========================================
print("\n👥 Starting migration for 'staff_members'...")
staff_ref = db.collection("staff_members")
staff_docs = staff_ref.stream()

st_count, st_skipped = 0, 0
for doc in staff_docs:
    data = doc.to_dict()
    uid = data.get("uid")
    if not StaffMember.objects.filter(uid=uid).exists():
        try:
            StaffMember.objects.create(
                uid=uid,
                full_name=data.get("fullName", ""),
                name=data.get("name", ""),
                surname=data.get("surname", ""),
                email=data.get("email", ""),
                role=data.get("role", "Staff"),
                portfolio=data.get("portfolio", ""),
                province=data.get("province", ""),
                face_url=data.get("faceUrl", ""),
                is_active=data.get("isActive", True),
                created_at=data.get("createdAt", "")
            )
            st_count += 1
        except Exception as e:
            print(f"❌ Error migrating staff {uid}: {e}")
    else:
        st_skipped += 1
print(f"✅ Staff: {st_count} added, {st_skipped} skipped.")

# ==========================================
# 8. MIGRATE AUDIT LOGS
# ==========================================
print("\n📜 Starting migration for 'audit_logs'...")
audit_ref = db.collection("audit_logs")
audit_docs = audit_ref.stream()

al_count, al_skipped = 0, 0

for doc in audit_docs:
    data = doc.to_dict()
    
    # We use action + uid + timestamp as a unique constraint
    action = data.get("action", "")
    uid = data.get("uid", "")
    timestamp_val = str(data.get("timestamp", ""))  # Convert to string to be safe

    if not AuditLog.objects.filter(action=action, uid=uid, timestamp=timestamp_val).exists():
        try:
            AuditLog.objects.create(
                action=action,
                details=data.get("details", ""),
                reference_id=data.get("referenceId", "N/A"),
                actor_name=data.get("actorName", ""),
                actor_role=data.get("actorRole", ""),
                actor_face_url=data.get("actorFaceUrl", ""),
                uid=uid,
                university_name=data.get("universityName", ""),
                university_logo=data.get("universityLogo", ""),
                branch_email=data.get("branchEmail", ""),
                target_member_name=data.get("targetMemberName", ""),
                target_member_role=data.get("targetMemberRole", ""),
                student_name=data.get("studentName", "N/A"),
                timestamp=timestamp_val,
                device_time=data.get("deviceTime", "")
            )
            al_count += 1
        except Exception as e:
            print(f"❌ Error migrating audit log: {e}")
    else:
        al_skipped += 1

print(f"✅ Audit Logs: {al_count} added, {al_skipped} skipped.")
print("\n🚀 All migrations completed!")