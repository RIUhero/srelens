// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const config = JSON.parse(
  readFileSync(new URL("../src-tauri/tauri.conf.json", import.meta.url), "utf8"),
) as { app: { security: { csp: string | null; devCsp?: string | null } } };

describe("Tauri CSP", () => {
  it("has a fail-closed production policy", () => {
    const csp = config.app.security.csp;
    expect(csp).not.toBeNull();
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("connect-src 'self' ipc: http://ipc.localhost");
    expect(csp).toContain("object-src 'none'");
    expect(csp).not.toContain("'unsafe-eval'");
    expect(csp).not.toContain("*");
    expect(csp).not.toContain("localhost:1450");
  });

  it("limits development exceptions to the fixed Vite origin", () => {
    const devCsp = config.app.security.devCsp;
    expect(devCsp).toContain("http://localhost:1450");
    expect(devCsp).toContain("ws://localhost:1450");
    expect(devCsp).not.toContain("'unsafe-eval'");
    expect(devCsp).not.toContain("*");
  });
});
