// The updated way to get environment variables
const functions = require('firebase-functions');
const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
const fetch = require('node-fetch');
const admin = require('firebase-admin');
const crypto = require('crypto'); // <-- Corrected: Imported at the top

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Create an Express app
const app = express();
app.use(bodyParser.json());

// Get the Paystack secret key from the environment variable
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;
const ADMIN_SHARE_PERCENT = 8;

/**
 * All your routes now go here.
 */
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
      // Your client app passes the Firestore document ID as the orderReference.
      // This is the correct way to map back to the order.
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
// A more robust and correct webhook handler
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
    
    // **KEY CORRECTION:** Get the requested amount, not the final amount.
    // The amount paid by the customer is in `amount`.
    const paystackAmount = transaction.amount;
    
    // Fetch the order from Firestore
    const orderDoc = await db.collection('orders').doc(orderReference).get();
    if (!orderDoc.exists) {
      console.error(`Order ${orderReference} not found.`);
      return res.status(404).send('Order not found.');
    }
    
    const orderData = orderDoc.data();
    
    // Convert the stored amount to cents for a reliable comparison.
    // Ensure `totalPaidAmount` is stored as a number, not a string.
    const firestoreAmountCents = Math.round(orderData.totalPaidAmount * 100);

    // Now, compare the amounts.
    if (paystackAmount !== firestoreAmountCents) {
      console.error(`Payment amount mismatch for order: ${orderReference}`);
      console.error(`Paystack amount: ${paystackAmount}, Firestore amount: ${firestoreAmountCents}`);
      // Log the mismatch but still update the order to 'paid' if the status is 'success'.
      // This is a business decision. You might choose to flag it for manual review instead.
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
            gateway_response: transaction.gateway_response, // Include this for debugging
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
// The key line: Export the Express app as an HTTP function
exports.api = functions.https.onRequest(app);