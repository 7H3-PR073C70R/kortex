import test from "node:test";
import assert from "node:assert/strict";
import {
  isForbiddenIpv4,
  isForbiddenIpv6,
  isForbiddenHostname,
  isSafeOutboundUrl,
} from "./security_guard.ts";

test("SSRF Guard - IPv4 Private, Loopback, Link-Local and CGNAT", () => {
  // 1. Loopback
  assert.equal(isForbiddenIpv4("127.0.0.1"), true, "127.0.0.1 must be blocked");
  assert.equal(isForbiddenIpv4("127.255.255.254"), true, "127.x.x.x must be blocked");

  // 2. RFC 1918 Private
  assert.equal(isForbiddenIpv4("10.0.0.1"), true, "10.0.0.1 must be blocked");
  assert.equal(isForbiddenIpv4("172.16.0.1"), true, "172.16.0.1 must be blocked");
  assert.equal(isForbiddenIpv4("172.31.255.255"), true, "172.31.255.255 must be blocked");
  assert.equal(isForbiddenIpv4("192.168.1.1"), true, "192.168.1.1 must be blocked");

  // 3. CGNAT (100.64.0.0/10)
  assert.equal(isForbiddenIpv4("100.64.0.1"), true, "CGNAT 100.64.0.1 must be blocked");
  assert.equal(isForbiddenIpv4("100.127.255.254"), true, "CGNAT 100.127.x.x must be blocked");

  // 4. Cloud Metadata & Link-Local (169.254.0.0/16)
  assert.equal(isForbiddenIpv4("169.254.169.254"), true, "Cloud metadata 169.254.169.254 must be blocked");
  assert.equal(isForbiddenIpv4("169.254.1.1"), true, "Link-local 169.254.1.1 must be blocked");

  // 5. Current network & Multicast & Broadcast
  assert.equal(isForbiddenIpv4("0.0.0.0"), true, "0.0.0.0 must be blocked");
  assert.equal(isForbiddenIpv4("224.0.0.1"), true, "Multicast 224.0.0.1 must be blocked");
  assert.equal(isForbiddenIpv4("255.255.255.255"), true, "Broadcast 255.255.255.255 must be blocked");

  // Public IPv4 should NOT be forbidden
  assert.equal(isForbiddenIpv4("8.8.8.8"), false, "Public IP 8.8.8.8 must be allowed");
  assert.equal(isForbiddenIpv4("1.1.1.1"), false, "Public IP 1.1.1.1 must be allowed");
  assert.equal(isForbiddenIpv4("104.21.5.12"), false, "Public IP 104.21.5.12 must be allowed");
});

test("SSRF Guard - IPv6 Loopback, ULA, Link-Local and IPv4-Mapped IPv6", () => {
  // 1. Loopback & Unspecified
  assert.equal(isForbiddenIpv6("::1"), true, "::1 loopback must be blocked");
  assert.equal(isForbiddenIpv6("[::1]"), true, "[::1] must be blocked");
  assert.equal(isForbiddenIpv6("::"), true, ":: unspecified must be blocked");

  // 2. IPv4-Mapped IPv6
  assert.equal(isForbiddenIpv6("::ffff:127.0.0.1"), true, "::ffff:127.0.0.1 must be blocked");
  assert.equal(isForbiddenIpv6("::ffff:169.254.169.254"), true, "::ffff:169.254.169.254 must be blocked");
  assert.equal(isForbiddenIpv6("::ffff:10.0.0.1"), true, "::ffff:10.0.0.1 must be blocked");
  assert.equal(isForbiddenIpv6("::ffff:100.64.0.1"), true, "::ffff:100.64.0.1 (CGNAT) must be blocked");

  // 3. Unique Local Address (ULA fd00::/8, fc00::/7)
  assert.equal(isForbiddenIpv6("fd00::1"), true, "fd00::1 ULA must be blocked");
  assert.equal(isForbiddenIpv6("fc00::dead:beef"), true, "fc00:: ULA must be blocked");

  // 4. Link-Local Unicast (fe80::/10)
  assert.equal(isForbiddenIpv6("fe80::1"), true, "fe80::1 link-local must be blocked");
  assert.equal(isForbiddenIpv6("fe80::200:5efe:10.0.0.1"), true, "fe80:: link-local must be blocked");

  // Public IPv6 should NOT be forbidden
  assert.equal(isForbiddenIpv6("2606:4700:4700::1111"), false, "Cloudflare public IPv6 must be allowed");
  assert.equal(isForbiddenIpv6("2001:4860:4860::8888"), false, "Google public IPv6 must be allowed");
});

