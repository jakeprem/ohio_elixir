import { ImageResponse } from "@takumi-rs/image-response";

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

// Calculate dynamic font size based on title length
function getTitleFontSize(title: string): number {
  const len = title.length;
  if (len <= 20) return 80;
  if (len <= 35) return 64;
  if (len <= 50) return 52;
  if (len <= 70) return 42;
  return 34;
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
          alignItems: "center",
          justifyContent: "center",
          width: "100%",
          height: "100%",
          backgroundColor: "#5A3E99",
          backgroundImage: "linear-gradient(135deg, #667eea 0%, #5A3E99 50%, #764ba2 100%)",
          padding: "60px 80px",
          fontFamily: "Geist, sans-serif",
        }}
      >
        {/* Top: Ohio Elixir branding */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            marginBottom: 32,
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: 64,
              height: 64,
              backgroundColor: "rgba(255,255,255,0.2)",
              borderRadius: 32,
              marginRight: 16,
            }}
          >
            <span style={{ color: "white", fontSize: 32, fontWeight: 700 }}>OE</span>
          </div>
          <span
            style={{
              color: "rgba(255,255,255,0.8)",
              fontSize: 24,
              fontWeight: 600,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
            }}
          >
            Ohio Elixir
          </span>
        </div>

        {/* Main title - dynamically sized */}
        <div
          style={{
            display: "flex",
            textAlign: "center",
            color: "white",
            fontWeight: 700,
            lineHeight: 1.1,
            maxWidth: 1000,
            fontSize: titleFontSize,
            textShadow: "0 2px 10px rgba(0,0,0,0.3)",
          }}
        >
          {title}
        </div>

        {/* Subtitle (date + venue) */}
        {subtitle && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              color: "rgba(255,255,255,0.85)",
              fontSize: 30,
              marginTop: 32,
              fontWeight: 500,
            }}
          >
            <div
              style={{
                width: 32,
                height: 2,
                backgroundColor: "rgba(255,255,255,0.5)",
                marginRight: 16,
                borderRadius: 1,
              }}
            />
            {subtitle}
            <div
              style={{
                width: 32,
                height: 2,
                backgroundColor: "rgba(255,255,255,0.5)",
                marginLeft: 16,
                borderRadius: 1,
              }}
            />
          </div>
        )}

        {/* Bottom: website */}
        <div
          style={{
            display: "flex",
            position: "absolute",
            bottom: 48,
          }}
        >
          <span
            style={{
              color: "rgba(255,255,255,0.5)",
              fontSize: 18,
              letterSpacing: "0.05em",
            }}
          >
            ohioelixir.com
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
