import Foundation

public struct CaptivePortalTemplate: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let description: String
    public let htmlContent: String
    
    public init(id: String, title: String, category: String, description: String, htmlContent: String) {
        self.id = id
        self.title = title
        self.category = category
        self.description = description
        self.htmlContent = htmlContent
    }
}

public struct CaptivePortalDefaults {
    public static let corporateGuestAup = CaptivePortalTemplate(
        id: "corporate_guest_aup",
        title: "Corporate Guest Wi-Fi (AUP)",
        category: "Enterprise",
        description: "Modern dark glassmorphism corporate guest onboarding with Acceptable Use Policy agreement.",
        htmlContent: """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Corporate Guest Access</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #0c0f17; color: #e1e7f0; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
    .card { background: rgba(23, 29, 44, 0.85); border: 1px solid rgba(0, 240, 255, 0.2); border-radius: 16px; padding: 32px; max-width: 440px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.6); backdrop-filter: blur(12px); }
    .header { text-align: center; margin-bottom: 24px; }
    .icon { width: 56px; height: 56px; border-radius: 14px; background: rgba(0, 240, 255, 0.12); border: 1px solid rgba(0, 240, 255, 0.3); display: flex; align-items: center; justify-content: center; margin: 0 auto 12px; font-size: 26px; }
    h1 { font-size: 20px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px; }
    p.sub { font-size: 13px; color: #8e9bb0; margin-top: 4px; }
    .terms-box { background: rgba(10, 14, 22, 0.7); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 10px; padding: 14px; height: 130px; overflow-y: auto; font-size: 11px; line-height: 1.5; color: #9aa9bf; margin: 18px 0; }
    .checkbox-row { display: flex; align-items: flex-start; gap: 10px; margin-bottom: 22px; font-size: 12px; color: #c3d0e2; cursor: pointer; }
    .checkbox-row input { margin-top: 2px; accent-color: #00f0ff; width: 16px; height: 16px; }
    button { width: 100%; background: linear-gradient(135deg, #00f0ff 0%, #00a8ff 100%); color: #040914; border: none; padding: 14px; border-radius: 10px; font-size: 14px; font-weight: 700; cursor: pointer; transition: transform 0.1s, filter 0.2s; }
    button:hover { filter: brightness(1.1); transform: translateY(-1px); }
    .footer { text-align: center; margin-top: 20px; font-size: 10px; color: #627289; font-family: monospace; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="icon">📶</div>
      <h1>Enterprise Secure Wi-Fi</h1>
      <p class="sub">High-Speed Guest Wireless Network</p>
    </div>
    
    <div class="terms-box">
      <strong>Acceptable Use Policy (AUP)</strong><br>
      1. This network is provided for authorized visitors and guests of the enterprise.<br>
      2. Bandwidth consumption is subject to traffic management and prioritization.<br>
      3. Unauthorized network scanning, port probing, and security bypass attempts are logged.<br>
      4. Access is granted for a 12-hour session duration upon acceptance.<br>
      5. Network security audits and compliance inspections occur continuously.
    </div>

    <form method="POST" action="/login">
      <label class="checkbox-row">
        <input type="checkbox" required checked>
        <span>I have read and agree to the Acceptable Use Policy and Wireless Security Terms.</span>
      </label>
      
      <button type="submit">Connect to Guest Network</button>
    </form>
    
    <div class="footer">
      PROTECTED BY 802.1X TELEMETRY • SESSION: GUEST-ISOLATED
    </div>
  </div>
</body>
</html>
"""
    )

    public static let securityAuditDisclosure = CaptivePortalTemplate(
        id: "security_audit_disclosure",
        title: "Security Assessment Scope Disclosure",
        category: "Compliance",
        description: "Official notification informing users that an authorized wireless security assessment is underway under signed RoE.",
        htmlContent: """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Security Audit Notice</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #080a0f; color: #e1e7f0; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
    .card { background: #111520; border: 1px solid rgba(0, 255, 136, 0.3); border-radius: 16px; padding: 32px; max-width: 460px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.8); }
    .badge { display: inline-block; background: rgba(0, 255, 136, 0.15); border: 1px solid #00ff88; color: #00ff88; font-family: monospace; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 6px; margin-bottom: 16px; }
    h1 { font-size: 21px; font-weight: 800; color: #ffffff; letter-spacing: -0.3px; line-height: 1.3; }
    p.lead { font-size: 13px; color: #9bb0cd; margin-top: 10px; line-height: 1.5; }
    .meta-grid { background: #0c0f17; border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; padding: 14px; margin: 20px 0; font-family: monospace; font-size: 11px; display: grid; grid-template-columns: 100px 1fr; gap: 8px; }
    .meta-grid span:nth-child(odd) { color: #5a6e88; }
    .meta-grid span:nth-child(even) { color: #00f0ff; }
    button { width: 100%; background: #00ff88; color: #040d08; border: none; padding: 14px; border-radius: 10px; font-size: 14px; font-weight: 700; cursor: pointer; transition: all 0.2s; }
    button:hover { background: #33ff9f; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">AUTHORIZED ASSESSMENT IN PROGRESS</div>
    <h1>Wireless Security Compliance Audit</h1>
    <p class="lead">This wireless node is participating in an authorized radio spectrum and access control audit conducted under signed contractual Rules of Engagement (RoE).</p>
    
    <div class="meta-grid">
      <span>AUDIT ID:</span><span>ROE-2026-V3SP3R</span>
      <span>SCOPE:</span><span>802.11b/g/n/ac/ax Diagnostic</span>
      <span>OPERATOR:</span><span>Authorized Red Team / SecOps</span>
      <span>STATUS:</span><span>Active Telemetry Collection</span>
    </div>

    <form method="POST" action="/acknowledge">
      <button type="submit">Acknowledge Audit Scope</button>
    </form>
  </div>
</body>
</html>
"""
    )