test("SSRF Guard - Hostname & Rebinding Provider Filtering", () => {
  // 1. Localhost and internal suffixes
  assert.equal(isForbiddenHostname("localhost"), true);
  assert.equal(isForbiddenHostname("foo.localhost"), true);
  assert.equal(isForbiddenHostname("server.local"), true);
  assert.equal(isForbiddenHostname("app.internal"), true);
  assert.equal(isForbiddenHostname("device.lan"), true);

  // 2. Cloud metadata hostnames
  assert.equal(isForbiddenHostname("169.254.169.254"), true);
  assert.equal(isForbiddenHostname("metadata.google.internal"), true);
  assert.equal(isForbiddenHostname("instance-data"), true);

  // 3. Wildcard DNS rebinding domain providers
  assert.equal(isForbiddenHostname("127.0.0.1.nip.io"), true);
  assert.equal(isForbiddenHostname("test.169.254.169.254.nip.io"), true);
  assert.equal(isForbiddenHostname("spoof.sslip.io"), true);
  assert.equal(isForbiddenHostname("localtest.me"), true);
  assert.equal(isForbiddenHostname("app.localtest.me"), true);

  // Safe hostnames
  assert.equal(isForbiddenHostname("supabase.co"), false);
  assert.equal(isForbiddenHostname("kortex.app"), false);
  assert.equal(isForbiddenHostname("cloudflare.com"), false);
});

test("SSRF Guard - isSafeOutboundUrl Comprehensive Vectors", async () => {
  // Protocol rejection
  assert.equal(await isSafeOutboundUrl("ftp://example.com"), false, "ftp must be rejected");
  assert.equal(await isSafeOutboundUrl("file:///etc/passwd"), false, "file schema must be rejected");
  assert.equal(await isSafeOutboundUrl("gopher://127.0.0.1:70"), false, "gopher must be rejected");

  // Vector 1: Loopback
  assert.equal(await isSafeOutboundUrl("http://127.0.0.1/admin"), false);
  assert.equal(await isSafeOutboundUrl("http://localhost:8080"), false);
  assert.equal(await isSafeOutboundUrl("http://[::1]:3000"), false);

  // Vector 2: RFC 1918 Private
  assert.equal(await isSafeOutboundUrl("http://10.0.0.5:8000/api"), false);
  assert.equal(await isSafeOutboundUrl("http://172.16.1.1:5432"), false);
  assert.equal(await isSafeOutboundUrl("http://192.168.1.254/router"), false);

  // Vector 3: CGNAT
  assert.equal(await isSafeOutboundUrl("http://100.64.0.1:9090"), false);

  // Vector 4: Cloud metadata
  assert.equal(await isSafeOutboundUrl("http://169.254.169.254/latest/meta-data/"), false);

  // Vector 5: IPv4-mapped IPv6
  assert.equal(await isSafeOutboundUrl("http://[::ffff:127.0.0.1]/"), false);
  assert.equal(await isSafeOutboundUrl("http://[::ffff:169.254.169.254]/"), false);

  // Vector 6: ULA IPv6
  assert.equal(await isSafeOutboundUrl("http://[fd00::1]:80/"), false);

  // Vector 7: Link-local IPv6
  assert.equal(await isSafeOutboundUrl("http://[fe80::1]:80/"), false);

  // Vector 8: DNS rebinding wildcard domains
  assert.equal(await isSafeOutboundUrl("http://127.0.0.1.nip.io/exploit"), false);
  assert.equal(await isSafeOutboundUrl("http://169.254.169.254.nip.io/"), false);
  assert.equal(await isSafeOutboundUrl("http://localtest.me:8000/"), false);

  // Valid external URLs
  assert.equal(await isSafeOutboundUrl("https://8.8.8.8/dns-query"), true);
  assert.equal(await isSafeOutboundUrl("https://1.1.1.1/cdn-cgi/trace"), true);
});
