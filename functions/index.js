// The updated way to get environment variables
require("dotenv").config(); // add this line at the top
const functions = require('firebase-functions');
const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
// const fetch = require('node-fetch'); // <-- REMOVED this problematic package
const admin = require('firebase-admin');
const crypto = require('crypto');
 

// --- ADD THESE FOR EMAIL ---
const nodemailer = require("nodemailer");
const cors = require("cors"); // ✅ only import 
const { onSchedule } = require("firebase-functions/v2/scheduler");

// ---------------------------

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Create an Express app
const app = express();
app.use(bodyParser.json());
app.use(cors({ origin: ["https://tactapp.web.app", "https://tact-3c612.web.app"] }));
 
// Now use environment variables directly:
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY; 
const GMAIL_EMAIL = process.env.GMAIL_EMAIL;
const GMAIL_PASSWORD = process.env.GMAIL_PASSWORD;
console.log(`Paystack key loaded: ${PAYSTACK_SECRET_KEY}`, !!PAYSTACK_SECRET_KEY);

// Initialize Paystack constants
// !! SECURITY: Make sure this is set in your environment, not hardcoded
 const PAYSTACK_API_BASE = 'https://api.paystack.co';

// --- TIERED PRICING CONSTANTS (in CENTS) ---
const TIER1_CENTS = 18900; // R189
const TIER2_CENTS = 25000; // R250
const TIER3_CENTS = 29900; // R299
// -------------------------------------------------------------------------

/**
 * Helper function to determine the subscription amount based on member count
 * @param {number} memberCount
 * @returns {number} Amount in cents
 */
function determineSubscriptionAmount(memberCount) {
    if (memberCount >= 500) {
        return TIER3_CENTS;
    } else if (memberCount >= 300) {
        return TIER2_CENTS;
    } else if (memberCount >= 50) {
        return TIER1_CENTS;
    } else {
        // Default to TIER1 as the minimum paid subscription
        return TIER1_CENTS; 
    }
}

// =========================================================================
// 1. HTTP ENDPOINT: /initialize-subscription
// =========================================================================
app.post('/initialize-subscription', async (req, res) => {
    try {
        const { email, amount, uid, tier, memberCount } = req.body;

        if (!email || !amount || !uid) {
            return res.status(400).json({ error: 'Missing required subscription details.' });
        }
        
        const reference = `AUTH_${uid}_${Date.now()}`;
        
        const body = {
            email: email,
            amount: amount,
            currency: 'ZAR',
            reference: reference, 
            channels: ['card', 'bank', 'ussd', 'qr'],
            metadata: {
                custom_fields: [
                    {
                        display_name: "Subscription_Type",
                        variable_name: "subscription_type",
                        value: "monthly_overseer_tier",
                    },
                    {
                        display_name: "Firebase_UID",
                        variable_name: "firebase_uid",
                        value: uid,
                    },
                    {
                        display_name: "Tier_Level",
                        variable_name: "tier_level",
                        value: tier || "N/A",
                    },
                    {
                        display_name: "Member_Count",
                        variable_name: "member_count",
                        value: memberCount.toString(),
                    }
                ]
            }
        };

        const response = await axios.post(
            `${PAYSTACK_API_BASE}/transaction/initialize`,
            body,
            {
                headers: {
                    Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
                    'Content-Type': 'application/json',
                },
            }
        );

        if (!response.data.status) {
            console.error('Paystack init error:', response.data.message);
            return res.status(400).json({ error: response.data.message || 'Paystack initialization failed.' });
        }

        return res.json({ authorization_url: response.data.data.authorization_url });

    } catch (error) {
        console.error('Error in initialize-subscription:', error.response?.data || error.message);
        return res.status(500).json({ error: 'Failed to initialize subscription payment.' });
    }
});
 
