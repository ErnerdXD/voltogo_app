import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const url = new URL(req.url);
  const resId = url.searchParams.get("res_id");

  if (!resId) {
    return new Response("Missing reservation ID", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const { data: res, error } = await supabase
    .from("reservations")
    .select(`
      id,
      status,
      start_time,
      end_time,
      current_battery,
      vehicle_id,
      slots (
        slot_code,
        connector_type,
        price_per_kwh,
        stations (
          name,
          address
)
)
`)
.eq("id", resId)
    .maybeSingle();

  if (error || !res) {
    return new Response("Reservation not found", { status: 404 });
  }

  // Fetch vehicle info
  const { data: vehicle } = await supabase
    .from("vehicles")
    .select("brand, model, plate_number, battery_capacity_kwh")
    .eq("id", res.vehicle_id)
    .maybeSingle();

  const slot = (res as any).slots ?? {};
  const station = slot.stations ?? {};
  const startBattery = res.current_battery ?? 30;
  const batteryCapacity = vehicle?.battery_capacity_kwh ?? 40;
  const pricePerKwh = slot.price_per_kwh ?? 0;

  const escape = (s: string) =>
    (s ?? "").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  const stationName = escape(station.name ?? "Charging Station");
  const stationAddress = escape(station.address ?? "");
  const connectorType = escape(slot.connector_type ?? "");
  const slotCode = escape(slot.slot_code ?? "");
  const vehicleLabel = vehicle
    ? escape(`${vehicle.brand ?? ""} ${vehicle.model ?? ""}`.trim())
    : "";
  const plateNumber = escape(vehicle?.plate_number ?? "");

  const startTime = res.start_time
    ? new Date(res.start_time).toLocaleTimeString("en-MY", {
        hour: "2-digit",
        minute: "2-digit",
      })
    : "--:--";
  const endTime = res.end_time
    ? new Date(res.end_time).toLocaleTimeString("en-MY", {
        hour: "2-digit",
        minute: "2-digit",
      })
    : "--:--";

  const statusColor =
    res.status === "active"
      ? "#4caf50"
      : res.status === "paid"
      ? "#4fc3f7"
      : "#ff9800";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Voltogo – Charging Tracker</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      background: #0f1117;
      color: white;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }

    .logo {
      font-size: 22px;
      font-weight: 800;
      color: #4fc3f7;
      letter-spacing: 1px;
      margin-bottom: 20px;
    }

    .logo span { color: #ffffff; }

    .card {
      background: #1a1d27;
      border-radius: 20px;
      padding: 24px;
      width: 100%;
      max-width: 380px;
      margin-bottom: 16px;
    }

    .section-label {
      font-size: 11px;
      color: #666;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 8px;
    }

    .station-name {
      font-size: 18px;
      font-weight: 700;
      color: #4fc3f7;
      margin-bottom: 4px;
    }

    .station-address {
      font-size: 13px;
      color: #888;
      margin-bottom: 12px;
    }

    .badges {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 4px;
    }

    .badge {
      background: #252836;
      border: 1px solid #333;
      border-radius: 20px;
      padding: 4px 12px;
      font-size: 12px;
      color: #ccc;
    }

    .status-badge {
      background: ${statusColor}22;
      border: 1px solid ${statusColor};
      color: ${statusColor};
    }

    .divider {
      border: none;
      border-top: 1px solid #2a2d3a;
      margin: 16px 0;
    }

    /* Battery ring */
    .battery-wrap {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 8px 0 16px;
    }

    .ring-container {
      position: relative;
      width: 160px;
      height: 160px;
      margin-bottom: 12px;
    }

    svg.ring {
      transform: rotate(-90deg);
      width: 160px;
      height: 160px;
    }

    .ring-track { fill: none; stroke: #252836; stroke-width: 12; }
    .ring-fill  { fill: none; stroke: #4fc3f7; stroke-width: 12;
                  stroke-linecap: round;
                  stroke-dasharray: 408;
                  stroke-dashoffset: 408;
                  transition: stroke-dashoffset 0.8s ease; }

    .ring-label {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
    }

    .ring-pct {
      font-size: 38px;
      font-weight: 800;
      line-height: 1;
    }

    .ring-sub {
      font-size: 12px;
      color: #888;
      margin-top: 4px;
    }

    .charging-label {
      font-size: 13px;
      color: #4fc3f7;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .dot {
      width: 8px;
      height: 8px;
      background: #4fc3f7;
      border-radius: 50%;
      animation: pulse 1.2s infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50%       { opacity: 0.4; transform: scale(0.7); }
    }

    /* Info rows */
    .info-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 0;
      border-bottom: 1px solid #252836;
      font-size: 14px;
    }

    .info-row:last-child { border-bottom: none; }

    .info-key { color: #888; }
    .info-val { font-weight: 600; color: #eee; }

    .time-row {
      display: flex;
      justify-content: space-between;
      margin-top: 12px;
    }

    .time-block {
      text-align: center;
      flex: 1;
    }

    .time-block:first-child { text-align: left; }
    .time-block:last-child  { text-align: right; }

    .time-val {
      font-size: 20px;
      font-weight: 700;
      color: #fff;
    }

    .time-key { font-size: 11px; color: #666; margin-top: 2px; }

    .footer {
      font-size: 12px;
      color: #444;
      margin-top: 8px;
      text-align: center;
    }
  </style>
</head>
<body>

  <div class="logo">volt<span>ogo</span> ⚡</div>

  <!-- Station card -->
  <div class="card">
    <div class="section-label">Charging at</div>
    <div class="station-name">${stationName}</div>
    ${stationAddress ? `<div class="station-address">📍 ${stationAddress}</div>` : ""}
    <div class="badges">
      ${slotCode ? `<span class="badge">🔌 ${slotCode}</span>` : ""}
      ${connectorType ? `<span class="badge">${connectorType}</span>` : ""}
      ${pricePerKwh ? `<span class="badge">RM${Number(pricePerKwh).toFixed(2)}/kWh</span>` : ""}
      <span class="badge status-badge">${res.status ?? "unknown"}</span>
    </div>
  </div>

  <!-- Battery card -->
  <div class="card">
    <div class="battery-wrap">
      <div class="ring-container">
        <svg class="ring" viewBox="0 0 160 160">
          <circle class="ring-track" cx="80" cy="80" r="65"/>
          <circle class="ring-fill" id="ringFill" cx="80" cy="80" r="65"/>
        </svg>
        <div class="ring-label">
          <div class="ring-pct" id="pct">0%</div>
          <div class="ring-sub">battery</div>
        </div>
      </div>
      <div class="charging-label">
        <div class="dot"></div>
        Charging in progress
      </div>
    </div>

    <hr class="divider"/>

    <div class="info-row">
      <span class="info-key">Start battery</span>
      <span class="info-val">${startBattery}%</span>
    </div>
    <div class="info-row">
      <span class="info-key">Capacity</span>
      <span class="info-val">${batteryCapacity} kWh</span>
    </div>
    <div class="info-row">
      <span class="info-key">Est. added energy</span>
      <span class="info-val" id="kwh">-- kWh</span>
    </div>
    <div class="info-row">
      <span class="info-key">Est. cost so far</span>
      <span class="info-val" id="cost">RM --</span>
    </div>

    <hr class="divider"/>

    <div class="time-row">
      <div class="time-block">
        <div class="time-val">${startTime}</div>
        <div class="time-key">Start</div>
      </div>
      <div class="time-block">
        <div class="time-val">${endTime}</div>
        <div class="time-key">End</div>
      </div>
    </div>
  </div>

  <!-- Vehicle card -->
  ${vehicleLabel || plateNumber ? `
  <div class="card">
    <div class="section-label">Vehicle</div>
    ${vehicleLabel ? `<div class="info-row"><span class="info-key">Car</span><span class="info-val">${vehicleLabel}</span></div>` : ""}
    ${plateNumber ? `<div class="info-row"><span class="info-key">Plate</span><span class="info-val">${plateNumber}</span></div>` : ""}
  </div>
  ` : ""}

  <div class="footer">Booking ID: ${resId.substring(0, 8).toUpperCase()}</div>

<script>
  const CIRCUMFERENCE = 2 * Math.PI * 65; // ~408.4
  const ring = document.getElementById("ringFill");
  const pctEl = document.getElementById("pct");
  const kwhEl = document.getElementById("kwh");
  const costEl = document.getElementById("cost");

  const capacity = ${batteryCapacity};
  const pricePerKwh = ${pricePerKwh};
  let battery = ${startBattery};

  function setRing(pct) {
    const offset = CIRCUMFERENCE * (1 - pct / 100);
    ring.style.strokeDashoffset = offset;
    ring.style.strokeDasharray = CIRCUMFERENCE;

    // Color: red < 20, orange < 50, green > 80, else blue
    if (pct < 20)       ring.style.stroke = "#f44336";
    else if (pct < 50)  ring.style.stroke = "#ff9800";
    else if (pct >= 80) ring.style.stroke = "#4caf50";
    else                ring.style.stroke = "#4fc3f7";
  }

  function update() {
    pctEl.textContent = battery + "%";
    const kwhAdded = ((battery - ${startBattery}) / 100) * capacity;
    kwhEl.textContent = kwhAdded.toFixed(1) + " kWh";
    costEl.textContent = "RM " + (kwhAdded * pricePerKwh).toFixed(2);
    setRing(battery);
  }

  update();

  const interval = setInterval(() => {
    if (battery >= 100) { clearInterval(interval); return; }
    battery++;
    update();
  }, 1000);
</script>
</body>
</html>`;

   return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Access-Control-Allow-Origin": "*",
    },
  });
});