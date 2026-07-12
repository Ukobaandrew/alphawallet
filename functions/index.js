const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

// Initialize Firebase Admin
admin.initializeApp();

// Get SendGrid configuration
const sendgridConfig = functions.config().sendgrid || {};
const sendgridApiKey = sendgridConfig.apikey;
const fromEmail = sendgridConfig.fromemail || 'info@dighostassettech.com.ng';
const fromName = sendgridConfig.fromname || 'Alpha Bank';

// Set up SendGrid
if (!sendgridApiKey) {
    console.error('❌ SendGrid API key is not configured');
    console.error('Run: firebase functions:config:set sendgrid.apikey="SG.WbVopQCATfmbmKOKdxvHmQ.iwXVlWjjrTijrSiSGcaRsWnWVjFWGhcSQ0SnHb3dULQ"');
} else {
    sgMail.setApiKey(sendgridApiKey);
    console.log('✅ SendGrid configured successfully');
}

/**
 * Main Cloud Function: Send transaction email notification
 * Triggers when a new transaction is added to Firestore
 */
exports.sendTransactionEmail = functions.firestore
    .document('users/{userId}/transactions/{transactionId}')
    .onCreate(async (snapshot, context) => {
        try {
            console.log('🚀 Starting transaction email process...');
            
            const transaction = snapshot.data();
            const userId = context.params.userId;
            const transactionId = context.params.transactionId;
            
            // Validate transaction data
            if (!transaction || transaction.amount === undefined) {
                console.log('⚠️ Invalid transaction data, skipping...');
                return null;
            }
            
            console.log(`📊 Processing transaction: ${transactionId} for user: ${userId}`);
            
            // Get user data from Firestore
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .get();
            
            if (!userDoc.exists) {
                console.log(`❌ User ${userId} not found in Firestore`);
                return null;
            }
            
            const userData = userDoc.data();
            const userEmail = userData.email;
            
            if (!userEmail) {
                console.log('❌ User has no email address');
                return null;
            }
            
            // Check notification preferences
            const notificationPrefs = userData.notificationEnabled;
            if (notificationPrefs === false) {
                console.log('📴 User has disabled email notifications');
                return null;
            }
            
            // Prepare email data
            const amount = Math.abs(transaction.amount);
            const isCredit = transaction.amount > 0;
            const formattedAmount = new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: transaction.currency || 'USD'
            }).format(amount);
            
            // Format date
            let transactionDate;
            if (transaction.timestamp && transaction.timestamp.toDate) {
                transactionDate = transaction.timestamp.toDate().toLocaleString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });
            } else {
                transactionDate = new Date().toLocaleString('en-US');
            }
            
            // Prepare email message
            const msg = {
                to: userEmail,
                from: {
                    email: fromEmail,
                    name: fromName
                },
                subject: `Alpha Bank: ${isCredit ? 'Credit' : 'Debit'} of ${formattedAmount}`,
                html: generateEmailHTML(userData, transaction, formattedAmount, isCredit, transactionDate),
                text: generateEmailText(userData, transaction, formattedAmount, isCredit, transactionDate),
                trackingSettings: {
                    clickTracking: { enable: true },
                    openTracking: { enable: true }
                }
            };
            
            console.log(`📧 Sending email to: ${userEmail}`);
            
            // Send email via SendGrid
            await sgMail.send(msg);
            
            console.log('✅ Email sent successfully!');
            
            // Log the email in Firestore
            await admin.firestore()
                .collection('users')
                .doc(userId)
                .collection('email_logs')
                .add({
                    transactionId: transactionId,
                    email: userEmail,
                    amount: transaction.amount,
                    type: transaction.type || 'transaction',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: 'sent'
                });
            
            return { success: true, email: userEmail };
            
        } catch (error) {
            console.error('❌ Error sending transaction email:', error);
            
            // Log error to Firestore
            try {
                await admin.firestore()
                    .collection('email_errors')
                    .add({
                        userId: context.params.userId,
                        transactionId: context.params.transactionId,
                        error: error.message || error.toString(),
                        timestamp: admin.firestore.FieldValue.serverTimestamp()
                    });
            } catch (logError) {
                console.error('Failed to log error:', logError);
            }
            
            return { success: false, error: error.message };
        }
    });

