import { ImageResponse } from "@takumi-rs/image-response";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// Get the directory of this script to find the logo
const __dirname = dirname(fileURLToPath(import.meta.url));
const logoPath = join(__dirname, "..", "static", "images", "logo.webp");

// Load and encode logo as base64 data URL
let logoDataUrl: string;
try {
  const logoBuffer = readFileSync(logoPath);
  const base64 = logoBuffer.toString("base64");
  logoDataUrl = `data:image/webp;base64,${base64}`;
} catch (error) {
  console.error("Warning: Could not load logo.webp, using fallback");
  logoDataUrl = "";
}

// Parse command-line arguments - expects JSON as first arg
const args = process.argv.slice(2);

if (args.length === 0) {
  console.error("Usage: bun run og-generator.tsx '{\"title\":\"...\",\"subtitle\":\"...\"}'");
  process.exit(1);
}

let params: { title?: string; subtitle?: string };
try {
  params = JSON.parse(args[0]);
} catch {
  console.error("Invalid JSON input");
  process.exit(1);
}

const { title, subtitle } = params;

if (!title) {
  console.error("Missing required parameter: title");
  process.exit(1);
}

// Calculate dynamic font size based on title length - scaled up for better space usage
function getTitleFontSize(title: string): number {
  const len = title.length;
  if (len <= 15) return 96;
  if (len <= 25) return 84;
  if (len <= 40) return 72;
  if (len <= 55) return 60;
  if (len <= 70) return 52;
  return 44;
}

const titleFontSize = getTitleFontSize(title);

// Generate the image using inline styles (required for Satori/Takumi)
try {
  const response = new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          width: "100%",
          height: "100%",
          backgroundColor: "#1a1a2e",
          fontFamily: "Geist, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Background gradient overlay */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundImage: "linear-gradient(135deg, #667eea 0%, #4a3a8c 40%, #764ba2 100%)",
            display: "flex",
          }}
        />

        {/* Decorative geometric elements */}
        <div
          style={{
            position: "absolute",
            top: -100,
            right: -100,
            width: 400,
            height: 400,
            borderRadius: 200,
            backgroundColor: "rgba(255,255,255,0.05)",
            display: "flex",
          }}
        />
        <div
          style={{
            position: "absolute",
            bottom: -150,
            left: -150,
            width: 500,
            height: 500,
            borderRadius: 250,
            backgroundColor: "rgba(255,255,255,0.03)",
            display: "flex",
          }}
        />

        {/* Main content area */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            flex: 1,
            padding: "60px 80px 80px 80px",
            position: "relative",
          }}
        >
          {/* Logo - larger and more prominent */}
          <div
            style={{
              display: "flex",
              marginBottom: 40,
            }}
          >
            {logoDataUrl ? (
              <img
                src={logoDataUrl}
                width={120}
                height={120}
                style={{
                  filter: "drop-shadow(0 4px 20px rgba(0,0,0,0.3))",
                }}
              />
            ) : (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: 120,
                  height: 120,
                  backgroundColor: "rgba(255,255,255,0.15)",
                  borderRadius: 60,
                }}
              >
                <span style={{ color: "white", fontSize: 48, fontWeight: 700 }}>OE</span>
              </div>
            )}
          </div>

          {/* Main title - large and impactful */}
          <div
            style={{
              display: "flex",
              textAlign: "center",
              color: "white",
              fontWeight: 700,
              lineHeight: 1.1,
              maxWidth: 1000,
              fontSize: titleFontSize,
              textShadow: "0 4px 20px rgba(0,0,0,0.4)",
              letterSpacing: "-0.02em",
            }}
          >
            {title}
          </div>

          {/* Subtitle with decorative accent */}
          {subtitle && (
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                marginTop: 36,
              }}
            >
              {/* Accent line */}
              <div
                style={{
                  width: 60,
                  height: 4,
                  backgroundColor: "#FD4F00",
                  borderRadius: 2,
                  marginBottom: 24,
                  display: "flex",
                }}
              />
              <div
                style={{
                  display: "flex",
                  color: "rgba(255,255,255,0.9)",
                  fontSize: 36,
                  fontWeight: 500,
                  letterSpacing: "0.01em",
                }}
              >
                {subtitle}
              </div>
            </div>
          )}
        </div>

        {/* Footer bar */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            padding: "24px 80px",
            backgroundColor: "rgba(0,0,0,0.2)",
          }}
        >
          <span
            style={{
              color: "rgba(255,255,255,0.85)",
              fontSize: 24,
              fontWeight: 500,
              letterSpacing: "0.02em",
            }}
          >
            www.ohioelixir.com
          </span>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );

  const buffer = await response.arrayBuffer();
  const uint8 = new Uint8Array(buffer);

  // Write raw PNG bytes to stdout
  await Bun.write(Bun.stdout, uint8);
} catch (error) {
  console.error("Error generating image:", error instanceof Error ? error.message : error);
  process.exit(1);
}
