const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')('sk_test_51RkEzYFhCUXnfsMqfjJeo9uSWnzBD42wXi5JVkcVTKbzTjXg6K91IbQ71hLyruvFXtNSDS7NoKmJe7mp93FLEOjr00zw0tVYFh');

admin.initializeApp();

exports.createStripePaymentLink = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const data = req.body;
    console.log('Raw incoming data:', JSON.stringify(data));

    // Validate required fields
    if (!data.products || !Array.isArray(data.products)) {
      throw new Error('Products array is required');
    }

    // Create Firestore order
    const orderRef = admin.firestore().collection('orders').doc();
    await orderRef.set({
      userId: data.userId,
      products: data.products,
      amount: data.amount,
      currency: data.currency || 'ZAR',
      address: data.address,
      needsDelivery: data.needsDelivery,
      deliveryCharge: data.deliveryCharge || 0,
      paymentMethod: data.paymentMethod || 'Credit/Debit Card (Stripe Payment Link)',
      status: 'pending_payment',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      orderReference: data.orderReference,
    });

    // Prepare line items - STRIPE-SPECIFIC FORMATTING
    const lineItems = data.products.map(product => {
      // Convert price to cents (Stripe requires integers)
      const unitAmount = Math.round(parseFloat(product.price) * 100);
      
      return {
        price_data: {
          currency: (data.currency || 'zar').toLowerCase(),
          product_data: {
            name: product.productName || 'Unnamed Product',
            // Add more product details if needed
          },
          unit_amount: unitAmount,
        },
        quantity: parseInt(product.quantity) || 1,
      };
    });

    // Add delivery fee if needed
    if (data.needsDelivery && data.deliveryCharge > 0) {
      lineItems.push({
        price_data: {
          currency: (data.currency || 'zar').toLowerCase(),
          product_data: {
            name: 'Delivery Fee',
          },
          unit_amount: Math.round(parseFloat(data.deliveryCharge) * 100),
        },
        quantity: 1,
      });
    }

    console.log('Final line items being sent to Stripe:', JSON.stringify(lineItems, null, 2));

    // Create Stripe Payment Link with explicit parameters
    const paymentLink = await stripe.paymentLinks.create({
      line_items: lineItems,
      after_completion: {
        type: 'redirect',
        redirect: {
          url: `https://your-app.com/payment-success?orderId=${orderRef.id}`,
        },
      },
      metadata: {
        firebase_order_id: orderRef.id,
        firebase_user_id: data.userId,
      },
      automatic_tax: {
        enabled: false, // Set to true if you need tax calculation
      },
    });

    return res.status(200).json({
      success: true,
      paymentLinkUrl: paymentLink.url,
      orderId: orderRef.id,
    });

  } catch (error) {
    console.error('FULL ERROR DETAILS:', {
      message: error.message,
      type: error.type,
      stack: error.stack,
      raw: error.raw ? error.raw.message : null,
    });

    return res.status(500).json({
      success: false,
      error: error.message,
      type: error.type || 'StripeAPIError',
      details: error.raw ? error.raw.message : null,
    });
  }
});