// =========================================================================
// 2. PAYSTACK WEBHOOK HANDLER (Subscription Flow)
// =========================================================================
app.post('/paystack-subscription-webhook', async (req, res) => {
    const hash = crypto.createHmac('sha512', PAYSTACK_SECRET_KEY)
        .update(JSON.stringify(req.body))
        .digest('hex');

    if (hash !== req.headers['x-paystack-signature']) {
        console.error("Subscription Webhook Security Failure: Mismatched signature.");
        return res.status(401).send('Unauthorized');
    }
    
    const event = req.body;
    const transaction = event.data;

    if (event.event === 'charge.success' && transaction.status === 'success') {
        
        const metadata = transaction.metadata?.custom_fields;
        const subscriptionTypeField = metadata?.find(f => f.variable_name === 'subscription_type');
        const overseerUidField = metadata?.find(f => f.variable_name === 'firebase_uid');
        const memberCountField = metadata?.find(f => f.variable_name === 'member_count');

        if (subscriptionTypeField?.value !== 'monthly_overseer_tier' || !overseerUidField?.value) {
            return res.status(200).send('Event received, but not a subscription charge.'); 
        }

        const overseerUid = overseerUidField.value;
        const authCode = transaction.authorization?.authorization_code;
        const email = transaction.customer?.email;
        const chargedAmountCents = transaction.amount; 

        if (!overseerUid || !authCode || !email) {
             console.error(`Missing vital data in subscription charge.success payload for UID: ${overseerUid}`);
             return res.status(200).send('Missing critical data in payload.'); 
        }

        try {
            const nextChargeDate = admin.firestore.Timestamp.fromMillis(
                Date.now() + (30 * 24 * 60 * 60 * 1000)
            );
            
            const currentMemberCount = memberCountField ? parseInt(memberCountField.value) : 0;

            await db.collection('overseers').doc(overseerUid).set({
                paystackAuthCode: authCode,
                paystackEmail: email,
                subscriptionStatus: 'active',
                lastCharged: admin.firestore.FieldValue.serverTimestamp(),
                lastChargedAmount: chargedAmountCents,
                currentMemberCount: currentMemberCount,
                nextChargeDate: nextChargeDate, 
            }, { merge: true });
            
            console.log(`Overseer ${overseerUid} successfully subscribed/authorized. Auth code stored.`);
            return res.status(200).send('Subscription webhook processed.');

        } catch (error) {
            console.error(`Error processing subscription charge.success for ${overseerUid}:`, error);
            return res.status(500).send('Internal server error during Firestore update.');
        }
    }
    
    if (event.event === 'charge.failure') {
        const metadata = transaction.metadata?.custom_fields;
        const overseerUidField = metadata?.find(f => f.variable_name === 'firebase_uid');

        if (overseerUidField?.value) {
             await db.collection('overseers').doc(overseerUidField.value).set({
                subscriptionStatus: 'payment_failed',
                lastAttempted: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            console.log(`Initial charge failed for overseer ${overseerUidField.value}.`);
        }
    }

    res.status(200).send('Webhook received.');
});

// =========================================================================
// 3. EXISTING MARKETPLACE/ORDER LOGIC
// =========================================================================

const ADMIN_SHARE_PERCENT = 8;

app.post('/create_seller_subaccount', async (req, res) => {
  try {
    const { uid, business_name, bank_code, account_number, contact_email } = req.body;
    if (!uid || !business_name || !bank_code || !account_number || !contact_email) {
      return res.status(400).json({ error: 'Missing required seller info' });
    }
    const paystackResponse = await axios.post(
      'https://api.paystack.co/subaccount',
      {
        business_name,
        settlement_bank: bank_code,
        account_number,
        percentage_charge: 91,
        primary_contact_email: contact_email,
      },
      {
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );
    const { status, message, data } = paystackResponse.data;
    if (!status) {
      return res.status(400).json({ error: message });
    }
    const subaccount_code = data.subaccount_code;
    await db.collection('users').doc(uid).update({
      sellerPaystackAccount: subaccount_code,
    });
    return res.json({ success: true, subaccount_code });
  } catch (error) {
    console.error('Paystack subaccount error:', error.response?.data || error.message);
    return res.status(500).json({ error: 'Failed to create subaccount' });
  }
});

app.post('/create-payment-link', async (req, res) => {
  try {
    const { email, products, orderReference } = req.body;
    if (!email || !products || !Array.isArray(products) || !orderReference) {
      return res.status(400).json({ error: 'Invalid request body' });
    }
    let totalAmount = 0;
    const subaccounts = [];
    products.forEach((product) => {
      const amountCents = Math.round(product.price * product.quantity * 100);
      totalAmount += amountCents;
      if (product.subaccount) {
        const sellerShare = Math.round(amountCents * (1 - ADMIN_SHARE_PERCENT / 100));
        subaccounts.push({
          subaccount: product.subaccount,
          share: sellerShare,
        });
      }
    });
    const body = {
      email,
      amount: totalAmount,
      currency: 'ZAR',
      channels: ['card', 'bank', 'ussd', 'qr', 'mobile_money'],
      split: subaccounts.length > 0 ? {
        type: 'flat',
        subaccounts: subaccounts,
      } : undefined,
      reference: orderReference,
    };
    
    // --- FIX: Replaced node-fetch with axios ---
    const response = await axios.post(
      'https://api.paystack.co/transaction/initialize',
      body,
      {
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );
    const data = response.data; // axios uses .data
    // -------------------------------------------
    
    if (!data.status) {
      console.error('Paystack API error:', data.message);
      return res.status(400).json({ error: data.message || 'Paystack API error' });
    }
    return res.json({ paymentLink: data.data.authorization_url });
  } catch (error) {
    console.error('Error creating payment link:', error.response?.data || error.message);
    return res.status(500).json({ error: 'Server error' });
  }
});

app.post('/paystack-webhook', async (req, res) => {
  const hash = crypto.createHmac('sha512', PAYSTACK_SECRET_KEY)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (hash !== req.headers['x-paystack-signature']) {
    return res.status(401).send('Invalid signature');
  }

  const event = req.body;
  if (event.event === 'charge.success') {
    const transaction = event.data;
    const orderReference = transaction.reference;
    
    const isSubscriptionWebhook = transaction.metadata?.custom_fields?.some(
        f => f.variable_name === 'subscription_type' && f.value === 'monthly_overseer_tier'
    );

    if (isSubscriptionWebhook) {
        return res.status(200).send('Subscription event delegated.');
    }

    const paystackAmount = transaction.amount;
    const orderDoc = await db.collection('orders').doc(orderReference).get();
    if (!orderDoc.exists) {
      console.error(`Order ${orderReference} not found.`);
      return res.status(404).send('Order not found.');
    }
    
    const orderData = orderDoc.data();
    const firestoreAmountCents = Math.round(orderData.totalPaidAmount * 100);

    if (paystackAmount !== firestoreAmountCents) {
      console.error(`Payment amount mismatch for order: ${orderReference}`);
      console.error(`Paystack amount: ${paystackAmount}, Firestore amount: ${firestoreAmountCents}`);
    }
    
    if (transaction.status === 'success') {
      try {
        await db.collection('orders').doc(orderReference).update({
          status: 'paid',
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paystackTransactionData: {
            id: transaction.id,
            amount: transaction.amount,
            currency: transaction.currency,
            channel: transaction.channel,
            gateway_response: transaction.gateway_response, 
          }
        });
        console.log(`Order ${orderReference} updated to paid.`);
        return res.status(200).send('Webhook received and order updated.');
      } catch (error) {
        console.error('Error updating order status:', error);
        return res.status(500).send('Internal server error.');
      }
    }
  }

  res.status(200).send('Webhook received.');
});

// =========================================================================
// 4. NEW EMAIL ROUTE (Integrated into the 'api' app)
// =========================================================================

let emailTransporter; // Use a unique name
app.post('/sendCustomEmail', async (req, res) => {
    const { to, subject, body, attachmentUrl } = req.body;

    if (!to || !subject || !body) {
      return res.status(400).send({ error: "Missing required fields: to, subject, body" });
    }

    try {
      if (!emailTransporter) { 
        if (!GMAIL_EMAIL || !GMAIL_PASSWORD) {
           console.error("Gmail email or password not set in functions config.");
           return res.status(500).send({ error: "Email service not configured." });
        }
        
        emailTransporter = nodemailer.createTransport({
          service: "gmail",
          auth: {
            user: GMAIL_EMAIL,
            pass: GMAIL_PASSWORD,
          },
        });
      }

      let emailAttachments = [];

      if (attachmentUrl) {
        console.log(`Downloading attachment from: ${attachmentUrl}`);
        try {
          const response = await axios.get(attachmentUrl, {
            responseType: "arraybuffer",
          });
          const buffer = Buffer.from(response.data, "binary");
          
          emailAttachments.push({
            filename: "Report.pdf",
            content: buffer,
            contentType: "application/pdf",
          });

        } catch (e) {
          console.error("Failed to download attachment:", e);
          return res.status(500).send({ error: "Failed to download attachment." });
        }
      }

      const mailOptions = {
        from: `"Dankie App" <${GMAIL_EMAIL}>`,
        to: to,
        subject: subject,
        html: `<p>${body.replace(/\n/g, "<br>")}</p>`,
        attachments: emailAttachments,
      };

      await emailTransporter.sendMail(mailOptions);
      console.log(`Email successfully sent to ${to}`);
      return res.status(200).send({ success: true });

    } catch (error) {
      console.error("Error sending email:", error);
      return res.status(500).send({ error: "Failed to send email." });
    }
});


// =========================================================================
// 5. EXPORT THE 'api' FUNCTION
// =========================================================================
exports.api = functions.https.onRequest(app);

// =========================================================================
// 6. SCHEDULED SUBSCRIPTION CRON JOB (FIXED TO V1 SYNTAX)
exports.monthlySubscriptionCharge = onSchedule(
  {
    schedule: '0 0 1 * *', // Runs at midnight UTC on the 1st of every month
    timeZone: 'UTC',
    region: 'us-central1', // V2 functions often require a region
  },
  async (event) => {
    
    console.log('Starting monthly subscription charge job.');

    const activeOverseersSnapshot = await db.collection('overseers')
        .where('subscriptionStatus', '==', 'active')
        .get();

    if (activeOverseersSnapshot.empty) {
      console.log('No active overseers found to charge.');
      return null;
    }

    const chargePromises = [];

    for (const doc of activeOverseersSnapshot.docs) {
      const overseerData = doc.data();
      const overseerId = doc.id;
      
      if (overseerData.nextChargeDate && overseerData.nextChargeDate.toMillis() > Date.now()) {
        console.log(`Overseer ${overseerId} not yet due for charge.`);
        continue; 
      }

      chargePromises.push((async () => {
        const authCode = overseerData.paystackAuthCode;
        const email = overseerData.paystackEmail;

        if (!authCode || !email) {
          console.error(`Missing auth code or email for overseer ${overseerId}. Marking as error.`);
          await doc.ref.update({ subscriptionStatus: 'authorization_error' });
          return;
        }

        const membersSnapshot = await db.collection('users')
            .where('overseerUid', '==', overseerId)
            .get();
        const currentMemberCount = membersSnapshot.size;
        const chargeAmountCents = determineSubscriptionAmount(currentMemberCount);

        try {
          const chargeResponse = await axios.post(
            `${PAYSTACK_API_BASE}/transaction/charge_authorization`,
            {
              authorization_code: authCode,
              email: email,
              amount: chargeAmountCents,
              currency: 'ZAR',
              metadata: { 
                member_count: currentMemberCount,
                charged_tier_cents: chargeAmountCents 
              }
            },
            {
              headers: {
                Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
                'Content-Type': 'application/json',
              },
            }
          );

          if (chargeResponse.data.status) {
            await doc.ref.update({
              lastCharged: admin.firestore.FieldValue.serverTimestamp(),
              lastChargedAmount: chargeAmountCents,
              currentMemberCount: currentMemberCount,
              nextChargeDate: admin.firestore.Timestamp.fromMillis(
                Date.now() + (30 * 24 * 60 * 60 * 1000)
              ),
              subscriptionStatus: 'active',
            });
            console.log(`Successfully charged overseer ${overseerId} R${(chargeAmountCents / 100).toFixed(2)}.`);
          } else {
            console.error(`Charge failed for overseer ${overseerId}: ${chargeResponse.data.message}`);
            await doc.ref.update({ 
              subscriptionStatus: 'payment_failed',
              lastAttemptedChargeAmount: chargeAmountCents,
              lastAttempted: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (chargeError) {
          console.error(`API call failed for overseer ${overseerId}:`, chargeError.response?.data || chargeError.message);
          await doc.ref.update({ 
            subscriptionStatus: 'payment_failed',
            lastAttempted: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      })());
    }

    await Promise.all(chargePromises);
    console.log('Monthly subscription charge job completed.');
    return null;
  }
);