/**
 * Generate HTML email template
 */
function generateEmailHTML(userData, transaction, formattedAmount, isCredit, date) {
    const userName = userData.name || userData.firstName || userData.email?.split('@')[0] || 'Valued Customer';
    const transactionType = transaction.type || transaction.transactionType || 'Transaction';
    const status = transaction.status || 'Completed';
    
    return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Alpha Bank Transaction</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                padding: 40px 20px;
                margin: 0;
            }
            .email-container {
                max-width: 600px;
                margin: 0 auto;
                background: white;
                border-radius: 20px;
                overflow: hidden;
                box-shadow: 0 20px 60px rgba(0, 51, 102, 0.3);
            }
            .header {
                background: linear-gradient(135deg, #003366 0%, #004080 100%);
                padding: 40px;
                text-align: center;
                color: white;
            }
            .logo {
                width: 80px;
                height: 80px;
                margin: 0 auto 20px;
                background: white;
                border-radius: 20px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 32px;
                font-weight: 800;
                color: #003366;
            }
            .content {
                padding: 40px;
            }
            .amount {
                font-size: 48px;
                font-weight: 800;
                text-align: center;
                margin: 30px 0;
                color: ${isCredit ? '#27ae60' : '#e74c3c'};
            }
            .transaction-details {
                background: #f8f9fa;
                border-radius: 15px;
                padding: 25px;
                margin: 30px 0;
                border-left: 5px solid ${isCredit ? '#27ae60' : '#e74c3c'};
            }
            .detail-row {
                display: flex;
                justify-content: space-between;
                padding: 12px 0;
                border-bottom: 1px solid #e9ecef;
            }
            .detail-row:last-child {
                border-bottom: none;
            }
            .label {
                font-weight: 600;
                color: #003366;
            }
            .footer {
                background: #003366;
                color: white;
                padding: 30px;
                text-align: center;
            }
            .support-box {
                background: #e3f2fd;
                border-radius: 15px;
                padding: 20px;
                margin: 30px 0;
                text-align: center;
                border: 2px solid #2196f3;
            }
            @media (max-width: 480px) {
                .content { padding: 20px; }
                .header { padding: 30px 20px; }
                .amount { font-size: 36px; }
            }
        </style>
    </head>
    <body>
        <div class="email-container">
            <div class="header">
                <div class="logo">AB</div>
                <h1>Alpha Bank</h1>
                <p>Transaction Notification</p>
            </div>
            
            <div class="content">
                <h2 style="color: #003366; margin-bottom: 20px;">Hello ${userName},</h2>
                <p style="color: #666; margin-bottom: 10px;">
                    A transaction has been processed on your Alpha Bank account:
                </p>
                
                <div class="amount">
                    ${isCredit ? '+' : '−'}${formattedAmount}
                </div>
                
                <div class="transaction-details">
                    <div class="detail-row">
                        <span class="label">Description</span>
                        <span>${transaction.description || transactionType}</span>
                    </div>
                    <div class="detail-row">
                        <span class="label">Date & Time</span>
                        <span>${date}</span>
                    </div>
                    <div class="detail-row">
                        <span class="label">Type</span>
                        <span>${transactionType}</span>
                    </div>
                    <div class="detail-row">
                        <span class="label">Status</span>
                        <span style="color: ${status === 'completed' ? '#27ae60' : '#f39c12'}; font-weight: 600;">
                            ${status}
                        </span>
                    </div>
                    ${transaction.referenceNumber ? `
                    <div class="detail-row">
                        <span class="label">Reference</span>
                        <span>${transaction.referenceNumber}</span>
                    </div>` : ''}
                </div>
                
                <div class="support-box">
                    <h3 style="color: #1565c0; margin-bottom: 15px;">Need Help?</h3>
                    <p style="color: #1976d2; margin-bottom: 10px;">
                        📞 24/7 Support: <strong>1-800-ALPHA-BANK</strong>
                    </p>
                    <p style="color: #1976d2;">
                        ✉️ Email: <strong>support@alphabank.com</strong>
                    </p>
                </div>
                
                <p style="color: #666; font-size: 14px; text-align: center; margin-top: 30px;">
                    <em>This is an automated message. Please do not reply.</em>
                </p>
            </div>
            
            <div class="footer">
                <p>© ${new Date().getFullYear()} Alpha Bank. All rights reserved.</p>
                <p style="opacity: 0.8; margin-top: 10px;">Member FDIC • Equal Housing Lender</p>
                <p style="opacity: 0.6; font-size: 12px; margin-top: 10px;">
                    To manage email notifications, visit Settings in the Alpha Bank app.
                </p>
            </div>
        </div>
    </body>
    </html>
    `;
}

/**
 * Generate plain text email
 */
function generateEmailText(userData, transaction, formattedAmount, isCredit, date) {
    const userName = userData.name || userData.firstName || userData.email?.split('@')[0] || 'Valued Customer';
    const transactionType = transaction.type || transaction.transactionType || 'Transaction';
    
    return `
ALPHA BANK - TRANSACTION NOTIFICATION
═══════════════════════════════════════════

Hello ${userName},

A transaction has been processed on your Alpha Bank account:

═══════════════════════════════════════════
TRANSACTION DETAILS:
• Amount: ${isCredit ? '+' : '-'}${formattedAmount}
• Description: ${transaction.description || transactionType}
• Date & Time: ${date}
• Type: ${transactionType}
• Status: ${transaction.status || 'Completed'}
${transaction.referenceNumber ? `• Reference: ${transaction.referenceNumber}` : ''}
═══════════════════════════════════════════

NEED HELP?
──────────
• 24/7 Customer Support: 1-800-ALPHA-BANK
• Email Support: support@alphabank.com
• Live Chat: Available in Alpha Bank app

SECURITY REMINDER:
─────────────────
If you don't recognize this transaction, contact us immediately.

© ${new Date().getFullYear()} Alpha Bank. Member FDIC. Equal Housing Lender.
This is an automated message. Please do not reply.
    `;
}

/**
 * Test function to verify email setup
 */
exports.sendTestEmail = functions.https.onCall(async (data, context) => {
    try {
        // Check if user is authenticated
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                'You must be logged in to send test emails'
            );
        }
        
        const userEmail = context.auth.token.email || data.email;
        
        if (!userEmail) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Email address is required'
            );
        }
        
        // Send test email
        const msg = {
            to: userEmail,
            from: {
                email: fromEmail,
                name: fromName
            },
            subject: '✅ Alpha Bank: Cloud Functions Test',
            html: `
            <div style="font-family: Arial, sans-serif; padding: 30px; max-width: 600px; margin: 0 auto;">
                <div style="background: #003366; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0;">
                    <h1>Alpha Bank</h1>
                    <p>Cloud Functions Test</p>
                </div>
                <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px;">
                    <h2 style="color: #003366;">✅ Test Successful!</h2>
                    <p>This is a test email to verify that your Cloud Functions are properly set up.</p>
                    <p><strong>Status:</strong> ✅ Working</p>
                    <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
                    <p>If you received this, transaction emails will work automatically.</p>
                </div>
            </div>
            `,
            text: `Alpha Bank Cloud Functions Test\n\nIf you receive this, email system is working.\n\nTime: ${new Date().toLocaleString()}`
        };
        
        await sgMail.send(msg);
        
        console.log(`✅ Test email sent to: ${userEmail}`);
        
        return {
            success: true,
            message: 'Test email sent successfully',
            email: userEmail,
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('❌ Test email error:', error);
        
        throw new functions.https.HttpsError(
            'internal',
            `Failed to send test email: ${error.message}`
        );
    }
});

/**
 * HTTP endpoint for health check
 */
exports.healthCheck = functions.https.onRequest(async (req, res) => {
    try {
        const config = functions.config().sendgrid || {};
        
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            projectId: process.env.GCLOUD_PROJECT,
            region: process.env.FUNCTION_REGION,
            sendgrid: {
                configured: !!config.apikey,
                hasFromEmail: !!config.fromemail,
                hasFromName: !!config.fromname
            },
            instructions: {
                testEmail: 'Call sendTestEmail from your Flutter app',
                deploy: 'firebase deploy --only functions',
                logs: 'firebase functions:log'
            }
        });
    } catch (error) {
        res.status(500).json({
            status: 'error',
            error: error.message
        });
    }
});

console.log('✅ Cloud Functions module loaded successfully');
console.log('📧 SendGrid configured:', !!sendgridApiKey);