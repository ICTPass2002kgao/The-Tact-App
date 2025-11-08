// =========================================================================
// IMPORTS AND INITIALIZATION
// =========================================================================
const functions = require('firebase-functions');
const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
const fetch = require('node-fetch');
const admin = require('firebase-admin');
const crypto = require('crypto');
// 2ND GEN IMPORTS for HTTP and Scheduled functions
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler"); 

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Create an Express app
const app = express();
app.use(bodyParser.json());

// **SECURE:** Retrieve the secret key from environment configuration
const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key; 
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
        // Default to TIER1 as the minimum paid subscription if they manually subscribe
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

        // Double check the incoming amount against server-side logic for security
        if (determineSubscriptionAmount(memberCount) !== amount) {
            console.warn(`Amount mismatch for UID ${uid}. Client sent ${amount}, server calculated ${determineSubscriptionAmount(memberCount)}.`);
        }
        
        // Generate a unique reference for the authorization transaction
        const reference = `AUTH_${uid}_${Date.now()}`;
        
        const body = {
            email: email,
            amount: amount, // Amount passed from client (in cents)
            currency: 'ZAR',
            reference: reference, // Unique reference for the initial transaction
            channels: ['card', 'bank', 'ussd', 'qr'],
            // Metadata is crucial for the webhook to know this is a subscription initiation
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
    // 1. Security Check: Verify Paystack Signature (Crucial)
    const hash = crypto.createHmac('sha512', PAYSTACK_SECRET_KEY)
        .update(JSON.stringify(req.body))
        .digest('hex');

    if (hash !== req.headers['x-paystack-signature']) {
        console.error("Subscription Webhook Security Failure: Mismatched signature.");
        return res.status(401).send('Unauthorized');
    }
    
    const event = req.body;
    const transaction = event.data;

    // Check if it's a successful charge event for a subscription
    if (event.event === 'charge.success' && transaction.status === 'success') {
        
        // Extract metadata saved during initialization
        const metadata = transaction.metadata?.custom_fields;
        const subscriptionTypeField = metadata?.find(f => f.variable_name === 'subscription_type');
        const overseerUidField = metadata?.find(f => f.variable_name === 'firebase_uid');
        const memberCountField = metadata?.find(f => f.variable_name === 'member_count');

        // Verify this is the subscription type webhook we care about
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
            // Determine the next charge date (30 days from now)
            const nextChargeDate = admin.firestore.Timestamp.fromMillis(
                Date.now() + (30 * 24 * 60 * 60 * 1000)
            );
            
            const currentMemberCount = memberCountField ? parseInt(memberCountField.value) : 0;

            // 2. Update the overseer document for recurring charges
            await db.collection('overseers').doc(overseerUid).update({
                paystackAuthCode: authCode,
                paystackEmail: email,
                subscriptionStatus: 'active', // Set to active on successful initial charge/authorization
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
    
    // Process failed initial charges
    if (event.event === 'charge.failure') {
        const metadata = transaction.metadata?.custom_fields;
        const overseerUidField = metadata?.find(f => f.variable_name === 'firebase_uid');

        if (overseerUidField?.value) {
             await db.collection('overseers').doc(overseerUidField.value).update({
                subscriptionStatus: 'payment_failed',
                lastAttempted: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            console.log(`Initial charge failed for overseer ${overseerUidField.value}.`);
        }
    }

    // Acknowledge the webhook regardless of event type to prevent retries
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
      // ** CORRECTION: Paystack uses 'reference' for order tracking.
      reference: orderReference,
    };
    const response = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const data = await response.json();
    if (!data.status) {
      console.error('Paystack API error:', data.message);
      return res.status(400).json({ error: data.message || 'Paystack API error' });
    }
    return res.json({ paymentLink: data.data.authorization_url });
  } catch (error) {
    console.error('Error creating payment link:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

app.post('/paystack-webhook', async (req, res) => {
  const hash = crypto.createHmac('sha512', PAYSTACK_SECRET_KEY)
    .update(JSON.stringify(req.body))
    .digest('hex');

  // Verify that the request is from Paystack
  if (hash !== req.headers['x-paystack-signature']) {
    return res.status(401).send('Invalid signature');
  }

  const event = req.body;
  if (event.event === 'charge.success') {
    const transaction = event.data;
    const orderReference = transaction.reference;
    
    // Check if this webhook is for an 'order' and not a 'subscription'
    const isSubscriptionWebhook = transaction.metadata?.custom_fields?.some(
        f => f.variable_name === 'subscription_type' && f.value === 'monthly_overseer_tier'
    );

    if (isSubscriptionWebhook) {
        // Ignore here; this event is handled by /paystack-subscription-webhook
        return res.status(200).send('Subscription event delegated.');
    }

    // Process as an Order Webhook
    const paystackAmount = transaction.amount;
    
    // Fetch the order from Firestore
    const orderDoc = await db.collection('orders').doc(orderReference).get();
    if (!orderDoc.exists) {
      console.error(`Order ${orderReference} not found.`);
      return res.status(404).send('Order not found.');
    }
    
    const orderData = orderDoc.data();
    
    // Convert the stored amount to cents for a reliable comparison.
    const firestoreAmountCents = Math.round(orderData.totalPaidAmount * 100);

    // Now, compare the amounts.
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
// 4. FUNCTION EXPORTS (2ND GEN)
// =========================================================================

// EXPORT 1: HTTP Express App (2nd Gen)
// This runs the Express app 'app' for all the routes defined above.
exports.api = onRequest(app);

// EXPORT 2: SCHEDULED SUBSCRIPTION CRON JOB (2nd Gen)
exports.monthlySubscriptionCharge = onSchedule(
  {
    schedule: '0 0 1 * *',
    timeZone: 'UTC',
  },
  async (event) => {
    console.log('Starting monthly subscription charge job.');

    // Get all active overseer subscriptions
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
      
      // Use the nextChargeDate field set by the webhook/last charge
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

        // Get the current member count from the 'users' collection
        const membersSnapshot = await db.collection('users')
            .where('overseerUid', '==', overseerId)
            .get();
        const currentMemberCount = membersSnapshot.size;

        // Determine the dynamic charge amount (in cents) using the shared function
        const chargeAmountCents = determineSubscriptionAmount(currentMemberCount);

        // Call Paystack's Charge Authorization API
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
            // Success: Update Firestore with new charge details
            await doc.ref.update({
              lastCharged: admin.firestore.FieldValue.serverTimestamp(),
              lastChargedAmount: chargeAmountCents,
              currentMemberCount: currentMemberCount,
              // Set next charge date for next month (30 days from now)
              nextChargeDate: admin.firestore.Timestamp.fromMillis(
                Date.now() + (30 * 24 * 60 * 60 * 1000)
              ),
              subscriptionStatus: 'active',
            });
            console.log(`Successfully charged overseer ${overseerId} R${(chargeAmountCents / 100).toFixed(2)}.`);
          } else {
            // Failure: Log the failure and update status to flag for attention
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