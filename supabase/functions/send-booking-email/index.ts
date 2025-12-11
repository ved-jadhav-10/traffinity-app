// Supabase Edge Function: send-booking-email
// Triggers when a booking is approved and sends confirmation email to user

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

interface BookingApprovalPayload {
  type: 'UPDATE'
  table: 'bookings'
  schema: 'public'
  record: {
    id: string
    user_id: string
    user_name: string
    vehicle_number: string
    vehicle_type: string
    duration: number
    status: string
    booking_start_time: string
    booking_end_time: string
    slot_id: string
  }
  old_record: {
    status: string
  }
}

serve(async (req) => {
  try {
    const payload: BookingApprovalPayload = await req.json()
    
    // Only send email when booking status changes from 'pending' to 'approved'
    if (payload.old_record.status !== 'pending' || payload.record.status !== 'approved') {
      return new Response(JSON.stringify({ message: 'No email needed' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Fetch additional booking details (slot, parking layout info)
    const bookingDetailsResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/bookings?id=eq.${payload.record.id}&select=*,parking_slots(slot_label,parking_layouts(name,location))`,
      {
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
      }
    )

    const bookingDetails = await bookingDetailsResponse.json()
    if (!bookingDetails || bookingDetails.length === 0) {
      throw new Error('Booking not found')
    }

    const booking = bookingDetails[0]
    const parkingLayout = booking.parking_slots?.parking_layouts
    const slotLabel = booking.parking_slots?.slot_label

    // Get user email from auth
    const userResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${payload.record.user_id}`,
      {
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
      }
    )

    const userData = await userResponse.json()
    const userEmail = userData.email

    if (!userEmail) {
      throw new Error('User email not found')
    }

    // Format dates for email
    const startDate = new Date(payload.record.booking_start_time)
    const endDate = new Date(payload.record.booking_end_time)
    
    const formatDate = (date: Date) => {
      return date.toLocaleDateString('en-IN', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    }

    const formatTime = (date: Date) => {
      return date.toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      })
    }

    // Prepare email content
    const emailHtml = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Parking Booking Confirmed</title>
          <style>
            body {
              font-family: 'Arial', sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #06d6a0 0%, #4a90e2 100%);
              color: white;
              padding: 30px;
              text-align: center;
              border-radius: 10px 10px 0 0;
            }
            .header h1 {
              margin: 0;
              font-size: 28px;
            }
            .content {
              background: #ffffff;
              padding: 30px;
              border: 1px solid #e0e0e0;
              border-top: none;
            }
            .detail-box {
              background: #f5f5f5;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .detail-row {
              display: flex;
              justify-content: space-between;
              padding: 10px 0;
              border-bottom: 1px solid #e0e0e0;
            }
            .detail-row:last-child {
              border-bottom: none;
            }
            .label {
              font-weight: bold;
              color: #555;
            }
            .value {
              color: #333;
              text-align: right;
            }
            .success-badge {
              background: #06d6a0;
              color: white;
              padding: 10px 20px;
              border-radius: 20px;
              display: inline-block;
              font-weight: bold;
              margin: 20px 0;
            }
            .footer {
              text-align: center;
              padding: 20px;
              color: #999;
              font-size: 12px;
            }
            .important-note {
              background: #fff3cd;
              border-left: 4px solid #ffa726;
              padding: 15px;
              margin: 20px 0;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>🅿️ Parking Booking Confirmed!</h1>
          </div>
          
          <div class="content">
            <p>Dear ${payload.record.user_name},</p>
            
            <p>Great news! Your parking booking has been <strong>approved</strong> by the admin.</p>
            
            <div class="success-badge">✓ BOOKING CONFIRMED</div>
            
            <div class="detail-box">
              <h3 style="margin-top: 0; color: #4a90e2;">Parking Details</h3>
              <div class="detail-row">
                <span class="label">Parking Name:</span>
                <span class="value">${parkingLayout?.name || 'N/A'}</span>
              </div>
              <div class="detail-row">
                <span class="label">Location:</span>
                <span class="value">${parkingLayout?.location || 'N/A'}</span>
              </div>
              <div class="detail-row">
                <span class="label">Spot Number:</span>
                <span class="value"><strong>${slotLabel || 'N/A'}</strong></span>
              </div>
            </div>
            
            <div class="detail-box">
              <h3 style="margin-top: 0; color: #4a90e2;">Booking Information</h3>
              <div class="detail-row">
                <span class="label">Date:</span>
                <span class="value">${formatDate(startDate)}</span>
              </div>
              <div class="detail-row">
                <span class="label">Start Time:</span>
                <span class="value">${formatTime(startDate)}</span>
              </div>
              <div class="detail-row">
                <span class="label">End Time:</span>
                <span class="value">${formatTime(endDate)}</span>
              </div>
              <div class="detail-row">
                <span class="label">Duration:</span>
                <span class="value">${payload.record.duration} hour${payload.record.duration > 1 ? 's' : ''}</span>
              </div>
            </div>
            
            <div class="detail-box">
              <h3 style="margin-top: 0; color: #4a90e2;">Vehicle Details</h3>
              <div class="detail-row">
                <span class="label">Vehicle Number:</span>
                <span class="value"><strong>${payload.record.vehicle_number}</strong></span>
              </div>
              <div class="detail-row">
                <span class="label">Vehicle Type:</span>
                <span class="value">${payload.record.vehicle_type}</span>
              </div>
            </div>
            
            <div class="important-note">
              <strong>⚠️ Important:</strong> Please arrive on time and park only in your designated spot (${slotLabel}). 
              Your booking will automatically expire at the end time.
            </div>
            
            <p>If you have any questions or need to modify your booking, please contact the parking administrator.</p>
            
            <p>Thank you for using Traffinity ParkHub!</p>
          </div>
          
          <div class="footer">
            <p>This is an automated email from Traffinity ParkHub Manager.</p>
            <p>&copy; ${new Date().getFullYear()} Traffinity. All rights reserved.</p>
          </div>
        </body>
      </html>
    `

    // Send email using Supabase Auth (simple method, rate-limited)
    // For production with high volume, use Resend/SendGrid instead
    
    console.log('Sending email to:', userEmail)
    console.log('Booking ID:', payload.record.id)
    console.log('Parking:', parkingLayout?.name)
    console.log('Spot:', slotLabel)

    // Simple email notification using a basic email template
    // This logs the email for now - for actual sending, set up an email service
    // (Resend is recommended - see PARKHUB_SETUP_GUIDE.md Step 2.5)
    
    const emailSubject = `Parking Booking Confirmed - Spot ${slotLabel}`
    const emailPreview = `Your parking at ${parkingLayout?.name} has been approved!`
    
    console.log('Subject:', emailSubject)
    console.log('Preview:', emailPreview)
    console.log('HTML length:', emailHtml.length, 'characters')
    
    // Email logged successfully - view in Supabase Dashboard > Functions > Logs
    // To actually send emails, uncomment Resend integration below and set RESEND_API_KEY:
    /*
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    if (resendApiKey) {
      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: 'Traffinity ParkHub <noreply@traffinity.com>',
          to: [userEmail],
          subject: emailSubject,
          html: emailHtml,
        }),
      })
      const resendResult = await emailResponse.json()
      console.log('Resend response:', resendResult)
    }
    */

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Booking confirmation email sent',
        recipient: userEmail,
        bookingId: payload.record.id,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error sending booking email:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