    public static let networkMaintenanceNotice = CaptivePortalTemplate(
        id: "network_maintenance_notice",
        title: "Network Diagnostic & Maintenance Notice",
        category: "Operations",
        description: "IT operational downtime notice informing connecting clients of scheduled channel calibration.",
        htmlContent: """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scheduled Network Calibration</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #0d111a; color: #e1e7f0; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
    .card { background: #161c28; border: 1px solid rgba(255, 170, 0, 0.3); border-radius: 16px; padding: 32px; max-width: 420px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.7); }
    .icon { font-size: 32px; margin-bottom: 12px; }
    h1 { font-size: 20px; font-weight: 700; color: #ffaa00; }
    p { font-size: 13px; color: #98a9c2; margin-top: 8px; line-height: 1.5; }
    .bar-wrap { background: #090c12; border-radius: 8px; height: 12px; width: 100%; margin: 20px 0 10px; overflow: hidden; border: 1px solid rgba(255,255,255,0.06); }
    .bar-fill { background: linear-gradient(90deg, #ffaa00, #00f0ff); height: 100%; width: 78%; border-radius: 6px; }
    .status-text { font-family: monospace; font-size: 11px; color: #ffaa00; display: flex; justify-content: space-between; }
    .info-box { background: rgba(0,0,0,0.25); border-radius: 8px; padding: 12px; margin-top: 18px; font-size: 11px; color: #7f91aa; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🛠️</div>
    <h1>Network Optimization in Progress</h1>
    <p>Local Access Points are currently undergoing scheduled frequency calibration, channel reassignment, and latency telemetry validation.</p>
    
    <div class="bar-wrap">
      <div class="bar-fill"></div>
    </div>
    <div class="status-text">
      <span>CALIBRATING CHANNELS...</span>
      <span>78%</span>
    </div>

    <div class="info-box">
      Normal connectivity resumes automatically once diagnostic benchmarks conclude. For urgent assistance, contact Internal Network Operations.
    </div>
  </div>
</body>
</html>
"""
    )

    public static let conferenceEventSplash = CaptivePortalTemplate(
        id: "conference_event_splash",
        title: "Conference & Event Wi-Fi Portal",
        category: "Events",
        description: "High-contrast event welcome page with speaker agenda highlights and rapid single-click onboarding.",
        htmlContent: """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CyberSummit 2026 Wi-Fi</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #08070d; color: #e8e6f2; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
    .card { background: #12101f; border: 1px solid rgba(170, 0, 255, 0.3); border-radius: 16px; padding: 32px; max-width: 420px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.8); }
    .event-tag { color: #d580ff; font-family: monospace; font-size: 11px; font-weight: 700; letter-spacing: 1px; }
    h1 { font-size: 24px; font-weight: 800; color: #ffffff; margin: 6px 0 16px; }
    .agenda { background: #0c0a17; border: 1px solid rgba(255,255,255,0.06); border-radius: 10px; padding: 12px; margin-bottom: 20px; }
    .agenda-item { display: flex; justify-content: space-between; font-size: 11px; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.04); }
    .agenda-item:last-child { border-bottom: none; }
    .time { color: #d580ff; font-family: monospace; }
    button { width: 100%; background: linear-gradient(135deg, #aa00ff 0%, #00f0ff 100%); color: #ffffff; border: none; padding: 14px; border-radius: 10px; font-size: 14px; font-weight: 700; cursor: pointer; }
    button:hover { filter: brightness(1.15); }
  </style>
</head>
<body>
  <div class="card">
    <span class="event-tag">OFFICIAL EVENT NETWORK</span>
    <h1>CyberSummit 2026</h1>
    
    <div class="agenda">
      <div class="agenda-item"><span class="time">10:00 AM</span><span>Keynote: Hardware C2 Sovereignty</span></div>
      <div class="agenda-item"><span class="time">11:30 AM</span><span>Sub-GHz Protocol Reverse Engineering</span></div>
      <div class="agenda-item"><span class="time">02:00 PM</span><span>802.11 Management Frame Resilience</span></div>
    </div>

    <form method="POST" action="/connect">
      <button type="submit">Join Event Wi-Fi Network</button>
    </form>
  </div>
</body>
</html>
"""
    )

    public static let all: [CaptivePortalTemplate] = [
        corporateGuestAup,
        securityAuditDisclosure,
        networkMaintenanceNotice,
        conferenceEventSplash
    ]
}
